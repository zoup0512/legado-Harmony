import { Books } from '../../database/entities/Books';

export class ReaderProgressSummary {
  started: boolean = false;
  chapterTitle: string = '';
  // 0 表示总章节数未知
  percent: number = 0;
}

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

  // 书架展示用：优先使用阅读器缓存（需与当前文件一致），否则退回数据库字段
  static summarize(book: Books, load: () => Books | undefined): ReaderProgressSummary {
    let index = book.durChapterIndex;
    let title = book.durChapterTitle ?? '';
    let total = book.totalChapterNum;
    try {
      const saved = load();
      const currentUrl = book.serverBookUrl ?? book.bookUrl;
      if (saved && typeof saved === 'object' && currentUrl &&
        (saved.serverBookUrl ?? saved.bookUrl) === currentUrl) {
        index = saved.durChapterIndex ?? index;
        title = saved.durChapterTitle ?? title;
        total = saved.totalChapterNum ?? total;
      }
    } catch (_) {
      // 缓存不可用时仅展示数据库中的进度
    }
    const summary = new ReaderProgressSummary();
    summary.chapterTitle = title.trim();
    summary.started = summary.chapterTitle.length > 0;
    if (summary.started && Number.isInteger(index) && index >= 0 && total > 0) {
      summary.percent = Math.min(100, Math.max(1, Math.round((index + 1) * 100 / total)));
    }
    return summary;
  }
}
