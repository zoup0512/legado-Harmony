import { describe, expect, it } from '@ohos/hypium';
import { BookOwnership } from '../../../main/ets/privacy/BookAccessState';
import { PrivacyForeground } from '../../../main/ets/privacy/PrivacyForeground';
import { PrivateBookAutoUnlock, PrivateBookUnlockSnapshot } from '../../../main/ets/privacy/PrivateBookAutoUnlock';

function tick(): Promise<void> { return new Promise<void>((resolve) => { setTimeout(resolve, 10); }); }

class UnlockFixture {
  foreground: PrivacyForeground = new PrivacyForeground();
  state: PrivateBookUnlockSnapshot = {
    active: true, ready: true, ownership: BookOwnership.PRIVATE, failed: false,
    unlocked: false, authenticating: false, generation: 1
  };
  calls: number = 0;
  returns: number = 0;
  restores: number = 0;
  pending: boolean = false;
  finish: (success: boolean) => void = (_success: boolean): void => {};
  coordinator: PrivateBookAutoUnlock;

  constructor() {
    this.coordinator = new PrivateBookAutoUnlock(this.foreground, {
      snapshot: (): PrivateBookUnlockSnapshot => this.state,
      unlock: (): Promise<boolean> => {
        this.calls++;
        return new Promise<boolean>((resolve) => { this.finish = resolve; });
      },
      restored: async (): Promise<void> => { this.restores++; },
      returnToShelf: (): void => { this.returns++; },
      pendingChanged: (pending: boolean): void => { this.pending = pending; }
    }, 1);
  }
}

export default function privateBookAutoUnlockTest() {
  describe('PrivateBookAutoUnlockTest', () => {
    it('publicUnknownAndFailedBooksNeverAuthenticate', 0, async () => {
      const fixture = new UnlockFixture();
      fixture.state.ownership = BookOwnership.PUBLIC;
      fixture.foreground.enter();
      await tick();
      fixture.state.ownership = BookOwnership.UNKNOWN;
      fixture.coordinator.reconcile();
      await tick();
      fixture.state.ownership = BookOwnership.PRIVATE;
      fixture.state.failed = true;
      fixture.coordinator.reconcile();
      await tick();
      expect(fixture.calls).assertEqual(0);
      fixture.coordinator.dispose();
    });

    it('foregroundBeforeShowAuthenticatesOnceAndRestores', 0, async () => {
      const fixture = new UnlockFixture();
      fixture.state.active = false;
      fixture.foreground.enter();
      await tick();
      expect(fixture.calls).assertEqual(0);
      fixture.state.active = true;
      fixture.coordinator.reconcile();
      fixture.coordinator.reconcile();
      await tick();
      expect(fixture.calls).assertEqual(1);
      fixture.state.unlocked = true;
      fixture.finish(true);
      await tick();
      fixture.coordinator.reconcile();
      expect(fixture.restores).assertEqual(1);
      expect(fixture.calls).assertEqual(1);
      expect(fixture.pending).assertFalse();
      fixture.coordinator.dispose();
    });

    it('showBeforeForegroundWaitsForFinalGeneration', 0, async () => {
      const fixture = new UnlockFixture();
      fixture.coordinator.reconcile();
      await tick();
      expect(fixture.calls).assertEqual(0);
      fixture.state.generation++;
      fixture.foreground.enter();
      await tick();
      expect(fixture.calls).assertEqual(1);
      fixture.finish(false);
      await tick();
      expect(fixture.returns).assertEqual(1);
      fixture.coordinator.reconcile();
      await tick();
      expect(fixture.calls).assertEqual(1);
      fixture.coordinator.dispose();
    });

    it('pinRouteReturnDoesNotRestartAuthentication', 0, async () => {
      const fixture = new UnlockFixture();
      fixture.foreground.enter();
      await tick();
      fixture.state.active = false;
      fixture.coordinator.reconcile();
      fixture.state.active = true;
      fixture.coordinator.reconcile();
      await tick();
      expect(fixture.calls).assertEqual(1);
      fixture.state.active = false;
      fixture.finish(false);
      await tick();
      expect(fixture.returns).assertEqual(0);
      fixture.state.active = true;
      fixture.coordinator.reconcile();
      expect(fixture.returns).assertEqual(1);
      fixture.coordinator.dispose();
    });

    it('backgroundCancelsTimerAndNextEpochCanAuthenticate', 0, async () => {
      const fixture = new UnlockFixture();
      fixture.foreground.enter();
      fixture.foreground.leave();
      await tick();
      expect(fixture.calls).assertEqual(0);
      fixture.state.generation++;
      fixture.foreground.enter();
      await tick();
      expect(fixture.calls).assertEqual(1);
      fixture.coordinator.dispose();
      fixture.finish(false);
    });

    it('backgroundInvalidatesLateFailureWithoutNavigating', 0, async () => {
      const fixture = new UnlockFixture();
      fixture.foreground.enter();
      await tick();
      const oldFinish = fixture.finish;
      fixture.foreground.leave();
      fixture.state.generation++;
      oldFinish(false);
      await tick();
      expect(fixture.returns).assertEqual(0);
      fixture.foreground.enter();
      await tick();
      expect(fixture.calls).assertEqual(2);
      fixture.state.unlocked = true;
      fixture.finish(true);
      await tick();
      expect(fixture.restores).assertEqual(1);
      fixture.coordinator.dispose();
    });

    it('hideBeforeDelayDoesNotOpenAuthentication', 0, async () => {
      const fixture = new UnlockFixture();
      fixture.foreground.enter();
      fixture.state.active = false;
      fixture.coordinator.reconcile();
      await tick();
      expect(fixture.calls).assertEqual(0);
      fixture.coordinator.dispose();
    });
  });
}
