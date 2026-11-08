import { dataItem } from 'ets/componets/dataList/dataItem';
import { router } from '@kit.ArkUI';
import { bundleManager, common, Want } from '@kit.AbilityKit';
import { productViewManager } from '@kit.StoreKit';
import Logger from '../../../../common/utils/Logger';
import { MarketUpdateCallbacks, MarketUpdateController, MarketUpdateFailure } from '../../../../common/utils/MarketUpdateController';
import { showMessage } from '../../../../componets/common/promptShow';

@Entry
@Component
struct AboutUsPage {
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @StorageLink('topRectHeight') topRectHeight: number = 0
  @State version: string = ''
  @State first_list: dataItem[] = [
    new dataItem("检查更新", 1),
  ];
  @State end_list: dataItem[] = [
    new dataItem("用户隐私与协议", 1),
    new dataItem("免责声明", 3),
  ]
  private marketUpdate: MarketUpdateController = new MarketUpdateController()

  aboutToAppear(): void {
    this.marketUpdate.activate()
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
      this.version = info.versionName ? `V${info.versionName}` : ''
    } catch (_) {
      this.version = ''
      Logger.error('AboutUsPage: failed to read installed app version')
    }
  }

  onPageShow(): void {
    this.marketUpdate.activate()
  }

  onPageHide(): void {
    this.marketUpdate.deactivate()
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
        Logger.warn('AboutUsPage: app market opening timed out')
        this.showMarketMessage('未收到应用市场响应，请稍后重试或前往应用市场搜索“密读”查看更新')
      } else {
        Logger.warn('AboutUsPage: failed to open app market')
        this.showMarketMessage('无法打开应用市场，请稍后重试或前往应用市场搜索“密读”查看更新')
      }
    })
  }

  private showMarketMessage(message: string): void {
    try {
      showMessage(message, 3000)
    } catch (_) {
      Logger.warn('AboutUsPage: failed to show app market feedback')
    }
  }

  firstUrl_list(value: number | string) {
    switch (value) {
      case 1:
      // 仅打开应用市场查看更新，不将跳转结果当作版本检查结果。
        this.openMarket()
        break
    }
  }

  endUrl_list(value: number | string) {
    switch (value) {
      case 1:
      //用户隐私与协议
        router.pushUrl({
          url: "pages/view/myCenter/aboutUs/PrivacyAgreementPage"
        })
        break
      case 3:
      //免责声明
        router.pushUrl({
          url: "pages/view/myCenter/aboutUs/DisclaimerPage"
        })
        break
    }
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Flex() {
          Column() {
            Image($r("app.media.return_left"))
              .size({ width: 24, height: 24 })
              .interpolation(ImageInterpolation.Medium)
              .onClick(() => {
                router.back()
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('33%')

          Column() {
            Text(`关于我们`)
              .lineHeight(24)
              .font({
                family: "PingFang SC",
                size: 16,
                weight: 500,
                style: FontStyle.Normal,
              })
          }.width('33%')
        }
        .padding({
          top: 12,
          bottom: 12,
        })
        .height(48)
        .width("100%")

        this.middleClick(this.first_list, "app.media.right", this.version, "first")

        this.middleClick(this.end_list, "app.media.right", null, "end")
      }
      .padding({
        left: 20,
        right: 20,
        top: this.topRectHeight,
        bottom: this.bottomRectHeight
      })
      .height("100%")
      .backgroundColor("rgb(245, 245, 245)")
    }
  }

  @Builder
  middleClick(list: Array<dataItem>, image: string, version: string | null, urlList: string) {
    Column() {
      ForEach(list, (item: dataItem) => {
        Row() {
          Text(item.title)
            .lineHeight(22)
            .font({
              // family: "PingFang SC",
              size: 16,
              weight: 400,
              style: FontStyle.Normal,
            })
          Blank(20)
          if (version && item.value === 1) {
            Text(version)
              .lineHeight(20)
              .font({
                // family: "PingFang SC",
                size: 12,
                weight: 400,
                style: FontStyle.Normal,
              })
              .baselineOffset(4)
              .opacity(0.45)
              .margin({
                right: 4
              })
          }
          Image($r(`${image}`)).size({ width: 24, height: 24 })
        }
        .width("100%")
        .height(48)
        .onClick(() => {
          switch (urlList) {
            case 'first':
              this.firstUrl_list(item.value)
              break
            case 'end':
              this.endUrl_list(item.value)
              break
          }
        })
      })
    }

    .padding({
      top: 12,
      bottom: 12,
      left: 20,
      right: 20
    })
    .backgroundColor(Color.White)
    .borderRadius(10)
  }
}
