import { describe, expect, it } from '@ohos/hypium';
import { PRIVACY_BOOK_GROUP } from '../../../main/ets/privacy/PrivacyConstants';
import {
  filterPublicHistories, PrivacyBookIdentity, PrivacyHistoryIdentity, PrivacyOwnershipLookup
} from '../../../main/ets/privacy/PrivacyOwnershipLookup';

async function expectOwnershipFailure(operation: () => Promise<PrivacyHistoryIdentity[]>): Promise<void> {
  let rejected = false;
  let result: PrivacyHistoryIdentity[] | undefined;
  try {
    result = await operation();
  } catch (_) {
    rejected = true;
  }
  expect(rejected).assertTrue();
  expect(result === undefined).assertTrue();
}

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

    it('matchesBothHistoryIdentifiers', 0, () => {
      const lookup = new PrivacyOwnershipLookup([{ id: 7 }]);
      expect(lookup.isPrivateHistory({ id: 7, originBookId: 8 })).assertTrue();
      expect(lookup.isPrivateHistory({ id: 8, originBookId: 7 })).assertTrue();
      expect(lookup.isPrivateHistory({ id: 7, originBookId: 7 })).assertTrue();
      expect(lookup.isPrivateHistory({ originBookId: 7 })).assertTrue();
      expect(lookup.isPrivateHistory({ id: 8, originBookId: 9 })).assertFalse();
    });

    it('normalizesAbsolutePathsAndEncodedFileUriAliasesInBothDirections', 0, () => {
      const path = '/data/storage/el2/base/files/书 名.epub';
      const uri = 'file:///data/storage/el2/base/files/%E4%B9%A6%20%E5%90%8D.epub';
      const pathLookup = new PrivacyOwnershipLookup([{ id: 7, bookUrl: path }]);
      const uriLookup = new PrivacyOwnershipLookup([{ id: 8, bookUrl: uri }]);
      expect(pathLookup.isPrivateBook({ id: 10, bookUrl: uri })).assertTrue();
      expect(uriLookup.isPrivateBook({ id: 11, bookUrl: path })).assertTrue();
      expect(pathLookup.isPrivateHistory({ id: 12, originBookId: 13, bookUrl: uri })).assertTrue();
      expect(uriLookup.isPrivateHistory({ bookUrl: path })).assertTrue();
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
        expect(lookup.isPrivateHistory({ id: 10, bookUrl: source })).assertFalse();
      }
      const lookup = new PrivacyOwnershipLookup([{ id: 7 }]);
      expect(lookup.isPrivateHistory({ id: 7, bookUrl: sources[1] })).assertTrue();
      expect(lookup.isPrivateHistory({})).assertFalse();
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

    it('filtersAllOwnershipFormsWithOneLoadAndKeepsPublicOrder', 0, async () => {
      const histories: PrivacyHistoryIdentity[] = [
        { id: 7 }, { id: 20 }, { id: 21, originBookId: 7 },
        { id: 22, bookUrl: 'file:///data/private%20book.epub' },
        { id: 23, bookUrl: '/data/public.epub' }, { id: 24 }
      ];
      let loads = 0;
      let generationChecks = 0;
      const result = await filterPublicHistories<PrivacyHistoryIdentity>(histories, 3, async () => {
        loads++;
        return new PrivacyOwnershipLookup([{ id: 7, bookUrl: '/data/private book.epub' }]);
      }, () => { generationChecks++; return 3; });
      expect(loads).assertEqual(1);
      expect(generationChecks).assertEqual(1);
      expect(result.length).assertEqual(3);
      expect(result[0]).assertEqual(histories[1]);
      expect(result[1]).assertEqual(histories[4]);
      expect(result[2]).assertEqual(histories[5]);
      expect(histories.length).assertEqual(6);
    });

    it('keepsFirstPublicHistoryWhenTheMostRecentRowIsPrivate', 0, async () => {
      const histories: PrivacyHistoryIdentity[] = [{ id: 7 }, { id: 8 }, { id: 9 }];
      const publicHistories = await filterPublicHistories<PrivacyHistoryIdentity>(histories, 3,
        async () => new PrivacyOwnershipLookup([{ id: 7 }]), () => 3);
      const limited = publicHistories.slice(0, 1);
      expect(limited.length).assertEqual(1);
      expect(limited[0]).assertEqual(histories[1]);
    });

    it('returnsEmptyWhenAllHistoriesArePrivate', 0, async () => {
      const result = await filterPublicHistories<PrivacyHistoryIdentity>([{ id: 7 }, { originBookId: 7 }], 3,
        async () => new PrivacyOwnershipLookup([{ id: 7 }]), () => 3);
      expect(result.length).assertEqual(0);
    });

    it('treatsKnownEmptyOwnershipAsPublic', 0, async () => {
      const histories: PrivacyHistoryIdentity[] = [{ id: 8 }, { bookUrl: '/data/public.epub' }];
      const result = await filterPublicHistories<PrivacyHistoryIdentity>(histories, 3,
        async () => new PrivacyOwnershipLookup([]), () => 3);
      expect(result.length).assertEqual(2);
      expect(result[0]).assertEqual(histories[0]);
      expect(result[1]).assertEqual(histories[1]);
    });

    it('skipsOwnershipAndGenerationReadsForEmptyInput', 0, async () => {
      let calls = 0;
      const histories: PrivacyHistoryIdentity[] = [];
      const result = await filterPublicHistories<PrivacyHistoryIdentity>(histories, 3, async () => {
        calls++;
        throw new Error('Ownership unavailable');
      }, () => { calls++; throw new Error('Generation unavailable'); });
      expect(result.length).assertEqual(0);
      expect(calls).assertEqual(0);
    });

    it('failsClosedForUnknownGenerationWithoutLoadingOwnership', 0, async () => {
      let loads = 0;
      const result = await filterPublicHistories<PrivacyHistoryIdentity>([{ id: 8 }], -1, async () => {
        loads++;
        return new PrivacyOwnershipLookup([]);
      }, () => -1);
      expect(result.length).assertEqual(0);
      expect(loads).assertEqual(0);
    });

    it('reloadsOwnershipForEveryOperationAndGeneration', 0, async () => {
      let privateBooks: PrivacyBookIdentity[] = [];
      let generation = 3;
      let loads = 0;
      const loadOwnership = async (): Promise<PrivacyOwnershipLookup> => {
        loads++;
        return new PrivacyOwnershipLookup(privateBooks);
      };
      const histories: PrivacyHistoryIdentity[] = [{ id: 7 }];
      expect((await filterPublicHistories<PrivacyHistoryIdentity>(histories, generation, loadOwnership, () => generation)).length)
        .assertEqual(1);
      privateBooks = [{ id: 7 }];
      expect((await filterPublicHistories<PrivacyHistoryIdentity>(histories, generation, loadOwnership, () => generation)).length)
        .assertEqual(0);
      privateBooks = [];
      generation++;
      expect((await filterPublicHistories<PrivacyHistoryIdentity>(histories, generation, loadOwnership, () => generation)).length)
        .assertEqual(1);
      expect(loads).assertEqual(3);
    });

    it('discardsResultsIfGenerationChangesDuringOwnershipLoad', 0, async () => {
      let generation = 3;
      const result = await filterPublicHistories<PrivacyHistoryIdentity>([{ id: 8 }], generation, async () => {
        generation++;
        return new PrivacyOwnershipLookup([]);
      }, () => generation);
      expect(result.length).assertEqual(0);
    });

    it('doesNotReturnPublicRowsWhenOwnershipLoadFails', 0, async () => {
      await expectOwnershipFailure(() => filterPublicHistories<PrivacyHistoryIdentity>([{ id: 8 }], 3, async () => {
        throw new Error('Privacy ownership database unavailable');
      }, () => 3));
    });

    it('doesNotReuseSuccessfulSnapshotAfterALaterReadFailure', 0, async () => {
      let loads = 0;
      const loadOwnership = async (): Promise<PrivacyOwnershipLookup> => {
        loads++;
        if (loads > 1) throw new Error('Ownership query failed');
        return new PrivacyOwnershipLookup([]);
      };
      expect((await filterPublicHistories<PrivacyHistoryIdentity>([{ id: 8 }], 3, loadOwnership, () => 3)).length).assertEqual(1);
      await expectOwnershipFailure(() => filterPublicHistories<PrivacyHistoryIdentity>([{ id: 8 }], 3, loadOwnership, () => 3));
      expect(loads).assertEqual(2);
    });

    it('doesNotReturnPublicRowsWhenGenerationReadFails', 0, async () => {
      await expectOwnershipFailure(() => filterPublicHistories<PrivacyHistoryIdentity>([{ id: 8 }], 3,
        async () => new PrivacyOwnershipLookup([]), () => { throw new Error('Generation unavailable'); }));
    });
  });
}
