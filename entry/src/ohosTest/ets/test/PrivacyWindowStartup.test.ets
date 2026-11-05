import { describe, expect, it } from '@ohos/hypium';
import { loadPrivacyProtectedContent } from '../../../main/ets/privacy/PrivacyWindowStartup';

export default function privacyWindowStartupTest() {
  describe('PrivacyWindowStartupTest', () => {
    it('loadsOnlyAfterNativeProtectionCompletes', 0, async () => {
      const events: string[] = [];
      await loadPrivacyProtectedContent(async (): Promise<void> => {
        events.push('protect');
        await Promise.resolve();
        events.push('protected');
      }, () => true, () => { events.push('load'); });
      expect(events.join(',')).assertEqual('protect,protected,load');
    });

    it('protectionFailureNeverLoadsContent', 0, async () => {
      let loaded = false;
      let failed = false;
      try {
        await loadPrivacyProtectedContent(async (): Promise<void> => {
          throw new Error('native protection unavailable');
        }, () => true, () => { loaded = true; });
      } catch (_) {
        failed = true;
      }
      expect(failed).assertTrue();
      expect(loaded).assertFalse();
    });

    it('destroyedStageCannotLoadAfterDelayedProtection', 0, async () => {
      let current = true;
      let loaded = false;
      await loadPrivacyProtectedContent(async (): Promise<void> => {
        await Promise.resolve();
        current = false;
      }, () => current, () => { loaded = true; });
      expect(loaded).assertFalse();
    });

    it('alreadyDestroyedStageDoesNotStartNativeWork', 0, async () => {
      let protectedWindow = false;
      await loadPrivacyProtectedContent(async (): Promise<void> => {
        protectedWindow = true;
      }, () => false, () => { throw new Error('must not load'); });
      expect(protectedWindow).assertFalse();
    });
  });
}
