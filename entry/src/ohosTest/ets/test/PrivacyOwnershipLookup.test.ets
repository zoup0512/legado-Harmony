import { describe, expect, it } from '@ohos/hypium';
import { PRIVACY_BOOK_GROUP } from '../../../main/ets/privacy/PrivacyConstants';
import {
  PrivacyBookIdentity, PrivacyOwnershipLookup
} from '../../../main/ets/privacy/PrivacyOwnershipLookup';

export default function privacyOwnershipLookupTest() {
  describe('PrivacyOwnershipLookupTest', () => {
    it('matchesPersistedIdsAndExplicitPrivateGroup', 0, () => {
      const lookup = new PrivacyOwnershipLookup([{ id: 7 }]);
      expect(PRIVACY_BOOK_GROUP).assertEqual(99);
      expect(lookup.isPrivateBook({ id: 7, bookGroup: 3 })).assertTrue();
      expect(lookup.isPrivateBook({ id: 8, bookGroup: PRIVACY_BOOK_GROUP })).assertTrue();
      expect(lookup.isPrivateBook({ id: 8, bookGroup: 3 })).assertFalse();
      expect(lookup.isPrivateBook({})).assertFalse();
    });

    it('normalizesAbsolutePathsAndEncodedFileUriAliasesInBothDirections', 0, () => {
      const path = '/data/storage/el2/base/files/书 名.epub';
      const uri = 'file:///data/storage/el2/base/files/%E4%B9%A6%20%E5%90%8D.epub';
      const pathLookup = new PrivacyOwnershipLookup([{ id: 7, bookUrl: path }]);
      const uriLookup = new PrivacyOwnershipLookup([{ id: 8, bookUrl: uri }]);
      expect(pathLookup.isPrivateBook({ id: 10, bookUrl: uri })).assertTrue();
      expect(uriLookup.isPrivateBook({ id: 11, bookUrl: path })).assertTrue();
      expect(pathLookup.isPrivateBook({ id: 12, bookUrl: uri })).assertTrue();
      expect(uriLookup.isPrivateBook({ bookUrl: path })).assertTrue();
    });

    it('doesNotMatchMissingPathsRemoteUrlsOrMalformedAliases', 0, () => {
      const sources: string[] = [
        '', 'https://books.example/private.epub', 'local://legacy-id',
        'file://remote-host/share/book.epub', 'file:////remote-host/share/book.epub',
        'file:///data/bad%ZZ.epub', 'file:///data/book.epub?download=1'
      ];
      for (const source of sources) {
        const lookup = new PrivacyOwnershipLookup([{ bookUrl: source }]);
        expect(lookup.isPrivateBook({ bookUrl: source })).assertFalse();
        expect(lookup.isPrivateBook({ id: 10, bookUrl: source })).assertFalse();
      }
      const lookup = new PrivacyOwnershipLookup([{ id: 7 }]);
      expect(lookup.isPrivateBook({ id: 7, bookUrl: sources[1] })).assertTrue();
      expect(lookup.isPrivateBook({})).assertFalse();
    });

    it('copiesOwnershipInsteadOfRetainingMutableRows', 0, () => {
      const privateBooks: PrivacyBookIdentity[] = [{ id: 7, bookUrl: '/data/old.epub' }];
      const lookup = new PrivacyOwnershipLookup(privateBooks);
      privateBooks[0].id = 8;
      privateBooks[0].bookUrl = '/data/new.epub';
      privateBooks.push({ id: 9 });
      expect(lookup.isPrivateBook({ id: 7 })).assertTrue();
      expect(lookup.isPrivateBook({ bookUrl: 'file:///data/old.epub' })).assertTrue();
      expect(lookup.isPrivateBook({ id: 8, bookUrl: '/data/new.epub' })).assertFalse();
      expect(lookup.isPrivateBook({ id: 9 })).assertFalse();
      expect(new PrivacyOwnershipLookup(privateBooks).isPrivateBook({ id: 8 })).assertTrue();
    });
  });
}
