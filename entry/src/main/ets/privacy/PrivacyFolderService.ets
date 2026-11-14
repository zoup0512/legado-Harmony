import BooksDao from '../database/dao/BooksDao';
import booksUtils from '../common/utils/booksUtils';
import { LocalBookAccessLogic } from '../common/utils/LocalBookAccess';
import { Books } from '../database/entities/Books';
import privacySessionService from './PrivacySessionService';
import { capturePrivacyGeneration, isPrivacyGenerationValid } from './PrivacyAccessGuard';
import { PRIVACY_BOOK_GROUP, PRIVACY_GUIDE_ORIGIN } from './PrivacyConstants';
import { AppUtil, PreferencesUtil } from '@pura/harmony-utils';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';
import Logger from '../common/utils/Logger';
import { LocalBookImportLogic } from '../common/utils/LocalBookImportService';

export { PRIVACY_BOOK_GROUP } from './PrivacyConstants';

const GUIDE_SEEDED_KEY: string = 'PrivacyGuideBookSeeded';
const GUIDE_RAWFILE: string = 'privacy_folder_guide.txt';
const GUIDE_BOOK_NAME: string = '隐私文件夹说明';

class PrivacyFolderService {
  private guideTask: Promise<void> | undefined;

  async list(searchKey: string = ''): Promise<Books[]> {
    if (!await privacySessionService.requireUnlock()) return [];
    const generation = capturePrivacyGeneration();
    if (!isPrivacyGenerationValid(generation)) return [];
    await this.ensureGuideBook(generation);
    if (!isPrivacyGenerationValid(generation)) return [];
    const books = await BooksDao.search({ searchKey: searchKey, bookGroup: PRIVACY_BOOK_GROUP });
    return isPrivacyGenerationValid(generation) ? books : [];
  }

  // 已放入过说明书，说明用户至少成功解锁过一次隐私文件夹
  hasSeededGuide(): boolean {
    return PreferencesUtil.getSync(GUIDE_SEEDED_KEY, false) as boolean;
  }

  // 首次解锁时放入一本说明书；只放一次，用户删除后不再恢复
  private ensureGuideBook(generation: number): Promise<void> {
    if (this.hasSeededGuide()) return Promise.resolve();
    if (this.guideTask === undefined) {
      this.guideTask = this.seedGuideBook(generation).finally((): void => { this.guideTask = undefined; });
    }
    return this.guideTask;
  }

  private async seedGuideBook(generation: number): Promise<void> {
    let path = '';
    try {
      const context = AppUtil.getContext();
      const content = context.resourceManager.getRawFileContentSync(GUIDE_RAWFILE);
      const dir = context.filesDir + '/localBooks';
      if (!fs.accessSync(dir)) fs.mkdirSync(dir, true);
      path = dir + '/' + util.generateRandomUUID() + '.txt';
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(file.fd, content.buffer.slice(content.byteOffset, content.byteOffset + content.byteLength));
      } finally {
        fs.closeSync(file);
      }
      const book = new Books();
      book.bookName = LocalBookImportLogic.generateDisplayName(GUIDE_BOOK_NAME, await BooksDao.getExistingBookNames());
      book.bookUrl = path;
      book.origin = PRIVACY_GUIDE_ORIGIN;
      book.originName = GUIDE_BOOK_NAME + '.txt';
      book.author = '隐私阅读器';
      book.bookGroup = PRIVACY_BOOK_GROUP;
      book.isJoin = true;
      book.isLocalBook = true;
      book.canUpdate = false;
      book.localFileSize = content.byteLength;
      book.localFileModified = Date.now();
      if (!isPrivacyGenerationValid(generation) || !await BooksDao.insert(book, generation)) return;
      PreferencesUtil.putSync(GUIDE_SEEDED_KEY, true);
      path = '';
    } catch (_) {
      Logger.warn('Privacy guide book unavailable');
    } finally {
      if (path.length > 0) {
        try {
          fs.unlinkSync(path);
        } catch (_) {
        }
      }
    }
  }

  async add(book: Books): Promise<boolean> {
    if (!await privacySessionService.requireUnlock()) return false;
    const generation = capturePrivacyGeneration();
    if (!LocalBookAccessLogic.isLocalFilePath(book.bookUrl) || !isPrivacyGenerationValid(generation)) return false;
    book.bookGroup = PRIVACY_BOOK_GROUP;
    book.isJoin = true;
    const added = await booksUtils.addBooks(book, generation);
    return added && isPrivacyGenerationValid(generation);
  }

  async moveIn(book: Books, generation: number = capturePrivacyGeneration()): Promise<boolean> {
    if (!book.id || !isPrivacyGenerationValid(generation)) return false;
    if (!await privacySessionService.requireUnlock() || !isPrivacyGenerationValid(generation)) return false;
    // The persisted record/path is authoritative; legacy false isLocalBook flags are allowed.
    const stored = await BooksDao.getBookByIds([book.id]);
    if (!isPrivacyGenerationValid(generation) || stored.length !== 1 ||
      !LocalBookAccessLogic.isLocalFilePath(stored[0].bookUrl)) return false;
    const moved = await BooksDao.updateBookGroup(book.id, PRIVACY_BOOK_GROUP, generation);
    return moved && isPrivacyGenerationValid(generation);
  }

  async moveOut(book: Books, generation: number = capturePrivacyGeneration()): Promise<boolean> {
    if (!book.id || !isPrivacyGenerationValid(generation)) return false;
    if (!await privacySessionService.requireUnlock() || !isPrivacyGenerationValid(generation)) return false;
    if (!await BooksDao.isPrivateBook(book) || !isPrivacyGenerationValid(generation)) return false;
    const moved = await BooksDao.updateBookGroup(book.id, 3, generation);
    return moved && isPrivacyGenerationValid(generation);
  }

  async remove(book: Books, generation: number = capturePrivacyGeneration()): Promise<boolean> {
    if (!book.id || !isPrivacyGenerationValid(generation)) return false;
    if (!await privacySessionService.requireUnlock() || !isPrivacyGenerationValid(generation)) return false;
    const removed = await booksUtils.delBooksById(book.id, generation);
    return removed && isPrivacyGenerationValid(generation);
  }
}

export default new PrivacyFolderService();
