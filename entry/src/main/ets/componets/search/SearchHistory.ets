@Component
export struct SearchHistory {
  build() {
    Column() {
      Text('输入书名或作者开始搜索')
        .fontSize(16)
        .fontColor($r('app.string.color_black_45'))
    }
    .width('100%')
    .padding(20)
  }
}