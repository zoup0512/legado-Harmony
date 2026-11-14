import { promptAction, router } from '@kit.ArkUI';
import { Books } from '../../../database/entities/Books';
import privacyFolderService from '../../../privacy/PrivacyFolderService';
import privacySessionService, { PrivacyBiometricType } from '../../../privacy/PrivacySessionService';
import privacyCredentialService from '../../../privacy/PrivacyCredentialService';
import Header from '../../../componets/common/Header';
import BasicDataSource from '../../../common/LazyIDataSource/BasicDataSource';
import { ThemeStorageKey } from '../../../common/constants/Theme';
import { ThemeItem } from '../../../common/model/Theme';
import BookInfos from '../bookShelf/components/BookInfos';
import BookInfoGrids from '../bookShelf/components/BookInfoGrids';

/**
 * 隐私文件夹内容。既用于独立页面（PrivacyFolder），也用于首页底部的“隐私”Tab。
 * 宿主负责传入 visible：页面 onPageShow/onPageHide，或 Tab 是否当前可见且首页在前台。
 * enterSeq 每次“主动进入”时递增，用来触发一次指纹/人脸自动解锁；页面返回不会递增，避免重复拉起认证。
 */
@Component
export default struct PrivacyFolderView {
  @Prop @Watch('onVisibleChanged') visible: boolean = false;
  @Prop @Watch('onEnter') enterSeq: number = 0;
  // 嵌入首页 Tab 时不显示返回按钮
  @Prop embedded: boolean = false;
  @StorageLink('topRectHeight') topRectHeight: number = 0;
  @StorageLink(ThemeStorageKey.THEME) theme: ThemeItem = {
    mainColor: '#24b277', secondColor: '#e4f5ee', text: '主题3'
  };
  @State unlocked: boolean = false;
  @State books: Books[] = [];
  @State searchKey: string = '';
  @State busy: boolean = false;
  @State credentialKnown: boolean = false;
  @State configured: boolean = false;
  // Enrolled fingerprint/face: unlock uses system biometrics; otherwise the six-digit PIN.
  @State biometricReady: boolean = false;
  @State biometricType: PrivacyBiometricType = PrivacyBiometricType.NONE;
  @State credentialError: string = '';
  @State EXHIBIT: string = '列表';
  @Provide('booksDataSource') booksDataSource: BasicDataSource<Books> = new BasicDataSource<Books>();
  @StorageLink('BOOK_IS_BOOK_REFRESHING') @Watch('onShelfChanged') isBookRefreshing: number = 0;
  private unsubscribe: (() => void) | undefined;
  private active: boolean = false;
  private loadRequestId: number = 0;
  private statusRequestId: number = 0;
  private operationId: number = 0;
  private autoUnlockTimer: number = -1;

  onShelfChanged(): void {
    if (this.unlocked && this.visible) this.loadBooks();
  }

  aboutToAppear(): void {
    this.active = true;
    this.unsubscribe?.();
    this.unsubscribe = privacySessionService.onStateChanged((locked: boolean): void => {
      if (locked) {
        this.clearLockedState();
      } else if (this.visible) {
        this.syncSession();
      }
    });
    this.syncSession();
    this.refreshBiometricReady();
    this.refreshCredentialStatus();
    if (this.enterSeq > 0) this.scheduleAutoUnlock();
  }

  onVisibleChanged(): void {
    if (this.visible) {
      // Never start authentication here: router returns can precede the pending result.
      this.syncSession();
      if (!this.busy) {
        this.refreshBiometricReady();
        this.refreshCredentialStatus();
      }
    } else {
      this.cancelAutoUnlock();
      this.clearBooks();
    }
  }

  onEnter(): void {
    this.scheduleAutoUnlock();
  }

  // Open the system fingerprint/face prompt once per explicit entry.
  private scheduleAutoUnlock(): void {
    this.refreshBiometricReady();
    if (this.unlocked || !this.biometricReady) return;
    this.cancelAutoUnlock();
    this.autoUnlockTimer = setTimeout((): void => {
      this.autoUnlockTimer = -1;
      if (this.active && this.visible && !this.unlocked && !privacySessionService.isUnlocked()) this.unlock();
    }, 350);
  }

  private cancelAutoUnlock(): void {
    if (this.autoUnlockTimer !== -1) clearTimeout(this.autoUnlockTimer);
    this.autoUnlockTimer = -1;
  }

