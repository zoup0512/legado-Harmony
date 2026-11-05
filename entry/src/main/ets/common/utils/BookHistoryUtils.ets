/**
 * @author 2008
 * @datetime 2024/8/5 22:30
 * @className: BookHistoryUtils
 * 阅读历史记录
 */
import bookHistoryDao from '../../database/dao/BookHistoryDao';
import { BookHistory } from '../../database/entities/BookHistory';
import booksUtils from './booksUtils';
import BooksDao from '../../database/dao/BooksDao';
import { getPrivacyGeneration } from '../../privacy/PrivacyAccessGuard';

export class BookHistoryUtils {
  async deleteBookHistory(id: number) {
   return await bookHistoryDao.deleteBookHistory(id)
  }
  async deleteAllBookHistory(){
   bookHistoryDao.deleteAllBookHistory()
  }
  async addBooks(books: BookHistory){
    const generation = getPrivacyGeneration();
    try {
      if (await bookHistoryDao.isPrivateHistory(books) || getPrivacyGeneration() !== generation) return;
      await bookHistoryDao.insert(books, generation);
      if (getPrivacyGeneration() !== generation) return;
      // Reuse the persisted record rather than new Books defaults in partialUpdate.
      const id = books.originBookId ?? books.id;
      if (id === undefined) return;
      const stored = await BooksDao.getBookByIds([id]);
      if (!stored[0] || await bookHistoryDao.isPrivateHistory(books) || getPrivacyGeneration() !== generation) return;
      const book = stored[0];
      book.durChapterTitle = books.durChapterTitle;
      book.lastCheckTime = books.durChapterTime;
      book.durChapterIndex = books.durChapterIndex;
      book.durChapterTime = Date.now();
      await booksUtils.partialUpdate(book);
    } catch (_) {
      // Failed ownership lookup must not publish a potentially-private history row.
    }
  }
}

const bookHistoryUtils = new BookHistoryUtils();
export default bookHistoryUtils as BookHistoryUtils;