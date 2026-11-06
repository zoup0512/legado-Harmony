import { display, promptAction, router } from '@kit.ArkUI';
import LayoutMoreDialog from '../../../componets/Reader/LayoutMoreDialog';
import { MusicPlayer } from 'ets/componets/Reader/MusicPlayer';
import { bookParser, readerCore, ReadPageComponent } from '@kit.ReaderKit';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ClickUtil, PreferencesUtil } from '@pura/harmony-utils';
import { Books } from '../../../database/entities/Books';
import { WindowAbility } from '../../../entryability/WindowAbility';
import BasicDataSource from '../../../common/LazyIDataSource/BasicDataSource';
import BrightnessUtil from '../../../../common/utils/BrightnessUtil';
import { requireReadableLocalBookPath } from '../../../common/utils/LocalBookAccess';
import BooksDao from '../../../database/dao/BooksDao';
import privacySessionService from '../../../privacy/PrivacySessionService';
import { PageAccessRefresh } from '../../../privacy/PageAccessRefresh';
import { ReaderFontManager, ReaderFontOption, SYSTEM_FONT_NAME } from '../../../common/utils/ReaderFontManager';
import { FontPickerPanel } from '../../../componets/Reader/FontPickerPanel';

interface ParamsObj {
  bookData: Books,
  clickBookCatalogId: number,
}

interface themeItem {
  fontColor: string,
  themeColor: string,
  themeBgImg: string,
}

@Entry
@Component
struct ReaderPage3 {
  @StorageLink('windowWidth') windowWidth: number = 0;
  @StorageLink('windowHeight') windowHeight: number = 0;
  @StorageLink('colorMode') @Watch('colorModeChange') colorMode: ConfigurationConstant.ColorMode =
    ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @StorageLink('topRectHeight') topRectHeight: number = 0
  @State ReaderPadding: number = 24 // 边距
  @State isShowSetting: boolean = false
  @State isShowListen: boolean = false
  @State isShowContentSetting: boolean = false
  @State isShowMoreLayout: boolean = false
  @State isShowFontPicker: boolean = false //字体选择面板
  @State fontOptions: ReaderFontOption[] = [] //可选字体列表
  @State isImportingFont: boolean = false //字体导入中
  @State isLuminanceFollowSystem: boolean = false //亮度跟随系统
  @State isScreenState: boolean = false //屏幕是否常亮
  @State ParagraphSpacing: number = -2
  //书籍解析用数据
  @State bookData: Books = new Books(); //书籍数据
  @State CatalogList: BasicDataSource<bookParser.CatalogItem> = new BasicDataSource<bookParser.CatalogItem>(); //章节数据
  readerComponentController: readerCore.ReaderComponentController = new readerCore.ReaderComponentController();
  //资源请求回调是否已注册（仅使用自定义字体时注册，避免干扰图片/CSS 加载）
  private fontResourceListenerRegistered: boolean = false;
  //阅读器设置
  @State isShowCatalogDialog: boolean = false // 目录弹窗
  @State readerSetting: readerCore.ReaderSetting = {
    fontName: '系统字体',
    fontPath: '',
    fontSize: 18,
    fontColor: '#000000',
    fontWeight: 400,
    lineHeight: 1.9,
    nightMode: false,
    themeColor: 'rgba(248, 249, 250, 1)',
    themeBgImg: '',
    flipMode: '0',
    scaledDensity: display.getDefaultDisplaySync().scaledDensity > 0 ?
    display.getDefaultDisplaySync().scaledDensity :
      1,
    viewPortWidth: this.windowWidth,
    viewPortHeight: this.windowHeight
  };
  private screenDensityCallBack: Callback<number> | null = null;
  private BookHandler: bookParser.BookParserHandler | null = null;
  private scrollerForList: ListScroller = new ListScroller();
  @State readerLoading: boolean = true
  @State readerError: string = ''
  @State privacyCovered: boolean = true
  @State privacyChecking: boolean = true
  @State privacyBusy: boolean = false
  @State privacyError: string = ''
  private privacyRequired: boolean = true;
  private privacyGeneration: number = -1;
  private accessRefresh: PageAccessRefresh = new PageAccessRefresh();
  private pageActive: boolean = false;
  private pageReady: boolean = false;
  private readerStarted: boolean = false;
  private unsubscribePrivacy: (() => void) | undefined;
  @State themeList: themeItem[] = [
    { fontColor: '#000000', themeColor: '#FFFFFF', themeBgImg: '' },
    { fontColor: '#000000', themeColor: '#c6b6a4', themeBgImg: '' },
    { fontColor: '#000000', themeColor: '#C5E7CE', themeBgImg: '' },
    { fontColor: '#FFFFFF', themeColor: '#202224', themeBgImg: '' },
  ]

