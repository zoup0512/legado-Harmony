import BooksDao from '../database/dao/BooksDao';
import booksUtils from '../common/utils/booksUtils';
import { Books } from '../database/entities/Books';

export const PRIVACY_BOOK_GROUP: number = 99;

class PrivacyFolderService {
  async list(searchKey: string = ''): Promise<Books[]> {
    return await BooksDao.search({ searchKey: searchKey, bookGroup: PRIVACY_BOOK_GROUP });
  }

  async add(book: Books): Promise<boolean> {
    if (!book.isLocalBook || !book.bookUrl) return false;
    book.bookGroup = PRIVACY_BOOK_GROUP;
    book.isJoin = true;
    return await booksUtils.addBooks(book);
  }

  async moveIn(book: Books): Promise<boolean> {
    if (!book.id || !book.isLocalBook) return false;
    return await BooksDao.updateBookGroup(book.id, PRIVACY_BOOK_GROUP);
  }

  async moveOut(book: Books): Promise<boolean> {
    if (!book.id) return false;
    return await BooksDao.updateBookGroup(book.id, 3);
  }

  async remove(book: Books): Promise<boolean> {
    if (!book.id) return false;
    await BooksDao.deleteBook([book.id]);
    return true;
  }
}

export default new PrivacyFolderService();
