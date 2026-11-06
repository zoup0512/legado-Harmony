import fs from '@ohos.file.fs';
import { common } from '@kit.AbilityKit';
import { hash, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { font } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { READER_BUILTIN_FONT_FILE_NAME, ReaderFontImportFiles, ReaderFontLogic } from './ReaderFontLogic';

/** 阅读器可选字体 */
export class ReaderFontOption {
  name: string = '';
  /** 字体文件绝对路径；空串表示跟随系统字体 */
  path: string = '';
  builtin: boolean = false;
  /** 内容版本用于预览身份；同一路径覆盖后也必须重新注册字体。 */
  contentHash: string = '';
}

const TAG = 'ReaderFont';
export const SYSTEM_FONT_NAME: string = '系统字体';
export const BUILTIN_FONT_NAME: string = '钉钉进步体';
const FONT_SUFFIX_FILTERS: string[] = ['.ttf', '.otf'];
const FONT_IMPORT_MAX_COUNT: number = 5;

class NativeReaderFontImportFiles implements ReaderFontImportFiles {
  async validate(path: string, expectedSize: number): Promise<string> {
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const stat = fs.statSync(file.fd);
      if (!stat.isFile() || stat.size <= 0 || stat.size !== expectedSize) {
        throw new Error('字体文件为空或拷贝不完整');
      }
      const head = new ArrayBuffer(4);
      if (fs.readSync(file.fd, head, { length: 4 }) !== 4 ||
        !ReaderFontLogic.hasFontSignature(new Uint8Array(head))) {
        throw new Error('不是有效的字体文件');
      }
    } finally {
      fs.closeSync(file);
    }
    return await hash.hash(path, 'sha256');
  }

  rename(source: string, target: string): void {
    // 不先 unlink：平台不支持替换或 rename 失败时，保留旧目标并报告失败。
    fs.renameSync(source, target);
  }

  removeTemporary(path: string): void {
    if (path.length === 0) {
      return;
    }
    try {
      if (fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
    } catch (error) {
      hilog.warn(0x0000, TAG, 'cleanup font temporary file failed: %{public}s', JSON.stringify(error));
    }
  }
}

/** 阅读字体管理：内置字体、用户导入、版本化预览和 ReaderKit 字体资源。 */
export class ReaderFontManager {
  private static fontBufferCache: Map<string, ArrayBuffer> = new Map();
  private static registeredPreviewFamilies: Set<string> = new Set();
  private static importFiles: ReaderFontImportFiles = new NativeReaderFontImportFiles();

  static fontsDir(context: common.UIAbilityContext): string {
    return context.filesDir + '/fonts';
  }

  static async ensureBuiltinFont(context: common.UIAbilityContext): Promise<string> {
    const dir = ReaderFontManager.fontsDir(context);
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir, true);
    }
    const targetPath = dir + '/' + READER_BUILTIN_FONT_FILE_NAME;
    if (fs.accessSync(targetPath)) {
      return targetPath;
    }
    const raw = await context.resourceManager.getRawFileContent(READER_BUILTIN_FONT_FILE_NAME);
    const tempPath = dir + '/.' + util.generateRandomUUID() + '.copying';
    try {
      const file = fs.openSync(tempPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        // slice 复制有效视图，避免把底层 buffer 的其它字节写进字体。
        fs.writeSync(file.fd, raw.slice().buffer as ArrayBuffer);
      } finally {
        fs.closeSync(file);
      }
      await ReaderFontManager.importFiles.validate(tempPath, raw.byteLength);
      // 另一个请求可能已完成提取，无需再次替换。
      if (!fs.accessSync(targetPath)) {
        ReaderFontManager.importFiles.rename(tempPath, targetPath);
        ReaderFontManager.fontBufferCache.delete(targetPath);
      }
      return targetPath;
    } finally {
      ReaderFontManager.importFiles.removeTemporary(tempPath);
    }
  }

  /** 系统字体 + 内置字体 + fonts 目录下的导入字体，目录即清单。 */
  static async listFontOptions(context: common.UIAbilityContext): Promise<ReaderFontOption[]> {
    const options: ReaderFontOption[] = [];
    const system = new ReaderFontOption();
    system.name = SYSTEM_FONT_NAME;
    options.push(system);
    try {
      const builtinPath = await ReaderFontManager.ensureBuiltinFont(context);
      const builtin = new ReaderFontOption();
      builtin.name = BUILTIN_FONT_NAME;
      builtin.path = builtinPath;
      builtin.builtin = true;
      builtin.contentHash = await hash.hash(builtinPath, 'sha256');
      options.push(builtin);
    } catch (error) {
      hilog.error(0x0000, TAG, 'ensureBuiltinFont failed: %{public}s', JSON.stringify(error));
    }
    const dir = ReaderFontManager.fontsDir(context);
    if (fs.accessSync(dir)) {
      const fileNames = fs.listFileSync(dir).sort();
      for (let index = 0; index < fileNames.length; index++) {
        const fileName = fileNames[index];
        if (!ReaderFontManager.isFontFile(fileName) || fileName === READER_BUILTIN_FONT_FILE_NAME) {
          continue;
        }
        try {
          const path = dir + '/' + fileName;
          if (!fs.statSync(path).isFile()) {
            continue;
          }
          const option = new ReaderFontOption();
          option.name = ReaderFontManager.baseName(fileName);
          option.path = path;
          option.contentHash = await hash.hash(path, 'sha256');
          options.push(option);
        } catch (error) {
          hilog.warn(0x0000, TAG, 'inspect font failed: %{public}s', JSON.stringify(error));
        }
      }
    }
    return options;
  }

  static async pickFontUris(context: common.UIAbilityContext): Promise<string[]> {
    try {
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = FONT_IMPORT_MAX_COUNT;
      options.fileSuffixFilters = FONT_SUFFIX_FILTERS;
      const documentPicker = new picker.DocumentViewPicker(context);
      return await documentPicker.select(options);
    } catch (error) {
      hilog.error(0x0000, TAG, 'pick font cancelled or failed: %{public}s', JSON.stringify(error));
      return [];
    }
  }

  /** 唯一临时文件先校验再提交，同名替换失败不损坏原文件和缓存。 */
  static async importFont(context: common.UIAbilityContext, sourceUri: string): Promise<ReaderFontOption> {
    let source: fs.File | undefined;
    let tempPath = '';
    try {
      source = fs.openSync(sourceUri, fs.OpenMode.READ_ONLY);
      const originalName = ReaderFontManager.safeFileName(source.name);
      if (originalName.length === 0 || !ReaderFontManager.isFontFile(originalName)) {
        throw new Error('不是有效的字体文件');
      }
      ReaderFontLogic.assertImportName(originalName);
      const sourceStat = fs.statSync(source.fd);
      if (!sourceStat.isFile() || sourceStat.size <= 0) {
        throw new Error('字体文件为空或不是普通文件');
      }
      const dir = ReaderFontManager.fontsDir(context);
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }
      const finalPath = dir + '/' + originalName;
      tempPath = dir + '/.' + util.generateRandomUUID() + '.importing';
      await fs.copyFile(source.fd, tempPath, 0);
      const contentHash = await ReaderFontLogic.commitImport(ReaderFontManager.importFiles,
        tempPath, finalPath, sourceStat.size, ReaderFontManager.fontBufferCache);
      const option = new ReaderFontOption();
      option.name = ReaderFontManager.baseName(originalName);
      option.path = finalPath;
      option.contentHash = contentHash;
      hilog.info(0x0000, TAG, 'font imported size=%{public}d', sourceStat.size);
      return option;
    } finally {
      if (source) {
        try {
          fs.closeSync(source);
        } catch (_) {
        }
      }
      // copy 失败也要清理；已提交或已清理的临时路径不会再次删除任何目标。
      ReaderFontManager.importFiles.removeTemporary(tempPath);
    }
  }

  static deleteFont(option: ReaderFontOption): boolean {
    const fileName = option.path.substring(option.path.lastIndexOf('/') + 1);
    if (option.builtin || option.path.length === 0 || fileName === READER_BUILTIN_FONT_FILE_NAME) {
      return false;
    }
    try {
      if (fs.accessSync(option.path)) {
        fs.unlinkSync(option.path);
      }
      ReaderFontManager.fontBufferCache.delete(option.path);
      return true;
    } catch (error) {
      hilog.error(0x0000, TAG, 'delete font failed: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  static isFontAvailable(path: string): boolean {
    if (path.length === 0) {
      return false;
    }
    try {
      return fs.accessSync(path);
    } catch (_) {
      return false;
    }
  }

  static displayNameOf(path: string): string {
    return ReaderFontManager.baseName(path.substring(path.lastIndexOf('/') + 1));
  }

  /** 只为当前字体的完整路径提供字节；空 buffer 不代表 SDK 已承诺默认回退。 */
  static serveFontResource(context: common.UIAbilityContext, selectedPath: string, url: string): ArrayBuffer {
    if (!ReaderFontLogic.matchesResource(ReaderFontManager.fontsDir(context), selectedPath, url)) {
      return new ArrayBuffer(0);
    }
    try {
      return ReaderFontManager.readFontBuffer(selectedPath);
    } catch (error) {
      hilog.warn(0x0000, TAG, 'read selected font failed: %{public}s', JSON.stringify(error));
      return new ArrayBuffer(0);
    }
  }

  private static readFontBuffer(path: string): ArrayBuffer {
    const cached = ReaderFontManager.fontBufferCache.get(path);
    if (cached) {
      return cached;
    }
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const stat = fs.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);
      if (fs.readSync(file.fd, buffer) !== stat.size) {
        throw new Error('字体读取不完整');
      }
      ReaderFontManager.fontBufferCache.set(path, buffer);
      return buffer;
    } finally {
      fs.closeSync(file);
    }
  }

  /** 只记住成功的版本化注册，失败时允许下次刷新重试。 */
  static registerFontForPreview(option: ReaderFontOption): string {
    const familyName = ReaderFontManager.previewFamilyOf(option);
    if (familyName.length === 0 || ReaderFontManager.registeredPreviewFamilies.has(familyName)) {
      return familyName;
    }
    try {
      font.registerFont({ familyName: familyName, familySrc: option.path });
      ReaderFontManager.registeredPreviewFamilies.add(familyName);
      return familyName;
    } catch (error) {
      hilog.warn(0x0000, TAG, 'register preview failed: %{public}s', JSON.stringify(error));
      return '';
    }
  }

  static previewFamilyOf(option: ReaderFontOption): string {
    return ReaderFontLogic.previewFamily(option.path, option.contentHash);
  }

  private static isFontFile(fileName: string): boolean {
    return /\.(ttf|otf)$/i.test(fileName);
  }

  private static baseName(fileName: string): string {
    const dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }

  private static safeFileName(rawName: string): string {
    let name = rawName;
    const slash = Math.max(name.lastIndexOf('/'), name.lastIndexOf('\\'));
    if (slash >= 0) {
      name = name.substring(slash + 1);
    }
    name = name.replace(/[\\/:*?"<>|\x00-\x1f]/g, '_').trim();
    if (name.length > 100) {
      const dot = name.lastIndexOf('.');
      const ext = dot > 0 ? name.substring(dot) : '';
      name = name.substring(0, 100 - ext.length) + ext;
    }
    return name;
  }
}
