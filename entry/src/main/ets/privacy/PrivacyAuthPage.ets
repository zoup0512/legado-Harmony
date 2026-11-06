import { router } from '@kit.ArkUI';
import Header from '../componets/common/Header';
import { ThemeStorageKey } from '../common/constants/Theme';
import { ThemeItem } from '../common/model/Theme';
import privacySessionService, {
  PrivacyAuthMode, PrivacyAuthRequestInfo, PrivacyAuthStage, PrivacyBiometricPurpose
} from './PrivacySessionService';
import { PrivacyMonotonicClock } from './PrivacyMonotonicClock';
import { PrivacyPinPad } from './PrivacyPinPad';

@Entry
@Component
export default struct PrivacyAuthPage {
  @StorageLink(ThemeStorageKey.THEME) theme: ThemeItem = {
    mainColor: '#188bff', secondColor: '#e3f1ff', text: '蓝色'
  };
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0;
  @State info: PrivacyAuthRequestInfo = new PrivacyAuthRequestInfo();
  @State pin: string = '';
  @State confirmation: string = '';
  // Setting a new PIN: false while entering it, true while re-entering it to confirm.
  @State confirming: boolean = false;
  @State errorMessage: string = '';
  @State busy: boolean = false;
  @State ready: boolean = false;
  @State retrySeconds: number = 0;
  private requestId: number = 0;
  private mode: PrivacyAuthMode = PrivacyAuthMode.UNLOCK;
  private generation: number = -1;
  private active: boolean = false;
  private leaving: boolean = false;
  private completeOnExit: boolean = false;
  private finalized: boolean = false;
  private readonly clock: PrivacyMonotonicClock = new PrivacyMonotonicClock();
  private retryUntil: number = 0;
  private retryTimer: number = -1;
  private unsubscribeCancel: (() => void) | undefined;

  aboutToAppear(): void {
    const params = router.getParams() as PrivacyAuthRequestInfo;
    if (params === undefined || typeof params.requestId !== 'number') {
      this.exit(false);
      return;
    }
    this.requestId = params.requestId;
    this.mode = params.mode;
    this.generation = privacySessionService.getGeneration();
    this.active = true;
    if (!this.refreshRequest()) {
      this.exit(false);
      return;
    }
    this.unsubscribeCancel = privacySessionService.onAuthRequestCancelled(this.requestId, (): void => {
      // Runs synchronously on lock/background, before any delayed native callback can win.
      this.clearInputs();
      this.exit(false);
    });
  }

  onPageShow(): void {
    if (!this.leaving && !this.finalized) {
      this.active = true;
      if (!this.refreshRequest()) this.exit(false);
    }
  }

  onPageHide(): void {
    this.finishExit();
  }

  aboutToDisappear(): void {
    this.finishExit();
  }

  onBackPress(): boolean {
    this.exit(false);
    return true;
  }

  private isCurrent(): boolean {
    return this.active && !this.leaving && !this.finalized &&
      this.generation === privacySessionService.getGeneration() &&
      privacySessionService.isAuthRequestCurrent(this.requestId);
  }

  private clearInputs(): void {
    this.pin = '';
    this.confirmation = '';
    this.confirming = false;
  }

  private canType(): boolean {
    return this.isCurrent() && !this.busy && this.retrySeconds === 0;
  }

  private onDigit(digit: string): void {
    if (!this.canType() || !/^[0-9]$/.test(digit)) return;
    this.errorMessage = '';
    if (this.confirming) {
      if (this.confirmation.length >= 6) return;
      this.confirmation += digit;
      if (this.confirmation.length === 6) {
        if (this.confirmation !== this.pin) {
          this.clearInputs();
          this.errorMessage = '两次输入的密码不一致，请重新设置';
          return;
        }
        this.submitPin();
      }
      return;
    }
    if (this.pin.length >= 6) return;
    this.pin += digit;
    if (this.pin.length === 6) {
      if (this.needsConfirmation()) {
        this.confirming = true;
      } else {
        this.submitPin();
      }
    }
  }

  private onDelete(): void {
    if (!this.canType()) return;
    if (this.confirming) {
      this.confirmation = this.confirmation.slice(0, -1);
    } else {
      this.pin = this.pin.slice(0, -1);
    }
  }

