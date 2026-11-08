import CommonConstants from '../../common/constants/CommonConstants'
import { router } from '@kit.ArkUI'
import { Books } from '../../database/entities/Books'
import { BookHistory } from '../../database/entities/BookHistory'
import bookHistoryUtils from '../../common/utils/BookHistoryUtils'
import booksUtil from '../../common/utils/booksUtils'
import { ThemeStorageKey } from '../../common/constants/Theme'
import { ThemeItem } from '../../common/model/Theme'
import { bookParser } from '@kit.ReaderKit'
import { showMessage } from '../../componets/common/promptShow'
import {
  LocalBookAccessLogic,
  LOCAL_BOOK_MISSING_MESSAGE,
  requireReadableLocalBookPath
} from '../../common/utils/LocalBookAccess'
import BooksDao from '../../database/dao/BooksDao'
import privacySessionService from '../../privacy/PrivacySessionService'
import { PageAccessRefresh } from '../../privacy/PageAccessRefresh'
import { BookAccessState, BookOwnership } from '../../privacy/BookAccessState'
import privacyForeground from '../../privacy/PrivacyForeground'
import { PrivateBookAutoUnlock, PrivateBookUnlockSnapshot } from '../../privacy/PrivateBookAutoUnlock'

/**
 * 标题图片样式
 */
@Extend(Image)
function titleImageStyle() {
  .fillColor(Color.White).width(CommonConstants.TITLE_IMG_SIZE).height(CommonConstants.TITLE_IMG_SIZE)
}

/**
 * 加入书架dialog
 */
@CustomDialog
struct AddBookShelfDialog {
  controller?: CustomDialogController;

  build() {
    Row() {
      Image($r('app.media.ic_public_confirm')).width(24).height(24).fillColor('#FFFFFF')
      Text('加入书架成功').fontSize(14).fontWeight(400).lineHeight(22).fontColor('#FFFFFF')
      Blank()
    }.height(56).width(CommonConstants.FULL_WIDTH).padding({
      left: 20,
      right: 20,
      top: 16,
      bottom: 16
    }).backgroundColor('#333333')
  }
}

@Entry
@Component
struct BookDetailPage {
  @State isShow: boolean = true;
  @State currentIndex: number = 0;
  // 是否加入书架
  @State isAddBookShelf: boolean = false;
  @State bookData: Books = new Books()
  @State catalogLoading: boolean = true
  @State catalogError: string = ''
  @State privacyCovered: boolean = true
  @State privacyChecking: boolean = true
  @State privacyBusy: boolean = false
  @State resumeAuthPending: boolean = false
  @State privacyError: string = ''
  @State accessFailed: boolean = false
  @State ownership: BookOwnership = BookOwnership.UNKNOWN
  private privacyGeneration: number = -1
  private accessRefresh: PageAccessRefresh = new PageAccessRefresh()
  private pageActive: boolean = false
  private pageReady: boolean = false
  private catalogReady: boolean = false
  private unsubscribePrivacy: (() => void) | undefined
  private autoUnlock?: PrivateBookAutoUnlock
  // 加入书架dialog
  dialogController: CustomDialogController = new CustomDialogController({
    builder: AddBookShelfDialog(),
    cornerRadius: 8,
    offset: { dx: 0, dy: -100 },
    gridCount: 4,
    customStyle: false,
  })
  @State CatalogList: bookParser.CatalogItem[] = []; //章节数据
  // 主题颜色
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem
  @StorageLink('BOOK_IS_BOOK_REFRESHING') isBookRefreshing: number = 0

  onPageShow() {
    this.pageActive = true
    this.logAccessLifecycle('show')
    if (this.pageReady) {
      this.refreshDetailAccess()
    }
    this.autoUnlock?.reconcile()
  }

  onPageHide() {
    this.pageActive = false
    this.invalidateDetailAccess(true)
    this.autoUnlock?.reconcile()
    this.logAccessLifecycle('hide')
  }

  aboutToDisappear() {
    this.pageActive = false
    this.pageReady = false
    this.autoUnlock?.dispose()
    this.autoUnlock = undefined
    this.invalidateDetailAccess(true)
    this.unsubscribePrivacy?.()
    this.unsubscribePrivacy = undefined
    this.logAccessLifecycle('disappear')
  }

