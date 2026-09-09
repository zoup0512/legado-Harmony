import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { Books } from '../../../database/entities/Books';
import privacyFolderService from '../../../privacy/PrivacyFolderService';
import privacySessionService from '../../../privacy/PrivacySessionService';
import Header from '../../../componets/common/Header';

@Entry
@Component
export default struct PrivacyFolder {
  @State unlocked: boolean = false;
  @State books: Books[] = [];
  @State searchKey: string = '';
  @State busy: boolean = false;
  @StorageLink('BOOK_IS_BOOK_REFRESHING') isBookRefreshing: number = 0;

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
          List({ space: 10 }) {
            ForEach(this.books, (book: Books) => {
              ListItem() {
                Row({ space: 12 }) {
                  Column() { Text(book.bookName).fontSize(16); Text(book.author || '本地书籍').fontSize(12).fontColor('#888888'); }
                    .alignItems(HorizontalAlign.Start).layoutWeight(1);
                  Text('移出').fontColor('#3478F6').onClick(async () => {
                    if (this.busy) return;
                    this.busy = true;
                    try {
                      const moved = await privacyFolderService.moveOut(book);
                      if (moved) {
                        this.isBookRefreshing++;
                        await this.loadBooks();
                      }
                      promptAction.showToast({ message: moved ? '已移出至未分组书架' : '移出失败，请重试' });
                    } finally {
                      this.busy = false;
                    }
                  });
                  Text('删除').fontColor('#E64545').onClick(async () => {
                    await privacyFolderService.remove(book); await this.loadBooks();
                  });
                }.padding(12).backgroundColor('#FFFFFF').borderRadius(10)
                  .onClick(() => router.pushUrl({ url: 'pages/view/Reader/ReaderPage3', params: { bookData: book, clickBookCatalogId: 0 } }));
              }
            })
          }.layoutWeight(1)
        }
      }
    }.width('100%').height('100%').padding({ left: 20, right: 20, top: 0, bottom: 16 })
      .backgroundColor('#F6F7F9');
  }
}
