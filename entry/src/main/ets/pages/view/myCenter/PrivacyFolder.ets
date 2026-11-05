import { promptAction, router } from '@kit.ArkUI';
import { Books } from '../../../database/entities/Books';
import privacyFolderService from '../../../privacy/PrivacyFolderService';
import privacySessionService from '../../../privacy/PrivacySessionService';
import privacyCredentialService from '../../../privacy/PrivacyCredentialService';
import Header from '../../../componets/common/Header';
import BasicDataSource from '../../../common/LazyIDataSource/BasicDataSource';
import { ThemeStorageKey } from '../../../common/constants/Theme';
import { ThemeItem } from '../../../common/model/Theme';
import BookInfos from '../bookShelf/components/BookInfos';
import BookInfoGrids from '../bookShelf/components/BookInfoGrids';

@Entry
@Component
export default struct PrivacyFolder {
  @StorageLink(ThemeStorageKey.THEME) theme: ThemeItem = {
    mainColor: '#188bff', secondColor: '#e3f1ff', text: '蓝色'
  };
  @State unlocked: boolean = false;
  @State books: Books[] = [];
  @State searchKey: string = '';
  @State busy: boolean = false;
  @State credentialKnown: boolean = false;
  @State configured: boolean = false;
  @State biometricEnabled: boolean = false;
  @State credentialError: string = '';
  @State EXHIBIT: string = '列表';
  @Provide('booksDataSource') booksDataSource: BasicDataSource<Books> = new BasicDataSource<Books>();
  @StorageLink('BOOK_IS_BOOK_REFRESHING') @Watch('onShelfChanged') isBookRefreshing: number = 0;
  private unsubscribe: (() => void) | undefined;
  private active: boolean = false;
  private visible: boolean = false;
  private loadRequestId: number = 0;
  private statusRequestId: number = 0;
  private operationId: number = 0;
  private savedBiometricEnabled: boolean = false;

  onShelfChanged(): void {
    if (this.unlocked && this.visible) this.loadBooks();
  }

  aboutToAppear(): void {
    this.active = true;
    this.visible = true;
    this.unsubscribe?.();
    this.unsubscribe = privacySessionService.onStateChanged((locked: boolean): void => {
      if (locked) {
        this.clearLockedState();
      } else if (this.visible) {
        this.syncSession();
      }
    });
    this.syncSession();
    this.refreshCredentialStatus();
  }

  onPageShow(): void {
    this.visible = true;
    // Never start authentication here: router returns can precede the pending result.
    this.syncSession();
    if (!this.busy) this.refreshCredentialStatus();
  }

  onPageHide(): void {
    this.visible = false;
    this.clearBooks();
  }