  async aboutToAppear() {
    this.pageActive = true
    this.isShow = false
    this.logAccessLifecycle('appear')
    this.autoUnlock = new PrivateBookAutoUnlock(privacyForeground, {
      snapshot: (): PrivateBookUnlockSnapshot => ({
        active: this.pageActive,
        ready: this.pageReady,
        ownership: this.ownership,
        failed: this.accessFailed,
        unlocked: privacySessionService.isUnlocked(),
        authenticating: this.privacyBusy || privacySessionService.isAuthenticating(),
        generation: privacySessionService.getGeneration()
      }),
      unlock: (): Promise<boolean> => this.unlockDetail(),
      restored: (): Promise<void> => this.refreshDetailAccess(),
      returnToShelf: (): void => {
        AppStorage.setOrCreate('RETURN_TO_BOOKSHELF', true)
        router.back({ url: 'pages/Index' })
      },
      pendingChanged: (pending: boolean): void => { this.resumeAuthPending = pending }
    })
    this.unsubscribePrivacy = privacySessionService.onStateChanged((locked: boolean) => {
      this.invalidateDetailAccess(locked)
      this.logAccessLifecycle('session')
      if (this.pageActive && this.pageReady && (!locked || this.ownership !== BookOwnership.PRIVATE)) {
        this.refreshDetailAccess()
      }
      this.autoUnlock?.reconcile()
    })
    const params = router.getParams() as Books | undefined
    if (!params) {
      this.catalogLoading = false
      this.privacyChecking = false
      this.accessFailed = true
      this.privacyError = LOCAL_BOOK_MISSING_MESSAGE
      return
    }
    this.bookData = params
    this.pageReady = true
    await this.refreshDetailAccess()
  }

  private getAccessRequestId(): number {
    return this.accessRefresh.getRequestId()
  }

  private isCurrentAccessRequest(requestId: number, generation: number): boolean {
    return BookAccessState.isCurrent(this.pageActive, this.pageReady, requestId, this.getAccessRequestId(),
      generation, privacySessionService.getGeneration())
  }

  private canShowDetail(): boolean {
    return this.pageActive && this.pageReady && !this.privacyCovered &&
      BookAccessState.canAccess(this.ownership, privacySessionService.isUnlocked(),
        this.privacyGeneration, privacySessionService.getGeneration())
  }

  private logAccessLifecycle(event: string) {
  }

  private invalidateDetailAccess(lockPrivate: boolean) {
    if (lockPrivate && this.ownership === BookOwnership.PRIVATE) {
      this.coverPrivateDetail()
      return
    }
    this.accessRefresh.invalidate()
    this.privacyCovered = true
    this.privacyGeneration = -1
    this.privacyChecking = !this.accessFailed
    if (!this.accessFailed) this.privacyError = ''
    this.isShow = false
    this.dialogController.close()
  }

  private coverPrivateDetail() {
    this.accessRefresh.invalidate()
    this.privacyCovered = true
    this.privacyChecking = true
    this.privacyGeneration = -1
    if (!this.accessFailed) this.privacyError = ''
    this.isShow = false
    this.CatalogList = []
    this.catalogReady = false
    this.dialogController.close()
    this.logAccessLifecycle('private-covered')
    this.autoUnlock?.reconcile()
  }

  private async refreshDetailAccess(): Promise<void> {
    if (!this.pageReady || !this.pageActive) return
    const generation = privacySessionService.getGeneration()
    await this.accessRefresh.refresh(generation, privacySessionService.isUnlocked(),
      (requestId: number): Promise<boolean> => this.refreshDetailAccessRequest(requestId, generation))
  }

  private async refreshDetailAccessRequest(requestId: number, generation: number): Promise<boolean> {
    if (!this.isCurrentAccessRequest(requestId, generation)) return false
    this.privacyCovered = true
    this.privacyChecking = true
    this.accessFailed = false
    this.privacyError = ''
    this.isShow = false
    this.logAccessLifecycle('refresh-start')
    try {
      const required = await BooksDao.isPrivateBook(this.bookData)
      if (!this.isCurrentAccessRequest(requestId, generation)) return false
      this.ownership = BookAccessState.fromPrivate(required)
      this.privacyGeneration = generation
      this.logAccessLifecycle('refresh-verified')
      if (this.ownership === BookOwnership.PRIVATE && !privacySessionService.isUnlocked()) {
        this.coverPrivateDetail()
        return false
      }
      this.privacyCovered = false
      if (!this.catalogReady) {
        await this.initUrlBook(requestId, generation)
      }
      if (!this.isCurrentAccessRequest(requestId, generation) || !this.canShowDetail()) return false
      this.isShow = true
      if (!this.bookData.isJoin) {
        const isJoin = await booksUtil.isExistBooks(this.bookData.bookUrl, this.bookData.bookName)
        if (this.isCurrentAccessRequest(requestId, generation) && this.canShowDetail()) {
          this.bookData.isJoin = isJoin
        }
      }
      return this.isCurrentAccessRequest(requestId, generation) && this.canShowDetail() && this.catalogReady
    } catch (_) {
      if (this.isCurrentAccessRequest(requestId, generation)) {
        this.ownership = BookOwnership.UNKNOWN
        this.privacyGeneration = -1
        this.privacyCovered = true
        this.accessFailed = true
        this.privacyError = '无法确认书籍访问权限，请重新检查或返回后重试'
        this.isShow = false
        this.logAccessLifecycle('refresh-failed')
      }
      return false
    } finally {
      if (this.isCurrentAccessRequest(requestId, generation)) {
        this.privacyChecking = false
        if (this.privacyCovered && !this.privacyError && this.accessFailed) {
          this.privacyError = '请重新检查书籍访问权限'
        }
        this.logAccessLifecycle('refresh-finished')
      }
      this.autoUnlock?.reconcile()
    }
  }

