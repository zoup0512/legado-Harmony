import { PreferencesUtil } from '@pura/harmony-utils';
import { ThemeStorageKey } from '../common/constants/Theme';
import { ThemeItem } from '../common/model/Theme';
import privacyFolderService from './PrivacyFolderService';

const ONBOARDING_SHOWN_KEY: string = 'PrivacyOnboardingShown';
const SPOT_SIZE: number = 52;
const CARD_GAP: number = 20;

export class PrivacyOnboardingStore {
  // 只引导一次；已经用过隐私文件夹的老用户不再打扰
  static shouldShow(): boolean {
    try {
      return !(PreferencesUtil.getSync(ONBOARDING_SHOWN_KEY, false) as boolean) && !privacyFolderService.hasSeededGuide();
    } catch (_) {
      return false;
    }
  }

  static markShown(): void {
    PreferencesUtil.putSync(ONBOARDING_SHOWN_KEY, true);
  }
}

/**
 * 首次进入书架时的隐私文件夹引导：遮罩 + 高亮底部“隐私”入口 + 说明卡片。
 * centerX / centerY 为“隐私”入口图标中心在窗口中的坐标（vp）。
 */
@Component
export default struct PrivacyOnboarding {
  @Prop centerX: number = 0;
  @Prop centerY: number = 0;
  onTry: () => void = (): void => {};
  onLater: () => void = (): void => {};
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {
    mainColor: '#24b277', secondColor: '#e4f5ee', text: '主题3'
  };
  @State pulse: number = 0;

  private cardBottomY(): number {
    return this.centerY - SPOT_SIZE / 2 - CARD_GAP;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 遮罩：吞掉点击，避免误触下层书架
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.62)')
        .onClick((): void => {})

      if (this.cardBottomY() > 0) {
        // 卡片底部指向“隐私”入口的小三角
        Row()
          .width(16)
          .height(16)
          .backgroundColor(Color.White)
          .rotate({ angle: 45 })
          .position({ x: this.centerX - 8, y: this.cardBottomY() - 10 })

        Column() {
          this.Card()
        }
        .width('100%')
        .padding({ left: 24, right: 24 })
        .position({ x: 0, y: 0 })
        .height(this.cardBottomY())
        .justifyContent(FlexAlign.End)
      }

      // 高亮的“隐私”入口
      Stack() {
        Circle()
          .width(SPOT_SIZE)
          .height(SPOT_SIZE)
          .fill(Color.Transparent)
          .stroke(Color.White)
          .strokeWidth(2)
          .scale({ x: 1 + this.pulse * 0.5, y: 1 + this.pulse * 0.5 })
          .opacity(0.9 * (1 - this.pulse))
          .onAppear((): void => {
            this.getUIContext().animateTo({ duration: 1400, iterations: -1, curve: Curve.EaseOut }, (): void => {
              this.pulse = 1;
            });
          })
        Row() {
          Image($r('app.media.privacy_lock')).width(24).height(24).fillColor(this.theme.mainColor)
        }
        .width(SPOT_SIZE)
        .height(SPOT_SIZE)
        .borderRadius(SPOT_SIZE / 2)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(Color.White)
      }
      .width(SPOT_SIZE)
      .height(SPOT_SIZE)
      .position({ x: this.centerX - SPOT_SIZE / 2, y: this.centerY - SPOT_SIZE / 2 })
      .accessibilityText('打开隐私文件夹')
      .onClick((): void => this.onTry())
    }
    .width('100%')
    .height('100%')
    .transition(TransitionEffect.OPACITY.animation({ duration: 250 }))
  }

  @Builder
  Card() {
    Column() {
      Row() {
        Image($r('app.media.privacy_lock')).width(26).height(26).fillColor(this.theme.mainColor)
      }
      .width(52)
      .height(52)
      .borderRadius(26)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.theme.secondColor)

      Text('隐私文件夹')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F1F1F')
        .margin({ top: 14 })
      Text('把不想被看到的书，单独锁起来')
        .fontSize(14)
        .fontColor('#888888')
        .margin({ top: 6 })

      Column({ space: 12 }) {
        this.Feature('指纹 / 人脸解锁，未录入时用六位密码')
        this.Feature('不出现在书架和搜索结果中')
        this.Feature('离开应用自动上锁')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ top: 16, bottom: 16, left: 16, right: 16 })
      .margin({ top: 18 })
      .borderRadius(12)
      .backgroundColor('#F6F7F9')

      Row({ space: 12 }) {
        Button('稍后再说', { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(42)
          .fontSize(15)
          .fontColor('#555555')
          .backgroundColor('#F0F1F3')
          .onClick((): void => this.onLater())
        Button('立即体验', { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(42)
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor(this.theme.mainColor)
          .onClick((): void => this.onTry())
      }
      .width('100%')
      .margin({ top: 20 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 24, bottom: 20 })
    .borderRadius(20)
    .backgroundColor(Color.White)
  }

  @Builder
  Feature(text: string) {
    Row({ space: 10 }) {
      Circle().width(6).height(6).fill(this.theme.mainColor)
      Text(text).fontSize(14).fontColor('#333333').layoutWeight(1)
    }
    .width('100%')
  }
}