  private promptText(): string {
    if (this.needsConfirmation()) {
      if (this.confirming) return '请再次输入以确认';
      return this.info.stage === PrivacyAuthStage.SETUP_PIN ? '请设置六位隐私密码' : '请输入新的六位隐私密码';
    }
    if (this.mode === PrivacyAuthMode.UNLOCK) return '请输入隐私密码';
    return '请输入当前隐私密码';
  }

  private stopRetryTimer(): void {
    if (this.retryTimer !== -1) clearInterval(this.retryTimer);
    this.retryTimer = -1;
  }

  private refreshRequest(): boolean {
    const info = privacySessionService.getAuthRequest(this.requestId, this.mode);
    if (info === undefined) return false;
    this.info = info;
    this.ready = true;
    this.stopRetryTimer();
    this.retryUntil = this.clock.now() + info.retryAfterMs;
    this.updateRetryCountdown();
    if (this.retrySeconds > 0) {
      this.retryTimer = setInterval((): void => this.updateRetryCountdown(), 1000);
    }
    return true;
  }

  private updateRetryCountdown(): void {
    this.retrySeconds = Math.max(0, Math.ceil((this.retryUntil - this.clock.now()) / 1000));
    if (this.retrySeconds === 0) this.stopRetryTimer();
  }

  private finishExit(): void {
    this.clearInputs();
    this.stopRetryTimer();
    this.active = false;
    if (this.finalized) return;
    this.finalized = true;
    this.unsubscribeCancel?.();
    this.unsubscribeCancel = undefined;
    // A result is not released to callers while this page can still hold PIN input.
    if (this.completeOnExit && this.generation === privacySessionService.getGeneration() &&
      privacySessionService.completeAuthRequest(this.requestId)) return;
    privacySessionService.cancelAuthRequest(this.requestId);
  }

  private exit(success: boolean): void {
    if (this.leaving || this.finalized) return;
    this.leaving = true;
    this.completeOnExit = success;
    this.clearInputs();
    this.stopRetryTimer();
    this.busy = false;
    this.active = false;
    if (!success) privacySessionService.cancelAuthRequest(this.requestId);
    try {
      router.back();
    } catch (_) {
      // Navigation failure must never release an approval to the waiting caller.
      this.completeOnExit = false;
      this.finishExit();
    }
  }

  private async submitPin(): Promise<void> {
    if (!this.isCurrent() || this.busy || this.retrySeconds > 0) return;
    this.busy = true;
    this.errorMessage = '';
    let pin = this.pin;
    let confirmation = this.confirmation;
    this.clearInputs();
    try {
      const success = await privacySessionService.submitPin(this.requestId, pin, confirmation);
      if (!this.isCurrent()) return;
      if (!this.refreshRequest()) {
        this.exit(false);
        return;
      }
      if (!success) {
        this.errorMessage = privacySessionService.getLastFailureMessage() || '验证失败，请重试';
      } else if (this.info.approved) {
        this.exit(true);
      }
    } finally {
      pin = '';
      confirmation = '';
      if (this.isCurrent()) this.busy = false;
    }
  }

  private async authenticate(purpose: PrivacyBiometricPurpose): Promise<void> {
    if (!this.isCurrent() || this.busy) return;
    this.clearInputs();
    this.busy = true;
    this.errorMessage = '';
    try {
      const success = await privacySessionService.authenticateBiometric(this.requestId, purpose);
      if (!this.isCurrent()) return;
      if (!this.refreshRequest()) {
        this.exit(false);
        return;
      }
      if (!success) {
        this.errorMessage = privacySessionService.getLastFailureMessage() || '系统认证失败，可返回使用密码';
      } else if (this.info.approved) {
        this.exit(true);
      }
    } finally {
      if (this.isCurrent()) this.busy = false;
    }
  }

  private returnToPin(): void {
    if (this.busy || !this.isCurrent()) return;
    this.clearInputs();
    privacySessionService.returnToPin(this.requestId);
    this.errorMessage = '';
    this.refreshRequest();
  }

  private needsConfirmation(): boolean {
    return this.info.stage === PrivacyAuthStage.SETUP_PIN || this.info.stage === PrivacyAuthStage.REPLACE_PIN;
  }

