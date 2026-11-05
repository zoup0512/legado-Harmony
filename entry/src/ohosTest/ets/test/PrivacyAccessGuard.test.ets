import { describe, expect, it } from '@ohos/hypium';
import { PrivacyAccessGuard } from '../../../main/ets/privacy/PrivacyAccessGuard';

export default function privacyAccessGuardTest() {
  describe('PrivacyAccessGuardTest', () => {
    it('failsClosedBeforeSessionBinding', 0, () => {
      const guard = new PrivacyAccessGuard();
      expect(guard.getGeneration()).assertEqual(-1);
      expect(guard.capture()).assertEqual(-1);
      expect(guard.isValid(-1)).assertFalse();
      expect(guard.isValid(0)).assertFalse();
    });

    it('capturesOnlyAnUnlockedSession', 0, () => {
      const guard = new PrivacyAccessGuard();
      let unlocked = false;
      guard.bind(() => unlocked, () => 7);
      expect(guard.getGeneration()).assertEqual(7);
      expect(guard.capture()).assertEqual(-1);
      expect(guard.isValid(7)).assertFalse();
      unlocked = true;
      expect(guard.capture()).assertEqual(7);
      expect(guard.isValid(7)).assertTrue();
    });

    it('invalidatesCapturedAuthorizationOnLockAndRelock', 0, () => {
      const guard = new PrivacyAccessGuard();
      let unlocked = true;
      let generation = 3;
      guard.bind(() => unlocked, () => generation);
      const captured = guard.capture();
      expect(guard.isValid(captured)).assertTrue();
      unlocked = false;
      generation++;
      expect(guard.isValid(captured)).assertFalse();
      unlocked = true;
      expect(guard.isValid(captured)).assertFalse();
      expect(guard.isValid(guard.capture())).assertTrue();
    });

    it('rejectsChangedGenerationEvenIfUnlockedAgain', 0, () => {
      const guard = new PrivacyAccessGuard();
      let generation = 10;
      guard.bind(() => true, () => generation);
      const captured = guard.capture();
      generation = 12;
      expect(guard.isValid(captured)).assertFalse();
      expect(guard.capture()).assertEqual(12);
    });

    it('failsClosedWhenProvidersThrowOrReturnInvalidGeneration', 0, () => {
      const guard = new PrivacyAccessGuard();
      guard.bind(() => { throw new Error('Session unavailable'); }, () => 1);
      expect(guard.capture()).assertEqual(-1);
      expect(guard.isValid(1)).assertFalse();
      guard.bind(() => true, () => { throw new Error('Generation unavailable'); });
      expect(guard.capture()).assertEqual(-1);
      expect(guard.getGeneration()).assertEqual(-1);
      expect(guard.isValid(0)).assertFalse();
      guard.bind(() => true, () => -1);
      expect(guard.capture()).assertEqual(-1);
      expect(guard.isValid(-1)).assertFalse();
    });

    it('usesLiveProvidersInsteadOfSnapshotState', 0, () => {
      const guard = new PrivacyAccessGuard();
      let generation = 0;
      let unlocked = true;
      guard.bind(() => unlocked, () => generation);
      expect(guard.isValid(0)).assertTrue();
      generation++;
      expect(guard.isValid(0)).assertFalse();
      expect(guard.isValid(1)).assertTrue();
      unlocked = false;
      expect(guard.isValid(1)).assertFalse();
    });
  });
}
