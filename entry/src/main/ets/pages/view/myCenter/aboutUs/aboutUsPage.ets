import { dataItem } from 'ets/componets/dataList/dataItem';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct AboutUsPage {
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @StorageLink('topRectHeight') topRectHeight: number = 0
  @StorageProp('leftRectWidth') leftRectWidth: number = 0
  @StorageProp('rightRectWidth') rightRectWidth: number = 0
  @State end_list: dataItem[] = [
    new dataItem("用户隐私与协议", 1),
    new dataItem("免责声明", 3),
  ]

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

        this.middleClick(this.end_list, "app.media.right")
      }
      .padding({
        left: 20 + this.leftRectWidth,
        right: 20 + this.rightRectWidth,
        top: this.topRectHeight,
        bottom: this.bottomRectHeight
      })
      .width("100%")
      .constraintSize({ maxWidth: 840 })
    }
    .width("100%")
    .height("100%")
    .align(Alignment.Top)
    .backgroundColor("rgb(245, 245, 245)")
  }

  @Builder
  middleClick(list: Array<dataItem>, image: string) {
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
          Image($r(`${image}`)).size({ width: 24, height: 24 })
        }
        .width("100%")
        .height(48)
        .onClick(() => {
          this.endUrl_list(item.value)
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
