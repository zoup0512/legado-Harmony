import { router } from '@kit.ArkUI'
import { MyThemeConfigComp } from './MyThemeConfigComp'

@Entry
@Component
struct MyThemeConfig {
  @StorageLink('topRectHeight') topRectHeight: number = 0
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0
  @StorageProp('leftRectWidth') leftRectWidth: number = 0
  @StorageProp('rightRectWidth') rightRectWidth: number = 0
  build() {
    Column() {
      // 头部标题栏
      RelativeContainer() {
        Image($r('sys.media.ohos_ic_public_arrow_left'))
          .width(24)
          .aspectRatio(1)
          .alignRules({
            center: {anchor: '__container__', align: VerticalAlign.Center},
            left: {anchor: '__container__', align: HorizontalAlign.Start}
          })
          .onClick(() => {
            router.back()
          })
        Text('主题')
          .fontWeight(FontWeight.Bold)
          .alignRules({
            center: {anchor: '__container__', align: VerticalAlign.Center},
            middle: {anchor: '__container__', align: HorizontalAlign.Center}
          })
      }
      .padding({left: 20, right: 20, top: 12, bottom: 12})
      .width('100%')
      .height(48)
      .constraintSize({ maxWidth: 840 })

      // 仅保留已实现的个性主题配置
      Column() {
        MyThemeConfigComp()
      }
      .padding({left: 20, right: 20, top: 24, bottom: 16})
      .borderRadius({
        topLeft: 12,
        topRight: 12
      })
      .backgroundColor('#fff')
      .width('100%')
      .constraintSize({ maxWidth: 840 })
      .layoutWeight(1)
    }
    .height('100%')
    .width('100%')
    .padding({top: this.topRectHeight, bottom: this.bottomRectHeight,
      left: this.leftRectWidth, right: this.rightRectWidth})
    .backgroundColor('#f5f5f5')

  }
}
