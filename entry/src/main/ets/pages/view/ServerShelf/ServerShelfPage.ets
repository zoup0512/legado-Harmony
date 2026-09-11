/**
 * 服务器书架：连接 reader-dev 服务器，管理网页端上传书籍的本地缓存
 *
 * 首次进入配置服务器地址 + accessToken（格式 用户名:token，Web 端登录后获取），
 * 保存后同步书架；书籍下载到设备后由本地 ReaderKit 阅读，刷新时检查远端更新。
 */
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ThemeItem } from '../../../common/model/Theme';
import { ThemeStorageKey } from '../../../common/constants/Theme';
import { showMessage } from '../../../componets/common/promptShow';
import ServerApi, { ServerBook, ServerConfig } from '../../../common/utils/ServerApi';
import BooksDao from '../../../database/dao/BooksDao';
import { Books } from '../../../database/entities/Books';

@Entry
@Component
struct ServerShelfPage {
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem
  @StorageLink('topRectHeight') topRectHeight: number = 0
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @State books: ServerBook[] = []
  @State loading: boolean = false
  @State editing: boolean = false
  @State serverUrl: string = ''
  @State token: string = ''
  @State testing: boolean = false
  @StorageLink('BOOK_IS_BOOK_REFRESHING') isBookRefreshing: number = 0

  aboutToAppear() {
    const config = ServerApi.getConfig();
    if (config.baseUrl.length > 0 && config.token.length > 0) {
      this.serverUrl = config.baseUrl;
      this.token = config.token;
      this.loadShelf();
    } else {
      this.editing = true;
    }
  }

  async loadShelf() {
    this.loading = true;
    try {
      this.books = await ServerApi.getBookshelf(true);
      // 先完成元数据/缓存状态同步，再通知主书架重新查询
      await ServerApi.syncToShelf(this.books);
      this.isBookRefreshing++;
    } catch (e) {
      showMessage('获取书架失败：' + (e instanceof Error ? e.message : '网络错误'));
    } finally {
      this.loading = false;
    }
  }

  private async localBook(book: ServerBook): Promise<Books> {
    const rows = await BooksDao.getServerBookByUrl(book.bookUrl);
    if (rows.length > 0) {
      return rows[0];
    }
    throw new Error('本地书架中没有对应书籍');
  }

