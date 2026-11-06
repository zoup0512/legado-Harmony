import { describe, expect, it } from '@ohos/hypium';
import { Books } from '../../../main/ets/database/entities/Books';
import { readerCore } from '@kit.ReaderKit';
import { ReaderProgress } from '../../../main/ets/common/utils/ReaderProgress';

function savedProgress(path: string): Books {
  const saved = new Books();
  saved.bookUrl = path;
  saved.durChapterIndex = 4;
  saved.durChapterTitle = 'Chapter five';
  const position = new readerCore.PageDataInfo('text', 'test-node');
  position.resourceIndex = 4;
  position.startDomPos = 'saved-position';
  saved.localBookDurChapterPos = position;
  return saved;
}

export default function readerProgressTest() {
  describe('ReaderProgressTest', () => {
    it('newlyImportedBookNeedsNoSavedProgress', 0, () => {
      const book = new Books();
      book.bookUrl = '/books/new.epub';
      ReaderProgress.restore(book, (): Books | undefined => undefined);
      expect(book.localBookDurChapterPos === null).assertTrue();
      expect(book.durChapterIndex).assertEqual(0);
    });

    it('unreadableCacheDoesNotPreventOpening', 0, () => {
      const book = new Books();
      book.durChapterIndex = 2;
      ReaderProgress.restore(book, (): Books | undefined => { throw new Error('cache unavailable'); });
      expect(book.durChapterIndex).assertEqual(2);
    });

    it('matchingBookRestoresProgress', 0, () => {
      const book = new Books();
      book.bookUrl = '/books/current.epub';
      const saved = savedProgress(book.bookUrl);
      ReaderProgress.restore(book, (): Books => saved);
      expect(book.localBookDurChapterPos === saved.localBookDurChapterPos).assertTrue();
      expect(book.durChapterIndex).assertEqual(4);
      expect(book.durChapterTitle).assertEqual('Chapter five');
    });

    it('invalidPositionDoesNotReplaceShelfProgress', 0, () => {
      const book = new Books();
      book.bookUrl = '/books/current.epub';
      const saved = savedProgress(book.bookUrl);
      if (saved.localBookDurChapterPos) saved.localBookDurChapterPos.resourceIndex = -1;
      ReaderProgress.restore(book, (): Books => saved);
      expect(book.localBookDurChapterPos === null).assertTrue();
      expect(book.durChapterIndex).assertEqual(0);
    });

    it('sameNameAtDifferentPathDoesNotRestoreProgress', 0, () => {
      const book = new Books();
      book.bookName = 'Same title';
      book.bookUrl = '/books/new.epub';
      const saved = savedProgress('/books/old.epub');
      saved.bookName = book.bookName;
      ReaderProgress.restore(book, (): Books => saved);
      expect(book.durChapterIndex).assertEqual(0);
      expect(book.localBookDurChapterPos === null).assertTrue();
    });
  });
}
