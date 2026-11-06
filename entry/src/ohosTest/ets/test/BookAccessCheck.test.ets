import { describe, expect, it } from '@ohos/hypium';
import { checkPrivateBook, PrivacyOwnershipLookup } from '../../../main/ets/privacy/PrivacyOwnershipLookup';
import { PRIVACY_BOOK_GROUP } from '../../../main/ets/privacy/PrivacyConstants';
import { PageAccessRefresh } from '../../../main/ets/privacy/PageAccessRefresh';

class OwnershipGate {
  wait: Promise<PrivacyOwnershipLookup>;
  private release: (value: PrivacyOwnershipLookup) => void = (_value: PrivacyOwnershipLookup): void => {};

  constructor() {
    this.wait = new Promise<PrivacyOwnershipLookup>((resolve) => { this.release = resolve; });
  }

  open(): void { this.release(new PrivacyOwnershipLookup([])); }
}

export default function bookAccessCheckTest() {
  describe('BookAccessCheckTest', () => {
    it('ordinaryBookRequiresSuccessfulOwnershipLookup', 0, async () => {
      const required = await checkPrivateBook({ id: 1, bookGroup: 4 },
        async (): Promise<PrivacyOwnershipLookup> => new PrivacyOwnershipLookup([]));
      expect(required).assertFalse();
    });

    it('explicitPrivateBookNeedsNoDatabaseLookup', 0, async () => {
      let calls = 0;
      const required = await checkPrivateBook({ bookGroup: PRIVACY_BOOK_GROUP },
        async (): Promise<PrivacyOwnershipLookup> => { calls++; throw new Error('unavailable'); });
      expect(required).assertTrue();
      expect(calls).assertEqual(0);
    });

    it('failedLookupNeverClassifiesBookAsPublic', 0, async () => {
      let rejected = false;
      try {
        await checkPrivateBook({ id: 1 },
          async (): Promise<PrivacyOwnershipLookup> => { throw new Error('unavailable'); });
      } catch (_) { rejected = true; }
      expect(rejected).assertTrue();
    });

    it('synchronousLookupFailureRejects', 0, async () => {
      let rejected = false;
      try {
        await checkPrivateBook({ id: 1 },
          (): Promise<PrivacyOwnershipLookup> => { throw new Error('unavailable'); });
      } catch (_) { rejected = true; }
      expect(rejected).assertTrue();
    });

    it('timeoutAllowsRetryAndIgnoresLateOwnershipResult', 0, async () => {
      const gate = new OwnershipGate();
      const refresh = new PageAccessRefresh();
      let published = 0;
      let rejected = false;
      try {
        await refresh.refresh(1, false, async (_requestId: number): Promise<boolean> => {
          await checkPrivateBook({ id: 1 }, (): Promise<PrivacyOwnershipLookup> => gate.wait, 10);
          published++;
          return true;
        });
      } catch (_) { rejected = true; }
      expect(rejected).assertTrue();
      expect(published).assertEqual(0);
      await refresh.refresh(1, false, async (_requestId: number): Promise<boolean> => {
        await checkPrivateBook({ id: 1 },
          async (): Promise<PrivacyOwnershipLookup> => new PrivacyOwnershipLookup([]));
        published++;
        return true;
      });
      gate.open();
      await gate.wait;
      await Promise.resolve();
      expect(published).assertEqual(1);
    });

    it('hiddenPageDiscardsCompletedOwnershipCheck', 0, async () => {
      const gate = new OwnershipGate();
      const entered = new OwnershipGate();
      const refresh = new PageAccessRefresh();
      let published = false;
      const pending = refresh.refresh(1, false, async (requestId: number): Promise<boolean> => {
        entered.open();
        await checkPrivateBook({ id: 1 }, (): Promise<PrivacyOwnershipLookup> => gate.wait);
        if (requestId !== refresh.getRequestId()) return false;
        published = true;
        return true;
      });
      await entered.wait;
      refresh.invalidate();
      gate.open();
      await pending;
      expect(published).assertFalse();
    });
  });
}
