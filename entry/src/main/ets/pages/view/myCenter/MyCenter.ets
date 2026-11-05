import router from '@ohos.router'
import { dataItem } from '../../../componets/dataList/dataItem'
import { PublicConstants } from '../../../common/constants/PublicConstants'
import { ColumnModifier } from '../../../common/utils/ComponetModifier'
import { ThemeStorageKey } from '../../../common/constants/Theme'
import { ThemeItem } from '../../../common/model/Theme'

@Entry
@Component
export default struct MyCenter {
  @State end_list: dataItem[] = [
    new dataItem("主题", 6, $r("app.media.my_center_book_icon")),
    new dataItem("关于我们", 2, $r("app.media.my_center_about_icon")),
  ]
  Column = new ColumnModifier()
  // 主题颜色
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem

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
              Text(item.title).fontSize(14).width("75%").layoutWeight(1)
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
      colors: [[this.theme.mainColor, 0.0], [this.theme.secondColor, 0.2]] // 数组末尾元素占比小于1时满足重复着色效果
    })
    .height('100%')
  }

  // 按菜单标识跳转，避免调整顺序后入口错位
  endOnclick(value: number | string) {
    switch (value) {
      case 2:
        router.pushUrl({
          url: 'pages/view/myCenter/aboutUs/aboutUsPage'
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
