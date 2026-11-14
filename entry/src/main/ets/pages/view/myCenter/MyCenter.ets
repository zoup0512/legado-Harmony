import router from '@ohos.router'
import { dataItem } from '../../../componets/dataList/dataItem'
import { PublicConstants } from '../../../common/constants/PublicConstants'
import { ThemeStorageKey } from '../../../common/constants/Theme'
import { ThemeItem } from '../../../common/model/Theme'
import { ColumnModifier } from '../../../common/utils/ComponetModifier'
import { bundleManager, common, Want } from '@kit.AbilityKit'
import { productViewManager } from '@kit.StoreKit'
import Logger from '../../../common/utils/Logger'
import { MarketUpdateCallbacks, MarketUpdateController, MarketUpdateFailure } from '../../../common/utils/MarketUpdateController'
import { showMessage } from '../../../componets/common/promptShow'

@Entry
@Component
export default struct MyCenter {
  @Prop @Watch('onVisibleChanged') visible: boolean = false
  @State version: string = ''
  @State end_list: dataItem[] = [
    new dataItem("主题", 6, $r("app.media.my_center_book_icon")),
    new dataItem("检查更新", 2, $r("app.media.my_center_cloud_icon")),
    new dataItem("用户隐私与协议", 3, $r("app.media.my_center_file_icon")),
    new dataItem("免责声明", 4, $r("app.media.my_center_about_icon")),
  ]
  Column = new ColumnModifier()
  // 主题颜色：顶部（含状态栏）为主题色渐变沉浸式背景，与书架一致
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem
  private marketUpdate: MarketUpdateController = new MarketUpdateController()

  aboutToAppear(): void {
    this.onVisibleChanged()
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
      this.version = info.versionName ? `V${info.versionName}` : ''
    } catch (_) {
      this.version = ''
      Logger.error('MyCenter: failed to read installed app version')
    }
  }

  onVisibleChanged(): void {
    if (this.visible) {
      this.marketUpdate.activate()
    } else {
      this.marketUpdate.deactivate()
    }
  }

  aboutToDisappear(): void {
    this.marketUpdate.deactivate()
  }

  private openMarket(): void {
    this.marketUpdate.open((callbacks: MarketUpdateCallbacks): void => {
      const request: Want = {
        parameters: {
          bundleName: 'com.razor.h.reader'
        }
      }
      productViewManager.loadProduct(getContext(this) as common.UIAbilityContext, request, {
        onError: (): void => { callbacks.onError() },
        onAppear: (): void => { callbacks.onAppear() },
        onDisappear: (): void => { callbacks.onDisappear() }
      })
    }, (failure: MarketUpdateFailure): void => {
      if (failure === MarketUpdateFailure.TIMEOUT) {
        Logger.warn('MyCenter: app market opening timed out')
        this.showMarketMessage('未收到应用市场响应，请稍后重试或前往应用市场搜索“隐私阅读器”查看更新')
      } else {
        Logger.warn('MyCenter: failed to open app market')
        this.showMarketMessage('无法打开应用市场，请稍后重试或前往应用市场搜索“隐私阅读器”查看更新')
      }
    })
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
      Text("我的")
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .width("100%")
        .height(48)

      Scroll() {
        Column() {
          ForEach(this.end_list, (item: dataItem) => {
            Row({ space: 10 }) {
              Image(item.icon).size({ width: 20, height: 20 }).interpolation(ImageInterpolation.High)
              Text(item.title).fontSize(14).layoutWeight(1)
              if (item.value === 2 && this.version) {
                Text(this.version)
                  .fontSize(12)
                  .opacity(0.45)
              }
              Image($r("app.media.right")).size({ width: 24, height: 24 })
            }
            .width("100%")
            .height(45)
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
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .padding({ bottom: 10 })
    }
    .attributeModifier(this.Column)
    .linearGradient({
      direction: GradientDirection.Bottom, // 渐变方向
      colors: [[this.theme.mainColor, 0.0], [this.theme.secondColor, 0.2]]
    })
    .height('100%')
  }

  // 按菜单标识跳转，避免调整顺序后入口错位
  endOnclick(value: number | string) {
    switch (value) {
      case 2:
        // 仅打开应用市场查看更新，不将跳转结果当作版本检查结果。
        this.openMarket()
        break;
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
      case 6:
        router.pushUrl({
          url: '/pages/view/myCenter/MyThemeConfig'.slice(1)
        })
        break;
    }
  }
}
