import BooksDao from '../database/dao/BooksDao';
import booksUtils from '../common/utils/booksUtils';
import { LocalBookAccessLogic } from '../common/utils/LocalBookAccess';
import { Books } from '../database/entities/Books';
import privacySessionService from './PrivacySessionService';
import { capturePrivacyGeneration, isPrivacyGenerationValid } from './PrivacyAccessGuard';
import { PRIVACY_BOOK_GROUP } from './PrivacyConstants';

export { PRIVACY_BOOK_GROUP } from './PrivacyConstants';

class PrivacyFolderService {
  async list(searchKey: string = ''): Promise<Books[]> {
    if (!await privacySessionService.requireUnlock()) return [];
    const generation = capturePrivacyGeneration();
    if (!isPrivacyGenerationValid(generation)) return [];
    const books = await BooksDao.search({ searchKey: searchKey, bookGroup: PRIVACY_BOOK_GROUP });
    return isPrivacyGenerationValid(generation) ? books : [];
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
