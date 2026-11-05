import { router } from '@kit.ArkUI';
import Header from '../componets/common/Header';
import { ThemeStorageKey } from '../common/constants/Theme';
import { ThemeItem } from '../common/model/Theme';
import privacySessionService, {
  PrivacyAuthMode, PrivacyAuthRequestInfo, PrivacyAuthStage, PrivacyBiometricPurpose
} from './PrivacySessionService';
import { PrivacyMonotonicClock } from './PrivacyMonotonicClock';

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

  private pinPlaceholder(): string {
    if (this.needsConfirmation()) return '输入六位新密码';
    if (this.mode === PrivacyAuthMode.CHANGE_PIN) return '输入六位旧密码';
    return '输入六位隐私密码';
  }

  private submitLabel(): string {
    if (this.busy) return '验证中…';
    if (this.info.stage === PrivacyAuthStage.SETUP_PIN) return '设置密码并解锁';
    if (this.info.stage === PrivacyAuthStage.REPLACE_PIN) return '保存新密码';
    if (this.mode === PrivacyAuthMode.UNLOCK) return '解锁';
    if (this.mode === PrivacyAuthMode.DISABLE_BIOMETRIC) return '验证密码并关闭';
    return '验证当前密码';
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
      Header({ title: this.title(), customLeftBuilder: this.cancelButton })
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
              if (this.needsConfirmation()) {
                Text('使用六位数字，两次输入需一致。密码不会通过页面路由传递，快捷生物认证默认关闭。')
                  .fontSize(14).fontColor('#777777')
              } else if (this.mode === PrivacyAuthMode.UNLOCK) {
                Text('请输入六位数字隐私密码').fontSize(15).fontColor('#555555')
              } else {
                Text('即使隐私会话已解锁，此操作仍需重新验证当前密码。')
                  .fontSize(14).fontColor('#777777')
              }
              TextInput({ text: this.pin, placeholder: this.pinPlaceholder() })
                .type(InputType.NUMBER_PASSWORD)
                .showPasswordIcon(false)
                .maxLength(6)
                .inputFilter('[0-9]*')
                .copyOption(CopyOptions.None)
                .height(52)
                .enabled(!this.busy)
                .onChange((value: string): void => { this.pin = value.replace(/[^0-9]/g, '').slice(0, 6); })
              if (this.needsConfirmation()) {
                TextInput({ text: this.confirmation, placeholder: '再次输入六位新密码' })
                  .type(InputType.NUMBER_PASSWORD)
                  .showPasswordIcon(false)
                  .maxLength(6)
                  .inputFilter('[0-9]*')
                  .copyOption(CopyOptions.None)
                  .height(52)
                  .enabled(!this.busy)
                  .onChange((value: string): void => {
                    this.confirmation = value.replace(/[^0-9]/g, '').slice(0, 6);
                  })
              }
              if (this.retrySeconds > 0) {
                Text(`密码尝试过多，请在 ${this.retrySeconds} 秒后重试`)
                  .fontSize(14).fontColor('#B84A36')
              }
              Button(this.submitLabel())
                .width('100%').backgroundColor(this.theme.mainColor)
                .enabled(!this.busy && this.retrySeconds === 0 && this.pin.length === 6 &&
                  (!this.needsConfirmation() || this.confirmation.length === 6))
                .onClick((): void => { this.submitPin(); })
              if (this.info.stage === PrivacyAuthStage.VERIFY_PIN && this.info.biometricEnabled &&
                this.mode === PrivacyAuthMode.UNLOCK) {
                Button(this.busy ? '系统认证中…' : '使用指纹 / 人脸解锁')
                  .width('100%').enabled(!this.busy)
                  .onClick((): void => { this.authenticate(PrivacyBiometricPurpose.UNLOCK); })
              }
              if (this.info.stage === PrivacyAuthStage.VERIFY_PIN && this.info.biometricEnabled &&
                (this.mode === PrivacyAuthMode.UNLOCK || this.mode === PrivacyAuthMode.CHANGE_PIN)) {
                Button('忘记密码？通过系统认证重设')
                  .width('100%').enabled(!this.busy)
                  .onClick((): void => { this.authenticate(PrivacyBiometricPurpose.RESET_PIN); })
                Text('重设必须重新完成系统认证，已解锁会话不能代替本次验证。')
                  .fontSize(12).fontColor('#777777')
              } else if (this.info.stage === PrivacyAuthStage.VERIFY_PIN && !this.info.biometricEnabled) {
                Text('未预先开启快捷生物认证时，忘记密码无法绕过验证；不会删除或接管原有书籍。')
                  .fontSize(12).fontColor('#777777')
              }
              if (this.info.stage === PrivacyAuthStage.REPLACE_PIN) {
                Button('返回密码验证').width('100%').enabled(!this.busy)
                  .onClick((): void => this.returnToPin())
              }
            }
          }
          if (this.errorMessage.length > 0) {
            Text(this.errorMessage).fontSize(14).fontColor('#B84A36').textAlign(TextAlign.Center)
          }
          Text('离开此页、切换应用或取消时会清空输入并终止本次认证。')
            .fontSize(12).fontColor('#999999').textAlign(TextAlign.Center)
        }
        .width('100%')
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
