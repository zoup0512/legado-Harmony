import { bookParser } from '@kit.ReaderKit';
import BooksDao, { BookCoverPatch } from '../../database/dao/BooksDao';
import { Books } from '../../database/entities/Books';
import { capturePrivacyGeneration, isPrivacyGenerationValid } from '../../privacy/PrivacyAccessGuard';
import bookCoverStore, { ExtractedBookInfo } from './BookCoverStore';
import { LocalBookAccessLogic } from './LocalBookAccess';

const UNKNOWN_AUTHOR: string = '暂无';

/** 为导入时尚未提取封面的老书补封面；每本书每次启动只尝试一次 */
class BookCoverBackfill {
  private attempted: Set<number> = new Set<number>();
  private running: boolean = false;

  private needsCover(book: Books): boolean {
    return book.id !== undefined && !this.attempted.has(book.id) && !book.coverUrl &&
      bookCoverStore.mayHaveEmbeddedCover(LocalBookAccessLogic.localPathOf(book.bookUrl));
  }

  private async save(book: Books, extracted: ExtractedBookInfo, generation: number): Promise<boolean> {
    const patch: BookCoverPatch = {};
    if (extracted.coverPath.length > 0) patch.coverUrl = extracted.coverPath;
    if (extracted.author.length > 0 && (!book.author || book.author === UNKNOWN_AUTHOR)) {
      patch.author = extracted.author;
    }
    if (patch.coverUrl === undefined && patch.author === undefined) return false;
    if (!isPrivacyGenerationValid(generation) ||
      !await BooksDao.updateBookCover(book.id as number, patch, generation)) {
      bookCoverStore.deleteCover(extracted.coverPath);
      return false;
    }
    if (patch.coverUrl !== undefined) book.coverUrl = patch.coverUrl;
    if (patch.author !== undefined) book.author = patch.author;
    return true;
  }

  /** 阅读页已创建解析器时直接复用，避免重复解析 */
  async fromParser(book: Books, handler: bookParser.BookParserHandler): Promise<boolean> {
    if (!this.needsCover(book)) return false;
    this.attempted.add(book.id as number);
    const generation = capturePrivacyGeneration();
    return this.save(book, await bookCoverStore.extractFromParser(handler), generation);
  }

  /** 书架加载后依次补封面，返回是否有书籍被更新 */
  async run(books: Books[]): Promise<boolean> {
    if (this.running) return false;
    this.running = true;
    let changed = false;
    try {
      for (const book of books) {
        if (!this.needsCover(book)) continue;
        this.attempted.add(book.id as number);
        const generation = capturePrivacyGeneration();
        const path = LocalBookAccessLogic.localPathOf(book.bookUrl);
        if (await this.save(book, await bookCoverStore.extractFromBookFile(path), generation)) {
          changed = true;
        }
      }
    } finally {
      this.running = false;
    }
    return changed;
  }
}

const bookCoverBackfill = new BookCoverBackfill();
export default bookCoverBackfill;
