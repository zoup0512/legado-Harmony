import { promptAction } from '@kit.ArkUI';
import userAuth from '@ohos.userIAM.userAuth';
import { util } from '@kit.ArkTS';

export enum PrivacySessionState {
  LOCKED = 'locked',
  UNLOCKED = 'unlocked'
}

class PrivacySessionService {
  private state: PrivacySessionState = PrivacySessionState.LOCKED;
  private listeners: Array<(locked: boolean) => void> = [];
  private authenticating: boolean = false;
  private authInstance: userAuth.UserAuthInstance | undefined;
  private authRequestId: number = 0;
  private pendingFinish: ((value: number) => void) | undefined;
  private lastFailureMessage: string = '';

  isUnlocked(): boolean { return this.state === PrivacySessionState.UNLOCKED; }
  isAuthenticating(): boolean { return this.authenticating; }
  getLastFailureMessage(): string { return this.lastFailureMessage; }

  private createChallenge(): Uint8Array {
    return util.generateRandomBinaryUUID();
  }

  private cancelAuthInstance(): void {
    const instance = this.authInstance;
    this.authInstance = undefined;
    if (instance === undefined) {
      return;
    }
    try {
      instance.cancel();
    } catch (_) {
      // The device may have ended the request already; cancel is best-effort.
    }
  }

  private isTypeAvailable(authType: userAuth.UserAuthType): boolean {
    try {
      userAuth.getAvailableStatus(authType, userAuth.AuthTrustLevel.ATL2);
      return true;
    } catch (_) {
      return false;
    }
  }

  private failureMessage(resultCode: number): string {
    if (resultCode === 0) {
      return '系统认证未能启动，可能已被临时锁定，请锁屏解锁后重试';
    }
    if (resultCode === userAuth.UserAuthResultCode.CANCELED) {
      return '已取消认证';
    }
    if (resultCode === userAuth.UserAuthResultCode.LOCKED) {
      return '认证已被锁定，请稍后重试';
    }
    if (resultCode === userAuth.UserAuthResultCode.NOT_ENROLLED) {
      return '未录入指纹或人脸，请先在系统设置中录入';
    }
    if (resultCode === userAuth.UserAuthResultCode.TYPE_NOT_SUPPORT) {
      return '设备不支持该认证方式';
    }
    if (resultCode === userAuth.UserAuthResultCode.TRUST_LEVEL_NOT_SUPPORT) {
      return '设备不支持当前认证安全等级';
    }
    if (resultCode === userAuth.UserAuthResultCode.BUSY) {
      return '认证服务繁忙，请稍后重试';
    }
    return '认证失败，请重试';
  }

  // Runs one widget-auth attempt and resolves with the delivered result code.
  // The modern widget callback reports UserAuthResultCode values, where
  // success is 12500000; a stray 0 from an empty callback must NOT unlock.
  private runAuthOnce(authTypes: userAuth.UserAuthType[]): Promise<number> {
    return new Promise<number>((resolve) => {
      let settled: boolean = false;
      const finish = (code: number): void => {
        if (settled) {
          return;
        }
        settled = true;
        if (this.pendingFinish === finish) {
          this.pendingFinish = undefined;
        }
        resolve(code);
      };
      this.pendingFinish = finish;
      const authParam: userAuth.AuthParam = {
        challenge: this.createChallenge(),
        authType: authTypes,
        authTrustLevel: userAuth.AuthTrustLevel.ATL2
      };
      try {
        const instance = userAuth.getUserAuthInstance(authParam, { title: '解锁隐私文件夹' });
        this.authInstance = instance;
        const callback: userAuth.IAuthCallback = {
          onResult: (result: userAuth.UserAuthResult): void => {
            finish(result.result);
          }
        };
        instance.on('result', callback);
        instance.start();
      } catch (_) {
        finish(-1);
        return;
      }
      setTimeout((): void => finish(-1), 30000);
    });
  }

  async unlock(): Promise<boolean> {
    if (this.isUnlocked()) {
      return true;
    }
    if (this.authenticating) {
      return false;
    }
    this.authenticating = true;
    this.lastFailureMessage = '';
    this.authRequestId++;
    const requestId: number = this.authRequestId;
    try {
      const fingerprintReady: boolean = this.isTypeAvailable(userAuth.UserAuthType.FINGERPRINT);
      const faceReady: boolean = this.isTypeAvailable(userAuth.UserAuthType.FACE);
      const authTypes: userAuth.UserAuthType[] = [];
      if (fingerprintReady) {
        authTypes.push(userAuth.UserAuthType.FINGERPRINT);
      }
      if (faceReady) {
        authTypes.push(userAuth.UserAuthType.FACE);
      }
      if (authTypes.length === 0) {
        this.lastFailureMessage = '未检测到已录入的指纹或人脸，请先在系统设置中录入';
        return false;
      }

      const startedAt: number = Date.now();
      let resultCode: number = await this.runAuthOnce(authTypes);
      if (requestId !== this.authRequestId) {
        return false;
      }
      // Some devices reject a combined face+fingerprint widget before showing
      // any UI; retry once with fingerprint only in that instant-failure case.
      if (resultCode !== userAuth.UserAuthResultCode.SUCCESS && authTypes.length > 1 &&
        Date.now() - startedAt < 2500 && fingerprintReady) {
        this.cancelAuthInstance();
        resultCode = await this.runAuthOnce([userAuth.UserAuthType.FINGERPRINT]);
      }
      if (requestId !== this.authRequestId) {
        return false;
      }
      if (resultCode === userAuth.UserAuthResultCode.SUCCESS) {
        this.state = PrivacySessionState.UNLOCKED;
        this.notify();
        return true;
      }
      this.lastFailureMessage = this.failureMessage(resultCode);
      return false;
    } catch (_) {
      this.lastFailureMessage = '认证失败，请重试';
      return false;
    } finally {
      if (requestId === this.authRequestId) {
        this.authenticating = false;
        this.pendingFinish = undefined;
        this.cancelAuthInstance();
      }
    }
  }

  lock(): void {
    this.authRequestId++;
    this.authenticating = false;
    const finish = this.pendingFinish;
    this.pendingFinish = undefined;
    if (finish !== undefined) {
      finish(-1);
    }
    this.cancelAuthInstance();
    this.state = PrivacySessionState.LOCKED;
    this.notify();
  }

  onStateChanged(listener: (locked: boolean) => void): void { this.listeners.push(listener); }
  private notify(): void {
    const locked = !this.isUnlocked();
    this.listeners.forEach(listener => listener(locked));
  }

  async requireUnlock(): Promise<boolean> {
    if (this.isUnlocked()) return true;
    await promptAction.showToast({ message: '请先解锁隐私文件夹' });
    return false;
  }
}

export default new PrivacySessionService();