  private refreshBiometricReady(): void {
    this.biometricReady = privacySessionService.isBiometricAvailable();
    this.biometricType = this.biometricReady ? privacySessionService.getBiometricType() : PrivacyBiometricType.NONE;
  }

  aboutToDisappear(): void {
    this.cancelAutoUnlock();
    this.active = false;
    this.statusRequestId++;
    this.operationId++;
    this.unsubscribe?.();
    this.unsubscribe = undefined;
    this.clearBooks();
  }

  private clearBooks(): void {
    this.loadRequestId++;
    this.books = [];
    this.booksDataSource.clear();
  }

  private clearLockedState(): void {
    this.unlocked = false;
    this.searchKey = '';
    this.operationId++;
    this.busy = false;
    this.clearBooks();
  }

  private syncSession(): void {
    this.unlocked = privacySessionService.isUnlocked();
    if (this.unlocked) {
      if (this.visible) this.loadBooks();
    } else {
      this.searchKey = '';
      this.clearBooks();
    }
  }

  private async refreshCredentialStatus(): Promise<void> {
    const requestId = ++this.statusRequestId;
    const generation = privacySessionService.getGeneration();
    try {
      const status = await privacyCredentialService.getStatus();
      if (!this.active || requestId !== this.statusRequestId ||
        generation !== privacySessionService.getGeneration()) return;
      this.configured = status.configured;
      this.credentialKnown = true;
      this.credentialError = '';
    } catch (_) {
      if (!this.active || requestId !== this.statusRequestId ||
        generation !== privacySessionService.getGeneration()) return;
      this.credentialKnown = false;
      this.credentialError = '无法读取隐私凭据，请重试。原有隐私数据不会被删除或接管。';
      privacySessionService.lock();
    }
  }

  openImport(): void {
    router.pushUrl({
      url: 'pages/view/bookShelf/LocalImportPage',
      params: { bookType: 0, toPrivacy: true }
    });
  }

  async unlock(): Promise<void> {
    if (this.busy || privacySessionService.isAuthenticating()) return;
    const operationId = ++this.operationId;
    const generation = privacySessionService.getGeneration();
    this.busy = true;
    this.refreshBiometricReady();
    try {
      const success = await privacySessionService.unlock(this.getUIContext());
      if (!this.active || operationId !== this.operationId) return;
      if (success && generation === privacySessionService.getGeneration() && privacySessionService.isUnlocked()) {
        this.syncSession();
        await this.refreshCredentialStatus();
      } else if (this.visible) {
        promptAction.showToast({ message: privacySessionService.getLastFailureMessage() || '已取消隐私认证' });
      }
    } finally {
      if (this.active && operationId === this.operationId) this.busy = false;
    }
  }

  async loadBooks(): Promise<void> {
    if (!this.active || !this.visible || !privacySessionService.isUnlocked()) return;
    const generation = privacySessionService.getGeneration();
    const requestId = ++this.loadRequestId;
    try {
      const books = await privacyFolderService.list(this.searchKey);
      if (!this.active || !this.visible || requestId !== this.loadRequestId ||
        generation !== privacySessionService.getGeneration() || !privacySessionService.isUnlocked()) return;
      this.books = books;
      this.booksDataSource.clear();
      this.booksDataSource.pushAllData(books);
    } catch (_) {
      if (!this.active || !this.visible || requestId !== this.loadRequestId ||
        generation !== privacySessionService.getGeneration()) return;
      this.clearBooks();
      promptAction.showToast({ message: '无法读取隐私书籍，请稍后重试' });
    }
  }

  private unlockLabel(): string {
    if (this.busy) return '认证中…';
    if (!this.credentialKnown) return '读取凭据中…';
    return this.configured ? '输入密码解锁' : '设置六位隐私密码';
  }

  private lockedHint(): string {
    if (this.credentialKnown && !this.configured) return '设备未录入指纹或人脸，请设置六位隐私密码';
    return '解锁后查看你的私密书籍与文稿';
  }

