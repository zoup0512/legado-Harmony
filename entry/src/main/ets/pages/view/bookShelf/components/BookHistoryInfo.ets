import confirmDialogExample from '../../../../componets/common/confirmDialog'
import { Books } from '../../../../database/entities/Books'
import { router } from '@kit.ArkUI'
import { showMessage } from '../../../../componets/common/promptShow'
import booksUtil from '../../../../common/utils/booksUtils'
import { BookHistory } from '../../../../database/entities/BookHistory'
import bookHistoryUtils from '../../../../common/utils/BookHistoryUtils'
import clickUtil from '../../../../common/utils/ClickUtils'
import {
  isReadableLocalBook,
  LocalBookAccessLogic,
  LOCAL_BOOK_MISSING_MESSAGE
} from '../../../../common/utils/LocalBookAccess'
import BooksDao from '../../../../database/dao/BooksDao'
import BookHistoryDao from '../../../../database/dao/BookHistoryDao'
import privacySessionService from '../../../../privacy/PrivacySessionService'

@Component
  /**
   * 浏览历史记录
   */
export default struct BookHistoryInfo {
  @State book: Books = new Books()
  @Prop bookHistory: BookHistory
  @State delCache: boolean = false
  @StorageLink('BOOK_IS_BOOK_HISTORY_REFRESHING') isBookHistoryRefreshing: number = 0
  @StorageLink('BOOK_IS_BOOK_REFRESHING') @Watch('onShelfChanged') shelfRefresh: number = 0

  onShelfChanged(): void {
    this.clearHistory()
    if (this.active) this.loadHistory()
  }

  @State historyVisible: boolean = false
  private active: boolean = false
  private requestId: number = 0
  private unsubscribePrivacy: (() => void) | undefined

  aboutToAppear(): void {
    this.active = true
    this.unsubscribePrivacy = privacySessionService.onStateChanged((_locked: boolean): void => {
      this.clearHistory()
      if (this.active) this.loadHistory()
    })
    this.loadHistory()
  }

  aboutToDisappear(): void {
    this.active = false
    this.unsubscribePrivacy?.()
    this.unsubscribePrivacy = undefined
    this.clearHistory()
  }

  private clearHistory(): void {
    this.requestId++
    this.historyVisible = false
    this.book = new Books()
    this.bookInfoDel?.close()
  }

  private async loadHistory(): Promise<void> {
    const request = ++this.requestId
    const generation = privacySessionService.getGeneration()
    this.historyVisible = false
    try {
      if (await BookHistoryDao.isPrivateHistory(this.bookHistory)) return
      const id = this.bookHistory.originBookId ?? this.bookHistory.id
      const info = id === undefined ? [] : await BooksDao.getBookByIds([id])
      const book = info[0] ?? this.mergeBookHistoryToBooks(this.bookHistory)
      if (!info[0]) book.isJoin = false
      if (await BooksDao.isPrivateBook(book) || await BookHistoryDao.isPrivateHistory(this.bookHistory)) return
      if (!this.active || request !== this.requestId || generation !== privacySessionService.getGeneration()) return
      this.book = book
      this.historyVisible = true
    } catch (_) {
      // No fallback after an ownership query failure.
      if (request === this.requestId) this.clearHistory()
    }
  }

  private async canUseHistory(): Promise<boolean> {
    const generation = privacySessionService.getGeneration()
    const request = this.requestId
    try {
      const privateHistory = await BookHistoryDao.isPrivateHistory(this.bookHistory)
      const privateBook = await BooksDao.isPrivateBook(this.book)
      if (!this.active || request !== this.requestId || generation !== privacySessionService.getGeneration() ||
        privateHistory || privateBook) {
        this.clearHistory()
        return false
      }
      return this.historyVisible
    } catch (_) {
      this.clearHistory()
      return false
    }
  }

  mergeBookHistoryToBooks(history: BookHistory): Books {
    // 将 `BookHistory` 和 `Books` 对象转换为 JSON
    return JSON.parse(JSON.stringify(history)) as Books;
  }

