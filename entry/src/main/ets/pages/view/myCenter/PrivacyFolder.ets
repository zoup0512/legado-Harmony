import { promptAction } from '@kit.ArkUI';
import { Books } from '../../../database/entities/Books';
import privacyFolderService from '../../../privacy/PrivacyFolderService';
import privacySessionService from '../../../privacy/PrivacySessionService';
import Header from '../../../componets/common/Header';
import BasicDataSource from '../../../common/LazyIDataSource/BasicDataSource';
import BookInfos from '../bookShelf/components/BookInfos';
import BookInfoGrids from '../bookShelf/components/BookInfoGrids';

@Entry
@Component
export default struct PrivacyFolder {
  @State unlocked: boolean = false;
  @State books: Books[] = [];
  @State searchKey: string = '';
  @State busy: boolean = false;
  // 与主页书架一致的展示模式：列表 / 宫格
  @State EXHIBIT: string = '列表';
  @State EXHIBIT_NAMES: string[] = ['列表', '宫格'];
  // BookInfos/BookInfoGrids 的长按弹窗(BookInfoDialogs)依赖祖先提供该数据源
  @Provide('booksDataSource') booksDataSource: BasicDataSource<Books> = new BasicDataSource<Books>();
  // 长按弹窗内删除/移出隐私后累加该计数，隐私页同步重载列表
  @StorageLink('BOOK_IS_BOOK_REFRESHING') @Watch('onShelfChanged') isBookRefreshing: number = 0;

  onShelfChanged() {
    if (this.unlocked) {
      this.loadBooks();
    }
  }

  async aboutToAppear() {
    this.unlocked = privacySessionService.isUnlocked();
    if (this.unlocked) await this.loadBooks();
  }

  async unlock() {
    if (this.busy || privacySessionService.isAuthenticating()) return;
    this.busy = true;
    try {
      const success = await privacySessionService.unlock();
      if (success) {
        this.unlocked = true;
        await this.loadBooks();
      } else {
        promptAction.showToast({ message: privacySessionService.getLastFailureMessage() || '认证失败，请重试' });
      }
    } finally {
      this.busy = false;
    }
  }

  async loadBooks() {
    this.books = await privacyFolderService.list(this.searchKey);
  }

  lock() {
    privacySessionService.lock();
    this.unlocked = false;
    this.books = [];
  }

  build() {
    Column({ space: 16 }) {
      Header({ title: '隐私文件夹' })
      .width('100%')
      .margin({ bottom: 4 });
      if (!this.unlocked) {
        Column({ space: 18 }) {
          Text('🔒').fontSize(56);
          Text('私人阅读，独立保存').fontSize(20).fontWeight(FontWeight.Medium);
          Text('解锁后查看你的私密书籍与文稿').fontSize(14).fontColor('#777777');
          Button(this.busy ? '认证中…' : '解锁').width('70%').enabled(!this.busy).onClick(() => this.unlock());
          Text('仅保护应用内副本，系统目录中的原文件不会被删除')
            .fontSize(12).fontColor('#999999').textAlign(TextAlign.Center);
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center);
      } else {
        Search({ value: this.searchKey, placeholder: '搜索私密书籍' })
          .onChange(async (value: string) => { this.searchKey = value; await this.loadBooks(); });
        if (this.books.length === 0) {
          Text('暂无私密书籍').fontColor('#888888').layoutWeight(1).margin({ top: 60 });
        } else {
          // 列表/宫格切换，样式与主页书架一致：仅显示另一个模式入口
          Row() {
            ForEach(this.EXHIBIT_NAMES, (item: string) => {
              if (item !== this.EXHIBIT) {
                Text(item)
                  .fontSize(15)
                  .fontWeight(400)
                  .fontColor('rgba(0,0,0,0.5)')
                  .onClick(() => {
                    this.EXHIBIT = item
                  })
              }
            })
          }
          .width('100%')

          // 复用主页书架的书籍条目与布局（含封面角标、长按操作弹窗）
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
      .backgroundColor('#F6F7F9');
  }
}