  private async unlockDetail(): Promise<boolean> {
    if (this.privacyBusy || privacySessionService.isAuthenticating()) return false
    this.privacyBusy = true
    try {
      return await privacySessionService.unlock(this.getUIContext())
    } finally {
      this.privacyBusy = false
    }
  }

  async initUrlBook(requestId: number, generation: number) {
    this.catalogLoading = true
    this.catalogError = ''
    this.CatalogList = []
    let path = ''
    try {
      path = requireReadableLocalBookPath(this.bookData.bookUrl)
      const handler: bookParser.BookParserHandler = await bookParser.getDefaultHandler(path)
      if (!this.isCurrentAccessRequest(requestId, generation) || !this.canShowDetail()) return
      const catalog = handler.getCatalogList() || []
      if (catalog.length === 0) {
        throw new Error('书籍内容为空或格式不受支持')
      }
      this.CatalogList = catalog
      this.catalogReady = true
    } catch (_) {
      if (this.isCurrentAccessRequest(requestId, generation) && this.canShowDetail()) {
        this.catalogError = path.length === 0 ? LOCAL_BOOK_MISSING_MESSAGE :
          '本地书籍解析失败，文件可能损坏或格式不受支持，请重新导入'
      }
    } finally {
      if (this.isCurrentAccessRequest(requestId, generation)) this.catalogLoading = false
    }
  }

  async openReader(catalogId?: number) {
    if (!this.canShowDetail()) return
    const requestId = this.getAccessRequestId()
    const generation = privacySessionService.getGeneration()
    try {
      const required = await BooksDao.isPrivateBook(this.bookData)
      if (!this.isCurrentAccessRequest(requestId, generation)) return
      this.ownership = BookAccessState.fromPrivate(required)
      this.privacyGeneration = generation
      this.logAccessLifecycle('reader-verified')
      if (this.ownership === BookOwnership.PRIVATE && !privacySessionService.isUnlocked()) {
        this.coverPrivateDetail()
        return
      }
      if (!this.canShowDetail()) return
    } catch (_) {
      if (this.isCurrentAccessRequest(requestId, generation)) {
        this.ownership = BookOwnership.UNKNOWN
        this.accessFailed = true
        this.privacyError = '无法确认书籍访问权限，请重新检查或返回后重试'
        this.invalidateDetailAccess(false)
        this.logAccessLifecycle('reader-check-failed')
      }
      return
    }
    try {
      requireReadableLocalBookPath(this.bookData.bookUrl)
    } catch (_) {
      this.catalogError = LOCAL_BOOK_MISSING_MESSAGE
      this.CatalogList = []
      showMessage(LOCAL_BOOK_MISSING_MESSAGE)
      return
    }
    if (this.catalogLoading || this.catalogError.length > 0) {
      showMessage(this.catalogError || '正在加载本地书籍，请稍候')
      return
    }
    if (!this.isCurrentAccessRequest(requestId, generation) || !this.canShowDetail()) return
    this.logAccessLifecycle('reader-open')
    router.pushUrl({
      url: 'pages/view/Reader/ReaderPage3',
      params: { bookData: this.bookData, clickBookCatalogId: catalogId }
    })
  }

  // 加入书架函数
  async addBookShelf() {
    if (!this.canShowDetail()) return
    const generation = privacySessionService.getGeneration()
    const added = await booksUtil.addBooks(this.bookData)
    if (!added || !this.canShowDetail() || generation !== privacySessionService.getGeneration()) return
    this.dialogController.open();
    this.isAddBookShelf = true; // 1s后关闭dialog
    setTimeout(() => {
      this.isBookRefreshing++
      this.dialogController.close();
    }, 1000);
  }

