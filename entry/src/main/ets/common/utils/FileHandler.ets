import Logger from './Logger';
import { BusinessError } from '@ohos.base';
import fs, { Options } from '@ohos.file.fs';
import { common } from '@kit.AbilityKit';
import { chaptersItem } from 'ets/componets/dataList/ReaderChaptersItem';
import { showMessage } from '../../componets/common/promptShow';
import { picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { buffer } from '@kit.ArkTS'
import localBookImportService, {
  LOCAL_BOOK_FILE_SUFFIX_FILTERS,
  LocalBookImportCandidate,
  LocalBookImportStatus
} from './LocalBookImportService';


let options: Options = {
  encoding: 'utf-8'
};

export class FileHandler {
  static createImportRequestId(): string {
    return util.generateRandomUUID();
  }

  // Never log arbitrary platform messages: they can contain paths or document names.
  private static logImportError(requestId: string, stage: string, error: BusinessError) {
    Logger.error('LocalImport picker failed', stage, error.code ?? 0);
  }

  static async CopyFile(context: common.UIAbilityContext, srcUrl: string, currentIndex: number,
    requestId: string = FileHandler.createImportRequestId()): Promise<boolean> {
    if (!context || !context.filesDir || !srcUrl) {
      showMessage('本地导入失败，请查看 LocalImport 日志');
      return false;
    }
    const scanResult = await localBookImportService.scanPickerUris([srcUrl], requestId);
    if (scanResult.candidates.length === 0) {
      showMessage('本地导入失败，请查看 LocalImport 日志');
      return false;
    }
    const candidate: LocalBookImportCandidate = scanResult.candidates[0];
    if (candidate.status === LocalBookImportStatus.DUPLICATE) {
      showMessage('该本地书籍已存在');
      return false;
    }
    if (candidate.status !== LocalBookImportStatus.READY) {
      showMessage(candidate.message.length > 0 ? candidate.message : '本地导入失败，请查看 LocalImport 日志');
      return false;
    }
    const result = await localBookImportService.importSingle(context, candidate, currentIndex, requestId);
    if (result.status === LocalBookImportStatus.IMPORTED) {
      showMessage('导入并添加到书架成功');
      return true;
    }
    if (result.status === LocalBookImportStatus.DUPLICATE) {
      showMessage('该本地书籍已存在');
      return false;
    }
    showMessage('本地导入失败，请查看 LocalImport 日志');
    return false;
  }

  //动态获取文件大小
  static async ReadJSONFile(srcUrl: string) {
    try {
      let file = fs.openSync(srcUrl, fs.OpenMode.READ_WRITE);
      let stat = fs.statSync(file.path)
      let arrayBuffer = new ArrayBuffer(stat.size);
      let readLen: number = await fs.read(file.fd, arrayBuffer)
      let JSONString = buffer.from(arrayBuffer, 0, readLen).toString();
      return JSONString
    } catch (e) {
      Logger.error('FileHandler.ReadJSONFile failed', Logger.errorSummary(e));
      return ''
    }
  }

  static async readFile(readFileUrl: string) {
    let chapterNumber = 0
    const chapters: chaptersItem[] = [];
    //const regex = /===第(.*?)章 (.*?)===/g;
    const regex =
      /^[=|<]{0,4}((?:序章|楔子|番外|第\s{0,4})([\d〇零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+?\s{0,4})(?:章|回(?!合)|话(?!说)|节(?!课)|卷|篇(?!张)))(.{0,30})/g;
    await fs.readLines(readFileUrl, options).then((readerIterator: fs.ReaderIterator) => {
      for (let it = readerIterator.next();!it.done; it = readerIterator.next()) {
        const match = regex.exec(it.value);
        if (match) {
          const chapterTitleNumber = match[1]; // 书源内部章节
          const chapterTitle = match[3];
          chapterNumber++
          chapters.push(new chaptersItem(chapterNumber, chapterTitle, chapterTitleNumber, ''))
        } else {
          if (chapters.length > 0) {
            chapters[chapters.length - 1].content += it.value
          }
        }
      }
    }).catch((err: BusinessError) => {
      Logger.error('FileHandler.readFile failed', Logger.errorSummary(err));
    });
    // 移除chapters中content内容字符不超过5个字符的删除
    for (let i = 0; i < chapters.length; i++) {
      if (chapters[i].content.length < 5) {
        chapters.splice(i, 1)
        i--
      }
    }
    return chapters
  }

  static readonly LOCAL_BOOK_FILE_SUFFIX_FILTERS: string[] = LOCAL_BOOK_FILE_SUFFIX_FILTERS;

  static canPickDirectory(): boolean {
    return localBookImportService.canPickDirectory();
  }

  static async documentPickerDirectory(context: common.UIAbilityContext,
    requestId: string = FileHandler.createImportRequestId()): Promise<string[]> {
    return await localBookImportService.pickDirectoryUris(context, requestId);
  }

  static async documentPickerFile(context: common.UIAbilityContext, fileSuffixFilters: Array<string>,
    maxSelectNumber: number = 1, requestId: string = FileHandler.createImportRequestId()): Promise<string[]> {
    let stage = 'picker.context';
    try {
      if (!context) {
        throw new Error('Import context unavailable');
      }
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = maxSelectNumber;
      documentSelectOptions.selectMode = picker.DocumentSelectMode.FILE;
      documentSelectOptions.fileSuffixFilters = fileSuffixFilters;
      stage = 'picker.construct';
      const documentViewPicker = new picker.DocumentViewPicker(context);
      stage = 'picker.select';
      const result: Array<string> = await documentViewPicker.select(documentSelectOptions);
      return result;
    } catch (error) {
      const err = error as BusinessError;
      FileHandler.logImportError(requestId, stage, err);
      // Do not guess cancellation from an undocumented error code.
      showMessage('文件选择未完成，请查看 LocalImport 日志');
      return [];
    }
  }

  static async readJsonFile<T>(pathUrl: string): Promise<T | undefined> {
    try {
      const readString = await fs.readText(pathUrl);
      const data: T = JSON.parse(readString)
      return data
    } catch (err) {
      Logger.error('FileHandler.readJsonFile failed', Logger.errorSummary(err));
      return undefined
    }
  }

  static writeJsonFile(pathUrl: string, context: ArrayBuffer | string) {
    try {
      // 创建文件，并且写入内容，若是存在则重写内容
      let res = fs.accessSync(pathUrl);
      let file: fs.File
      if (res) {
        file = fs.openSync(pathUrl, fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      } else {
        file = fs.openSync(pathUrl, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      }
      fs.writeSync(file.fd, context)
      fs.close(file);
      return '写入成功'
    } catch (e) {
      Logger.error('FileHandler.writeJsonFile failed', Logger.errorSummary(e))
      return '写入失败' + JSON.stringify(e)
    }
  }

  static deleteJsonFile(pathUrl: string) {
    try {
      fs.unlinkSync(pathUrl);
      return '删除成功'
    } catch (e) {
      Logger.error('FileHandler.deleteJsonFile failed', Logger.errorSummary(e))
      return '删除失败'
    }
  }
}