  async aboutToAppear() {
    this.isScreenState = PreferencesUtil.getSync(`isScreenState`, this.isScreenState) as boolean
    const Brightness = BrightnessUtil.getBrightness('reader')
    if (Brightness == -1) {
      this.isLuminanceFollowSystem = true
    } else {
      BrightnessUtil.setBrightness('reader', Brightness)
    }
    this.pageActive = true;
    this.unsubscribePrivacy = privacySessionService.onStateChanged((locked: boolean) => {
      if (locked && this.privacyRequired) {
        this.coverPrivateReader();
      }
    });
    this.registerScreenDensityChange();
    this.registerListener();
    //  进入阅读页面后隐藏系统状态栏
    WindowAbility.getInstance().toggleWindowSystemBar([], this.getUIContext().getHostContext());
    const temp = router.getParams() as ParamsObj
    if (!temp || !temp.bookData) {
      this.readerLoading = false
      this.readerError = '书籍参数无效'
      this.privacyChecking = false
      this.privacyError = '书籍参数无效'
      return
    }
    this.bookData = temp.bookData
    const savedBook = PreferencesUtil.getSync(`BookCurrentData_${this.bookData.bookName}`, null) as Books | null
    const currentBookUrl = this.bookData.serverBookUrl ?? this.bookData.bookUrl
    const savedBookUrl = savedBook?.serverBookUrl ?? savedBook?.bookUrl
    if (savedBook?.localBookDurChapterPos && currentBookUrl && savedBookUrl === currentBookUrl) {
      this.bookData.localBookDurChapterPos = savedBook.localBookDurChapterPos
      this.bookData.durChapterIndex = savedBook.durChapterIndex ?? this.bookData.durChapterIndex
      this.bookData.durChapterTitle = savedBook.durChapterTitle ?? this.bookData.durChapterTitle
    }
    this.readerSetting = PreferencesUtil.getSync(`ReaderSetting_${this.bookData.bookName}`,
      this.readerSetting) as readerCore.ReaderSetting;
    // 上次选择的字体文件可能已被清理：回退系统字体，避免按钮显示一个用不了的字体名
    this.normalizeRestoredFont();
    // 必须在 startPlay 排版前注册，否则恢复阅读时首屏拿不到字体字节
    this.syncFontResourceListener();
    // 进入前同步日/夜模式，避免初始化后再翻转主题造成闪屏；
    // colorModeChange 已有 BookHandler 就绪保护，不会提前调用 setPageConfig
    this.colorMode = this.readerSetting.nightMode ? 0 : 1
    this.pageReady = true;
    await this.refreshReaderAccess();
  }

  onPageShow(): void {
    this.pageActive = true;
    if (this.pageReady) {
      this.refreshReaderAccess();
    }
  }

  onPageHide(): void {
    this.pageActive = false;
    this.accessRefresh.invalidate();
    if (this.privacyRequired) {
      this.coverPrivateReader();
    }
  }

  private get accessRequestId(): number {
    return this.accessRefresh.getRequestId();
  }

  private canReadCurrentBook(): boolean {
    return this.pageActive && !this.privacyCovered && (!this.privacyRequired ||
      (privacySessionService.isUnlocked() && this.privacyGeneration === privacySessionService.getGeneration()));
  }

  private releaseReader(): void {
    this.readerStarted = false;
    this.BookHandler = null;
    this.CatalogList.clear();
    try {
      this.readerComponentController.releaseBook();
    } catch (_) {
    }
  }

  private coverPrivateReader(): void {
    this.accessRefresh.invalidate();
    this.privacyCovered = true;
    this.privacyChecking = false;
    this.privacyGeneration = -1;
    this.privacyError = '隐私内容已锁定，请重新解锁';
    this.isShowSetting = false;
    this.isShowCatalogDialog = false;
    this.isShowListen = false;
    this.releaseReader();
  }

  private async refreshReaderAccess(): Promise<void> {
    if (!this.pageReady || !this.pageActive) return;
    const generation = privacySessionService.getGeneration();
    await this.accessRefresh.refresh(generation, privacySessionService.isUnlocked(),
      (requestId: number): Promise<boolean> => this.refreshReaderAccessRequest(requestId, generation));
  }

  private async refreshReaderAccessRequest(requestId: number, generation: number): Promise<boolean> {
    if (!this.pageReady || !this.pageActive || generation !== privacySessionService.getGeneration()) return false;
    this.privacyCovered = true;
    this.privacyChecking = true;
    this.privacyError = '';
    this.isShowSetting = false;
    this.isShowCatalogDialog = false;
    try {
      const required = await BooksDao.isPrivateBook(this.bookData);
      if (!this.pageActive || requestId !== this.accessRequestId ||
        generation !== privacySessionService.getGeneration()) {
        return false;
      }
      this.privacyRequired = required;
      this.privacyGeneration = generation;
      if (required && !privacySessionService.isUnlocked()) {
        this.coverPrivateReader();
        return false;
      }
      this.privacyCovered = false;
      if (!this.readerStarted || this.readerLoading || this.readerError.length > 0) {
        this.releaseReader();
        await this.startPlay(this.bookData.bookUrl ?? '',
          this.bookData.localBookDurChapterPos?.resourceIndex ?? 0,
          this.bookData.localBookDurChapterPos?.startDomPos ?? '', requestId);
      }
      return this.canReadCurrentBook() && requestId === this.accessRequestId && this.readerStarted;
    } catch (_) {
      if (requestId === this.accessRequestId) {
        this.privacyRequired = true;
        this.privacyCovered = true;
        this.privacyError = '无法确认书籍访问权限，请返回后重试';
        this.releaseReader();
      }
      return false;
    } finally {
      if (requestId === this.accessRequestId) {
        this.privacyChecking = false;
        if (this.pageActive && this.privacyCovered && !this.privacyError) {
          this.privacyError = '请解锁后继续阅读';
        }
      }
    }
  }

  private async unlockReader(): Promise<void> {
    if (this.privacyBusy) {
      return;
    }
    this.privacyBusy = true;
    try {
      const unlocked = await privacySessionService.unlock(this.getUIContext());
      if (unlocked && this.pageActive) {
        await this.refreshReaderAccess();
      } else if (this.pageActive) {
        this.privacyError = privacySessionService.getLastFailureMessage() || '请解锁后查看隐私内容';
      }
    } finally {
      this.privacyBusy = false;
    }
  }

