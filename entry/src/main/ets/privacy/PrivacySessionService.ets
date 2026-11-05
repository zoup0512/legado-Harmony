import { promptAction, UIContext } from '@kit.ArkUI';
import userAuth from '@ohos.userIAM.userAuth';
import { util } from '@kit.ArkTS';
import BooksDao from '../database/dao/BooksDao';
import privacyCredentialService, { PrivacyCredentialStatus } from './PrivacyCredentialService';
import { bindPrivacySession } from './PrivacyAccessGuard';

export enum PrivacySessionState {
  LOCKED = 'locked',
  UNLOCKED = 'unlocked'
}

export enum PrivacyAuthMode {
  UNLOCK = 'unlock',
  CHANGE_PIN = 'changePin',
  ENABLE_BIOMETRIC = 'enableBiometric',
  DISABLE_BIOMETRIC = 'disableBiometric'
}

export enum PrivacyAuthStage {
  VERIFY_PIN = 'verifyPin',
  LEGACY_PROOF = 'legacyProof',
  SETUP_PIN = 'setupPin',
  REPLACE_PIN = 'replacePin',
  ENABLE_BIOMETRIC = 'enableBiometric'
}

export enum PrivacyBiometricPurpose {
  UNLOCK = 'unlock',
  LEGACY_PROOF = 'legacyProof',
  RESET_PIN = 'resetPin',
  ENABLE = 'enable'
}

// Only non-secret state is exposed to the page. PINs never enter route parameters.
export class PrivacyAuthRequestInfo {
  requestId: number = 0;
  mode: PrivacyAuthMode = PrivacyAuthMode.UNLOCK;
  stage: PrivacyAuthStage = PrivacyAuthStage.VERIFY_PIN;
  biometricEnabled: boolean = false;
  retryAfterMs: number = 0;
  approved: boolean = false;
}

export interface PrivacyCredentialAccess {
  getStatus(): Promise<PrivacyCredentialStatus>;
  setup(pin: string, confirmation: string, isCurrent: () => boolean): Promise<void>;
  verify(pin: string, isCurrent: () => boolean): Promise<boolean>;
  replacePin(pin: string, confirmation: string, isCurrent: () => boolean): Promise<void>;
  setBiometricEnabled(enabled: boolean, isCurrent: () => boolean): Promise<void>;
}

export type PrivacyAuthPageOpener =
  (uiContext: UIContext | undefined, requestId: number, mode: PrivacyAuthMode) => Promise<void>;

class PrivacyAuthRequest {
  requestId: number = 0;
  generation: number = 0;
  mode: PrivacyAuthMode = PrivacyAuthMode.UNLOCK;
  status: PrivacyCredentialStatus = new PrivacyCredentialStatus();
  retryUntil: number = 0;
  ready: boolean = false;
  legacyProofRequired: boolean = false;
  legacyVerified: boolean = false;
  pinVerified: boolean = false;
  recoveryVerified: boolean = false;
  approved: boolean = false;
  operating: boolean = false;
  resolve: (value: boolean) => void = (_value: boolean): void => {};
  cancelListeners: Array<() => void> = [];
}

async function openPrivacyAuthPage(uiContext: UIContext | undefined, requestId: number,
  mode: PrivacyAuthMode): Promise<void> {
  if (uiContext === undefined) {
    throw new Error('请从应用页面打开隐私认证');
  }
  await uiContext.getRouter().pushUrl({
    url: 'privacy/PrivacyAuthPage',
    params: { requestId: requestId, mode: mode }
  });
}

export class PrivacySessionService {
  private state: PrivacySessionState = PrivacySessionState.LOCKED;
  private listeners: Array<(locked: boolean) => void> = [];
  private authenticating: boolean = false;
  private generation: number = 0;
  private nextRequestId: number = 0;
  private request: PrivacyAuthRequest | undefined;
  private authInstance: userAuth.UserAuthInstance | undefined;
  private pendingFinish: ((value: number) => void) | undefined;
  private lastFailureMessage: string = '';

  private credentials: PrivacyCredentialAccess;
  private hasPrivacyBooks: () => Promise<boolean>;
  private openPage: PrivacyAuthPageOpener;

  constructor(credentials: PrivacyCredentialAccess = privacyCredentialService,
    hasPrivacyBooks: () => Promise<boolean> = (): Promise<boolean> => BooksDao.hasPrivacyBooks(),
    openPage: PrivacyAuthPageOpener = openPrivacyAuthPage) {
    this.credentials = credentials;
    this.hasPrivacyBooks = hasPrivacyBooks;
    this.openPage = openPage;
  }

