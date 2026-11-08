import { describe, expect, it } from '@ohos/hypium';
import { MarketUpdateCallbacks, MarketUpdateController, MarketUpdateFailure,
  MarketUpdateTimer } from '../../../main/ets/common/utils/MarketUpdateController';

class FakeMarketTimer implements MarketUpdateTimer {
  callbacks: Array<() => void> = [];
  delays: number[] = [];
  pending: Set<number> = new Set<number>();

  schedule(callback: () => void, delayMs: number): number {
    const id = this.callbacks.length;
    this.callbacks.push(callback);
    this.delays.push(delayMs);
    this.pending.add(id);
    return id;
  }

  cancel(timerId: number): void {
    this.pending.delete(timerId);
  }

  // Deliberately allow stale/cancelled callbacks to prove request identity guards.
  fire(timerId: number): void {
    this.pending.delete(timerId);
    this.callbacks[timerId]();
  }
}

class MarketHarness {
  timer: FakeMarketTimer = new FakeMarketTimer();
  controller: MarketUpdateController = new MarketUpdateController(this.timer);
  calls: MarketUpdateCallbacks[] = [];
  failures: MarketUpdateFailure[] = [];

  open(): boolean {
    return this.controller.open((callbacks: MarketUpdateCallbacks): void => {
      this.calls.push(callbacks);
    }, (failure: MarketUpdateFailure): void => { this.failures.push(failure); });
  }
}

export default function marketUpdateControllerTest() {
  describe('MarketUpdateControllerTest', () => {
    it('inactivePageNeverStartsMarketOrTimer', 0, () => {
      const h = new MarketHarness();
      expect(h.open()).assertFalse();
      expect(h.calls.length).assertEqual(0);
      expect(h.timer.pending.size).assertEqual(0);
    });

    it('voidReturnIsNotSuccessAndRepeatedClicksStayLockedUntilDisappear', 0, () => {
      const h = new MarketHarness();
      h.controller.activate();
      expect(h.open()).assertTrue();
      expect(h.open()).assertFalse();
      expect(h.timer.delays[0]).assertEqual(10000);
      expect(h.timer.pending.size).assertEqual(1);
      expect(h.failures.length).assertEqual(0);
      h.calls[0].onAppear();
      expect(h.timer.pending.size).assertEqual(0);
      expect(h.open()).assertFalse();
      h.timer.fire(0);
      expect(h.failures.length).assertEqual(0);
      h.calls[0].onDisappear();
      expect(h.open()).assertTrue();
      expect(h.calls.length).assertEqual(2);
      h.controller.deactivate();
    });

    it('synchronousThrowReportsOnceClearsTimerAndAllowsRetry', 0, () => {
      const h = new MarketHarness();
      h.controller.activate();
      expect(h.controller.open((_callbacks: MarketUpdateCallbacks): void => {
        throw new Error('market unavailable');
      }, (failure: MarketUpdateFailure): void => { h.failures.push(failure); })).assertTrue();
      expect(h.failures.length).assertEqual(1);
      expect(h.failures[0]).assertEqual(MarketUpdateFailure.OPEN_FAILED);
      expect(h.timer.pending.size).assertEqual(0);
      expect(h.open()).assertTrue();
      h.timer.fire(0);
      expect(h.open()).assertFalse();
      expect(h.failures.length).assertEqual(1);
      h.controller.deactivate();
    });

    it('asynchronousOnErrorReportsOnceAndOldCallbacksCannotFinishRetry', 0, () => {
      const h = new MarketHarness();
      h.controller.activate();
      h.open();
      h.calls[0].onError();
      h.calls[0].onError();
      expect(h.failures.length).assertEqual(1);
      expect(h.failures[0]).assertEqual(MarketUpdateFailure.OPEN_FAILED);
      expect(h.timer.pending.size).assertEqual(0);
      expect(h.open()).assertTrue();
      h.calls[0].onAppear();
      h.calls[0].onDisappear();
      h.calls[0].onError();
      expect(h.timer.pending.size).assertEqual(1);
      expect(h.open()).assertFalse();
      expect(h.failures.length).assertEqual(1);
      h.calls[1].onDisappear();
      expect(h.timer.pending.size).assertEqual(0);
      expect(h.open()).assertTrue();
      h.controller.deactivate();
    });

    it('synchronousOnErrorThenThrowDoesNotReportTwice', 0, () => {
      const h = new MarketHarness();
      h.controller.activate();
      h.controller.open((callbacks: MarketUpdateCallbacks): void => {
        callbacks.onError();
        throw new Error('also thrown');
      }, (failure: MarketUpdateFailure): void => { h.failures.push(failure); });
      expect(h.failures.length).assertEqual(1);
      expect(h.timer.pending.size).assertEqual(0);
      expect(h.open()).assertTrue();
      h.controller.deactivate();
    });

    it('missingCallbacksTimeoutOnceUnlocksAndIgnoresLateOldResults', 0, () => {
      const h = new MarketHarness();
      h.controller.activate();
      h.open();
      h.timer.fire(0);
      h.timer.fire(0);
      expect(h.failures.length).assertEqual(1);
      expect(h.failures[0]).assertEqual(MarketUpdateFailure.TIMEOUT);
      expect(h.timer.pending.size).assertEqual(0);
      expect(h.open()).assertTrue();
      h.calls[0].onAppear();
      h.calls[0].onDisappear();
      h.calls[0].onError();
      h.timer.fire(0);
      expect(h.timer.pending.size).assertEqual(1);
      expect(h.open()).assertFalse();
      expect(h.failures.length).assertEqual(1);
      h.controller.deactivate();
    });

    it('pageLeaveCancelsSilentlyAndReentryRejectsEveryOldCallback', 0, () => {
      const h = new MarketHarness();
      h.controller.activate();
      h.open();
      h.controller.deactivate();
      h.controller.deactivate();
      expect(h.timer.pending.size).assertEqual(0);
      expect(h.open()).assertFalse();
      h.calls[0].onError();
      h.timer.fire(0);
      expect(h.failures.length).assertEqual(0);
      h.controller.activate();
      expect(h.open()).assertTrue();
      h.calls[0].onAppear();
      h.calls[0].onDisappear();
      h.calls[0].onError();
      h.timer.fire(0);
      expect(h.timer.pending.size).assertEqual(1);
      expect(h.open()).assertFalse();
      expect(h.failures.length).assertEqual(0);
      h.calls[1].onError();
      expect(h.failures.length).assertEqual(1);
      h.controller.deactivate();
    });

    it('disappearWithoutAppearIsNormalClosureNotUpdateCheckSuccess', 0, () => {
      const h = new MarketHarness();
      h.controller.activate();
      h.open();
      h.calls[0].onDisappear();
      h.calls[0].onError();
      h.timer.fire(0);
      expect(h.failures.length).assertEqual(0);
      expect(h.timer.pending.size).assertEqual(0);
      expect(h.open()).assertTrue();
      h.controller.deactivate();
    });

    it('pageLeaveAfterAppearReleasesDisplayedMarketWithoutFeedback', 0, () => {
      const h = new MarketHarness();
      h.controller.activate();
      h.open();
      h.calls[0].onAppear();
      h.controller.deactivate();
      h.calls[0].onError();
      h.calls[0].onDisappear();
      expect(h.failures.length).assertEqual(0);
      h.controller.activate();
      expect(h.open()).assertTrue();
      h.controller.deactivate();
    });
  });
}