  /**
   * Panel
   */
  @Builder
  catalogPanel() {
    Column() {
      Search({ placeholder: '搜索目录' }).height(34).padding({ top: 8, bottom: 8 })
      if (this.catalogLoading) {
        Row({ space: 8 }) {
          LoadingProgress().width(24).height(24)
          Text('正在加载本地书籍…').fontSize(14).fontColor('#666666')
        }.padding(16)
      } else if (this.catalogError.length > 0) {
        Column({ space: 12 }) {
          Text(this.catalogError).fontSize(14).fontColor('#666666').textAlign(TextAlign.Center)
          Button('返回书架').onClick(() => {
            router.back()
          })
        }.width('100%').padding(16)
      }
      Tabs({ index: this.currentIndex, barPosition: BarPosition.Start }) {
        TabContent() {
          Column() {
            List() {
              ForEach(this.CatalogList, (item: bookParser.CatalogItem, index: number) => {
                ListItem() {
                  Button({ type: ButtonType.Normal }) {
                    Row() {
                      Text(`${item.catalogName}`.replace(new RegExp('\\s{1,}', 'g'), ' ').replaceAll('=', ''))
                        .layoutWeight(1)
                    }.width('100%').padding({
                      left: 20,
                      right: 20,
                      top: 12,
                      bottom: 12
                    })
                  }.borderRadius(10).width('100%').backgroundColor(Color.White).onClick(() => {
                    this.openReader(item.catalogId)
                  })
                }
              })
            }.chainAnimation(true).edgeEffect(EdgeEffect.Fade).divider({
              strokeWidth: 0.8,
              color: '#cccccc',
              startMargin: 12,
              endMargin: 12
            })
          }
        }.tabBar(this.catalogTab(0, '目录', this.CatalogList.length))
      }.layoutWeight(1).onChange((index: number) => {
        this.currentIndex = index;
      })

      Row({ space: 20 }) {
        Button(this.bookData.isJoin ? '已加书架' : '加入书架')
          .padding({
            left: 32,
            right: 32,
            top: 8,
            bottom: 8
          })
          .width(150)
          .height(40)
          .borderRadius(200)
          .backgroundColor(this.theme.secondColor)
          .fontColor(this.theme.mainColor)
          .onClick(() => {
            !this.bookData.isJoin ? this.addBookShelf() : ''
          })
        Button('立即阅读')
          .padding({
            left: 32,
            right: 32,
            top: 8,
            bottom: 8
          })
          .width(150)
          .height(40)
          .borderRadius(200)
          .backgroundColor(this.theme.mainColor)
          .fontColor('#FFFFFF')
          .enabled(!this.catalogLoading && this.catalogError.length === 0)
          .onClick(() => {
            this.openReader()
          })
      }.padding({ top: 12, bottom: 12 }).justifyContent(FlexAlign.Center).width(CommonConstants.FULL_WIDTH).height(64)
    }
    .padding({ left: 20, right: 20, bottom: 12 })
    .width(CommonConstants.FULL_WIDTH)
    .height(CommonConstants.FULL_HEIGHT)
    .borderRadius(16)
  }

  /**
   * tab页签
   */
  @Builder
  catalogTab(index: number, name: string, count: number) {
    Column() {
      Row() {
        Text(name)
          .fontSize(16)
          .fontColor(this.currentIndex === index ? '#e0000000' : '#73000000')
          .fontWeight(500)
          .lineHeight(24)
        Text(count.toString())
          .fontSize(12)
          .lineHeight(20)
          .fontColor(this.currentIndex === index ? '#e0000000' : '#73000000')
          .fontWeight(500)
      }

      Divider()
        .width(10)
        .strokeWidth(3)
        .lineCap(LineCapStyle.Round)
        .color(this.theme.mainColor)
        .opacity(this.currentIndex === index ? 1 : 0)
    }.padding({ top: 8, bottom: 8 }).width(59).height(40)
  }

