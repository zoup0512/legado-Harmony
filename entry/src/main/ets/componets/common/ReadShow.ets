/**
 * 上次阅读弹窗
 */
import BooksDao from '../../database/dao/BooksDao'
import privacySessionService from '../../privacy/PrivacySessionService'
import bookHistoryDao from '../../database/dao/BookHistoryDao'
import { BookHistory } from '../../database/entities/BookHistory'
import { Books } from '../../database/entities/Books'
import { router } from '@kit.ArkUI'
import clickUtil from '../../common/utils/ClickUtils'
import { ThemeStorageKey } from '../../common/constants/Theme'
import { ThemeItem } from '../../common/model/Theme'
import { showMessage } from './promptShow'
import {
  isReadableLocalBook,
  LocalBookAccessLogic,
  LOCAL_BOOK_MISSING_MESSAGE
} from '../../common/utils/LocalBookAccess'

@Component
export default struct ReadShow {
  @Link showReadShow:boolean
  @State bookHistory:BookHistory[] = []
  @State book:Books = new Books()
  @StorageLink('BOOK_IS_BOOK_REFRESHING') @Watch('onShelfChanged') shelfRefresh: number = 0

  onShelfChanged(): void {
    this.clearHistory()
    if (this.active) this.getBookHistoryList()
  }

  // 主题颜色
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem

  private active: boolean = false
  private requestId: number = 0
  private unsubscribePrivacy: (() => void) | undefined

  aboutToAppear(): void {
    this.active = true
    this.unsubscribePrivacy = privacySessionService.onStateChanged((_locked: boolean): void => {
      this.clearHistory()
      if (this.active) this.getBookHistoryList()
    })
    this.getBookHistoryList()
  }

  aboutToDisappear(): void {
    this.active = false
    this.unsubscribePrivacy?.()
    this.unsubscribePrivacy = undefined
    this.clearHistory()
  }

  private clearHistory(): void {
    this.requestId++
    this.bookHistory = []
    this.book = new Books()
  }

  async getBookHistoryList(): Promise<void> {
    const request = ++this.requestId
    const generation = privacySessionService.getGeneration()
    try {
      const histories = await bookHistoryDao.searchLimit()
      const history = histories[0]
      if (!history || await bookHistoryDao.isPrivateHistory(history)) return
      const id = history.originBookId ?? history.id
      const books = id === undefined ? [] : await BooksDao.getBookByIds([id])
      const book: Books = books[0] ?? (JSON.parse(JSON.stringify(history)) as Books)
      if (!books[0]) book.isJoin = false
      if (await BooksDao.isPrivateBook(book) || await bookHistoryDao.isPrivateHistory(history)) return
      if (!this.active || request !== this.requestId || generation !== privacySessionService.getGeneration()) return
      this.book = book
      this.bookHistory = [history]
    } catch (_) {
      if (request === this.requestId) this.clearHistory()
    }
  }

  private async continueReading(): Promise<void> {
    const history = this.bookHistory[0]
    if (!history) return
    const request = this.requestId
    const generation = privacySessionService.getGeneration()
    try {
      const privateHistory = await bookHistoryDao.isPrivateHistory(history)
      const privateBook = await BooksDao.isPrivateBook(this.book)
      if (privateHistory || privateBook || !this.active || request !== this.requestId ||
        generation !== privacySessionService.getGeneration()) {
        this.clearHistory()
        return
      }
      if (!isReadableLocalBook(this.book.bookUrl)) {
        showMessage(LOCAL_BOOK_MISSING_MESSAGE)
        return
      }
      router.pushUrl({ url: 'pages/view/BookDetailPage', params: this.book })
    } catch (_) {
      this.clearHistory()
    }
  }
  build() {
    if (this.bookHistory[0] && this.book){
      Column(){
        Flex(
          {
            alignItems:ItemAlign.Center,
            alignContent:FlexAlign.SpaceBetween
          }
        ) {
          Image(LocalBookAccessLogic.selectLocalCover(this.bookHistory[0].coverUrl, $r('app.media.icon_book_default_cover_one')))
            .draggable(false)
            .alt($r('app.media.icon_book_default_cover_one')).width(40).height(52)
          Column({
            space:24
          })
          {
            Text(this.bookHistory[0].bookName)
              .fontSize(12)
              .fontColor(Color.White)
            Column(){
              Text(this.bookHistory[0].durChapterTitle).fontSize(12).fontColor(Color.White)
                .textOverflow({
                  overflow:TextOverflow.Ellipsis
                })
                .ellipsisMode(EllipsisMode.END)
                .fontWeight(500)
                .maxLines(1)
            }
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .padding({left:15})
          Column(){
            Text('继续阅读')
              .fontSize(12)
              .fontWeight(600)
              .padding(10)
              .borderRadius(20)
              .fontColor(this.theme.mainColor)
              .backgroundColor(Color.White)
          }
          .padding({left:55,right:30})
          .onClick(()=>{
            clickUtil.preventClick(() => { this.continueReading() })
          })

          Image($r("app.media.outlined")).width(15).height(15)
            .onClick(() => {
              this.showReadShow = !this.showReadShow
            })
        }
        .borderRadius(10)
      }
      .alignItems(HorizontalAlign.Start)
      .borderRadius(10)
      .padding(10)
      .width('95%')
      .backgroundColor('rgb(182,134,102)')
    }
  }
}