  isUnlocked(): boolean { return this.state === PrivacySessionState.UNLOCKED; }
  isAuthenticating(): boolean { return this.authenticating; }
  getLastFailureMessage(): string { return this.lastFailureMessage; }
  getGeneration(): number { return this.generation; }

  private createChallenge(): Uint8Array {
    return util.generateRandomBinaryUUID();
  }

  protected cancelAuthInstance(): void {
    const instance = this.authInstance;
    this.authInstance = undefined;
    if (instance === undefined) return;
    try {
      instance.cancel();
    } catch (_) {
      // Cancellation is best-effort; request/generation checks are authoritative.
    }
  }

  protected isTypeAvailable(authType: userAuth.UserAuthType): boolean {
    try {
      userAuth.getAvailableStatus(authType, userAuth.AuthTrustLevel.ATL2);
      return true;
    } catch (_) {
      return false;
    }
  }

  private failureMessage(resultCode: number): string {
    if (resultCode === 0) return '系统认证未能启动，可能已被临时锁定，请锁屏解锁后重试';
    if (resultCode === userAuth.UserAuthResultCode.CANCELED) return '已取消系统认证，可返回使用隐私密码';
    if (resultCode === userAuth.UserAuthResultCode.LOCKED) return '系统认证已被锁定，可使用隐私密码或稍后重试';
    if (resultCode === userAuth.UserAuthResultCode.NOT_ENROLLED) return '未录入指纹或人脸，可使用隐私密码';
    if (resultCode === userAuth.UserAuthResultCode.TYPE_NOT_SUPPORT) return '设备不支持该认证方式';
    if (resultCode === userAuth.UserAuthResultCode.TRUST_LEVEL_NOT_SUPPORT) return '设备不支持当前认证安全等级';
    if (resultCode === userAuth.UserAuthResultCode.BUSY) return '系统认证服务繁忙，请稍后重试';
    return '系统认证失败，可使用隐私密码或重试';
  }

  // Widget success is 12500000, never the stray 0 emitted by some devices.
  protected runAuthOnce(authTypes: userAuth.UserAuthType[]): Promise<number> {
    return new Promise<number>((resolve) => {
      let settled: boolean = false;
      let timeoutId: number = -1;
      const finish = (code: number): void => {
        if (settled) return;
        settled = true;
        if (timeoutId !== -1) clearTimeout(timeoutId);
        if (this.pendingFinish === finish) this.pendingFinish = undefined;
        resolve(code);
      };
      this.pendingFinish = finish;
      const authParam: userAuth.AuthParam = {
        challenge: this.createChallenge(),
        authType: authTypes,
        authTrustLevel: userAuth.AuthTrustLevel.ATL2
      };
      timeoutId = setTimeout((): void => finish(-1), 30000);
      try {
        const instance = userAuth.getUserAuthInstance(authParam, { title: '隐私文件夹身份验证' });
        this.authInstance = instance;
        const callback: userAuth.IAuthCallback = {
          onResult: (result: userAuth.UserAuthResult): void => finish(result.result)
        };
        instance.on('result', callback);
        instance.start();
      } catch (_) {
        finish(-1);
      }
    });
  }

  private async runSystemAuthentication(request: PrivacyAuthRequest): Promise<boolean> {
    const isCurrent = (): boolean => this.isCurrent(request);
    if (!isCurrent()) return false;
    const fingerprintReady = this.isTypeAvailable(userAuth.UserAuthType.FINGERPRINT);
    const faceReady = this.isTypeAvailable(userAuth.UserAuthType.FACE);
    const authTypes: userAuth.UserAuthType[] = [];
    if (fingerprintReady) authTypes.push(userAuth.UserAuthType.FINGERPRINT);
    if (faceReady) authTypes.push(userAuth.UserAuthType.FACE);
    if (authTypes.length === 0) {
      this.lastFailureMessage = request.legacyProofRequired ?
        '旧隐私书仍被保留。无法完成原指纹或人脸认证，不能设置新密码接管，请先恢复系统认证' :
        '未检测到已录入的指纹或人脸，请使用隐私密码，或先在系统设置中录入';
      return false;
    }
    try {
      const startedAt = Date.now();
      let resultCode = await this.runAuthOnce(authTypes);
      if (!isCurrent()) return false;
      // Preserve the immediate combined-widget fallback, but never reopen after cancellation.
      if (resultCode !== userAuth.UserAuthResultCode.SUCCESS &&
        resultCode !== userAuth.UserAuthResultCode.CANCELED && authTypes.length > 1 &&
        Date.now() - startedAt < 2500 && fingerprintReady) {
        this.cancelAuthInstance();
        resultCode = await this.runAuthOnce([userAuth.UserAuthType.FINGERPRINT]);
      }
      if (!isCurrent()) return false;
      if (resultCode === userAuth.UserAuthResultCode.SUCCESS) return true;
      this.lastFailureMessage = request.legacyProofRequired ?
        '原系统认证未通过，旧隐私书仍被保留，不能设置新密码接管' : this.failureMessage(resultCode);
      return false;
    } catch (_) {
      if (isCurrent()) this.lastFailureMessage = '系统认证失败，原有隐私数据仍受保护';
      return false;
    } finally {
      if (isCurrent()) {
        this.pendingFinish = undefined;
        this.cancelAuthInstance();
      }
    }
  }

