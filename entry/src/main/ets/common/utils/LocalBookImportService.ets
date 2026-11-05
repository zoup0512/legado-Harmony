import { BusinessError } from '@ohos.base';
import fs from '@ohos.file.fs';
import { common } from '@kit.AbilityKit';
import { fileUri, hash, ListFileOptions, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import BooksDao from '../../database/dao/BooksDao';
import { Books } from '../../database/entities/Books';

export const LOCAL_BOOK_FILE_SUFFIX_FILTERS: string[] = ['.txt', '.epub', '.mobi', '.azw', '.azw3'];
export const LOCAL_BOOK_IMPORT_MAX_COUNT: number = 500;
// 本地书默认进入"本地"分组；隐私导入时由调用方传入隐私分组
export const LOCAL_BOOK_DEFAULT_GROUP: number = 4;

export enum LocalBookImportStatus {
  READY = 'ready',
  DUPLICATE = 'duplicate',
  UNSUPPORTED = 'unsupported',
  FAILED = 'failed',
  IMPORTING = 'importing',
  IMPORTED = 'imported',
  CANCELLED = 'cancelled'
}

export class LocalBookImportCandidate {
  id: string = '';
  sourceUri: string = '';
  sourcePath: string = '';
  originalName: string = '';
  displayName: string = '';
  extension: string = '';
  size: number = 0;
  modifiedTime: number = 0;
  modifiedTimeReliable: boolean = true;
  contentHash: string = '';
  status: LocalBookImportStatus = LocalBookImportStatus.READY;
  selected: boolean = true;
  message: string = '';
}

export class LocalBookImportScanSummary {
  total: number = 0;
  ready: number = 0;
  duplicate: number = 0;
  unsupported: number = 0;
  failed: number = 0;
  selected: number = 0;
}

export class LocalBookImportScanResult {
  candidates: LocalBookImportCandidate[] = [];
  summary: LocalBookImportScanSummary = new LocalBookImportScanSummary();
  stagingPath: string = '';
  message: string = '';
}

export class LocalBookImportResult {
  candidateId: string = '';
  status: LocalBookImportStatus = LocalBookImportStatus.FAILED;
  message: string = '';
  book?: Books;
}

export class LocalBookBatchImportResult {
  results: LocalBookImportResult[] = [];
  selected: number = 0;
  completed: number = 0;
  imported: number = 0;
  duplicate: number = 0;
  failed: number = 0;
  cancelled: number = 0;
}

export type LocalBookImportProgressCallback =
  (completed: number, total: number, candidate: LocalBookImportCandidate) => void;
export type LocalBookImportCancelCheck = () => boolean;

class LocalBookImportState {
  localBooks: Books[] = [];
  usedNames: string[] = [];
}

/** Pure helpers kept public so filename and duplicate rules can be tested without Harmony UI. */
export class LocalBookImportLogic {
  static extensionOf(fileName: string): string {
    const safeName = LocalBookImportLogic.safeOriginalName(fileName);
    const dotIndex = safeName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex === safeName.length - 1) {
      return '';
    }
    return safeName.substring(dotIndex).toLowerCase();
  }

  static isSupportedFileName(fileName: string): boolean {
    return LOCAL_BOOK_FILE_SUFFIX_FILTERS.includes(LocalBookImportLogic.extensionOf(fileName));
  }

  static isHiddenPath(path: string): boolean {
    const normalized = path.replace(/\\/g, '/');
    const segments = normalized.split('/');
    for (let index = 0; index < segments.length; index++) {
      const segment = segments[index];
      if (segment.length > 1 && segment.startsWith('.')) {
        return true;
      }
    }
    return false;
  }

  static safeOriginalName(fileName: string): string {
    const normalized = fileName.replace(/\\/g, '/');
    const segments = normalized.split('/');
    let result = segments.length > 0 ? segments[segments.length - 1] : '';
    result = result.replace(/[\u0000-\u001f\\/:*?"<>|]/g, '_').trim();
    return result;
  }

  static displayBaseName(fileName: string): string {
    const safeName = LocalBookImportLogic.safeOriginalName(fileName);
    const extension = LocalBookImportLogic.extensionOf(safeName);
    let baseName = extension.length > 0 ? safeName.substring(0, safeName.length - extension.length) : safeName;
    baseName = baseName.trim();
    return baseName.length > 0 ? baseName : '本地书籍';
  }

  static duplicateKey(originalName: string, size: number, modifiedTime: number): string {
    return LocalBookImportLogic.safeOriginalName(originalName).toLowerCase() + '\n' +
      String(size) + '\n' + String(modifiedTime);
  }

  static generateDisplayName(baseName: string, existingNames: string[]): string {
    const usedNames = new Set<string>();
    for (let index = 0; index < existingNames.length; index++) {
      usedNames.add(existingNames[index].trim().toLowerCase());
    }
    return LocalBookImportLogic.generateDisplayNameFromSet(baseName, usedNames);
  }

  static generateDisplayNameFromSet(baseName: string, usedNames: Set<string>): string {
    const normalizedBase = baseName.trim().length > 0 ? baseName.trim() : '本地书籍';
    if (!usedNames.has(normalizedBase.toLowerCase())) {
      return normalizedBase;
    }
    let suffix = 2;
    let candidate = normalizedBase + ' (' + String(suffix) + ')';
    while (usedNames.has(candidate.toLowerCase())) {
      suffix++;
      candidate = normalizedBase + ' (' + String(suffix) + ')';
    }
    return candidate;
  }
}

export class LocalBookImportService {
  private stagingPaths: string[] = [];
  private cancelRequested: boolean = false;

  createRequestId(): string {
    return util.generateRandomUUID();
  }

  canPickDirectory(): boolean {
    return canIUse('SystemCapability.FileManagement.UserFileService.FolderSelection');
  }

  cancelImport(): void {
    this.cancelRequested = true;
  }

  async pickFileUris(context: common.UIAbilityContext,
    requestId: string = this.createRequestId()): Promise<string[]> {
    const started = Date.now();
    try {
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = LOCAL_BOOK_IMPORT_MAX_COUNT;
      options.fileSuffixFilters = LOCAL_BOOK_FILE_SUFFIX_FILTERS;
      const documentPicker = new picker.DocumentViewPicker(context);
      const result = await documentPicker.select(options);
      hilog.info(0x0000, 'LocalImport',
        'request=%{public}s stage=picker.files.done count=%{public}d elapsedMs=%{public}d',
        requestId, result.length, Date.now() - started);
      return result.slice(0, LOCAL_BOOK_IMPORT_MAX_COUNT);
    } catch (error) {
      this.logError(requestId, 'picker.files', error as BusinessError);
      return [];
    }
  }

  async pickDirectoryUris(context: common.UIAbilityContext,
    requestId: string = this.createRequestId()): Promise<string[]> {
    if (!this.canPickDirectory()) {
      hilog.info(0x0000, 'LocalImport',
        'request=%{public}s stage=picker.folder.unsupported', requestId);
      return [];
    }
    const started = Date.now();
    try {
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.selectMode = picker.DocumentSelectMode.FOLDER;
      const documentPicker = new picker.DocumentViewPicker(context);
      const result = await documentPicker.select(options);
      hilog.info(0x0000, 'LocalImport',
        'request=%{public}s stage=picker.folder.done count=%{public}d elapsedMs=%{public}d',
        requestId, result.length, Date.now() - started);
      return result.slice(0, 1);
    } catch (error) {
      this.logError(requestId, 'picker.folder', error as BusinessError);
      return [];
    }
  }

  async selectFiles(context: common.UIAbilityContext,
    requestId: string = this.createRequestId()): Promise<LocalBookImportScanResult> {
    const uris = await this.pickFileUris(context, requestId);
    return await this.scanPickerUris(uris, requestId);
  }

  async selectDirectory(context: common.UIAbilityContext, recursion: boolean,
    requestId: string = this.createRequestId()): Promise<LocalBookImportScanResult> {
    const uris = await this.pickDirectoryUris(context, requestId);
    if (uris.length === 0) {
      return new LocalBookImportScanResult();
    }
    return await this.scanDirectoryUri(context, uris[0], recursion, requestId);
  }

  async scanPickerUris(uris: string[],
    requestId: string = this.createRequestId()): Promise<LocalBookImportScanResult> {
    const result = new LocalBookImportScanResult();
    const limitedUris = uris.slice(0, LOCAL_BOOK_IMPORT_MAX_COUNT);
    for (let index = 0; index < limitedUris.length; index++) {
      result.candidates.push(this.inspectSource(limitedUris[index], '', ''));
    }
    await this.applyDuplicateAndNameRules(result.candidates);
    result.summary = this.summarize(result.candidates);
    hilog.info(0x0000, 'LocalImport',
      'request=%{public}s stage=scan.files.done total=%{public}d ready=%{public}d duplicate=%{public}d failed=%{public}d',
      requestId, result.summary.total, result.summary.ready, result.summary.duplicate,
      result.summary.failed + result.summary.unsupported);
    return result;
  }

  async scanDirectoryUri(context: common.UIAbilityContext, directoryUri: string, recursion: boolean,
    requestId: string = this.createRequestId()): Promise<LocalBookImportScanResult> {
    const result = new LocalBookImportScanResult();
    if (!directoryUri || !context) {
      return result;
    }
    const baseDir = context.cacheDir.length > 0 ? context.cacheDir : context.tempDir;
    let stagingPath = '';
    try {
      stagingPath = await fs.mkdtemp(baseDir + '/localBookImport-XXXXXX');
      this.stagingPaths.push(stagingPath);
      result.stagingPath = stagingPath;
      await fs.copy(directoryUri, fileUri.getUriFromPath(stagingPath));
      const contentRoot = await this.resolveCopiedDirectoryRoot(stagingPath);
      const options: ListFileOptions = {
        recursion: recursion
      };
      const entries = await fs.listFile(contentRoot, options);
      for (let index = 0; index < entries.length && result.candidates.length < LOCAL_BOOK_IMPORT_MAX_COUNT;
        index++) {
        const relativePath = entries[index];
        if (LocalBookImportLogic.isHiddenPath(relativePath)) {
          continue;
        }
        const sourcePath = this.listedPath(contentRoot, relativePath);
        let stat: fs.Stat;
        try {
          stat = fs.statSync(sourcePath);
        } catch (_) {
          const failed = new LocalBookImportCandidate();
          failed.id = util.generateRandomUUID();
          failed.status = LocalBookImportStatus.FAILED;
          failed.selected = false;
          failed.message = '无法读取文件元数据';
          result.candidates.push(failed);
          continue;
        }
        if (!stat.isFile()) {
          continue;
        }
        const originalName = LocalBookImportLogic.safeOriginalName(relativePath);
        const candidate = this.inspectSource(fileUri.getUriFromPath(sourcePath), sourcePath, originalName);
        candidate.modifiedTime = 0;
        candidate.modifiedTimeReliable = false;
        result.candidates.push(candidate);
      }
      await this.applyDuplicateAndNameRules(result.candidates);
      result.summary = this.summarize(result.candidates);
      hilog.info(0x0000, 'LocalImport',
        'request=%{public}s stage=scan.folder.done recursive=%{public}s total=%{public}d ready=%{public}d duplicate=%{public}d failed=%{public}d',
        requestId, String(recursion), result.summary.total, result.summary.ready, result.summary.duplicate,
        result.summary.failed + result.summary.unsupported);
      return result;
    } catch (error) {
      this.logError(requestId, 'scan.folder', error as BusinessError);
      await this.cleanupStagingPath(stagingPath);
      result.stagingPath = '';
      result.message = '文件夹扫描失败：目录文件过多（单次最多 500 个）或无法读取，请尝试直接批量选择文件';
      return result;
    }
  }

  async importSingle(context: common.UIAbilityContext, candidate: LocalBookImportCandidate, bookType: number,
    requestId: string = this.createRequestId()): Promise<LocalBookImportResult> {
    const state = await this.loadImportState();
    const result = await this.importOne(context, candidate, bookType, state, requestId, LOCAL_BOOK_DEFAULT_GROUP);
    return result;
  }

  async importCandidates(context: common.UIAbilityContext, candidates: LocalBookImportCandidate[], bookType: number,
    onProgress?: LocalBookImportProgressCallback,
    shouldCancel?: LocalBookImportCancelCheck,
    requestId: string = this.createRequestId(),
    bookGroup: number = LOCAL_BOOK_DEFAULT_GROUP): Promise<LocalBookBatchImportResult> {
    this.cancelRequested = false;
    const batchResult = new LocalBookBatchImportResult();
    const selectedCandidates: LocalBookImportCandidate[] = [];
    for (let index = 0; index < candidates.length; index++) {
      const candidate = candidates[index];
      if (candidate.selected && candidate.status === LocalBookImportStatus.READY) {
        selectedCandidates.push(candidate);
      }
    }
    batchResult.selected = selectedCandidates.length;
    const state = await this.loadImportState();
    for (let index = 0; index < selectedCandidates.length; index++) {
      const candidate = selectedCandidates[index];
      const externalCancelled = shouldCancel ? shouldCancel() : false;
      if (this.cancelRequested || externalCancelled) {
        candidate.status = LocalBookImportStatus.CANCELLED;
        candidate.message = '已取消';
        const cancelledResult = new LocalBookImportResult();
        cancelledResult.candidateId = candidate.id;
        cancelledResult.status = LocalBookImportStatus.CANCELLED;
        cancelledResult.message = candidate.message;
        batchResult.results.push(cancelledResult);
      } else {
        candidate.status = LocalBookImportStatus.IMPORTING;
        candidate.message = '正在导入';
        if (onProgress) {
          onProgress(batchResult.completed, batchResult.selected, candidate);
        }
        const itemResult = await this.importOne(context, candidate, bookType, state, requestId, bookGroup);
        batchResult.results.push(itemResult);
      }
      batchResult.completed++;
      if (onProgress) {
        onProgress(batchResult.completed, batchResult.selected, candidate);
      }
    }
    this.fillBatchCounts(batchResult);
    hilog.info(0x0000, 'LocalImport',
      'request=%{public}s stage=import.batch.done selected=%{public}d imported=%{public}d duplicate=%{public}d failed=%{public}d cancelled=%{public}d',
      requestId, batchResult.selected, batchResult.imported, batchResult.duplicate,
      batchResult.failed, batchResult.cancelled);
    return batchResult;
  }

  summarize(candidates: LocalBookImportCandidate[]): LocalBookImportScanSummary {
    const summary = new LocalBookImportScanSummary();
    summary.total = candidates.length;
    for (let index = 0; index < candidates.length; index++) {
      const candidate = candidates[index];
      if (candidate.selected) {
        summary.selected++;
      }
      switch (candidate.status) {
        case LocalBookImportStatus.READY:
          summary.ready++;
          break;
        case LocalBookImportStatus.DUPLICATE:
          summary.duplicate++;
          break;
        case LocalBookImportStatus.UNSUPPORTED:
          summary.unsupported++;
          break;
        case LocalBookImportStatus.FAILED:
          summary.failed++;
          break;
        default:
          break;
      }
    }
    return summary;
  }

  async cleanupStaging(): Promise<void> {
    const paths = this.stagingPaths.slice();
    this.stagingPaths = [];
    for (let index = 0; index < paths.length; index++) {
      await this.cleanupStagingPath(paths[index]);
    }
  }

  async cleanupScanResult(result: LocalBookImportScanResult): Promise<void> {
    if (result.stagingPath.length > 0) {
      await this.cleanupStagingPath(result.stagingPath);
      result.stagingPath = '';
    }
  }

  private inspectSource(sourceUri: string, sourcePath: string, knownName: string): LocalBookImportCandidate {
    const candidate = new LocalBookImportCandidate();
    candidate.id = util.generateRandomUUID();
    candidate.sourceUri = sourceUri;
    candidate.sourcePath = sourcePath;
    let file: fs.File | undefined;
    try {
      const source = sourceUri.length > 0 ? sourceUri : sourcePath;
      file = fs.openSync(source, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      candidate.sourcePath = sourcePath;
      if (candidate.sourcePath.length === 0) {
        try {
          candidate.sourcePath = file.path;
        } catch (_) {
          candidate.sourcePath = '';
        }
      }
      candidate.originalName = LocalBookImportLogic.safeOriginalName(
        knownName.length > 0 ? knownName : file.name);
      candidate.displayName = LocalBookImportLogic.displayBaseName(candidate.originalName);
      candidate.extension = LocalBookImportLogic.extensionOf(candidate.originalName);
      candidate.size = stat.size;
      candidate.modifiedTime = Math.floor(stat.mtime * 1000);
      if (!stat.isFile()) {
        candidate.status = LocalBookImportStatus.FAILED;
        candidate.selected = false;
        candidate.message = '所选项目不是文件';
      } else if (!LOCAL_BOOK_FILE_SUFFIX_FILTERS.includes(candidate.extension)) {
        candidate.status = LocalBookImportStatus.UNSUPPORTED;
        candidate.selected = false;
        candidate.message = '不支持此文件格式';
      } else if (candidate.size <= 0) {
        candidate.status = LocalBookImportStatus.FAILED;
        candidate.selected = false;
        candidate.message = '文件为空';
      }
    } catch (_) {
      candidate.originalName = LocalBookImportLogic.safeOriginalName(knownName);
      candidate.displayName = LocalBookImportLogic.displayBaseName(candidate.originalName);
      candidate.extension = LocalBookImportLogic.extensionOf(candidate.originalName);
      candidate.status = LocalBookImportStatus.FAILED;
      candidate.selected = false;
      candidate.message = '无法读取文件';
    } finally {
      if (file) {
        try {
          fs.closeSync(file);
        } catch (_) {
        }
      }
    }
    return candidate;
  }

  private async applyDuplicateAndNameRules(candidates: LocalBookImportCandidate[]): Promise<void> {
    const localBooks = await BooksDao.getLocalBooksForImportDuplicateCheck();
    const existingNames = await BooksDao.getExistingBookNames();
    const usedNames = new Set<string>();
    for (let index = 0; index < existingNames.length; index++) {
      usedNames.add(existingNames[index].trim().toLowerCase());
    }
    const seenUris = new Set<string>();
    const accepted: LocalBookImportCandidate[] = [];
    for (let index = 0; index < candidates.length; index++) {
      const candidate = candidates[index];
      if (candidate.status !== LocalBookImportStatus.READY) {
        continue;
      }
      if (candidate.sourceUri.length > 0 && seenUris.has(candidate.sourceUri)) {
        this.markDuplicate(candidate);
        continue;
      }
      let duplicateInBatch = false;
      for (let prior = 0; prior < accepted.length; prior++) {
        const priorCandidate = accepted[prior];
        if (priorCandidate.size !== candidate.size) {
          continue;
        }
        const priorHash = await this.ensureCandidateHash(priorCandidate);
        const currentHash = await this.ensureCandidateHash(candidate);
        if (priorHash.length > 0 && priorHash === currentHash) {
          duplicateInBatch = true;
          break;
        }
        const sameFallbackMetadata = priorCandidate.originalName.toLowerCase() === candidate.originalName.toLowerCase() &&
          priorCandidate.modifiedTimeReliable && candidate.modifiedTimeReliable &&
          priorCandidate.modifiedTime === candidate.modifiedTime;
        if ((priorHash.length === 0 || currentHash.length === 0) && sameFallbackMetadata) {
          duplicateInBatch = true;
          break;
        }
      }
      if (duplicateInBatch || await this.isStoredDuplicate(candidate, localBooks)) {
        this.markDuplicate(candidate);
        continue;
      }
      if (candidate.sourceUri.length > 0) {
        seenUris.add(candidate.sourceUri);
      }
      accepted.push(candidate);
      const baseName = LocalBookImportLogic.displayBaseName(candidate.originalName);
      candidate.displayName = LocalBookImportLogic.generateDisplayNameFromSet(baseName, usedNames);
      usedNames.add(candidate.displayName.toLowerCase());
    }
  }

  private markDuplicate(candidate: LocalBookImportCandidate): void {
    candidate.status = LocalBookImportStatus.DUPLICATE;
    candidate.selected = false;
    candidate.message = '书籍已存在';
  }

  //先按大小缩小范围，再用内容指纹确认重复；哈希不可用时才退回可靠元数据
  private async isStoredDuplicate(candidate: LocalBookImportCandidate,
    localBooks: Books[]): Promise<boolean> {
    const candidateName = LocalBookImportLogic.safeOriginalName(candidate.originalName).toLowerCase();
    for (let index = 0; index < localBooks.length; index++) {
      const book = localBooks[index];
      const storedSize = book.localFileSize ?? 0;
      if (storedSize > 0 && storedSize !== candidate.size) {
        continue;
      }
      if (storedSize === 0 && book.bookUrl) {
        try {
          const stat = fs.statSync(book.bookUrl);
          if (!stat.isFile() || stat.size !== candidate.size) {
            continue;
          }
          book.localFileSize = stat.size;
        } catch (_) {
          continue;
        }
      }
      const storedHash = await this.storedBookHash(book);
      const candidateHash = await this.ensureCandidateHash(candidate);
      if (storedHash.length > 0 && candidateHash.length > 0) {
        if (storedHash === candidateHash) {
          return true;
        }
        continue;
      }
      const storedName = LocalBookImportLogic.safeOriginalName(book.originName ?? '').toLowerCase();
      const storedBookName = (book.bookName ?? '').trim().toLowerCase();
      const nameMatches = storedName === candidateName || storedBookName === candidateName ||
        storedBookName === candidate.displayName.trim().toLowerCase();
      if (nameMatches && candidate.modifiedTimeReliable && (book.localFileModified ?? 0) > 0 &&
        book.localFileModified === candidate.modifiedTime) {
        return true;
      }
    }
    return false;
  }

  private async storedBookHash(book: Books): Promise<string> {
    if (book.localFileHash && book.localFileHash.length > 0) {
      return book.localFileHash;
    }
    if (!book.bookUrl) {
      return '';
    }
    const computed = await this.computeFileHash(book.bookUrl);
    if (computed.length > 0) {
      book.localFileHash = computed;
      if (book.id !== undefined) {
        await BooksDao.partialUpdate(book);
      }
    }
    return computed;
  }

  private async ensureCandidateHash(candidate: LocalBookImportCandidate): Promise<string> {
    if (candidate.contentHash.length > 0) {
      return candidate.contentHash;
    }
    const source = candidate.sourceUri.length > 0 ? candidate.sourceUri : candidate.sourcePath;
    if (!source) {
      return '';
    }
    candidate.contentHash = await this.computeFileHash(source);
    return candidate.contentHash;
  }

  private async computeFileHash(source: string): Promise<string> {
    let file: fs.File | undefined;
    try {
      file = fs.openSync(source, fs.OpenMode.READ_ONLY);
      const hashStream = hash.createHash('sha256');
      const chunkSize = 1024 * 1024;
      while (true) {
        const chunk = new ArrayBuffer(chunkSize);
        const readSize = await fs.read(file.fd, chunk);
        if (readSize <= 0) {
          break;
        }
        hashStream.update(readSize === chunkSize ? chunk : chunk.slice(0, readSize));
      }
      return hashStream.digest();
    } catch (_) {
      return '';
    } finally {
      if (file) {
        try {
          fs.closeSync(file);
        } catch (_) {
        }
      }
    }
  }

  private async loadImportState(): Promise<LocalBookImportState> {
    const state = new LocalBookImportState();
    state.localBooks = await BooksDao.getLocalBooksForImportDuplicateCheck();
    state.usedNames = await BooksDao.getExistingBookNames();
    return state;
  }

  private async importOne(context: common.UIAbilityContext, candidate: LocalBookImportCandidate, bookType: number,
    state: LocalBookImportState, requestId: string, bookGroup: number): Promise<LocalBookImportResult> {
    const result = new LocalBookImportResult();
    result.candidateId = candidate.id;
    let sourceFile: fs.File | undefined;
    let tempPath = '';
    let finalPath = '';
    let finalCreated = false;
    let stage = 'import.validate';
    try {
      if (!context || !context.filesDir) {
        throw new Error('Import context unavailable');
      }
      const source = candidate.sourceUri.length > 0 ? candidate.sourceUri : candidate.sourcePath;
      if (!source) {
        throw new Error('Import source unavailable');
      }
      sourceFile = fs.openSync(source, fs.OpenMode.READ_ONLY);
      const sourceStat = fs.statSync(sourceFile.fd);
      if (!sourceStat.isFile() || sourceStat.size <= 0 ||
        !LOCAL_BOOK_FILE_SUFFIX_FILTERS.includes(candidate.extension)) {
        throw new Error('Import source invalid');
      }
      candidate.size = sourceStat.size;
      if (candidate.modifiedTimeReliable) {
        candidate.modifiedTime = Math.floor(sourceStat.mtime * 1000);
      }
      await this.ensureCandidateHash(candidate);
      if (await this.isStoredDuplicate(candidate, state.localBooks)) {
        candidate.status = LocalBookImportStatus.DUPLICATE;
        candidate.selected = false;
        candidate.message = '书籍已存在';
        result.status = candidate.status;
        result.message = candidate.message;
        return result;
      }
      const usedNames = new Set<string>();
      for (let index = 0; index < state.usedNames.length; index++) {
        usedNames.add(state.usedNames[index].trim().toLowerCase());
      }
      if (usedNames.has(candidate.displayName.trim().toLowerCase())) {
        candidate.displayName = LocalBookImportLogic.generateDisplayNameFromSet(
          LocalBookImportLogic.displayBaseName(candidate.originalName), usedNames);
      }
      const localBooksDir = context.filesDir + '/localBooks';
      if (!fs.accessSync(localBooksDir)) {
        fs.mkdirSync(localBooksDir, true);
      }
      const localFileName = util.generateRandomUUID() + candidate.extension;
      finalPath = localBooksDir + '/' + localFileName;
      tempPath = finalPath + '.importing';
      stage = 'import.copy';
      await fs.copyFile(sourceFile.fd, tempPath, 0);
      fs.closeSync(sourceFile);
      sourceFile = undefined;
      const copiedStat = fs.statSync(tempPath);
      if (!copiedStat.isFile() || copiedStat.size <= 0 || copiedStat.size !== candidate.size) {
        throw new Error('Import copy verification failed');
      }
      stage = 'import.rename';
      fs.renameSync(tempPath, finalPath);
      tempPath = '';
      finalCreated = true;
      const book = new Books();
      book.bookName = candidate.displayName;
      book.bookUrl = finalPath;
      book.originName = candidate.originalName;
      book.author = '暂无';
      book.bookGroup = bookGroup;
      book.bookType = bookType;
      book.isJoin = true;
      book.isLocalBook = true;
      book.canUpdate = false;
      book.localFileSize = candidate.size;
      book.localFileModified = candidate.modifiedTime;
      book.localFileHash = candidate.contentHash;
      stage = 'import.database';
      const inserted = await BooksDao.insert(book);
      if (!inserted) {
        throw new Error('Bookshelf insert failed');
      }
      finalCreated = false;
      candidate.status = LocalBookImportStatus.IMPORTED;
      candidate.message = '导入成功';
      result.status = candidate.status;
      result.message = candidate.message;
      result.book = book;
      state.localBooks.push(book);
      state.usedNames.push(book.bookName);
      return result;
    } catch (error) {
      this.logError(requestId, stage, error as BusinessError);
      candidate.status = LocalBookImportStatus.FAILED;
      candidate.selected = false;
      candidate.message = '导入失败';
      result.status = candidate.status;
      result.message = candidate.message;
      return result;
    } finally {
      if (sourceFile) {
        try {
          fs.closeSync(sourceFile);
        } catch (_) {
        }
      }
      if (tempPath.length > 0) {
        this.deleteFileQuietly(tempPath);
      }
      if (finalCreated && finalPath.length > 0) {
        this.deleteFileQuietly(finalPath);
      }
    }
  }

  private fillBatchCounts(batchResult: LocalBookBatchImportResult): void {
    for (let index = 0; index < batchResult.results.length; index++) {
      switch (batchResult.results[index].status) {
        case LocalBookImportStatus.IMPORTED:
          batchResult.imported++;
          break;
        case LocalBookImportStatus.DUPLICATE:
          batchResult.duplicate++;
          break;
        case LocalBookImportStatus.CANCELLED:
          batchResult.cancelled++;
          break;
        case LocalBookImportStatus.FAILED:
          batchResult.failed++;
          break;
        default:
          break;
      }
    }
  }

  private async resolveCopiedDirectoryRoot(stagingPath: string): Promise<string> {
    try {
      const entries = await fs.listFile(stagingPath, { recursion: false });
      if (entries.length !== 1) {
        return stagingPath;
      }
      const copiedRoot = this.listedPath(stagingPath, entries[0]);
      return fs.statSync(copiedRoot).isDirectory() ? copiedRoot : stagingPath;
    } catch (_) {
      return stagingPath;
    }
  }

  private listedPath(root: string, entry: string): string {
    let relativePath = entry.replace(/\\/g, '/');
    while (relativePath.startsWith('/')) {
      relativePath = relativePath.substring(1);
    }
    return root + '/' + relativePath;
  }

  private async cleanupStagingPath(stagingPath: string): Promise<void> {
    const trackedIndex = this.stagingPaths.indexOf(stagingPath);
    if (trackedIndex >= 0) {
      this.stagingPaths.splice(trackedIndex, 1);
    }
    await this.removeDirectoryTree(stagingPath);
  }

  private async removeDirectoryTree(path: string): Promise<void> {
    try {
      if (!fs.accessSync(path)) {
        return;
      }
      const entries = await fs.listFile(path, { recursion: false });
      for (let index = 0; index < entries.length; index++) {
        const childPath = this.listedPath(path, entries[index]);
        try {
          if (fs.statSync(childPath).isDirectory()) {
            await this.removeDirectoryTree(childPath);
          } else {
            fs.unlinkSync(childPath);
          }
        } catch (_) {
        }
      }
      fs.rmdirSync(path);
    } catch (_) {
    }
  }

  private deleteFileQuietly(path: string): void {
    try {
      if (fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
    } catch (_) {
    }
  }

  private logError(requestId: string, stage: string, error: BusinessError): void {
    hilog.error(0x0000, 'LocalImport',
      'request=%{public}s stage=%{public}s code=%{public}s',
      requestId, stage, String(error.code ?? 'unknown'));
  }
}

const localBookImportService = new LocalBookImportService();
export default localBookImportService as LocalBookImportService;
