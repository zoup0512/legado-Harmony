import { describe, expect, it } from '@ohos/hypium';
import { loadWindowContentWhenReady } from '../../../main/ets/entryability/WindowContentStartup';

export default function windowContentStartupTest() {
  describe('WindowContentStartupTest', () => {
    it('loadsCurrentStageOnlyAfterWindowIsReady', 0, async () => {
      const events: string[] = [];
      await loadWindowContentWhenReady(async (): Promise<void> => {
        events.push('waiting');
        await Promise.resolve();
        events.push('ready');
      }, () => true, () => { events.push('load'); });
      expect(events.join(',')).assertEqual('waiting,ready,load');
    });

    it('windowReadinessFailureNeverLoadsContent', 0, async () => {
      let loaded = false;
      let failed = false;
      try {
        await loadWindowContentWhenReady(async (): Promise<void> => {
          throw new Error('window unavailable');
        }, () => true, () => { loaded = true; });
      } catch (_) {
        failed = true;
      }
      expect(failed).assertTrue();
      expect(loaded).assertFalse();
    });

    it('destroyedStageCannotLoadAfterDelayedReadiness', 0, async () => {
      let current = true;
      let loaded = false;
      await loadWindowContentWhenReady(async (): Promise<void> => {
        await Promise.resolve();
        current = false;
      }, () => current, () => { loaded = true; });
      expect(loaded).assertFalse();
    });

    it('alreadyDestroyedStageDoesNotWaitForWindow', 0, async () => {
      let waited = false;
      await loadWindowContentWhenReady(async (): Promise<void> => {
        waited = true;
      }, () => false, () => { throw new Error('must not load'); });
      expect(waited).assertFalse();
    });

    it('replacedStageCannotLoadButItsReplacementCan', 0, async () => {
      let currentStage = 1;
      const loaded: number[] = [];
      await loadWindowContentWhenReady(async (): Promise<void> => {
        await Promise.resolve();
        currentStage = 2;
      }, () => currentStage === 1, () => { loaded.push(1); });
      expect(loaded.length).assertEqual(0);
      await loadWindowContentWhenReady(async (): Promise<void> => {
        await Promise.resolve();
      }, () => currentStage === 2, () => { loaded.push(2); });
      expect(loaded.join(',')).assertEqual('2');
    });
  });
}