  build() {
    if (this.embedded) {
      // 首页 Tab：与“书架”一致，顶部（含状态栏）为主题色渐变沉浸式背景
      Column() {
        Row() {
          Text('隐私文件夹')
            .fontSize(25)
            .fontWeight(700)
            .lineHeight(30)
            .fontColor(this.theme.mainColor)
        }
        .width('100%')
        .height(40)
        .margin({ top: this.topRectHeight === 0 ? 30 : this.topRectHeight, bottom: 12 })
        .padding({ left: 20, right: 20 })

        Column({ space: 16 }) {
          this.BodyContent()
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 16, bottom: 16 })
        .backgroundColor(Color.White)
      }
      .width('100%')
      .height('100%')
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: [[this.theme.mainColor, 0], [this.theme.secondColor, 0.2]]
      })
    } else {
      Column({ space: 16 }) {
        Header({ title: '隐私文件夹' }).width('100%').margin({ bottom: 4 })
        this.BodyContent()
      }.width('100%').height('100%').padding({ left: 20, right: 20, top: 0, bottom: 16 })
      .backgroundColor('#F6F7F9')
    }
  }

  @Builder
  BodyContent() {
      if (!this.unlocked && this.biometricReady && this.biometricType !== PrivacyBiometricType.NONE) {
        // 指纹/人脸：仅显示图标，点击重新拉起系统认证
        Column() {
          Image(this.biometricType === PrivacyBiometricType.FINGERPRINT ?
            $r('app.media.privacy_fingerprint') : $r('app.media.privacy_face'))
            .width(96).height(96)
            .opacity(this.busy ? 0.5 : 1)
            .accessibilityText(this.biometricType === PrivacyBiometricType.FINGERPRINT ? '指纹解锁' : '人脸解锁')
            .onClick((): void => { this.unlock(); })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (!this.unlocked) {
        Column({ space: 18 }) {
          Image($r('sys.symbol.lock')).width(56).height(56).fillColor(this.theme.mainColor)
          Text('私人阅读，独立保存').fontSize(20).fontWeight(FontWeight.Medium)
          Text(this.lockedHint())
            .fontSize(14).fontColor('#777777')
          Column({ space: 6 }) {
            Text('· 优先使用指纹 / 人脸，未录入时使用六位密码').fontSize(13).fontColor('#555555')
            Text('· 离开应用即自动上锁').fontSize(13).fontColor('#555555')
            Text('· 不出现在普通书架中').fontSize(13).fontColor('#555555')
          }.alignItems(HorizontalAlign.Start)
          if (!this.biometricReady && this.credentialKnown && !this.configured) {
            Text('如有旧隐私书，需先验证原指纹或人脸；不可用时保留数据，不能直接接管。')
              .fontSize(12).fontColor('#777777').textAlign(TextAlign.Center)
          }
          if (!this.biometricReady && this.credentialError.length > 0) {
            Text(this.credentialError).fontSize(13).fontColor('#B84A36').textAlign(TextAlign.Center)
            Button('重新读取凭据').onClick((): void => { this.refreshCredentialStatus(); })
          } else {
            Button(this.unlockLabel()).width('80%').backgroundColor(this.theme.mainColor)
              .enabled(!this.busy && (this.biometricReady || this.credentialKnown))
              .onClick((): void => { this.unlock(); })
          }
          Text('仅保护应用内副本，系统目录中的原文件不会被删除')
            .fontSize(12).fontColor('#999999').textAlign(TextAlign.Center)
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Search({ value: this.searchKey, placeholder: '搜索私密书籍' })
          .onChange((value: string): void => { this.searchKey = value; this.loadBooks(); })
        Row({ space: 18 }) {
          Text('+ 导入书籍').fontSize(14).fontColor(this.theme.mainColor)
            .onClick((): void => this.openImport())
          Blank()
          Image($r('app.media.view_list'))
            .width(22).height(22)
            .fillColor(this.EXHIBIT === '列表' ? 'rgba(0,0,0,0.85)' : 'rgba(0,0,0,0.35)')
            .onClick((): void => { this.EXHIBIT = '列表'; })
          Image($r('app.media.view_grid'))
            .width(22).height(22)
            .fillColor(this.EXHIBIT === '宫格' ? 'rgba(0,0,0,0.85)' : 'rgba(0,0,0,0.35)')
            .onClick((): void => { this.EXHIBIT = '宫格'; })
        }.width('100%')
        if (this.books.length === 0) {
          Column({ space: 12 }) {
            Text('暂无私密书籍').fontColor('#888888')
          }.layoutWeight(1).margin({ top: 40 })
        } else {
          List({ space: 10 }) {
            ForEach(this.books, (book: Books) => {
              ListItem() {
                if (this.EXHIBIT === '宫格') {
                  BookInfoGrids({ book: book })
                } else {
                  BookInfos({ book: book })
                }
              }
            })
          }
          .alignListItem(ListItemAlign.Center)
          .layoutWeight(1)
          .lanes(this.EXHIBIT === '宫格' ? 3 : 1)
          .scrollBar(BarState.Off)
          .margin({ left: -10, right: -10 })
        }
      }
  }
}
