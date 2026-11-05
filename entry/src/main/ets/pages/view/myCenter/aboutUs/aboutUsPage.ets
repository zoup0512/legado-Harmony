import { dataItem } from 'ets/componets/dataList/dataItem';
import { router } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@ohos.base';
import hilog from '@ohos.hilog';
import { productViewManager } from '@kit.StoreKit';

@Entry
@Component
struct AboutUsPage {
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @StorageLink('topRectHeight') topRectHeight: number = 0
  @State version: string = "V1.0.0.1"
  @State first_list: dataItem[] = [
    new dataItem("检查更新", 1),
    new dataItem("更新日志", 2),
  ];
  @State end_list: dataItem[] = [
    new dataItem("用户隐私与协议", 1),
    new dataItem("免责声明", 3),
  ]
  firstUrl_list(value: number | string) {
    switch (value) {
      case 1:
      // 跳转到应用市场
        try {
          const request: Want = {
            parameters: {
              bundleName: 'com.razor.h.reader'
            }
          };
          productViewManager.loadProduct(getContext(this) as common.UIAbilityContext, request, {
            onError: (error: BusinessError) => {
              hilog.info(0, 'TAG', `loadProduct onError. code is ${error.code}, message is ${error.message}`);
            }
          });
        } catch (err) {
          hilog.error(0, 'TAG', `loadProduct failed. code is ${err.code}, message is ${err.message}`);
        }
        break
      case 2:
      // 更新日志
        router.pushUrl({
          url: "pages/view/myCenter/aboutUs/versionLogPage"
        })
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
