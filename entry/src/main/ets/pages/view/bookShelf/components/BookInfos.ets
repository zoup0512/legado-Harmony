import { Books } from '../../../../database/entities/Books'
import { router } from '@kit.ArkUI'
import BookInfoDialogs from './dialog/BookInfoDialogs'
import FontConstants from '../../../../common/constants/FontConstants'
import {
  isReadableLocalBook,
  LOCAL_BOOK_MISSING_MESSAGE
} from '../../../../common/utils/LocalBookAccess'
import { showMessage } from '../../../../componets/common/promptShow'
import BookCover from '../../../../componets/common/BookCover'

@Component
  /**
   * 书签
   */
export default struct BookInfos {
  @Prop currentIndex: number
  @Prop book: Books
  batchManage: boolean = false
  onBatchManage: (book: Books) => void = () => {
  }
  @State delCache: boolean = false
  bookInfoDialog: CustomDialogController | null = new CustomDialogController({
    builder: BookInfoDialogs({
      batchManage: this.batchManage,
      onBatchManage: () => {
        this.onBatchManage(this.book)
      },
      bookData: this.book, cancel: () => {
        this.exitDialog()
      }
    }),
    cancel: this.exitDialog,
    autoCancel: true,
    width: '100%',
    alignment: DialogAlignment.Bottom,
    customStyle: true
  })

  build() {
    Flex({
      alignItems: ItemAlign.Center, justifyContent: FlexAlign.SpaceBetween
    }) {
      Row({
        space: 20
      }) {
        Stack() {
          Stack() {
            if (this.book.isTop) {
              Text('置顶')
                .fontColor(Color.White)
                .fontWeight(FontConstants.FONT_WEIGHT_400)
                .fontSize(9)
                .padding(3)
                .borderRadius(5)
                .backgroundColor('rgba(0, 0, 0, 0.45)')
                .zIndex(1)
            }
            BookCover({
              coverUrl: this.book.coverUrl ?? '',
              customCoverUrl: this.book.customCoverUrl ?? '',
              bookName: this.book.bookName ?? '',
              author: this.book.author ?? '',
              coverWidth: 60,
              coverHeight: 80
            })
          }.alignContent(Alignment.BottomStart)
        }.alignContent(Alignment.TopEnd)

        Column({
          space: 12
        }) {
          Text(this.book.bookName).fontWeight(700)
          Column() {
            Text(this.book.intro)
              .fontSize(12)
              .fontColor('rgb(174,174,174)')
              .textOverflow({
                overflow: TextOverflow.Ellipsis
              })
              .maxLines(2)
              .fontWeight(500)
              .width('80%')
            Text(this.book.durChapterTitle)
              .fontSize(12)
              .fontColor('rgb(174,174,174)')
              .textOverflow({
                overflow: TextOverflow.Ellipsis
              })
              .ellipsisMode(EllipsisMode.END)
              .fontWeight(500)
              .maxLines(1)
          }.alignItems(HorizontalAlign.Start)
        }.alignItems(HorizontalAlign.Start)
      }
    }.onClick(() => {
      if (!isReadableLocalBook(this.book.bookUrl)) {
        showMessage(LOCAL_BOOK_MISSING_MESSAGE)
        return
      }
      router.pushUrl({
        url: 'pages/view/Reader/ReaderPage3', params: { bookData: this.book }
      })
    }).gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction((event: GestureEvent) => {
          this.bookInfoDialog?.open()
        })).padding(10).borderRadius(10)
  }

  //退出弹框
  exitDialog() {
    this.bookInfoDialog?.close()
  }
}