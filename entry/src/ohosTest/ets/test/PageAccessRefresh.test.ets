import { describe, expect, it } from '@ohos/hypium';
import { PageAccessRefresh } from '../../../main/ets/privacy/PageAccessRefresh';

class RefreshGate {
  wait: Promise<void>;
  private release: () => void = (): void => {};

  constructor() {
    this.wait = new Promise<void>((resolve) => { this.release = resolve; });
  }

  open(): void { this.release(); }
}

export default function pageAccessRefreshTest() {
  describe('PageAccessRefreshTest', () => {
    it('coalescesAppearanceAndShowDuringAndAfterInitialization', 0, async () => {
      const refresh = new PageAccessRefresh();
      const entered = new RefreshGate();
      const finish = new RefreshGate();
      let calls = 0;
      const initialize = async (_requestId: number): Promise<boolean> => {
        calls++;
        entered.open();
        await finish.wait;
        return true;
      };
      const appearance = refresh.refresh(1, true, initialize);
      await entered.wait;
      const show = refresh.refresh(1, true, initialize);
      expect(appearance === show).assertTrue();
      finish.open();
      await Promise.all([appearance, show]);
      await refresh.refresh(1, true, initialize);
      expect(calls).assertEqual(1);
    });

    it('hideAndShowRecheckOwnershipEvenWithoutSessionChange', 0, async () => {
      const refresh = new PageAccessRefresh();
      let calls = 0;
      const initialize = async (_requestId: number): Promise<boolean> => { calls++; return true; };
      await refresh.refresh(1, false, initialize);
      refresh.invalidate();
      await refresh.refresh(1, false, initialize);
      expect(calls).assertEqual(2);
    });

    it('discardsDelayedParserBeforeStartingNewControllerWork', 0, async () => {
      const refresh = new PageAccessRefresh();
      const entered = new RefreshGate();
      const finish = new RefreshGate();
      let calls = 0;
      let published = 0;
      const initialize = async (requestId: number): Promise<boolean> => {
        calls++;
        if (calls === 1) {
          entered.open();
          await finish.wait;
        }
        if (requestId !== refresh.getRequestId()) return false;
        published++;
        return true;
      };
      const old = refresh.refresh(1, true, initialize);
      await entered.wait;
      refresh.invalidate();
      const current = refresh.refresh(1, true, initialize);
      expect(calls).assertEqual(1);
      finish.open();
      await Promise.all([old, current]);
      expect(calls).assertEqual(2);
      expect(published).assertEqual(1);
    });

    it('onlyLatestQueuedShowCanInitialize', 0, async () => {
      const refresh = new PageAccessRefresh();
      let calls = 0;
      const initialize = async (_requestId: number): Promise<boolean> => { calls++; return true; };
      const old = refresh.refresh(1, true, initialize);
      refresh.invalidate();
      const current = refresh.refresh(2, true, initialize);
      await Promise.all([old, current]);
      expect(calls).assertEqual(1);
    });

    it('showBeforeAuthCompletionDoesNotSwallowUnlockedRefresh', 0, async () => {
      const refresh = new PageAccessRefresh();
      const entered = new RefreshGate();
      const finish = new RefreshGate();
      let uncovered = false;
      const locked = refresh.refresh(2, false, async (_requestId: number): Promise<boolean> => {
        entered.open();
        await finish.wait;
        return false;
      });
      await entered.wait;
      const unlocked = refresh.refresh(2, true, async (_requestId: number): Promise<boolean> => {
        uncovered = true;
        return true;
      });
      finish.open();
      await Promise.all([locked, unlocked]);
      expect(uncovered).assertTrue();
    });

    it('authCompletionBeforeShowIsCoalesced', 0, async () => {
      const refresh = new PageAccessRefresh();
      let calls = 0;
      const initialize = async (_requestId: number): Promise<boolean> => { calls++; return true; };
      await refresh.refresh(2, true, initialize);
      await refresh.refresh(2, true, initialize);
      expect(calls).assertEqual(1);
      await refresh.refresh(3, true, initialize);
      expect(calls).assertEqual(2);
    });

    it('failureIsRetryableAndDoesNotPoisonQueue', 0, async () => {
      const refresh = new PageAccessRefresh();
      let caught = false;
      try {
        await refresh.refresh(1, false, async (_requestId: number): Promise<boolean> => {
          throw new Error('ownership unavailable');
        });
      } catch (_) {
        caught = true;
      }
      expect(caught).assertTrue();
      let calls = 0;
      await refresh.refresh(1, false, async (_requestId: number): Promise<boolean> => {
        calls++;
        return false;
      });
      await refresh.refresh(1, false, async (_requestId: number): Promise<boolean> => {
        calls++;
        return true;
      });
      expect(calls).assertEqual(2);
    });

    it('lockInvalidatesCompletedAndInFlightAuthorization', 0, async () => {
      const refresh = new PageAccessRefresh();
      await refresh.refresh(4, true, async (_requestId: number): Promise<boolean> => true);
      const oldId = refresh.getRequestId();
      refresh.invalidate();
      expect(refresh.getRequestId() !== oldId).assertTrue();
      let called = false;
      await refresh.refresh(5, false, async (_requestId: number): Promise<boolean> => {
        called = true;
        return false;
      });
      expect(called).assertTrue();
    });
  });
}