  private async startPlay(path: string, resourceIndex: number, domPos: string, requestId: number) {
    if (!this.canReadCurrentBook() || requestId !== this.accessRequestId) {
      return;
    }
    this.readerLoading = true
    this.readerError = ''
    try {
      const localPath = requireReadableLocalBookPath(path)
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const initPromise: Promise<void> = this.readerComponentController.init(context);
      const defaultHandler: Promise<bookParser.BookParserHandler> = bookParser.getDefaultHandler(localPath);
      const result: [bookParser.BookParserHandler, void] = await Promise.all([defaultHandler, initPromise]);
      if (!this.canReadCurrentBook() || requestId !== this.accessRequestId) {
        return;
      }
      this.BookHandler = result[0];
      const catalog = this.BookHandler.getCatalogList() || []
      if (catalog.length === 0) {
        throw new Error('书籍内容为空或格式不受支持')
      }
      this.CatalogList.clear()
      this.CatalogList.pushAllData(catalog)
      const safeIndex = Math.max(0, Math.min(resourceIndex || 0, catalog.length - 1))
      this.bookData.durChapterIndex = safeIndex
      this.readerComponentController.registerBookParser(this.BookHandler);
      this.readerComponentController.setPageConfig(this.readerSetting);
      this.readerStarted = true;
      await this.readerComponentController.startPlay(safeIndex, domPos);
      if (!this.canReadCurrentBook() || requestId !== this.accessRequestId) {
        if (requestId === this.accessRequestId) this.releaseReader();
        return;
      }
      hilog.info(0x0000, 'testTag', 'catalog list length: ' + this.CatalogList.totalCount());
    } catch (err) {
      if (this.canReadCurrentBook() && requestId === this.accessRequestId) {
        this.readerStarted = false;
        this.readerError = err instanceof Error ? err.message : '书籍加载失败';
      }
    } finally {
      if (this.canReadCurrentBook() && requestId === this.accessRequestId) {
        if (this.readerError.length > 0) {
          this.readerLoading = false;
        } else {
          // 正常路径等首帧回调；旧请求不能在重锁后撤下遮挡。
          setTimeout(() => {
            if (this.canReadCurrentBook() && requestId === this.accessRequestId) {
              this.readerLoading = false;
            }
          }, 3000);
        }
      }
    }
  }

  /**
   * 系统的颜色模式更改后调整为对应的主题
   */
  colorModeChange() {
    if (this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      this.readerSetting.nightMode = true;
      this.readerSetting.fontColor = '#ffffff';
      this.readerSetting.themeColor = '#202224';
    } else {
      this.readerSetting.nightMode = false;
      this.readerSetting.fontColor = '#000000';
      this.readerSetting.themeColor = '#FFFFFF';
    }
    if (this.BookHandler) {
      this.readerComponentController.setPageConfig(this.readerSetting);
    }
  }

  /**
   * 注册屏幕密度变化回调。
   */
  registerScreenDensityChange() {
    this.screenDensityCallBack = (data: number) => {
      let displaySync = display.getDefaultDisplaySync();
      let scaledDensity = displaySync.scaledDensity;
      if (scaledDensity !== this.readerSetting.scaledDensity) {
        AppStorage.setOrCreate('isDensityChange', true);
        this.getUIContext().getRouter().back();
      }
    }
    display.on('change', this.screenDensityCallBack);
  }

  private registerListener(): void {
    this.readerComponentController.on('pageShow', (data: readerCore.PageDataInfo): void => {
      if (!this.canReadCurrentBook()) {
        return;
      }
      // 首帧真正渲染完成才撤加载层，避免提前露出未绘制画布造成闪屏
      this.readerLoading = false;
      this.bookData.localBookDurChapterPos = data;
      // ReaderKit 的 resourceIndex 基于 spine，可能超出目录列表范围；
      // 只接受范围内的下标，避免越界值写入 bookData 并持久化
      const resourceIndex = data.resourceIndex ?? this.bookData.durChapterIndex
      const currentCatalog = this.getCatalogItemSafely(resourceIndex)
      if (currentCatalog) {
        this.bookData.durChapterIndex = resourceIndex
        this.bookData.durChapterTitle = currentCatalog.catalogName;
      }
      this.bookData.totalChapterNum = this.CatalogList.totalCount();
      // 保存书籍数据。
      PreferencesUtil.putSync(`BookCurrentData_${this.bookData.bookName}`, this.bookData)
      //  保存阅读器设置。
      PreferencesUtil.putSync(`ReaderSetting_${this.bookData.bookName}`, this.readerSetting)
    });
    WindowAbility.getInstance().onWindowSizeChange(() => {
      if (!this.canReadCurrentBook() || !this.BookHandler) {
        return;
      }
      if (this.readerSetting.viewPortWidth != this.windowWidth ||
        this.readerSetting.viewPortHeight != this.windowHeight) {
        // 当窗口大小更改时，更新当前页面视区大小。
        this.readerSetting.viewPortWidth = this.windowWidth;
        this.readerSetting.viewPortHeight = this.windowHeight;
        try {
          this.readerComponentController.setPageConfig(this.readerSetting);
        } catch (e) {
          console.error('onWindowSizeChange, error ' + JSON.stringify(e));
        }
      }
    });
  }

  aboutToDisappear(): void {
    this.pageActive = false;
    this.pageReady = false;
    this.accessRefresh.invalidate();
    this.unsubscribePrivacy?.();
    this.unsubscribePrivacy = undefined;
    WindowAbility.getInstance().toggleWindowSystemBar(['status', 'navigation'], this.getUIContext().getHostContext());
    PreferencesUtil.putSync(`isScreenState`, this.isScreenState)
    display.off('change', this.screenDensityCallBack);
    this.readerComponentController.off('pageShow');
    this.readerComponentController.off('resourceRequest');
    this.releaseReader();
  }