  build() {
    if (this.privacyCovered) {
      Column({ space: 18 }) {
        if (this.resumeAuthPending || (this.ownership === BookOwnership.PRIVATE && !this.accessFailed) ||
          (this.privacyChecking && !this.accessFailed)) {
          Text('正在验证访问权限…').fontSize(20).fontWeight(FontWeight.Medium)
          LoadingProgress().width(36).height(36)
        } else {
          Text(BookAccessState.coverTitle(this.ownership, this.privacyChecking, this.accessFailed))
            .fontSize(20).fontWeight(FontWeight.Medium)
          Text(this.privacyError || '请重新检查书籍访问权限')
            .fontSize(14).fontColor('#666666').textAlign(TextAlign.Center)
          if (this.pageReady) {
            Button('重新检查').onClick(() => this.refreshDetailAccess())
          }
          Button('返回书架').onClick(() => router.back())
        }
      }.width('100%').height('100%').padding(32)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#F6F7F9')
    } else {
    Column() { // todo 状态栏
      Row() {

      }.width(CommonConstants.FULL_WIDTH).height(40)

      // 标题栏
      Row() { // 返回与标题
        Row({ space: 12 }) {
          Image($r("app.media.ic_public_return_left")).titleImageStyle().onClick(() => {
            router.back()
          })
          Text('书籍详情').fontColor(Color.White).fontSize(16)
        }.height(24)
      }.padding({
        left: 20,
        right: 20,
        top: 12,
        bottom: 12
      }).height(36).width(CommonConstants.FULL_WIDTH)

      // 小说标题
      Row({ space: CommonConstants.SPACE_20 }) {
        Image(LocalBookAccessLogic.selectLocalCover(this.bookData.coverUrl, $r('app.media.icon_book_default_cover_ten')))
          .alt($r('app.media.icon_book_default_cover_ten'))
          .width(CommonConstants.NOVEL_IMG_WIDTH)
          .height(CommonConstants.NOVEL_IMG_HEIGHT)
          .borderRadius(5)
        Column({ space: 8 }) {
          Text((this.bookData.bookName ?? '').replace(new RegExp('\\..*', 'g'), ''))
            .width('75%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(Color.White)
            .fontSize(20)
          Blank()
          if (this.bookData.author?.trim()) {
            Text(this.bookData.author)
              .fontSize(CommonConstants.FONT_NOVEL_DETAIL_AUTHOR_SIZE)
              .fontColor('#FFF')
              .opacity(0.45)
          }
        }.height(CommonConstants.NOVEL_IMG_HEIGHT).alignItems(HorizontalAlign.Start)
      }.padding({
        left: 20,
        right: 20,
        top: 12,
        bottom: 12
      }).width(CommonConstants.FULL_WIDTH).height(116)

      // 书籍简介
      Flex() {
        Text(this.bookData.intro?.trim() ? this.bookData.intro : '未提供简介')
          .fontColor('#FFFFFF')
          .fontSize(14)
          .fontWeight(400)
          .lineHeight(22)
      }.padding({
        left: 20,
        right: 20,
        top: 12,
        bottom: 12
      }).width(CommonConstants.FULL_WIDTH).bindSheet($$this.isShow, this.catalogPanel(), {
        detents: [SheetSize.MEDIUM, SheetSize.LARGE, 200],
        backgroundColor: '#FFFFFF',
        showClose: false,
        dragBar: true,
        enableOutsideInteractive: true,
      })

      // 章节目录Panel
      /*Panel(this.isValue) {
        Column() {

        }
      }
      .width(CommonConstants.FULL_WIDTH)
      .type(PanelType.Foldable)
      .halfHeight('50%')
      .backgroundColor('#FFFFFF')*/
    }
    .height(CommonConstants.FULL_HEIGHT)
    .width(CommonConstants.FULL_WIDTH)
    .backgroundColor($r('app.color.book_detail_background'))
    }
  }

  // @StorageLink('BOOK_IS_BOOK_HISTORY_REFRESHING') isBookHistoryRefreshing: number = 0
  //跳转阅读界面更新或者添加阅读历史记录方法
  async jumpReadPage(durChapterTitle: string, durChapterIndex: number) {
    if (!this.canShowDetail()) return
    let bookHistory = new BookHistory()
    bookHistory.id = this.bookData.id
    bookHistory.bookName = this.bookData.bookName
    bookHistory.author = this.bookData.author
    bookHistory.durChapterTime = Date.now()
    bookHistory.bookType = this.bookData.bookType
    bookHistory.bookUrl = this.bookData.bookUrl ?? ''
    bookHistory.coverUrl = this.bookData.coverUrl ?? ''
    bookHistory.originBookId = this.bookData.id
    bookHistory.durChapterTitle = durChapterTitle
    bookHistory.durChapterIndex = durChapterIndex
    bookHistoryUtils.addBooks(bookHistory)
  }
}