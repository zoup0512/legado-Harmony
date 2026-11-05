import { describe, expect, it } from '@ohos/hypium';
import {
  PrivacyCooldownClock, PrivacyMonotonicClock
} from '../../../main/ets/privacy/PrivacyMonotonicClock';
import { PrivacyPinPolicy } from '../../../main/ets/privacy/PrivacyPinPolicy';

class ClockSources {
  wallMs: number = 1000000;
  uptimeMs: number = 50000;
  wallReads: number = 0;

  wallNow(): number {
    this.wallReads++;
    return this.wallMs;
  }
}

function expectClockFailure(operation: () => void): void {
  let rejected = false;
  try {
    operation();
  } catch (_) {
    rejected = true;
  }
  expect(rejected).assertTrue();
}

export default function privacyMonotonicClockTest() {
  describe('PrivacyMonotonicClockTest', () => {
    it('elapsedClockUsesOnlyInjectedUptimeIncludingZero', 0, () => {
      const sources = new ClockSources();
      sources.uptimeMs = 0;
      const clock = new PrivacyMonotonicClock(() => sources.uptimeMs);
      expect(clock.now()).assertEqual(0);
      sources.wallMs += 86400000;
      expect(clock.now()).assertEqual(0);
      sources.uptimeMs += 12000;
      expect(clock.now()).assertEqual(12000);
      sources.wallMs = 1;
      expect(clock.now()).assertEqual(12000);
    });

    it('nonPendingSeedUsesWallOrPersistedFloorOnceThenOnlyElapsedTime', 0, () => {
      const initialWalls: number[] = [-1000000, 2000000];
      for (let index = 0; index < initialWalls.length; index++) {
        const sources = new ClockSources();
        sources.wallMs = initialWalls[index];
        const clock = new PrivacyCooldownClock(() => sources.wallNow(), () => sources.uptimeMs);
        const expectedSeed = Math.max(1000000, sources.wallMs);
        clock.seed(1000000, false);
        expect(clock.now()).assertEqual(expectedSeed);
        sources.wallMs += 86400000;
        sources.uptimeMs += 10000;
        clock.seed(sources.wallMs, false);
        expect(clock.now()).assertEqual(expectedSeed + 10000);
        sources.wallMs = 0;
        sources.uptimeMs += 20000;
        expect(clock.now()).assertEqual(expectedSeed + 30000);
        expect(sources.wallReads).assertEqual(1);
      }
    });

    it('pendingSeedUsesPersistedFloorWithoutReadingWallOrRearming', 0, () => {
      const sources = new ClockSources();
      sources.wallMs = Infinity;
      const clock = new PrivacyCooldownClock(() => sources.wallNow(), () => sources.uptimeMs);
      clock.seed(1000000, true);
      expect(clock.now()).assertEqual(1000000);
      sources.uptimeMs += 10000;
      clock.seed(1000000, true);
      expect(clock.now()).assertEqual(1010000);
      clock.seed(2000000, false);
      expect(clock.now()).assertEqual(1010000);
      sources.uptimeMs += PrivacyPinPolicy.MAX_RETRY_MS;
      clock.seed(1000000, true);
      expect(clock.now()).assertEqual(1010000 + PrivacyPinPolicy.MAX_RETRY_MS);
      expect(sources.wallReads).assertEqual(0);
    });

    it('invalidOrBackwardUptimeRejectsWithoutWallFallbackAndCanRecover', 0, () => {
      const sources = new ClockSources();
      const clock = new PrivacyMonotonicClock(() => sources.uptimeMs);
      expect(clock.now()).assertEqual(50000);
      const invalid: number[] = [-1, NaN, Infinity, 1.5, Number.MAX_SAFE_INTEGER + 1, 49999];
      for (let index = 0; index < invalid.length; index++) {
        sources.uptimeMs = invalid[index];
        expectClockFailure(() => { clock.now(); });
      }
      sources.uptimeMs = 51000;
      expect(clock.now()).assertEqual(51000);
    });

    it('unseededUnsafeWallAndVirtualOverflowRejectWithoutCorruptingSeed', 0, () => {
      const sources = new ClockSources();
      const clock = new PrivacyCooldownClock(() => sources.wallNow(), () => sources.uptimeMs);
      expectClockFailure(() => { clock.now(); });
      const invalid: number[] = [NaN, Infinity, 1.5, Number.MAX_SAFE_INTEGER];
      for (let index = 0; index < invalid.length; index++) {
        sources.wallMs = invalid[index];
        expectClockFailure(() => clock.seed(0, false));
      }
      sources.wallMs = 1000000;
      clock.seed(0, false);
      expect(clock.now()).assertEqual(1000000);
      sources.uptimeMs = Number.MAX_SAFE_INTEGER;
      expectClockFailure(() => { clock.now(); });
    });
  });
}