  build() {
    if (this.historyVisible) {
    Flex(
      {
        alignItems: ItemAlign.Center,
        justifyContent: FlexAlign.SpaceBetween
      }
    ) {
      Row({
        space: 20
      }) {
        Stack() {
          Image(LocalBookAccessLogic.selectLocalCover(this.book.coverUrl, $r('app.media.icon_book_default_cover_one')))
            .draggable(false)
            .alt($r('app.media.icon_book_default_cover_one'))
            .width(60)
            .height(80)
        }.alignContent(Alignment.BottomStart)

        Column({
          space: 24
        }) {
          Text(this.book.bookName)
            .fontWeight(700)
          Column() {
            Text(this.book.intro)
              .fontSize(12)
              .fontColor('rgb(174,174,174)')
              .textOverflow({
                overflow: TextOverflow.Ellipsis
              })
              .ellipsisMode(EllipsisMode.END)
              .fontWeight(500)
              .maxLines(1)
            Text(`最近阅读章节:${this.book.durChapterTitle}`)
              .fontSize(12)
              .fontColor('rgb(174,174,174)')
              .textOverflow({
                overflow: TextOverflow.Ellipsis
              })
              .ellipsisMode(EllipsisMode.END)
              .fontWeight(500)
              .maxLines(1)
          }
          .width('40%')
          .alignItems(HorizontalAlign.Start)
        }
        .alignItems(HorizontalAlign.Start)
        .onClick(() => {
          clickUtil.preventClick(async () => {
            if (!await this.canUseHistory()) return
            if (!isReadableLocalBook(this.book.bookUrl)) {
              showMessage(LOCAL_BOOK_MISSING_MESSAGE)
              return
            }
            router.pushUrl({
              url: 'pages/view/BookDetailPage',
              params: this.book
            })
          })
        })
      }

      Column({ space: 15 }) {
        Row() {
          Image($r('app.media.delete_svg')).width(17).fillColor('rgba(0, 0, 0, 0.6)')
        }
        .onClick(() => {
          if (this.bookInfoDel != null) {
            this.bookInfoDel.open()
          }
        })
        .padding({ right: 5 })

        Row() {
          Row({ space: 5 }) {
            Image(this.book.isJoin ? $r("app.media.add_check") : $r("app.media.add_shelf"))
              .width(this.book.isJoin ? 15 : 10)
              .height(this.book.isJoin ? 15 : 10)
              .fillColor('rgba(0, 0, 0, 0.9)')
            Text('书架').fontSize(10).fontColor('rgba(0, 0, 0, 0.45)')
          }
          .padding({
            left: 15,
            right: 15,
            bottom: 5,
            top: 5
          })
        }
        .backgroundColor(this.book.isJoin ? 'rgba(174,174,174,0.2)' : '')
        .borderColor('rgb(174,174,174)')
        .borderWidth(this.book.isJoin ? 0 : 1)
        .borderRadius(50)
        .onClick(async () => {
          if (!await this.canUseHistory()) return
          const generation = privacySessionService.getGeneration()
          const request = this.requestId
          const book = this.book
          let success = false
          if (!book.isJoin) {
            const candidate = this.mergeBookHistoryToBooks(this.bookHistory)
            candidate.id = undefined
            candidate.bookGroup = 3
            success = await booksUtil.addBooks(candidate)
          } else {
            const id = this.bookHistory.originBookId ?? book.id
            if (id !== undefined) success = await booksUtil.delBooksById(id)
          }
          if (!success || request !== this.requestId || generation !== privacySessionService.getGeneration() ||
            !await this.canUseHistory()) return
          book.isJoin = !book.isJoin
          this.book = book
          showMessage(book.isJoin ? '加入书架成功' : '移出书架成功')
        })
      }
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.End)
    }
    .gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction((event: GestureEvent) => {
          // this.bookInfoDialog?.open()
        }))
    .padding(10)
    .borderRadius(10)
    }
  }

  // bookInfoDialog: CustomDialogController | null = new CustomDialogController({
  //   builder: BookInfoDialogs({
  //     bookData:this.book,
  //     cancel: () => {
  //       this.exitDialog()
  //     }
  //   }),
  //   cancel: this.exitDialog,
  //   autoCancel: true,
  //   width:'100%',
  //   alignment: DialogAlignment.Bottom,
  //   customStyle:true
  // })
  //退出弹框
  // exitDialog(){
  //   this.bookInfoDialog?.close()
  // }

  //弹窗
  bookInfoDel: CustomDialogController | null = new CustomDialogController({
    builder: confirmDialogExample({
      confirm: () => {
        this.onAccept()
      },
      delCache: this.delCache,
      isShowCache: true
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    gridCount: 4,
    customStyle: false,
    cornerRadius: 25,
  })

  async onAccept() {
    if (!await this.canUseHistory()) return
    if (this.bookHistory.id) {
      let result = await bookHistoryUtils.deleteBookHistory(this.bookHistory.id)
      this.isBookHistoryRefreshing++
      showMessage(result ? '删除成功' : '删除失败')
    }
  }
}