  async unlock(uiContext?: UIContext): Promise<boolean> {
    if (this.isUnlocked()) return true;
    return this.requestAuthentication(PrivacyAuthMode.UNLOCK, uiContext);
  }

  async changePin(uiContext: UIContext): Promise<boolean> {
    return this.requestAuthentication(PrivacyAuthMode.CHANGE_PIN, uiContext);
  }

  async setBiometricEnabled(uiContext: UIContext, enabled: boolean): Promise<boolean> {
    return this.requestAuthentication(enabled ? PrivacyAuthMode.ENABLE_BIOMETRIC :
      PrivacyAuthMode.DISABLE_BIOMETRIC, uiContext);
  }

  private requestAuthentication(mode: PrivacyAuthMode, uiContext: UIContext | undefined): Promise<boolean> {
    if (this.authenticating) return Promise.resolve(false);
    this.authenticating = true;
    this.lastFailureMessage = '';
    const request = new PrivacyAuthRequest();
    request.requestId = ++this.nextRequestId;
    request.generation = this.generation;
    request.mode = mode;
    this.request = request;
    // Return this Promise immediately: lock also settles in-flight status/DAO/navigation awaits.
    return new Promise<boolean>((resolve) => {
      request.resolve = resolve;
      this.prepareRequest(request, uiContext);
    });
  }

  private async prepareRequest(request: PrivacyAuthRequest, uiContext: UIContext | undefined): Promise<void> {
    try {
      const status = await this.credentials.getStatus();
      if (!this.isCurrent(request)) return;
      request.status = status;
      request.retryUntil = Date.now() + status.retryAfterMs;
      if (!status.configured) {
        if (request.mode !== PrivacyAuthMode.UNLOCK) {
          this.lastFailureMessage = '请先设置六位隐私密码';
          this.settleRequest(request, false);
          return;
        }
        // A failed query must never be mistaken for a new/empty privacy folder.
        request.legacyProofRequired = await this.hasPrivacyBooks();
        if (!this.isCurrent(request)) return;
      }
      request.ready = true;
      await this.openPage(uiContext, request.requestId, request.mode);
    } catch (_) {
      if (this.isCurrent(request)) {
        this.lastFailureMessage = '无法读取隐私凭据、检查旧书或打开认证页面；原有数据不会被删除';
        this.settleRequest(request, false);
      }
    }
  }

  private isCurrent(request: PrivacyAuthRequest): boolean {
    return this.request === request && request.generation === this.generation;
  }

  isAuthRequestCurrent(requestId: number): boolean {
    const request = this.request;
    return request !== undefined && request.requestId === requestId && this.isCurrent(request);
  }

  private getStage(request: PrivacyAuthRequest): PrivacyAuthStage {
    if (!request.status.configured) {
      return request.legacyProofRequired && !request.legacyVerified ?
        PrivacyAuthStage.LEGACY_PROOF : PrivacyAuthStage.SETUP_PIN;
    }
    if (request.recoveryVerified || (request.mode === PrivacyAuthMode.CHANGE_PIN && request.pinVerified)) {
      return PrivacyAuthStage.REPLACE_PIN;
    }
    if (request.mode === PrivacyAuthMode.ENABLE_BIOMETRIC && request.pinVerified) {
      return PrivacyAuthStage.ENABLE_BIOMETRIC;
    }
    return PrivacyAuthStage.VERIFY_PIN;
  }

  getAuthRequest(requestId: number, mode: PrivacyAuthMode): PrivacyAuthRequestInfo | undefined {
    const request = this.request;
    if (request === undefined || !request.ready || !this.isCurrent(request) ||
      request.requestId !== requestId || request.mode !== mode) return undefined;
    const info = new PrivacyAuthRequestInfo();
    info.requestId = request.requestId;
    info.mode = request.mode;
    info.stage = this.getStage(request);
    info.biometricEnabled = request.status.biometricEnabled;
    info.retryAfterMs = Math.max(0, request.retryUntil - Date.now());
    info.approved = request.approved;
    return info;
  }