  async openBook(book: ServerBook) {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const local = await this.localBook(book);
      const hasCache = ServerApi.hasLocalCache(local);
      const hasUpdate = await ServerApi.refreshLocalStatus(local);
      if (hasCache && hasUpdate) {
        AlertDialog.show({
          title: '发现内容更新',
          message: '服务器上的小说文件已更新，是否下载最新版？不更新也可以继续阅读本地缓存。',
          autoCancel: true,
          primaryButton: { value: '继续阅读', action: () => {
            router.pushUrl({ url: 'pages/view/Reader/ReaderPage3', params: { bookData: local } });
          } },
          secondaryButton: { value: '下载更新', action: () => {
            this.downloadAndRead(context, local, book);
          } }
        });
        return;
      }
      if (hasCache && !hasUpdate) {
        router.pushUrl({
          url: 'pages/view/Reader/ReaderPage3',
          params: { bookData: local }
        });
        return;
      }
      await this.downloadAndRead(context, local, book);
    } catch (e) {
      showMessage('下载失败：' + (e instanceof Error ? e.message : '网络错误'));
    }
  }

  private async downloadAndRead(context: common.UIAbilityContext, local: Books, book: ServerBook) {
    this.loading = true;
    try {
      const downloaded = await ServerApi.ensureLocalBook(context, local);
      this.isBookRefreshing++;
      showMessage('下载完成，开始阅读');
      router.pushUrl({
        url: 'pages/view/Reader/ReaderPage3',
        params: { bookData: downloaded }
      });
    } catch (e) {
      showMessage('下载失败：' + (e instanceof Error ? e.message : '网络错误'));
    } finally {
      this.loading = false;
    }
  }

  // 保存前先试连：getBookshelf 通了才落配置
  async saveAndConnect() {
    if (this.serverUrl.trim().length === 0 || !this.serverUrl.trim().startsWith('http')) {
      showMessage('请输入正确的服务器地址（http://IP:端口）');
      return;
    }
    if (!this.token.trim().includes(':')) {
      showMessage('accessToken 格式应为 用户名:token');
      return;
    }
    this.testing = true;
    try {
      // 先试连，成功才落盘
      await ServerApi.getBookshelfAt(this.serverUrl, this.token);
      ServerApi.saveConfig(this.serverUrl, this.token);
      this.editing = false;
      showMessage('连接成功');
      this.loadShelf();
    } catch (e) {
      showMessage('连接失败：' + (e instanceof Error ? e.message : '网络错误'));
    } finally {
      this.testing = false;
    }
  }

  @Builder
  headerBar() {
    Row({ space: 12 }) {
      Image($r('app.media.ic_public_return_left'))
        .width(24)
        .onClick(() => {
          router.back();
        })
      Text('服务器书架')
        .fontSize(18)
        .fontWeight(600)
        .fontColor('#FFFFFF')
        .layoutWeight(1)
      if (!this.editing) {
        Image($r('app.media.refresh'))
          .width(22)
          .onClick(() => {
            this.loadShelf();
          })
        Image($r('app.media.my_center_set_icon'))
          .width(22)
          .onClick(() => {
            this.editing = true;
          })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
  }

  @Builder
  configForm() {
    Column({ space: 16 }) {
      Text('连接 reader-dev 服务器')
        .fontSize(18)
        .fontWeight(600)
        .fontColor('#182231')
      Text('在服务器 Web 端注册并登录后，从登录响应/浏览器 localStorage 中获取 accessToken（格式：用户名:token）')
        .fontSize(12)
        .fontColor('rgba(0,0,0,0.45)')
        .lineHeight(18)

      Column({ space: 8 }) {
        Text('服务器地址').fontSize(14).fontColor('#182231')
        TextInput({ text: this.serverUrl, placeholder: 'http://124.220.35.87:8180' })
          .height(46)
          .fontSize(14)
          .borderRadius(10)
          .backgroundColor('#F2F3F5')
          .onChange((value: string) => {
            this.serverUrl = value;
          })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Column({ space: 8 }) {
        Text('accessToken').fontSize(14).fontColor('#182231')
        TextInput({ text: this.token, placeholder: '用户名:token' })
          .height(46)
          .fontSize(14)
          .borderRadius(10)
          .backgroundColor('#F2F3F5')
          .onChange((value: string) => {
            this.token = value;
          })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Button(this.testing ? '连接中…' : '测试并保存')
        .width('100%')
        .height(44)
        .fontSize(16)
        .backgroundColor(this.theme.mainColor)
        .onClick(() => {
          this.saveAndConnect();
        })

      if (ServerApi.hasConfig() && !this.testing) {
        Text('取消')
          .fontSize(14)
          .fontColor('rgba(0,0,0,0.45)')
          .onClick(() => {
            this.editing = false;
          })
      }
    }
    .padding(20)
    .borderRadius(12)
    .backgroundColor(Color.White)
    .margin(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  bookCard(book: ServerBook) {
    Row({ space: 12 }) {
      if (book.coverUrl && book.coverUrl.length > 0) {
        Image(book.coverUrl)
          .width(72)
          .height(96)
          .borderRadius(6)
          .alt($r('app.media.icon'))
          .autoResize(true)
          .objectFit(ImageFit.Cover)
      } else {
        Text(book.name.length > 0 ? book.name.substring(0, 1) : '书')
          .width(72)
          .height(96)
          .borderRadius(6)
          .fontSize(28)
          .fontColor('#FFFFFF')
          .backgroundColor(this.theme.secondColor)
          .textAlign(TextAlign.Center)
      }
      Column({ space: 6 }) {
        Text(book.name)
          .fontSize(16)
          .fontWeight(600)
          .fontColor('#182231')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(book.author && book.author.length > 0 ? book.author : '佚名')
          .fontSize(13)
          .fontColor('rgba(0,0,0,0.45)')
        Text(book.downloaded
          ? (book.updateAvailable ? '有更新，点击重新下载' : '已下载，可离线阅读')
          : '未下载，点击下载到本地')
          .fontSize(12)
          .fontColor(book.updateAvailable ? '#D97706' : this.theme.mainColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Column() {
          Text(book.durChapterTitle && book.durChapterTitle.length > 0
            ? `已读：${book.durChapterTitle}` : '尚未阅读')
            .fontSize(12)
            .fontColor('rgba(0,0,0,0.45)')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor(Color.White)
    .onClick(() => {
      this.openBook(book);
    })
  }

  build() {
    Column() {
      Column() {
        this.headerBar()
      }
      .padding({ top: this.topRectHeight === 0 ? 30 : this.topRectHeight })
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: [[this.theme.mainColor, 0], [this.theme.secondColor, 0.2]]
      })

      Stack() {
        if (this.editing) {
          Scroll() {
            this.configForm()
          }
          .layoutWeight(1)
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
        } else if (this.loading) {
          Column({ space: 12 }) {
            LoadingProgress().width(40).height(40).color(this.theme.mainColor)
            Text('加载中…').fontSize(13).fontColor('rgba(0,0,0,0.45)')
          }
          .justifyContent(FlexAlign.Center)
          .height('100%')
        } else if (this.books.length === 0) {
          Column({ space: 10 }) {
            Text('书架还是空的').fontSize(15).fontColor('rgba(0,0,0,0.45)')
            Text('在服务器 Web 端「书仓/上传」导入 txt 小说后，这里会同步显示')
              .fontSize(12)
              .fontColor('rgba(0,0,0,0.35)')
          }
          .justifyContent(FlexAlign.Center)
          .height('100%')
        } else {
          Scroll() {
            Column({ space: 12 }) {
              ForEach(this.books, (book: ServerBook) => {
                this.bookCard(book)
              }, (book: ServerBook) => book.bookUrl)
            }
            .padding(16)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .layoutWeight(1)
      .padding({ bottom: this.bottomRectHeight })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F7')
  }
}
