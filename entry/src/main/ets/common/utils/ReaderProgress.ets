import { Books } from '../../database/entities/Books';

export class ReaderProgress {
  static restore(book: Books, load: () => Books | undefined): void {
    try {
      const savedBook = load();
      if (!savedBook || typeof savedBook !== 'object') return;
      const currentUrl = book.serverBookUrl ?? book.bookUrl;
      const savedUrl = savedBook.serverBookUrl ?? savedBook.bookUrl;
      const position = savedBook.localBookDurChapterPos;
      if (!currentUrl || savedUrl !== currentUrl || !position ||
        !Number.isInteger(position.resourceIndex) || position.resourceIndex < 0 ||
        typeof position.startDomPos !== 'string') return;
      book.localBookDurChapterPos = position;
      book.durChapterIndex = savedBook.durChapterIndex ?? book.durChapterIndex;
      book.durChapterTitle = savedBook.durChapterTitle ?? book.durChapterTitle;
    } catch (_) {
      // 历史缓存不可用时保留书架进度，不影响首次打开。
    }
  }
}