  build() {
    Stack() {
      ReadPageComponent({
        controller: this.readerComponentController,
        readerCallback: (err: BusinessError, data: readerCore.ReaderComponentController) => {
          // 失败分支 data 可能为 undefined，不能覆盖已有 controller
          if (data) {
            this.readerComponentController = data;
          }
          if (err && err.code) {
            this.readerLoading = false
            this.readerError = err.message || '阅读器初始化失败'
          }
        }
      }).width('100%').height('100%')
        .visibility(this.privacyCovered ? Visibility.Hidden : Visibility.Visible)

      if (!this.privacyCovered) {
      if (this.readerLoading || this.readerError.length > 0) {
        Column({ space: 16 }) {
          if (this.readerLoading) {
            LoadingProgress().width(40).height(40).color(this.colorMode == 0 ? '#F8F9FA' : '#182231')
            Text('正在加载书籍…').fontSize(14)
              .fontColor(this.colorMode == 0 ? 'rgba(248,249,250,0.8)' : '#666666')
          } else {
            Text('书籍加载失败').fontSize(18).fontWeight(600)
              .fontColor(this.colorMode == 0 ? 'rgba(248,249,250,1)' : '#182231')
            Text(this.readerError).fontSize(14)
              .fontColor(this.colorMode == 0 ? 'rgba(248,249,250,0.7)' : '#666666')
              .textAlign(TextAlign.Center)
            Button('返回书架')
              .height(40)
              .fontSize(14)
              .backgroundColor(this.colorMode == 0 ? '#3A3D42' : '#F2F3F5')
              .fontColor(this.colorMode == 0 ? 'rgba(248,249,250,1)' : '#182231')
              .onClick(() => {
                router.back()
              })
          }
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .width('100%')
        .height('100%')
        .padding(32)
        // 加载层背景跟随阅读主题，避免与正文主题不一致产生闪屏
        .backgroundColor(this.readerSetting.themeColor || '#FFFFFF')
      }

      Column() {
        if (this.isShowSetting) { // 阅读器-上方弹框
          Column() {
            Row({ space: 8 }) {
              Image($r("app.media.ic_public_return_left"))
                .fillColor(this.colorMode == 0 ? 'rgba(248, 249, 250, 1)' : 'rgba(19, 19, 19, 1.00)')
                .width(24)
                .onClick(() => {
                  router.back()
                })

              Text(`${this.currentCatalogTitle()}`
                .replace(new RegExp('\\s{1,}', 'g'), ' ')
                .replaceAll('=', ''))
                .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .fontColor(this.colorMode == 0 ? 'rgba(248, 249, 250, 1)' : 'rgba(19, 19, 19, 1.00)')

            }
            .padding({
              top: 12,
              left: 20,
              right: 20,
              bottom: 12
            })
            .width("100%")

            Divider()
          }
          .padding({ top: this.topRectHeight == 0 ? 40 : 0 })
          .backgroundColor(this.colorMode == 0 ? '#1F1F1F' : 'rgba(250, 250, 250, 1)')
          .transition(TransitionEffect.move(TransitionEdge.TOP).animation({ duration: 500 }))

          Blank(1).onClick(() => {
            this.isShowSetting = false
          })

          // 阅读器-下方弹框
          Column({ space: 20 }) {
            Divider()

            if (!this.isShowContentSetting) {
              Row({ space: 16 }) {
                Text("上一章")
                  .fontColor(this.colorMode == 0 ? 'rgba(248, 249, 250, 1)' : 'rgba(19, 19, 19, 1.00)')
                  .onClick(() => {
                    if (this.bookData.durChapterIndex > 0) {
                      this.bookData.durChapterIndex--
                      this.jumpToCatalogItem(this.getCatalogItemSafely(this.bookData.durChapterIndex))
                    }
                  })

                Slider({
                  value: this.bookData.durChapterIndex,
                  max: this.CatalogList.totalCount() - 1,
                  min: 0,
                  step: 1,
                  style: SliderStyle.InSet
                })
                  .selectedColor('rgba(0, 0, 0, 0.04)')
                  .blockSize({ width: 30, height: 30 })
                  .layoutWeight(1)
                  .onChange((value, mode) => {
                    //结束滑动后再跳转到对应章节
                    if (mode == SliderChangeMode.End) {
                      this.bookData.durChapterIndex = value
                      this.jumpToCatalogItem(this.getCatalogItemSafely(value))
                    }
                  })

                Text("下一章")
                  .fontColor(this.colorMode == 0 ? 'rgba(248, 249, 250, 1)' : 'rgba(19, 19, 19, 1.00)')
                  .onClick(() => {
                    if (this.bookData.durChapterIndex < this.CatalogList.totalCount() - 1) {
                      this.bookData.durChapterIndex++
                      this.jumpToCatalogItem(this.getCatalogItemSafely(this.bookData.durChapterIndex))
                    }
                  })
              }
              .padding({
                //todo:临时bottom距离
                left: 24, right: 24, bottom: '10%'
              })
              .width("100%")
            } else { // 下方-设置
              Column({ space: 12 }) {
                Row({ space: 5 }) {
                  Text('亮度')
                  Slider({
                    value: BrightnessUtil.getBrightness('reader'),
                    max: 1,
                    min: 0,
                    step: 0.01,
                    style: SliderStyle.InSet
                  })
                    .selectedColor('rgba(0, 0, 0, 0.04)')
                    .blockSize({ width: 30, height: 30 })
                    .layoutWeight(1)
                    .hitTestBehavior(this.isLuminanceFollowSystem ? HitTestMode.None : HitTestMode.Default)
                    .onChange((value) => {
                      if (!this.isLuminanceFollowSystem) {
                        BrightnessUtil.setBrightness('reader', value)
                      }
                    })
                  Text('随系统')
                  Toggle({ type: ToggleType.Switch, isOn: $$this.isLuminanceFollowSystem })
                    .onChange((value) => {
                      this.isLuminanceFollowSystem = value
                      BrightnessUtil.setBrightness('reader', value ? -1 : 0.3)
                    })
                  Text('常亮')
                  Toggle({ type: ToggleType.Switch, isOn: $$this.isScreenState })
                    .onChange((value) => {
                      this.isScreenState = value
                      BrightnessUtil.setScreenState(value)
                    })
                }

                Row({ space: 16 }) {
                  Text('字号')
                    .fontColor(this.colorMode == 0 ? 'rgba(248, 249, 250, 1)' : 'rgba(19, 19, 19, 1.00)')

                  Slider({
                    value: this.readerSetting.fontSize,
                    max: 48,
                    min: 12,
                    step: 1,
                    style: SliderStyle.InSet
                  })
                    .selectedColor('rgba(0, 0, 0, 0.04)')
                    .blockSize({ width: 30, height: 30 })
                    .layoutWeight(1)
                    .onChange((value) => {
                      this.readerSetting.fontSize = value
                      this.readerComponentController.setPageConfig(this.readerSetting);
                    })
                  Button(this.readerSetting.fontName === '' || this.readerSetting.fontName === SYSTEM_FONT_NAME
                    ? '字体' : `字体·${this.readerSetting.fontName}`)
                    .fontColor(this.colorMode == 0 ? 'rgba(248, 249, 250, 1)' : 'rgba(19, 19, 19, 1.00)')
                    // 字体名可能很长，限宽省略，避免挤压字号滑块
                    .constraintSize({ maxWidth: 110 })
                    .labelStyle({ maxLines: 1, overflow: TextOverflow.Ellipsis })
                    .onClick(() => {
                      this.openFontPicker()
                    })
                    .bindSheet($$this.isShowFontPicker, this.FontPickerDialog(), {
                      detents: ['60%'],
                      dragBar: false,
                      showClose: false,
                      onDisappear: () => {
                        this.isShowFontPicker = false
                      },
                      backgroundColor: this.colorMode == 0 ? 'rgba(19, 19, 19, 1.00)' : 'rgba(248, 249, 250, 1)'
                    })
                }

                Row({ space: 16 }) {
                  Text('行距')
                    .fontColor(this.colorMode == 0 ? 'rgba(248, 249, 250, 1)' : 'rgba(19, 19, 19, 1.00)')

                  Slider({
                    value: this.readerSetting.lineHeight,
                    max: 3,
                    min: 1,
                    step: 0.1,
                    style: SliderStyle.InSet
                  })
                    .selectedColor('rgba(0, 0, 0, 0.04)')
                    .blockSize({ width: 30, height: 30 })
                    .layoutWeight(1)
                    .onChange((value) => {
                      this.readerSetting.lineHeight = value
                      this.readerComponentController.setPageConfig(this.readerSetting);
                    })
                  /*Row() {
                    Button('更多').bindSheet($$this.isShowMoreLayout, this.LayoutMoreDialog(), {
                      height: 500,
                      showClose: false,
                      dragBar: false,
                      blurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
                      onDisappear: () => { // this.clickBookType = ''
                      }
                    }).onClick(() => {
                      this.isShowMoreLayout = true
                    })
                  }*/
                }

                Row({ space: 16 }) {
                  Text('背景')
                  Scroll() {
                    Row({ space: 12 }) {
                      ForEach(this.themeList, (item: themeItem) => {
                        Stack() {
                          Column()
                            .width('100%')
                            .height(30)
                            .borderWidth(this.readerSetting.themeColor == item.themeColor &&
                              this.readerSetting.fontColor == item.fontColor &&
                              this.readerSetting.themeBgImg == item.themeBgImg ? 1 : 2)
                            .borderColor(this.readerSetting.themeColor == item.themeColor &&
                              this.readerSetting.fontColor == item.fontColor &&
                              this.readerSetting.themeBgImg == item.themeBgImg ? '#ff6600' : item.themeColor)
                            .backgroundColor(item.themeColor)
                            .backgroundImage(item.themeBgImg)
                            .backgroundImagePosition(Alignment.BottomEnd)
                            .backgroundImageSize(ImageSize.Cover)
                            .borderRadius(20)
                        }
                        .width(50)
                        .constraintSize({
                          minWidth: 60
                        })
                        .borderRadius(30)
                        .borderStyle(BorderStyle.Solid)
                        .onClick(() => {
                          this.readerSetting.fontColor = item.fontColor;
                          this.readerSetting.themeColor = item.themeColor;
                          this.readerSetting.themeBgImg = item.themeBgImg;
                          this.readerComponentController.setPageConfig(this.readerSetting);
                        })
                      })
                    }
                  }
                  .scrollable(ScrollDirection.Horizontal)
                  .scrollBar(BarState.Off)
                  .edgeEffect(EdgeEffect.Spring)
                  .width('80%')

                  // Row() {
                  //   Button('更多')
                  // }
                }

                Row({ space: 16 }) {
                  // Button('自动阅读')
                  Button('仿真翻页')
                    .fontColor(this.colorMode == 0 ? 'rgba(248, 249, 250, 1)' : 'rgba(19, 19, 19, 1.00)')
                    .onClick(() => {
                      if (this.readerSetting.flipMode == '0') {
                        this.readerSetting.flipMode = '1';
                        promptAction.showToast({ message: '横滑' })
                      } else {
                        this.readerSetting.flipMode = '0';
                        promptAction.showToast({ message: '仿真' })
                      }
                      this.readerComponentController.setPageConfig(this.readerSetting);
                    })
                  // Button('更多设置')
                }
              }.padding({
                left: 20, right: 20
              })
            }

            Grid() {
              GridItem() {
                Column() {
                  Image($r("app.media.catalogue"))
                    .width(24)
                    .fillColor(this.colorMode == 0 ? 'rgba(248, 249, 250, 1)' : 'rgba(19, 19, 19, 1.00)')
                  Text("目录")
                    .fontColor(this.colorMode == 0 ? 'rgba(248, 249, 250, 1)' : 'rgba(19, 19, 19, 1.00)')
                }
                .onClick(() => {
                  this.isShowCatalogDialog = true
                })
                .bindSheet($$this.isShowCatalogDialog, this.CatalogDialog(), {
                  detents: ['90%'],
                  dragBar: false,
                  showClose: false,
                  onDisappear: () => {
                    this.isShowCatalogDialog = false
                  },
                  backgroundColor: this.colorMode == 0 ? 'rgba(19, 19, 19, 1.00)' : 'rgba(248, 249, 250, 1)'
                })
              }

              //todo:听书功能开发
              /*              GridItem() {
                              Column() {
                                Image($r("app.media.listen")).width(24)
                                Text("听书")
                              }
                            }
                            .bindContentCover($$this.isShowListen, this.BookListen(), {
                              modalTransition: ModalTransition.DEFAULT, backgroundColor: "rgba(51, 106, 128, 0.75)"
                            }).onClick(() => {
                              this.isShowListen = true
                            })*/

              GridItem() {
                Column() {
                  Image(this.colorMode == 0 ? $r("app.media.day_icon") : $r("app.media.night_icon"))
                    .width(24)
                    .fillColor(this.colorMode == 0 ? 'rgba(248, 249, 250, 1)' : 'rgba(19, 19, 19, 1.00)')
                  Text(this.colorMode == 0 ? "日间" : "夜间")
                    .fontColor(this.colorMode == 0 ? 'rgba(248, 249, 250, 1)' : 'rgba(19, 19, 19, 1.00)')
                }.onClick(() => {
                  this.colorMode = this.colorMode == 0 ? 1 : 0
                  if (this.colorMode == 0) {
                    this.readerSetting.nightMode = true;
                    this.readerSetting.fontColor = '#ffffff';
                    this.readerSetting.themeColor = '#202224';
                  } else {
                    this.readerSetting.nightMode = false;
                    this.readerSetting.fontColor = '#000000';
                    this.readerSetting.themeColor = '#FFFFFF';
                  }
                  this.readerComponentController.setPageConfig(this.readerSetting);
                })
              }

              GridItem() {
                Column() {
                  Image($r(this.isShowContentSetting ? "app.media.my_center_set_icon_fill" :
                    "app.media.my_center_set_icon"))
                    .width(24)
                    .fillColor(this.colorMode == 0 ? 'rgba(248, 249, 250, 1)' : 'rgba(19, 19, 19, 1.00)')
                  Text("设置")
                    .fontColor(this.colorMode == 0 ? 'rgba(248, 249, 250, 1)' : 'rgba(19, 19, 19, 1.00)')
                }.onClick(() => {
                  this.isShowContentSetting = !this.isShowContentSetting
                })
              }
            }.columnsTemplate("1fr 1fr 1fr").width("100%").height(60)
          }
          .backgroundColor(this.colorMode == 0 ? '#1F1F1F' : 'rgba(248, 249, 250, 1)')
          .transition(TransitionEffect.move(TransitionEdge.BOTTOM).animation({ duration: 500 }))
        }
      }.width("100%").height("100%").enabled(this.isShowSetting).padding({
        top: this.topRectHeight,
      })
      } else {
        Column({ space: 18 }) {
          Text(this.privacyChecking ? '正在确认访问权限…' : '隐私内容已锁定')
            .fontSize(20).fontWeight(FontWeight.Medium)
          if (this.privacyChecking) {
            LoadingProgress().width(36).height(36)
          } else {
            Text(this.privacyError || '解锁后继续阅读')
              .fontSize(14).fontColor('#666666').textAlign(TextAlign.Center)
            Button(this.privacyBusy ? '认证中…' : '解锁并继续')
              .enabled(!this.privacyBusy)
              .onClick(() => this.unlockReader())
            Button('返回书架').onClick(() => router.back())
          }
        }.width('100%').height('100%').padding(32)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F6F7F9')
      }
    }.width('100%').height('100%').onClick(() => {
      // 点击拉起菜单栏功能
      if (this.canReadCurrentBook()) {
        this.isShowSetting = true
      }
    })
  }

  /**
   * 目录弹窗
   */
  @Builder
  CatalogDialog() {
    Stack() {
      List({ space: 10, scroller: this.scrollerForList }) {
        LazyForEach(this.CatalogList, (item: bookParser.CatalogItem, index) => {
          ListItem() {
              Column() {
                Row() {
                  Text(item.catalogName)
                    .fontSize(14)
                    .fontColor(this.colorMode == 0 ?
                      (this.bookData.durChapterIndex == index ? 'rgba(129, 231, 126, 1.00)' :
                        'rgba(248, 249, 250, 1)') :
                      (this.bookData.durChapterIndex == index ? 'rgba(129, 231, 126, 1.00)' : 'rgba(19, 19, 19, 1.00)'))
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .padding({ top: 8, bottom: 8 })
                    .layoutWeight(1)
                }
                .width('100%')
              }
              .padding({
                left: item.catalogLevel ? item.catalogLevel * 26 : 16,
                right: 16,
              })
          }
          .onClick(() => {
            this.bookData.durChapterIndex = index
            this.jumpToCatalogItem(item)
            this.isShowCatalogDialog = false
          })
        })
      }
      .divider({
        strokeWidth: 0.8,
        color: this.colorMode == 0 ? 'rgba(248, 249, 250, 1)' : 'rgba(136, 136, 136, 1.00)',
        startMargin: 12,
        endMargin: 12
      })
      .width('100%')
      .height('100%')
      .onAppear(() => {
        this.scrollerForList.scrollToIndex(this.bookData.durChapterIndex)
      })

      Column() {
        Column() {
          Image($r('app.media.top'))
            .width(20)
            .height(20)
          Text('顶部')
            .fontSize(12)
        }
        .padding(5)
        .onClick(() => {
          this.scrollerForList.scrollToIndex(0)
        })

        Column() {
          Text() {
            SymbolSpan($r("sys.symbol.position"))
          }

          Text('定位')
            .fontSize(12)
        }
        .padding(5)
        .onClick(() => {
          this.scrollerForList.scrollToIndex(this.bookData.durChapterIndex)
        })

        Column() {
          Image($r('app.media.down'))
            .width(20)
            .height(20)
          Text('底部')
            .fontSize(12)
        }
        .padding(5)
        .onClick(() => {
          this.scrollerForList.scrollToIndex(this.CatalogList.totalCount() - 1)
        })
      }
      .padding(5)
      .backgroundColor('rgba(129, 231, 126, 1.00)')
      .borderRadius(20)
      .position({ bottom: '10%', right: '5%' })
    }
  }

  @Builder
  DialogString() {
    Row() {
      Text("喜欢就加入书架吧").lineHeight(22).font({
        size: 14, weight: 400
      }).fontColor($r("app.string.color_black_45"))
    }.margin({
      top: 12, bottom: 16
    })
  }

  @Builder
  BookListen() {
    MusicPlayer({ WidthMinus: 118, isShowListen: this.isShowListen }).width("100%").height("100%")
  }

  @Builder
  LayoutMoreDialog() {
    LayoutMoreDialog({ ReaderPadding: this.ReaderPadding }).height(500).width("100%")
  }

  @Builder
  FontPickerDialog() {
    FontPickerPanel({
      fontOptions: this.fontOptions,
      currentFontPath: this.readerSetting.fontPath,
      colorMode: this.colorMode,
      isImporting: this.isImportingFont,
      onSelect: (option: ReaderFontOption) => {
        this.selectFont(option)
        // 收起面板让用户直接看到排版变化
        this.isShowFontPicker = false
      },
      onImport: () => {
        this.importFontFlow()
      },
      onDelete: (option: ReaderFontOption) => {
        this.deleteFontFlow(option)
      }
    }).width('100%').height('100%')
  }

  private openFontPicker(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ReaderFontManager.listFontOptions(context).then((options: ReaderFontOption[]) => {
      this.fontOptions = options
      this.isShowFontPicker = true
    }).catch((error: BusinessError) => {
      hilog.error(0x0000, 'ReaderFont', 'list fonts failed: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '字体加载失败' })
    })
  }

  /** 应用所选字体：fontPath 交给内核（配合 resourceRequest 字节流），立即持久化 */
  private selectFont(option: ReaderFontOption): void {
    this.readerSetting.fontName = option.name;
    this.readerSetting.fontPath = option.path;
    this.syncFontResourceListener();
    this.readerComponentController.setPageConfig(this.readerSetting);
    PreferencesUtil.putSync(`ReaderSetting_${this.bookData.bookName}`, this.readerSetting)
  }

  /**
   * 按当前设置同步 resourceRequest 监听：
   * 只有使用自定义字体时才注册，其它情况保持不注册，避免影响内核默认的图片/CSS 加载。
   */
  private syncFontResourceListener(): void {
    const fontPath = this.readerSetting.fontPath;
    const needFont = !!fontPath && fontPath.length > 0;
    if (needFont && !this.fontResourceListenerRegistered) {
      this.readerComponentController.on('resourceRequest', (url: string): ArrayBuffer => {
        hilog.info(0x0000, 'ReaderFont', 'resourceRequest: %{public}s', url);
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        return ReaderFontManager.serveFontResource(context, this.readerSetting.fontPath, url);
      });
      this.fontResourceListenerRegistered = true;
    } else if (!needFont && this.fontResourceListenerRegistered) {
      this.readerComponentController.off('resourceRequest');
      this.fontResourceListenerRegistered = false;
    }
  }

  /** 恢复上次设置时校验字体文件是否还在，失效则回退系统字体 */
  private normalizeRestoredFont(): void {
    const path = this.readerSetting.fontPath;
    if (!path || path.length === 0) {
      // 旧偏好可能缺字段，统一补成系统字体，后续读取不再判 undefined
      this.readerSetting.fontName = SYSTEM_FONT_NAME;
      this.readerSetting.fontPath = '';
      return;
    }
    if (!ReaderFontManager.isFontAvailable(path)) {
      hilog.warn(0x0000, 'ReaderFont', 'restored font missing: %{public}s, fallback to system', path);
      this.readerSetting.fontName = SYSTEM_FONT_NAME;
      this.readerSetting.fontPath = '';
      return;
    }
    // 旧数据可能只有路径没有名字
    if (!this.readerSetting.fontName || this.readerSetting.fontName.length === 0) {
      this.readerSetting.fontName = ReaderFontManager.displayNameOf(path);
    }
  }

  private importFontFlow(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.isImportingFont = true
    ReaderFontManager.pickFontUris(context).then((uris: string[]) => {
      if (uris.length === 0) {
        this.isImportingFont = false
        return
      }
      return this.importFontUris(context, uris)
    }).catch((error: BusinessError) => {
      hilog.error(0x0000, 'ReaderFont', 'pick fonts failed: %{public}s', JSON.stringify(error));
      this.isImportingFont = false
      promptAction.showToast({ message: '字体导入失败' })
    })
  }

  private async importFontUris(context: common.UIAbilityContext, uris: string[]): Promise<void> {
    let successCount = 0;
    let failCount = 0;
    let replacedCurrentFont: ReaderFontOption | undefined;
    for (let index = 0; index < uris.length; index++) {
      try {
        const imported = await ReaderFontManager.importFont(context, uris[index]);
        if (imported.path === this.readerSetting.fontPath) {
          replacedCurrentFont = imported;
        }
        successCount++;
      } catch (error) {
        failCount++;
        hilog.error(0x0000, 'ReaderFont', 'import font[%{public}d] failed: %{public}s',
          index, JSON.stringify(error));
      }
    }
    this.isImportingFont = false
    if (successCount > 0) {
      try {
        this.fontOptions = await ReaderFontManager.listFontOptions(context);
      } catch (error) {
        hilog.error(0x0000, 'ReaderFont', 'refresh fonts failed: %{public}s', JSON.stringify(error));
      }
    }
    if (replacedCurrentFont && replacedCurrentFont.path === this.readerSetting.fontPath &&
      this.readerStarted && this.canReadCurrentBook()) {
      try {
        // 路径未变也要触发内核重载；中间配置不写入偏好，最终保留用户的字体选择。
        this.readerComponentController.setPageConfig({
          fontName: SYSTEM_FONT_NAME,
          fontPath: '',
          fontSize: this.readerSetting.fontSize,
          fontColor: this.readerSetting.fontColor,
          fontWeight: this.readerSetting.fontWeight,
          lineHeight: this.readerSetting.lineHeight,
          nightMode: this.readerSetting.nightMode,
          themeColor: this.readerSetting.themeColor,
          themeBgImg: this.readerSetting.themeBgImg,
          flipMode: this.readerSetting.flipMode,
          scaledDensity: this.readerSetting.scaledDensity,
          viewPortWidth: this.readerSetting.viewPortWidth,
          viewPortHeight: this.readerSetting.viewPortHeight
        });
        this.selectFont(replacedCurrentFont);
      } catch (error) {
        hilog.error(0x0000, 'ReaderFont', 'reload imported font failed: %{public}s', JSON.stringify(error));
        promptAction.showToast({ message: '字体已导入，刷新失败，请重新打开书籍' })
        return
      }
    }
    if (failCount > 0) {
      promptAction.showToast({ message: `${failCount} 个字体导入失败` })
    } else if (successCount > 0) {
      promptAction.showToast({ message: '导入成功' })
    }
  }

  private deleteFontFlow(option: ReaderFontOption): void {
    // 按路径判等：不同扩展名的同名字体（a.ttf / a.otf）展示名相同
    const wasCurrent = this.readerSetting.fontPath === option.path;
    if (!ReaderFontManager.deleteFont(option)) {
      promptAction.showToast({ message: '删除失败' })
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ReaderFontManager.listFontOptions(context).then((options: ReaderFontOption[]) => {
      this.fontOptions = options
    }).catch((error: BusinessError) => {
      hilog.error(0x0000, 'ReaderFont', 'refresh fonts failed: %{public}s', JSON.stringify(error));
    })
    if (wasCurrent) {
      // 删除的是使用中的字体，回退到系统字体
      const system = new ReaderFontOption();
      system.name = SYSTEM_FONT_NAME;
      system.path = '';
      this.selectFont(system)
    }
    promptAction.showToast({ message: '已删除' })
  }

  /**
   * 去掉页面过渡动画，加快阅读器的页面访问速度
   */
  pageTransition() {
    PageTransitionEnter({ duration: 0, curve: Curve.Sharp });
    PageTransitionExit({ duration: 0, curve: Curve.Sharp });
  }

  /**
   * 越界安全地取目录项：目录未加载（如 startPlay 失败）或下标超出
   * 目录长度时返回 undefined，调用方必须判空后再访问字段
   */
  private getCatalogItemSafely(index: number): bookParser.CatalogItem | undefined {
    if (index < 0 || index >= this.CatalogList.totalCount()) {
      return undefined
    }
    return this.CatalogList.getData(index)
  }

  private currentCatalogTitle(): string {
    return this.getCatalogItemSafely(this.bookData.durChapterIndex ?? 0)?.catalogName ?? ''
  }

  /**
   * 跳转到指定的章节
   *
   * @param catalogItem 书籍目录节点
   */
  private async jumpToCatalogItem(catalogItem?: bookParser.CatalogItem) {
    if (!this.canReadCurrentBook() || !catalogItem) {
      return
    }
    // 根据目录项获取章节的索引
    const resourceIndex = this.getResourceItemByCatalog(catalogItem).index;
    // 跳转到指定章节
    this.readerComponentController.startPlay(resourceIndex, '');
  }

  /**
   * 根据目录项获取章节位置信息
   *
   * @param catalogItem 书籍目录节点
   * @returns 返回找到的章节位置信息或默认的空章节位置信息
   */
  private getResourceItemByCatalog(catalogItem: bookParser.CatalogItem): bookParser.SpineItem {
    // 获取目录项中的内容文件引用，如果没有则默认为空字符串
    let resourceFile = catalogItem.resourceFile || '';

    // 获取默认处理程序中的书脊内容列表，如果没有则默认为空数组
    let spineList: bookParser.SpineItem[] = this.BookHandler?.getSpineList() || []

    // 过滤书脊内容列表，找出href与内容文件引用匹配的章节位置信息
    let resourceItemArr = spineList.filter(item => item.href === resourceFile);

    // 如果找到了匹配的章节位置信息，则返回第一个匹配的章节位置信息
    if (resourceItemArr.length > 0) {
      hilog.info(0x0000, 'testTag', 'getResourceItemByCatalog get resource ', resourceItemArr[0]);
      let resourceItem = resourceItemArr[0];
      return resourceItem;
      // 如果没有找到匹配的章节位置信息，但书脊内容列表有项，则返回书脊内容列表的第一项
    } else if (spineList.length > 0) {
      hilog.info(0x0000, 'testTag', 'getResourceItemByCatalog get resource in resourceList', spineList[0]);
      return spineList[0];
      // 如果书脊内容列表为空，则返回一个空的章节位置信息对象
    } else {
      hilog.info(0x0000, 'testTag', 'getResourceItemByCatalog get resource in escape');
      return {
        idRef: '',
        index: 0,
        href: '',
        properties: ''
      };
    }
  }
}
