import { UIContext } from '@kit.ArkUI';
import userAuth from '@ohos.userIAM.userAuth';
import { describe, expect, it } from '@ohos/hypium';
import { PrivacyCredentialStatus } from '../../../main/ets/privacy/PrivacyCredentialService';
import {
  PrivacyAuthMode, PrivacyAuthRequestInfo, PrivacyAuthStage, PrivacyBiometricPurpose,
  PrivacyCredentialAccess, PrivacySessionService
} from '../../../main/ets/privacy/PrivacySessionService';

class SessionTestGate {
  wait: Promise<void>;
  private release: () => void = (): void => {};

  constructor() {
    this.wait = new Promise<void>((resolve) => { this.release = resolve; });
  }

  open(): void { this.release(); }
}

class SessionTestCredentials implements PrivacyCredentialAccess {
  status: PrivacyCredentialStatus = new PrivacyCredentialStatus();
  failRead: boolean = false;
  failWrite: boolean = false;
  verifyCalls: number = 0;
  setupCalls: number = 0;
  replaceCalls: number = 0;
  biometricWrites: number = 0;
  lastPin: string = '';
  verifyGate: SessionTestGate | undefined;
  statusGate: SessionTestGate | undefined;
  currentCheck: (() => boolean) | undefined;
  retryUntil: number = 0;
  private readonly uptime: () => number;

  constructor(uptime: () => number) {
    this.uptime = uptime;
  }

  async getStatus(): Promise<PrivacyCredentialStatus> {
    if (this.statusGate !== undefined) await this.statusGate.wait;
    if (this.failRead) throw new Error('untrusted credential failure');
    const result = new PrivacyCredentialStatus();
    result.configured = this.status.configured;
    result.biometricEnabled = this.status.biometricEnabled;
    result.retryAfterMs = Math.max(0, this.retryUntil - this.uptime());
    return result;
  }

  async setup(pin: string, confirmation: string, isCurrent: () => boolean): Promise<void> {
    this.currentCheck = isCurrent;
    this.requireCurrent(isCurrent);
    if (pin !== confirmation || this.status.configured) throw new Error('test setup rejected');
    this.setupCalls++;
    this.lastPin = pin;
    this.status.configured = true;
  }

  async verify(pin: string, isCurrent: () => boolean): Promise<boolean> {
    this.verifyCalls++;
    this.currentCheck = isCurrent;
    if (this.verifyGate !== undefined) await this.verifyGate.wait;
    this.requireCurrent(isCurrent);
    this.lastPin = pin;
    if (pin !== '012345') {
      this.retryUntil = this.uptime() + 30000;
      return false;
    }
    this.retryUntil = 0;
    return true;
  }

  async replacePin(pin: string, confirmation: string, isCurrent: () => boolean): Promise<void> {
    this.currentCheck = isCurrent;
    this.requireCurrent(isCurrent);
    if (pin !== confirmation) throw new Error('test confirmation rejected');
    this.replaceCalls++;
    this.lastPin = pin;
  }

  async setBiometricEnabled(enabled: boolean, isCurrent: () => boolean): Promise<void> {
    this.currentCheck = isCurrent;
    this.requireCurrent(isCurrent);
    this.biometricWrites++;
    this.status.biometricEnabled = enabled;
  }

  private requireCurrent(isCurrent: () => boolean): void {
    if (!isCurrent() || this.failWrite) throw new Error('untrusted write rejected');
  }
}

class SessionTestPage {
  opened: SessionTestGate = new SessionTestGate();
  requestId: number = 0;
  mode: PrivacyAuthMode = PrivacyAuthMode.UNLOCK;
  openCalls: number = 0;
  failOpen: boolean = false;

  async open(_context: UIContext | undefined, requestId: number, mode: PrivacyAuthMode): Promise<void> {
    this.requestId = requestId;
    this.mode = mode;
    this.openCalls++;
    this.opened.open();
    if (this.failOpen) throw new Error('untrusted navigation failure');
  }
}

class SessionTestBooks {
  hasBooks: boolean = false;
  fail: boolean = false;
  gate: SessionTestGate | undefined;

  async hasPrivacyBooks(): Promise<boolean> {
    if (this.gate !== undefined) await this.gate.wait;
    if (this.fail) throw new Error('untrusted database failure');
    return this.hasBooks;
  }
}

