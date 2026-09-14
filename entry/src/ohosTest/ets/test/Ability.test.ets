import { hilog } from '@kit.PerformanceAnalysisKit';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium';
import { LocalBookImportLogic } from '../../../main/ets/common/utils/LocalBookImportService';

export default function abilityTest() {
  describe('ActsAbilityTest', () => {
    beforeAll(() => {
    });
    beforeEach(() => {
    });
    afterEach(() => {
    });
    afterAll(() => {
    });

    it('assertContain', 0, () => {
      hilog.info(0x0000, 'testTag', '%{public}s', 'it begin');
      const value = 'abc';
      const expected = 'b';
      expect(value).assertContain(expected);
      expect(value).assertEqual(value);
    });

    it('localBookImportFileRules', 0, () => {
      expect(LocalBookImportLogic.extensionOf('小说.TXT')).assertEqual('.txt');
      expect(LocalBookImportLogic.isSupportedFileName('book.epub')).assertTrue();
      expect(LocalBookImportLogic.isSupportedFileName('book.pdf')).assertFalse();
      expect(LocalBookImportLogic.isHiddenPath('/books/.cache/book.txt')).assertTrue();
      expect(LocalBookImportLogic.isHiddenPath('/books/cache/book.txt')).assertFalse();
      expect(LocalBookImportLogic.safeOriginalName('../书:名?.txt')).assertEqual('书_名_.txt');
    });

    it('localBookImportDuplicateAndDisplayRules', 0, () => {
      expect(LocalBookImportLogic.duplicateKey('Book.TXT', 100, 200))
        .assertEqual(LocalBookImportLogic.duplicateKey('book.txt', 100, 200));
      expect(LocalBookImportLogic.generateDisplayName('三体', ['三体', '三体 (2)']))
        .assertEqual('三体 (3)');
      expect(LocalBookImportLogic.generateDisplayName('新书', ['三体']))
        .assertEqual('新书');
    });
  });
}