  aboutToDisappear(): void {
    this.active = false;
    this.visible = false;
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
    this.biometricEnabled = false;
    this.savedBiometricEnabled = false;
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
      this.savedBiometricEnabled = status.biometricEnabled;
      this.biometricEnabled = status.biometricEnabled;
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

  private async changePin(): Promise<void> {
    if (this.busy || privacySessionService.isAuthenticating() || !privacySessionService.isUnlocked()) return;
    const operationId = ++this.operationId;
    const generation = privacySessionService.getGeneration();
    this.busy = true;
    try {
      const success = await privacySessionService.changePin(this.getUIContext());
      if (!this.active || operationId !== this.operationId || generation !== privacySessionService.getGeneration()) return;
      if (this.visible) {
        promptAction.showToast({ message: success ? '隐私密码已更新' :
          privacySessionService.getLastFailureMessage() || '未修改隐私密码' });
      }
      await this.refreshCredentialStatus();
    } finally {
      if (this.active && operationId === this.operationId) this.busy = false;
    }
  }

  private async setBiometricEnabled(enabled: boolean): Promise<void> {
    if (this.busy || privacySessionService.isAuthenticating() || !privacySessionService.isUnlocked()) {
      this.biometricEnabled = this.savedBiometricEnabled;
      return;
    }
    if (enabled === this.savedBiometricEnabled) return;
    const previous = this.savedBiometricEnabled;
    const operationId = ++this.operationId;
    const generation = privacySessionService.getGeneration();
    this.biometricEnabled = enabled;
    this.busy = true;
    try {
      const success = await privacySessionService.setBiometricEnabled(this.getUIContext(), enabled);
      if (!this.active || operationId !== this.operationId || generation !== privacySessionService.getGeneration()) return;
      // Failed/cancelled authentication must not leave an optimistic switch enabled.
      this.biometricEnabled = success ? enabled : previous;
      if (success) this.savedBiometricEnabled = enabled;
      if (this.visible) {
        promptAction.showToast({ message: success ? (enabled ? '已开启快捷生物认证' : '已关闭快捷生物认证') :
          privacySessionService.getLastFailureMessage() || '未更改生物认证设置' });
      }
      await this.refreshCredentialStatus();
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

  lock(): void {
    privacySessionService.lock();
  }

  private unlockLabel(): string {
    if (this.busy) return '认证中…';
    if (!this.credentialKnown) return '读取凭据中…';
    return this.configured ? '输入密码解锁' : '设置六位隐私密码';
  }

  build() {
    Column({ space: 16 }) {
      Header({ title: '隐私文件夹' }).width('100%').margin({ bottom: 4 })
      if (!this.unlocked) {
        Column({ space: 18 }) {
          Image($r('sys.symbol.lock')).width(56).height(56).fillColor(this.theme.mainColor)
          Text('私人阅读，独立保存').fontSize(20).fontWeight(FontWeight.Medium)
          Text(this.credentialKnown && !this.configured ? '首次使用请设置六位数字隐私密码' : '解锁后查看你的私密书籍与文稿')
            .fontSize(14).fontColor('#777777')
          Column({ space: 6 }) {
            Text('· 六位独立密码，指纹 / 人脸可选开启').fontSize(13).fontColor('#555555')
            Text('· 离开应用即自动上锁').fontSize(13).fontColor('#555555')
            Text('· 不出现在普通书架中').fontSize(13).fontColor('#555555')
          }.alignItems(HorizontalAlign.Start)
          if (this.credentialKnown && !this.configured) {
            Text('如有旧隐私书，需先验证原指纹或人脸；不可用时保留数据，不能直接接管。')
              .fontSize(12).fontColor('#777777').textAlign(TextAlign.Center)
          }
          if (this.credentialError.length > 0) {
            Text(this.credentialError).fontSize(13).fontColor('#B84A36').textAlign(TextAlign.Center)
            Button('重新读取凭据').onClick((): void => { this.refreshCredentialStatus(); })
          } else {
            Button(this.unlockLabel()).width('80%').backgroundColor(this.theme.mainColor)
              .enabled(!this.busy && this.credentialKnown).onClick((): void => { this.unlock(); })
          }
          Text('仅保护应用内副本，系统目录中的原文件不会被删除')
            .fontSize(12).fontColor('#999999').textAlign(TextAlign.Center)
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Row({ space: 12 }) {
          Button('修改密码').fontSize(13).enabled(!this.busy)
            .onClick((): void => { this.changePin(); })
          Blank()
          Button('立即上锁').fontSize(13).onClick((): void => this.lock())
        }.width('100%')
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text('快捷生物认证').fontSize(14)
            Text('开启需密码和系统认证，关闭也需密码').fontSize(11).fontColor('#777777')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.biometricEnabled })
            .enabled(!this.busy && this.credentialKnown)
            .selectedColor(this.theme.mainColor)
            .onChange((enabled: boolean): void => { this.setBiometricEnabled(enabled); })
        }.width('100%')
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
            Button('导入本地书籍').onClick((): void => this.openImport())
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
    }.width('100%').height('100%').padding({ left: 20, right: 20, top: 0, bottom: 16 })
      .backgroundColor('#F6F7F9')
  }
}