  private title(): string {
    if (this.info.stage === PrivacyAuthStage.SETUP_PIN) return '设置隐私密码';
    if (this.info.stage === PrivacyAuthStage.REPLACE_PIN) return '设置新隐私密码';
    if (this.mode === PrivacyAuthMode.CHANGE_PIN) return '修改隐私密码';
    if (this.mode === PrivacyAuthMode.ENABLE_BIOMETRIC) return '开启快捷生物认证';
    if (this.mode === PrivacyAuthMode.DISABLE_BIOMETRIC) return '关闭快捷生物认证';
    return '解锁隐私文件夹';
  }

  @Builder
  cancelButton() {
    Text('取消')
      .fontSize(15)
      .fontColor(this.theme.mainColor)
      .padding({ top: 8, bottom: 8 })
      .onClick((): void => this.exit(false))
  }

  build() {
    Column() {
      Header({
        title: this.title(),
        // Keep the page receiver when Header invokes its @BuilderParam.
        customLeftBuilder: () => { this.cancelButton() }
      })
      Scroll() {
        Column({ space: 20 }) {
          Text(this.title()).fontSize(23).fontWeight(FontWeight.Medium)
          if (this.ready) {
            if (this.info.stage === PrivacyAuthStage.LEGACY_PROOF) {
              Text('检测到原有隐私书籍。必须先通过原指纹或人脸系统认证，才能为这些书籍设置六位密码。')
                .fontSize(15).fontColor('#555555')
              Text('系统认证不可用时，原有数据仍被保留，不能通过设置新密码接管。')
                .fontSize(14).fontColor('#777777')
              Button(this.busy ? '系统认证中…' : '验证原指纹 / 人脸')
                .width('100%').backgroundColor(this.theme.mainColor).enabled(!this.busy)
                .onClick((): void => { this.authenticate(PrivacyBiometricPurpose.LEGACY_PROOF); })
            } else if (this.info.stage === PrivacyAuthStage.ENABLE_BIOMETRIC) {
              Text('当前密码已验证。请再完成一次指纹或人脸系统认证，以开启快捷解锁和忘记密码后的重设。')
                .fontSize(15).fontColor('#555555')
              Button(this.busy ? '系统认证中…' : '验证指纹 / 人脸并开启')
                .width('100%').backgroundColor(this.theme.mainColor).enabled(!this.busy)
                .onClick((): void => { this.authenticate(PrivacyBiometricPurpose.ENABLE); })
              Button('返回密码验证').width('100%').enabled(!this.busy)
                .onClick((): void => this.returnToPin())
            } else {
              Text(this.promptText()).fontSize(17).fontColor('#333333').margin({ top: 12 })
              Text(this.retrySeconds > 0 ? `密码尝试过多，请在 ${this.retrySeconds} 秒后重试` :
                (this.busy ? '验证中…' : this.errorMessage))
                .fontSize(14)
                .fontColor(this.busy && this.retrySeconds === 0 ? '#777777' : '#B84A36')
                .height(20)
                .textAlign(TextAlign.Center)
              PrivacyPinPad({
                filled: this.confirming ? this.confirmation.length : this.pin.length,
                inputEnabled: !this.busy && this.retrySeconds === 0,
                accentColor: this.theme.mainColor,
                onDigit: (digit: string): void => this.onDigit(digit),
                onDelete: (): void => this.onDelete()
              })
              if (this.info.stage === PrivacyAuthStage.REPLACE_PIN) {
                Button('返回密码验证').width('100%').enabled(!this.busy)
                  .onClick((): void => this.returnToPin())
              }
            }
          }
          if (this.errorMessage.length > 0 && (this.info.stage === PrivacyAuthStage.LEGACY_PROOF ||
            this.info.stage === PrivacyAuthStage.ENABLE_BIOMETRIC)) {
            Text(this.errorMessage).fontSize(14).fontColor('#B84A36').textAlign(TextAlign.Center)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 28, right: 28, top: 28, bottom: 24 })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%').height('100%')
    .padding({ bottom: this.bottomRectHeight })
    .backgroundColor('#F6F7F9')
  }
}
