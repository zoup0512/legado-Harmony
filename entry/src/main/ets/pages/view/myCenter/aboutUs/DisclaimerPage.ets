import { router } from '@kit.ArkUI';

@Entry
@Component
struct DisclaimerPage {
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @StorageLink('topRectHeight') topRectHeight: number = 0
  @State rowsData: Array<string> = [
    '免责声明（Disclaimer）',
    '密读是一款用于导入、管理和阅读设备本地书籍的开源工具，不提供图书内容、内置书源、网络搜索、网页抓取或在线阅读服务。',
    '请仅导入您合法拥有或已获得授权的书籍文件，并遵守适用法律和著作权规定。书籍内容由用户自行提供，其著作权归相应权利人所有；本应用不参与内容的获取或传播。',
    '不同文件的编码、排版和格式兼容性可能存在差异，实际解析能力以系统阅读组件为准。请保留原始文件；清除应用数据或卸载应用可能导致应用内副本、阅读进度和设置丢失。'
  ]
  build() {
    Column({ space: 16 }) {
      // 标题部分（不滚动，保持固定）
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
          Text(`免责声明`)
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

      // 可滚动的内容区域
      Scroll() {
        Column() {
          ForEach(this.rowsData, (item: string) => {
            Row() {
              Text(item)
                .lineHeight(22)
                .font({
                  family: "PingFang SC",
                  size: 14,
                  style: FontStyle.Normal,
                  weight: 400,
                })
            }.width("100%")
            .margin({ top: 12, bottom: 20 })
          })
        }
        .width("100%")
      }
      .scrollable(ScrollDirection.Vertical) // 设置为垂直滚动
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .height("100%")
      .margin({ bottom: 60 })
    }
    .height("100%") // 设置外部 Column 高度为 100%
    .padding({
      top: this.topRectHeight,
      left: 20,
      right: 20
    })
    .backgroundColor("rgb(245, 245, 245)")
  }
}