class SessionWithFakeBiometrics extends PrivacySessionService {
  results: number[] = [userAuth.UserAuthResultCode.SUCCESS];
  nativeCalls: number = 0;
  available: boolean = true;
  nativeGate: SessionTestGate | undefined;
  onNative: (() => void) | undefined;

  // Unlock routing: false keeps the PIN-page path; true takes the biometric-first path.
  enrolledForUnlock: boolean = false;

  protected isTypeAvailable(_type: userAuth.UserAuthType): boolean { return this.available; }

  isBiometricAvailable(): boolean { return this.enrolledForUnlock && this.available; }

  protected async runAuthOnce(_types: userAuth.UserAuthType[]): Promise<number> {
    this.nativeCalls++;
    const callback = this.onNative;
    if (callback !== undefined) callback();
    if (this.nativeGate !== undefined) await this.nativeGate.wait;
    return this.results.length > 0 ? this.results.shift() as number : userAuth.UserAuthResultCode.SUCCESS;
  }
}

class SessionFixture {
  uptimeMs: number = 50000;
  credentials: SessionTestCredentials = new SessionTestCredentials(() => this.uptimeMs);
  page: SessionTestPage = new SessionTestPage();
  books: SessionTestBooks = new SessionTestBooks();
  context: UIContext = {} as UIContext;
  service: SessionWithFakeBiometrics = new SessionWithFakeBiometrics(this.credentials,
    (): Promise<boolean> => this.books.hasPrivacyBooks(),
    (context: UIContext | undefined, requestId: number, mode: PrivacyAuthMode): Promise<void> =>
      this.page.open(context, requestId, mode), () => this.uptimeMs);

  constructor(configured: boolean = true, biometricEnabled: boolean = false) {
    this.credentials.status.configured = configured;
    this.credentials.status.biometricEnabled = biometricEnabled;
  }

  info(): PrivacyAuthRequestInfo {
    const info = this.service.getAuthRequest(this.page.requestId, this.page.mode);
    if (info === undefined) throw new Error('test request missing');
    return info;
  }

  complete(): boolean { return this.service.completeAuthRequest(this.page.requestId); }
  cancel(): void { this.service.cancelAuthRequest(this.page.requestId); }
}