  async submitPin(requestId: number, pin: string, confirmation: string = ''): Promise<boolean> {
    const request = this.request;
    if (request === undefined || !request.ready || request.operating || request.approved ||
      request.requestId !== requestId || !this.isCurrent(request)) return false;
    const isCurrent = (): boolean => this.isCurrent(request);
    const stage = this.getStage(request);
    if (!/^[0-9]{6}$/.test(pin) ||
      ((stage === PrivacyAuthStage.SETUP_PIN || stage === PrivacyAuthStage.REPLACE_PIN) && pin !== confirmation)) {
      this.lastFailureMessage = '请输入六位数字密码，设置新密码时两次输入必须相同';
      return false;
    }
    request.operating = true;
    this.lastFailureMessage = '';
    try {
      if (stage === PrivacyAuthStage.SETUP_PIN) {
        await this.credentials.setup(pin, confirmation, isCurrent);
        if (!isCurrent()) return false;
        request.approved = true;
      } else if (stage === PrivacyAuthStage.REPLACE_PIN) {
        await this.credentials.replacePin(pin, confirmation, isCurrent);
        if (!isCurrent()) return false;
        request.approved = true;
      } else if (stage === PrivacyAuthStage.VERIFY_PIN) {
        const verified = await this.credentials.verify(pin, isCurrent);
        if (!isCurrent()) return false;
        if (!verified) {
          this.lastFailureMessage = '隐私密码错误，请重试';
          const status = await this.credentials.getStatus();
          if (!isCurrent()) return false;
          request.status = status;
          request.retryUntil = Date.now() + status.retryAfterMs;
          return false;
        }
        request.pinVerified = true;
        if (request.mode === PrivacyAuthMode.UNLOCK) request.approved = true;
        if (request.mode === PrivacyAuthMode.DISABLE_BIOMETRIC) {
          await this.credentials.setBiometricEnabled(false, isCurrent);
          if (!isCurrent()) return false;
          request.approved = true;
        }
      } else {
        this.lastFailureMessage = '请先完成当前页面的系统身份验证';
        return false;
      }
      return isCurrent();
    } catch (_) {
      if (isCurrent()) {
        this.lastFailureMessage = '隐私凭据验证或保存失败，请稍后重试；原有数据仍受保护';
        // Refresh cooldown after a policy rejection, without revealing credential errors or secrets.
        try {
          const status = await this.credentials.getStatus();
          if (isCurrent()) {
            request.status = status;
            request.retryUntil = Date.now() + status.retryAfterMs;
          }
        } catch (_) {
          // A broken store must also invalidate cached biometric/recovery authorization.
          if (isCurrent()) {
            this.lastFailureMessage = '隐私凭据无法安全读取，请重新打开应用后重试；原有数据仍受保护';
            this.settleRequest(request, false);
          }
        }
      }
      return false;
    } finally {
      pin = '';
      confirmation = '';
      request.operating = false;
    }
  }

  async authenticateBiometric(requestId: number, purpose: PrivacyBiometricPurpose): Promise<boolean> {
    const request = this.request;
    if (request === undefined || !request.ready || request.operating || request.approved ||
      request.requestId !== requestId || !this.isCurrent(request)) return false;
    const stage = this.getStage(request);
    const legacy = purpose === PrivacyBiometricPurpose.LEGACY_PROOF && stage === PrivacyAuthStage.LEGACY_PROOF;
    const enable = purpose === PrivacyBiometricPurpose.ENABLE && stage === PrivacyAuthStage.ENABLE_BIOMETRIC;
    const unlock = purpose === PrivacyBiometricPurpose.UNLOCK && request.mode === PrivacyAuthMode.UNLOCK &&
      request.status.configured && request.status.biometricEnabled;
    const recovery = purpose === PrivacyBiometricPurpose.RESET_PIN && request.status.configured &&
      request.status.biometricEnabled &&
      (request.mode === PrivacyAuthMode.UNLOCK || request.mode === PrivacyAuthMode.CHANGE_PIN);
    if (!legacy && !enable && !unlock && !recovery) {
      this.lastFailureMessage = '此操作需要隐私密码；未预先开启生物认证时不能重设密码';
      return false;
    }
    const isCurrent = (): boolean => this.isCurrent(request);
    request.operating = true;
    this.lastFailureMessage = '';
    try {
      // Re-read before using cached biometric/recovery flags: a broken store is fail-closed.
      let status: PrivacyCredentialStatus;
      try {
        status = await this.credentials.getStatus();
      } catch (_) {
        if (isCurrent()) {
          this.lastFailureMessage = '隐私凭据无法安全读取，不能使用生物认证接管原有数据';
          this.settleRequest(request, false);
        }
        return false;
      }
      if (!isCurrent()) return false;
      if (status.configured !== request.status.configured ||
        ((unlock || recovery) && !status.biometricEnabled)) {
        this.lastFailureMessage = '隐私认证设置已变化，请重新打开认证页面';
        this.settleRequest(request, false);
        return false;
      }
      request.status = status;
      request.retryUntil = Date.now() + status.retryAfterMs;
      // Even an unlocked session must obtain a fresh system result for recovery/enabling.
      if (!await this.runSystemAuthentication(request) || !isCurrent()) return false;
      if (legacy) request.legacyVerified = true;
      if (recovery) request.recoveryVerified = true;
      if (unlock) request.approved = true;
      if (enable) {
        await this.credentials.setBiometricEnabled(true, isCurrent);
        if (!isCurrent()) return false;
        request.approved = true;
      }
      return isCurrent();
    } catch (_) {
      if (isCurrent()) this.lastFailureMessage = '生物认证设置保存失败，请重新验证后重试';
      return false;
    } finally {
      request.operating = false;
    }
  }

