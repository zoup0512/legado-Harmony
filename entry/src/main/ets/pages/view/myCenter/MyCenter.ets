import router from '@ohos.router'
import { dataItem } from '../../../componets/dataList/dataItem'
import { PublicConstants } from '../../../common/constants/PublicConstants'
import { ThemeStorageKey } from '../../../common/constants/Theme'
import { ThemeItem } from '../../../common/model/Theme'
import { common, Want } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import Logger from '../../../common/utils/Logger'
import { showMessage } from '../../../componets/common/promptShow'
import TabPageTitle from '../../../componets/common/TabPageTitle'

@Entry
@Component
export default struct MyCenter {
  @State end_list: dataItem[] = [
    new dataItem("主题", 6, $r("app.media.my_center_book_icon")),
    new dataItem("用户评价", 5, $r("app.media.my_center_review_icon")),
    new dataItem("用户隐私与协议", 3, $r("app.media.my_center_file_icon")),
    new dataItem("免责声明", 4, $r("app.media.my_center_about_icon")),
  ]
  // 主题颜色：顶部（含状态栏）为主题色渐变沉浸式背景，与书架一致
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem
  @StorageLink('topRectHeight') topRectHeight: number = 0
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0
  @StorageProp('leftRectWidth') leftRectWidth: number = 0
  @StorageProp('rightRectWidth') rightRectWidth: number = 0

  private openReview(): void {
    const failureMessage = '无法打开应用市场，请稍后重试或前往应用市场搜索“隐私阅读器”进行评价'
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
      if (!context) {
        Logger.warn('MyCenter: review context is unavailable')
        this.showMarketMessage(failureMessage)
        return
      }
      const request: Want = {
        action: 'ohos.want.action.appdetail',
        uri: 'market://details?id=com.razor.h.reader'
      }
      context.startAbility(request).catch((error: BusinessError): void => {
        Logger.error('MyCenter: failed to open app market for review', Logger.errorSummary(error))
        this.showMarketMessage(failureMessage)
      })
    } catch (_) {
      Logger.warn('MyCenter: failed to open app market for review')
      this.showMarketMessage(failureMessage)
    }
  }

  private showMarketMessage(message: string): void {
    try {
      showMessage(message, 3000)
    } catch (_) {
      Logger.warn('MyCenter: failed to show app market feedback')
    }
  }

  build() {
    Column() {
      TabPageTitle({ title: '我的', horizontalPadding: 0, topInset: this.topRectHeight === 0 ? 30 : 0 })
        .width('100%').constraintSize({ maxWidth: 840 })

      Scroll() {
        Column() {
          ForEach(this.end_list, (item: dataItem) => {
            Row({ space: 10 }) {
              Image(item.icon).size({ width: 20, height: 20 }).interpolation(ImageInterpolation.High)
              Text(item.title).fontSize(14).layoutWeight(1)
              Image($r("app.media.right")).size({ width: 24, height: 24 })
            }
            .width("100%")
            .constraintSize({ minHeight: 45 })
            .justifyContent(FlexAlign.SpaceBetween)
            .padding({
              top: 12,
              bottom: 12,
              left: 20,
              right: 20
            })
            .onClick(() => this.endOnclick(item.value))
          })
        }
        .padding({ top: 5, bottom: 5 })
        .backgroundColor(PublicConstants.THEME_COLOR_WHITE)
        .borderRadius(10)
        .width("100%")
      }
      .layoutWeight(1)
      .width('100%').constraintSize({ maxWidth: 840 })
      // 内容较少时在剩余空间内居中显示；超出时可正常滚动
      .align(Alignment.Center)
      .scrollBar(BarState.Off)
      .padding({ bottom: 10 })
    }
    .width('100%')
    .padding({
      left: 20 + this.leftRectWidth,
      right: 20 + this.rightRectWidth,
      top: this.topRectHeight,
      bottom: this.bottomRectHeight
    })
    .linearGradient({
      direction: GradientDirection.Bottom, // 渐变方向
      colors: [[this.theme.mainColor, 0.0], [this.theme.secondColor, 0.2]]
    })
    .height('100%')
  }

  // 按菜单标识跳转，避免调整顺序后入口错位
  endOnclick(value: number | string) {
    switch (value) {
      case 3:
        router.pushUrl({
          url: 'pages/view/myCenter/aboutUs/PrivacyAgreementPage'
        })
        break;
      case 4:
        router.pushUrl({
          url: 'pages/view/myCenter/aboutUs/DisclaimerPage'
        })
        break;
      case 5:
        this.openReview()
        break;
      case 6:
        router.pushUrl({
          url: '/pages/view/myCenter/MyThemeConfig'.slice(1)
        })
        break;
    }
  }
}
