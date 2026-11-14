import { BookCoverLogic } from '../../common/utils/BookCoverLogic'

/**
 * 书籍封面：用户自定义封面 > 书内封面 > 文字封面（书名 + 作者）
 */
@Component
export default struct BookCover {
  @Prop @Watch('onSourceChanged') coverUrl: string = ''
  @Prop @Watch('onSourceChanged') customCoverUrl: string = ''
  @Prop bookName: string = ''
  @Prop author: string = ''
  @Prop coverWidth: number = 60
  @Prop coverHeight: number = 80
  @Prop radius: number = 4
  @State loadFailed: boolean = false

  onSourceChanged(): void {
    this.loadFailed = false
  }

  build() {
    Stack() {
      if (!this.loadFailed && this.imageSource().length > 0) {
        Image(this.imageSource())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .draggable(false)
          .onError(() => {
            this.loadFailed = true
          })
      } else {
        this.TextCover()
      }
    }
    .width(this.coverWidth)
    .height(this.coverHeight)
    .borderRadius(this.radius)
    .clip(true)
  }

  private imageSource(): string {
    return BookCoverLogic.imageSourceOf(this.customCoverUrl, this.coverUrl)
  }

  @Builder
  TextCover() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 书脊高光
      Row()
        .width(Math.max(2, this.coverWidth * 0.05))
        .height('100%')
        .backgroundColor('rgba(255,255,255,0.18)')
        .margin({ left: this.coverWidth * 0.07 })
      Column() {
        Text(BookCoverLogic.displayTitleOf(this.bookName))
          .fontSize(Math.max(8, this.coverWidth * 0.15))
          .fontWeight(600)
          .lineHeight(Math.max(10, this.coverWidth * 0.2))
          .fontColor('#FFFFFF')
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
        if (this.author.trim().length > 0 && this.coverWidth >= 50) {
          Text(this.author.trim())
            .fontSize(Math.max(7, this.coverWidth * 0.1))
            .fontColor('rgba(255,255,255,0.75)')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .height('100%')
      .padding({
        left: this.coverWidth * 0.18,
        right: this.coverWidth * 0.08,
        top: this.coverHeight * 0.1,
        bottom: this.coverHeight * 0.08
      })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 160,
      colors: [[BookCoverLogic.paletteOf(this.bookName)[0], 0], [BookCoverLogic.paletteOf(this.bookName)[1], 1]]
    })
  }
}