  returnToPin(requestId: number): void {
    const request = this.request;
    if (request === undefined || request.requestId !== requestId || request.operating ||
      request.approved || !this.isCurrent(request)) return;
    request.pinVerified = false;
    request.recoveryVerified = false;
  }

  // Called only after the page has cleared its inputs and has an approved result.
  completeAuthRequest(requestId: number): boolean {
    const request = this.request;
    if (request === undefined || request.requestId !== requestId || request.operating ||
      !request.approved || !this.isCurrent(request)) return false;
    this.settleRequest(request, true);
    return true;
  }

  cancelAuthRequest(requestId: number): void {
    const request = this.request;
    if (request === undefined || request.requestId !== requestId) return;
    this.lastFailureMessage = '已取消隐私认证';
    this.settleRequest(request, false);
  }

  onAuthRequestCancelled(requestId: number, listener: () => void): () => void {
    const request = this.request;
    if (request === undefined || request.requestId !== requestId) return (): void => {};
    request.cancelListeners.push(listener);
    return (): void => {
      request.cancelListeners = request.cancelListeners.filter(item => item !== listener);
    };
  }

  private settleRequest(request: PrivacyAuthRequest, success: boolean): void {
    if (!this.isCurrent(request)) return;
    this.request = undefined;
    this.authenticating = false;
    const finish = this.pendingFinish;
    this.pendingFinish = undefined;
    if (finish !== undefined) finish(-1);
    this.cancelAuthInstance();
    if (success && request.mode === PrivacyAuthMode.UNLOCK) {
      this.state = PrivacySessionState.UNLOCKED;
      this.notify();
    }
    if (!success) {
      request.cancelListeners.slice().forEach(listener => {
        try { listener(); } catch (_) { /* A UI listener cannot prevent cancellation. */ }
      });
    }
    request.cancelListeners = [];
    request.resolve(success && request.generation === this.generation);
  }

  lock(): void {
    const request = this.request;
    // Invalidate tokens before cancelling native UI or invoking any page callback.
    this.generation++;
    this.request = undefined;
    this.authenticating = false;
    this.state = PrivacySessionState.LOCKED;
    const finish = this.pendingFinish;
    this.pendingFinish = undefined;
    if (finish !== undefined) finish(-1);
    this.cancelAuthInstance();
    if (request !== undefined) {
      this.lastFailureMessage = '隐私会话已上锁，请重新验证';
      request.cancelListeners.slice().forEach(listener => {
        try { listener(); } catch (_) { /* Continue settling every cancelled request. */ }
      });
      request.cancelListeners = [];
      request.resolve(false);
    }
    this.notify();
  }

  onStateChanged(listener: (locked: boolean) => void): () => void {
    this.listeners.push(listener);
    return (): void => { this.listeners = this.listeners.filter(item => item !== listener); };
  }

  private notify(): void {
    const locked = !this.isUnlocked();
    this.listeners.slice().forEach(listener => {
      try { listener(locked); } catch (_) { /* Observers must not interrupt locking. */ }
    });
  }

  async requireUnlock(): Promise<boolean> {
    if (this.isUnlocked()) return true;
    await promptAction.showToast({ message: '请先解锁隐私文件夹' });
    return false;
  }
}

const privacySessionService = new PrivacySessionService();
bindPrivacySession((): boolean => privacySessionService.isUnlocked(),
  (): number => privacySessionService.getGeneration());
export default privacySessionService;
