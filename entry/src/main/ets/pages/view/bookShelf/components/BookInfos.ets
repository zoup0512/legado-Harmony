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
import { PreferencesUtil } from '@pura/harmony-utils'
import { ReaderProgress, ReaderProgressSummary } from '../../../../common/utils/ReaderProgress'
import { LocalBookImportLogic } from '../../../../common/utils/LocalBookImportService'
import { ThemeStorageKey } from '../../../../common/constants/Theme'
import { ThemeItem } from '../../../../common/model/Theme'

@Component
  /**
   * 书签
   */
export default struct BookInfos {
  @Prop currentIndex: number
  @Prop @Watch('loadProgress') book: Books
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {
    mainColor: '#24b277', secondColor: '#e4f5ee', text: '主题3'
  }
  @State progress: ReaderProgressSummary = new ReaderProgressSummary()
  batchManage: boolean = false
  onBatchManage: (book: Books) => void = () => {
  }
  @State delCache: boolean = false
  bookInfoDialog: CustomDialogController | null = null

  private openBookInfoDialog(): void {
    // 控制器跟随窗口宽度，主体根组件限宽并居中，分屏时无需关闭弹窗。
    this.bookInfoDialog = new CustomDialogController({
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
    this.bookInfoDialog.open()
  }

  aboutToAppear(): void {
    this.loadProgress()
  }

  loadProgress(): void {
    this.progress = ReaderProgress.summarize(this.book, (): Books | undefined => {
      const key = `BookCurrentData_${this.book.bookName}`
      return PreferencesUtil.hasSync(key) ? PreferencesUtil.getSync(key, new Books()) as Books : undefined
    })
  }

  // 作者 · 格式，例如“心梦无痕 · TXT”
  private metaText(): string {
    const parts: string[] = []
    const author = (this.book.author ?? '').trim()
    parts.push(author.length > 0 && author !== '暂无' ? author : '未知作者')
    if (this.book.isLocalBook) {
      const extension = LocalBookImportLogic.extensionOf(this.book.bookUrl ?? '')
      if (extension.length > 1) parts.push(extension.substring(1).toUpperCase())
    }
    return parts.join(' · ')
  }

  private progressText(): string {
    return this.progress.started ? '读到 ' + this.progress.chapterTitle : '未开始阅读'
  }

  build() {
    Row({ space: 14 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        BookCover({
          coverUrl: this.book.coverUrl ?? '',
          customCoverUrl: this.book.customCoverUrl ?? '',
          bookName: this.book.bookName ?? '',
          author: this.book.author ?? '',
          coverWidth: 60,
          coverHeight: 80
        })
        if (this.book.isTop) {
          Text('置顶')
            .fontColor(Color.White)
            .fontWeight(FontConstants.FONT_WEIGHT_400)
            .fontSize(9)
            .padding({ left: 4, right: 4, top: 2, bottom: 2 })
            .borderRadius({ topLeft: 4, bottomRight: 6 })
            .backgroundColor(this.theme.mainColor)
        }
      }
      .borderRadius(4)
      .shadow({ radius: 6, color: 'rgba(0, 0, 0, 0.12)', offsetY: 2 })

      Column() {
        Text(this.book.bookName)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F1F1F')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.metaText())
          .fontSize(12)
          .fontColor('#999999')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 6 })
        if ((this.book.intro ?? '').trim().length > 0) {
          Text(this.book.intro)
            .fontSize(12)
            .fontColor('#AAAAAA')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
        }
        Blank()
        Row({ space: 8 }) {
          Text(this.progressText())
            .fontSize(12)
            .fontColor(this.progress.started ? '#666666' : '#AAAAAA')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.progress.percent > 0) {
            Text(this.progress.percent + '%')
              .fontSize(12)
              .fontColor(this.theme.mainColor)
          }
        }
        .width('100%')
        if (this.progress.percent > 0) {
          Progress({ value: this.progress.percent, total: 100, type: ProgressType.Linear })
            .width('100%')
            .color(this.theme.mainColor)
            .backgroundColor('#EFEFEF')
            .style({ strokeWidth: 3 })
            .margin({ top: 6 })
        }
      }
      .layoutWeight(1)
      .height(80)
      .padding({ top: 2, bottom: 2 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .stateStyles({
      pressed: {
        .backgroundColor('#F4F5F7')
      },
      normal: {
        .backgroundColor(Color.Transparent)
      }
    })
    .onClick(() => {
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
          this.openBookInfoDialog()
        }))
  }

  //退出弹框
  exitDialog() {
    this.bookInfoDialog?.close()
  }
}