export default function privacySessionTest() {
  describe('PrivacySessionTest', () => {
    it('enrolledBiometricsUnlockDirectlyWithoutPinPage', 0, async () => {
      const f = new SessionFixture(false);
      f.service.enrolledForUnlock = true;
      expect(await f.service.unlock()).assertTrue();
      expect(f.service.nativeCalls).assertEqual(1);
      expect(f.page.openCalls).assertEqual(0);
      expect(f.credentials.setupCalls).assertEqual(0);
      expect(f.service.isUnlocked()).assertTrue();
      expect(f.service.isAuthenticating()).assertFalse();
    });

    it('failedBiometricUnlockStaysLockedAndDoesNotFallBackToPin', 0, async () => {
      const f = new SessionFixture();
      f.service.enrolledForUnlock = true;
      f.service.results = [userAuth.UserAuthResultCode.CANCELED];
      expect(await f.service.unlock()).assertFalse();
      expect(f.page.openCalls).assertEqual(0);
      expect(f.service.isUnlocked()).assertFalse();
      expect(f.service.isAuthenticating()).assertFalse();
    });

    it('lockDuringBiometricUnlockSettlesFalse', 0, async () => {
      const f = new SessionFixture();
      f.service.enrolledForUnlock = true;
      const gate = new SessionTestGate();
      f.service.nativeGate = gate;
      const result = f.service.unlock();
      await Promise.resolve();
      f.service.lock();
      gate.open();
      expect(await result).assertFalse();
      expect(f.service.isUnlocked()).assertFalse();
    });

    it('usesMaskedPageRequestAndPreservesLeadingZeroWithoutAutomaticBiometrics', 0, async () => {
      const f = new SessionFixture();
      const result = f.service.unlock();
      await f.page.opened.wait;
      expect(f.info().stage).assertEqual(PrivacyAuthStage.VERIFY_PIN);
      expect(f.service.nativeCalls).assertEqual(0);
      expect(f.service.isAuthenticating()).assertTrue();
      expect(f.service.completeAuthRequest(f.page.requestId)).assertFalse();
      expect(await f.service.submitPin(f.page.requestId, '012345')).assertTrue();
      expect(f.credentials.lastPin).assertEqual('012345');
      expect(f.service.isUnlocked()).assertFalse();
      expect(f.complete()).assertTrue();
      expect(await result).assertTrue();
      expect(f.service.isUnlocked()).assertTrue();
    });

    it('newFolderRequiresConfirmationAndDoesNotRequireSystemEnrollment', 0, async () => {
      const f = new SessionFixture(false);
      f.service.available = false;
      const result = f.service.unlock();
      await f.page.opened.wait;
      expect(f.info().stage).assertEqual(PrivacyAuthStage.SETUP_PIN);
      expect(await f.service.submitPin(f.page.requestId, '012345', '012346')).assertFalse();
      expect(await f.service.submitPin(f.page.requestId, '12345', '12345')).assertFalse();
      expect(f.credentials.setupCalls).assertEqual(0);
      expect(await f.service.submitPin(f.page.requestId, '012345', '012345')).assertTrue();
      expect(f.credentials.setupCalls).assertEqual(1);
      expect(f.credentials.status.biometricEnabled).assertFalse();
      expect(f.service.nativeCalls).assertEqual(0);
      f.complete();
      expect(await result).assertTrue();
    });

    it('legacyBooksCannotBeTakenOverBeforeFreshOriginalSystemAuthentication', 0, async () => {
      const f = new SessionFixture(false);
      f.books.hasBooks = true;
      const result = f.service.unlock();
      await f.page.opened.wait;
      expect(f.info().stage).assertEqual(PrivacyAuthStage.LEGACY_PROOF);
      expect(await f.service.submitPin(f.page.requestId, '012345', '012345')).assertFalse();
      expect(f.credentials.setupCalls).assertEqual(0);
      expect(await f.service.authenticateBiometric(f.page.requestId, PrivacyBiometricPurpose.LEGACY_PROOF)).assertTrue();
      expect(f.info().stage).assertEqual(PrivacyAuthStage.SETUP_PIN);
      expect(f.service.isUnlocked()).assertFalse();
      expect(await f.service.submitPin(f.page.requestId, '012345', '012345')).assertTrue();
      f.complete();
      expect(await result).assertTrue();
    });

    it('unavailableLegacyAuthenticationPreservesDataAndBlocksSetup', 0, async () => {
      const f = new SessionFixture(false);
      f.books.hasBooks = true;
      f.service.available = false;
      const result = f.service.unlock();
      await f.page.opened.wait;
      expect(await f.service.authenticateBiometric(f.page.requestId, PrivacyBiometricPurpose.LEGACY_PROOF)).assertFalse();
      expect(f.service.getLastFailureMessage().indexOf('不能设置新密码接管') >= 0).assertTrue();
      expect(f.info().stage).assertEqual(PrivacyAuthStage.LEGACY_PROOF);
      expect(f.credentials.setupCalls).assertEqual(0);
      f.cancel();
      expect(await result).assertFalse();
    });

    it('credentialAndLegacyQueryFailuresAreNotInterpretedAsAnEmptyFolder', 0, async () => {
      const badCredential = new SessionFixture(false);
      badCredential.credentials.failRead = true;
      expect(await badCredential.service.unlock()).assertFalse();
      expect(badCredential.page.openCalls).assertEqual(0);
      expect(badCredential.service.getLastFailureMessage().indexOf('untrusted') < 0).assertTrue();
      const badDao = new SessionFixture(false);
      badDao.books.fail = true;
      expect(await badDao.service.unlock()).assertFalse();
      expect(badDao.page.openCalls).assertEqual(0);
      expect(badDao.credentials.setupCalls).assertEqual(0);
    });

    it('navigationFailureSettlesFalseAndReleasesAuthenticationState', 0, async () => {
      const f = new SessionFixture();
      f.page.failOpen = true;
      expect(await f.service.unlock()).assertFalse();
      expect(f.service.isAuthenticating()).assertFalse();
      expect(f.service.isUnlocked()).assertFalse();
    });

    it('lockSettlesPendingStatusImmediatelyAndLateReadCannotOpenAPage', 0, async () => {
      const f = new SessionFixture();
      const gate = new SessionTestGate();
      f.credentials.statusGate = gate;
      const generation = f.service.getGeneration();
      const result = f.service.unlock();
      f.service.lock();
      expect(await result).assertFalse();
      expect(f.service.getGeneration()).assertEqual(generation + 1);
      f.service.lock();
      expect(f.service.getGeneration()).assertEqual(generation + 2);
      gate.open();
      await Promise.resolve();
      await Promise.resolve();
      expect(f.page.openCalls).assertEqual(0);
    });

    it('lockSettlesPendingLegacyQueryWithoutWaitingForDatabase', 0, async () => {
      const f = new SessionFixture(false);
      const gate = new SessionTestGate();
      f.books.gate = gate;
      const result = f.service.unlock();
      await Promise.resolve();
      await Promise.resolve();
      f.service.lock();
      expect(await result).assertFalse();
      gate.open();
      await Promise.resolve();
      expect(f.page.openCalls).assertEqual(0);
    });

    it('lockClearsPageSynchronouslyAndInvalidatesDelayedPinCallback', 0, async () => {
      const f = new SessionFixture();
      const gate = new SessionTestGate();
      f.credentials.verifyGate = gate;
      const result = f.service.unlock();
      await f.page.opened.wait;
      let input = '012345';
      f.service.onAuthRequestCancelled(f.page.requestId, (): void => { input = ''; });
      const verification = f.service.submitPin(f.page.requestId, input);
      f.service.lock();
      expect(input).assertEqual('');
      expect(await result).assertFalse();
      expect(f.credentials.currentCheck?.()).assertFalse();
      gate.open();
      expect(await verification).assertFalse();
      expect(f.complete()).assertFalse();
      expect(f.service.isUnlocked()).assertFalse();
    });

    it('cancellingApprovedPageBeforeExitStillSettlesFalse', 0, async () => {
      const f = new SessionFixture();
      const result = f.service.unlock();
      await f.page.opened.wait;
      expect(await f.service.submitPin(f.page.requestId, '012345')).assertTrue();
      f.cancel();
      expect(await result).assertFalse();
      expect(f.complete()).assertFalse();
      expect(f.service.isUnlocked()).assertFalse();
    });

    it('wrongPinRefreshesCooldownAndNeverApprovesRequest', 0, async () => {
      const f = new SessionFixture();
      const result = f.service.unlock();
      await f.page.opened.wait;
      expect(await f.service.submitPin(f.page.requestId, '999999')).assertFalse();
      expect(f.info().retryAfterMs).assertEqual(30000);
      expect(f.complete()).assertFalse();
      f.cancel();
      expect(await result).assertFalse();
    });

    it('retryDisplayAdvancesByUptimeAndRepeatedReadsOrRefreshDoNotRearm', 0, async () => {
      const f = new SessionFixture(true, true);
      f.credentials.retryUntil = f.uptimeMs + 30000;
      const result = f.service.unlock();
      await f.page.opened.wait;
      expect(f.info().retryAfterMs).assertEqual(30000);
      f.uptimeMs += 10000;
      expect(f.info().retryAfterMs).assertEqual(20000);
      expect(f.info().retryAfterMs).assertEqual(20000);
      f.service.results = [userAuth.UserAuthResultCode.CANCELED];
      expect(await f.service.authenticateBiometric(f.page.requestId, PrivacyBiometricPurpose.UNLOCK)).assertFalse();
      expect(f.info().retryAfterMs).assertEqual(20000);
      f.uptimeMs += 19999;
      expect(f.info().retryAfterMs).assertEqual(1);
      f.uptimeMs++;
      expect(f.info().retryAfterMs).assertEqual(0);
      expect(f.info().retryAfterMs).assertEqual(0);
      f.cancel();
      expect(await result).assertFalse();
    });

    it('wrongPinRefreshUsesElapsedDeadlineRatherThanRepeatedFullDelay', 0, async () => {
      const f = new SessionFixture();
      const result = f.service.unlock();
      await f.page.opened.wait;
      expect(await f.service.submitPin(f.page.requestId, '999999')).assertFalse();
      expect(f.info().retryAfterMs).assertEqual(30000);
      f.uptimeMs += 12000;
      expect(f.info().retryAfterMs).assertEqual(18000);
      expect(f.info().retryAfterMs).assertEqual(18000);
      f.uptimeMs += 18000;
      expect(f.info().retryAfterMs).assertEqual(0);
      expect(await f.service.submitPin(f.page.requestId, '012345')).assertTrue();
      f.complete();
      expect(await result).assertTrue();
    });

    it('disabledBiometricsCannotUnlockOrResetPassword', 0, async () => {
      const f = new SessionFixture();
      const result = f.service.unlock();
      await f.page.opened.wait;
      expect(await f.service.authenticateBiometric(f.page.requestId, PrivacyBiometricPurpose.UNLOCK)).assertFalse();
      expect(await f.service.authenticateBiometric(f.page.requestId, PrivacyBiometricPurpose.RESET_PIN)).assertFalse();
      expect(f.service.nativeCalls).assertEqual(0);
      f.cancel();
      expect(await result).assertFalse();
    });

    it('brokenCredentialsCannotUseCachedBiometricAuthorization', 0, async () => {
      const f = new SessionFixture(true, true);
      const result = f.service.unlock();
      await f.page.opened.wait;
      f.credentials.failRead = true;
      expect(await f.service.authenticateBiometric(f.page.requestId, PrivacyBiometricPurpose.UNLOCK)).assertFalse();
      expect(await result).assertFalse();
      expect(f.service.nativeCalls).assertEqual(0);
      expect(f.service.isUnlocked()).assertFalse();
    });

    it('biometricZeroIsNotSuccessAndCombinedWidgetFallbackIsPreserved', 0, async () => {
      const f = new SessionFixture(true, true);
      f.service.results = [0, 0];
      const result = f.service.unlock();
      await f.page.opened.wait;
      expect(await f.service.authenticateBiometric(f.page.requestId, PrivacyBiometricPurpose.UNLOCK)).assertFalse();
      expect(f.service.nativeCalls).assertEqual(2);
      expect(f.service.isUnlocked()).assertFalse();
      expect(await f.service.submitPin(f.page.requestId, '012345')).assertTrue();
      f.complete();
      expect(await result).assertTrue();
    });

    it('combinedWidgetFallbackUsesUptimeAtTheImmediateResultBoundary', 0, async () => {
      const elapsedTimes: number[] = [2499, 2500, 30000];
      for (let index = 0; index < elapsedTimes.length; index++) {
        const f = new SessionFixture(true, true);
        f.service.results = [0, userAuth.UserAuthResultCode.SUCCESS];
        f.service.onNative = (): void => {
          if (f.service.nativeCalls === 1) f.uptimeMs += elapsedTimes[index];
        };
        const result = f.service.unlock();
        await f.page.opened.wait;
        const immediate = elapsedTimes[index] < 2500;
        expect(await f.service.authenticateBiometric(f.page.requestId, PrivacyBiometricPurpose.UNLOCK))
          .assertEqual(immediate);
        expect(f.service.nativeCalls).assertEqual(immediate ? 2 : 1);
        f.cancel();
        expect(await result).assertFalse();
      }
    });

    it('cancelledSystemWidgetDoesNotReopenAndStillAllowsPin', 0, async () => {
      const f = new SessionFixture(true, true);
      f.service.results = [userAuth.UserAuthResultCode.CANCELED];
      const result = f.service.unlock();
      await f.page.opened.wait;
      expect(await f.service.authenticateBiometric(f.page.requestId, PrivacyBiometricPurpose.UNLOCK)).assertFalse();
      expect(f.service.nativeCalls).assertEqual(1);
      expect(await f.service.submitPin(f.page.requestId, '012345')).assertTrue();
      f.complete();
      expect(await result).assertTrue();
    });

    it('lateBiometricSuccessCannotUnlockAfterLock', 0, async () => {
      const f = new SessionFixture(true, true);
      const gate = new SessionTestGate();
      f.service.nativeGate = gate;
      const result = f.service.unlock();
      await f.page.opened.wait;
      const verification = f.service.authenticateBiometric(f.page.requestId, PrivacyBiometricPurpose.UNLOCK);
      f.service.lock();
      expect(await result).assertFalse();
      gate.open();
      expect(await verification).assertFalse();
      expect(f.complete()).assertFalse();
      expect(f.service.isUnlocked()).assertFalse();
    });

    it('changePinRequiresOldPinAndConfirmationNotAnUnlockedFlag', 0, async () => {
      const f = new SessionFixture();
      const result = f.service.changePin(f.context);
      await f.page.opened.wait;
      expect(f.info().mode).assertEqual(PrivacyAuthMode.CHANGE_PIN);
      expect(f.info().stage).assertEqual(PrivacyAuthStage.VERIFY_PIN);
      expect(await f.service.submitPin(f.page.requestId, '012345')).assertTrue();
      expect(f.info().stage).assertEqual(PrivacyAuthStage.REPLACE_PIN);
      expect(f.credentials.replaceCalls).assertEqual(0);
      expect(await f.service.submitPin(f.page.requestId, '654321', '654320')).assertFalse();
      expect(await f.service.submitPin(f.page.requestId, '654321', '654321')).assertTrue();
      f.complete();
      expect(await result).assertTrue();
      expect(f.credentials.verifyCalls).assertEqual(1);
      expect(f.credentials.replaceCalls).assertEqual(1);
      expect(f.service.isUnlocked()).assertFalse();
    });

    it('enablingBiometricsRequiresPinThenFreshSystemSuccess', 0, async () => {
      const f = new SessionFixture();
      const result = f.service.setBiometricEnabled(f.context, true);
      await f.page.opened.wait;
      expect(await f.service.authenticateBiometric(f.page.requestId, PrivacyBiometricPurpose.ENABLE)).assertFalse();
      expect(f.service.nativeCalls).assertEqual(0);
      expect(await f.service.submitPin(f.page.requestId, '012345')).assertTrue();
      expect(f.info().stage).assertEqual(PrivacyAuthStage.ENABLE_BIOMETRIC);
      expect(f.credentials.biometricWrites).assertEqual(0);
      expect(await f.service.authenticateBiometric(f.page.requestId, PrivacyBiometricPurpose.ENABLE)).assertTrue();
      expect(f.credentials.biometricWrites).assertEqual(1);
      f.complete();
      expect(await result).assertTrue();
    });

    it('disablingBiometricsAlsoRequiresPinAndNoNativeShortcut', 0, async () => {
      const f = new SessionFixture(true, true);
      const result = f.service.setBiometricEnabled(f.context, false);
      await f.page.opened.wait;
      expect(await f.service.authenticateBiometric(f.page.requestId, PrivacyBiometricPurpose.RESET_PIN)).assertFalse();
      expect(await f.service.submitPin(f.page.requestId, '012345')).assertTrue();
      expect(f.credentials.status.biometricEnabled).assertFalse();
      expect(f.service.nativeCalls).assertEqual(0);
      f.complete();
      expect(await result).assertTrue();
    });

    it('forgottenPinUsesFreshPreEnabledSystemAuthenticationBeforeReplacement', 0, async () => {
      const f = new SessionFixture(true, true);
      const result = f.service.unlock();
      await f.page.opened.wait;
      expect(await f.service.authenticateBiometric(f.page.requestId, PrivacyBiometricPurpose.RESET_PIN)).assertTrue();
      expect(f.info().stage).assertEqual(PrivacyAuthStage.REPLACE_PIN);
      expect(f.service.isUnlocked()).assertFalse();
      expect(f.credentials.replaceCalls).assertEqual(0);
      expect(await f.service.submitPin(f.page.requestId, '654321', '654321')).assertTrue();
      f.complete();
      expect(await result).assertTrue();
      expect(f.service.nativeCalls).assertEqual(1);
      expect(f.credentials.verifyCalls).assertEqual(0);
      expect(f.credentials.replaceCalls).assertEqual(1);
    });

    it('failedWriteCannotApproveOrLeakRawError', 0, async () => {
      const f = new SessionFixture(false);
      f.credentials.failWrite = true;
      const result = f.service.unlock();
      await f.page.opened.wait;
      expect(await f.service.submitPin(f.page.requestId, '012345', '012345')).assertFalse();
      expect(f.complete()).assertFalse();
      expect(f.service.getLastFailureMessage().indexOf('untrusted') < 0).assertTrue();
      f.cancel();
      expect(await result).assertFalse();
    });

    it('parallelRequestsAreRejectedAndListenersCanUnsubscribe', 0, async () => {
      const f = new SessionFixture();
      let notifications = 0;
      const unsubscribe = f.service.onStateChanged((_locked: boolean): void => { notifications++; });
      const result = f.service.unlock();
      await f.page.opened.wait;
      expect(await f.service.unlock()).assertFalse();
      expect(await f.service.changePin(f.context)).assertFalse();
      expect(f.page.openCalls).assertEqual(1);
      f.service.lock();
      expect(await result).assertFalse();
      expect(notifications).assertEqual(1);
      unsubscribe();
      f.service.lock();
      expect(notifications).assertEqual(1);
    });

    it('lockFromStateObserverCannotReturnAnExpiredSuccess', 0, async () => {
      const f = new SessionFixture();
      f.service.onStateChanged((locked: boolean): void => { if (!locked) f.service.lock(); });
      const result = f.service.unlock();
      await f.page.opened.wait;
      await f.service.submitPin(f.page.requestId, '012345');
      f.complete();
      expect(await result).assertFalse();
      expect(f.service.isUnlocked()).assertFalse();
    });
  });
}
