/**
 * 服务器在线阅读器：按章拉取 reader-dev 服务器正文（getBookToc/getBookContent），
 * 渲染复用 TxtContentHandler（Canvas 分页 + 横滑翻页）。
 *
 * 章节内容按需拉取并缓存在内存；进度存本地 preferences 并尽力同步到服务器
 * （saveBookProgress，失败静默）。
 */
import { router } from '@kit.ArkUI';
import { ThemeItem } from '../../../common/model/Theme';
import { ThemeStorageKey } from '../../../common/constants/Theme';
import { showMessage } from '../../../componets/common/promptShow';
import ServerApi, { ServerBook, ServerChapter } from '../../../common/utils/ServerApi';
import bookDataPreferences from '../../../common/utils/DataPreferencesUtils';
import { chaptersItem } from '../../../componets/dataList/ReaderChaptersItem';
import { TxtContentHandler } from '../../../componets/Reader/TxtContentHandler';

interface ReaderParams {
  book: ServerBook
}

@Entry
@Component
struct ServerReaderPage {
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem
  @StorageLink('topRectHeight') topRectHeight: number = 0
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  book: ServerBook = new ServerBook()
  toc: ServerChapter[] = []
  // 正文内存缓存：index → content（避免重复拉取）
  contentCache: Map<number, string> = new Map()
  @State chapters: chaptersItem[] = []
  @State CurrentChapters: number = 0
  @State CurrentFontSize: number = 20
  @State LineHeight: number = 1.8
  @State loading: boolean = true
  @State errorMsg: string = ''
  @State showCatalog: boolean = false
  @State loadFailedIndex: number = -1

  aboutToAppear() {
    const params = router.getParams() as ReaderParams;
    if (params && params.book) {
      this.book = params.book;
    }
    this.initBook();
  }

  progressKey(): string {
    return 'server_shelf_progress_' + this.book.bookUrl;
  }

  async initBook() {
    this.loading = true;
    this.errorMsg = '';
    try {
      this.toc = await ServerApi.getBookToc(this.book);
      if (this.toc.length === 0) {
        this.errorMsg = '未获取到章节目录';
        this.loading = false;
        return;
      }
      this.chapters = this.toc.map((c: ServerChapter, i: number) =>
        new chaptersItem(i, c.title, '', ''));
      // 起始章：本地进度 > 服务器进度 > 0
      let start = this.book.durChapterIndex;
      const saved = bookDataPreferences.shared.get(this.progressKey());
      if (typeof saved === 'number' && saved >= 0 && saved < this.chapters.length) {
        start = saved;
      }
      if (start < 0 || start >= this.chapters.length) {
        start = 0;
      }
      await this.gotoChapter(start);
    } catch (e) {
      this.errorMsg = e instanceof Error ? e.message : '加载失败';
    } finally {
      this.loading = false;
    }
  }

  async gotoChapter(index: number) {
    if (index < 0 || index >= this.chapters.length) {
      return;
    }
    this.loading = true;
    this.errorMsg = '';
    this.loadFailedIndex = -1;
    try {
      let content = this.contentCache.get(index);
      if (!content || content.length === 0) {
        content = await ServerApi.getBookContent(this.toc[index]);
        this.contentCache.set(index, content);
      }
      const next = this.chapters.slice();
      next[index] = new chaptersItem(index, this.toc[index].title, '', content);
      this.chapters = next;
      this.CurrentChapters = index;
      this.saveProgress(index);
      this.prefetch(index + 1);
    } catch (e) {
      this.errorMsg = e instanceof Error ? e.message : '获取正文失败';
      this.loadFailedIndex = index;
    } finally {
      this.loading = false;
    }
  }

  // 静默预取下一章，翻章零等待
  async prefetch(index: number) {
    if (index < 0 || index >= this.toc.length || this.contentCache.has(index)) {
      return;
    }
    try {
      const content = await ServerApi.getBookContent(this.toc[index]);
      this.contentCache.set(index, content);
    } catch (e) {
      // 预取失败无所谓，翻章时再正式拉取
    }
  }

  saveProgress(index: number) {
    bookDataPreferences.shared.set(this.progressKey(), index);
    ServerApi.saveBookProgress(this.book, index, this.toc[index].title);
  }

  prevChapter() {
    if (this.CurrentChapters > 0) {
      this.gotoChapter(this.CurrentChapters - 1);
    } else {
      showMessage('已经是第一章了');
    }
  }

  nextChapter() {
    if (this.CurrentChapters < this.chapters.length - 1) {
      this.gotoChapter(this.CurrentChapters + 1);
    } else {
      showMessage('已经是最后一章了');
    }
  }

  @Builder
  topBar() {
    Row({ space: 10 }) {
      Image($r('app.media.ic_public_return_left'))
        .width(24)
        .onClick(() => {
          router.back();
        })
      Column({ space: 2 }) {
        Text(this.book.name)
          .fontSize(15)
          .fontWeight(600)
          .fontColor('#182231')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.chapters[this.CurrentChapters]?.title ?? '')
          .fontSize(12)
          .fontColor('rgba(0,0,0,0.45)')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .backgroundColor(Color.White)
  }

  @Builder
  bottomBar() {
    Row({ space: 12 }) {
      Button('上一章')
        .fontSize(13)
        .height(36)
        .layoutWeight(1)
        .backgroundColor('#F2F3F5')
        .fontColor('#182231')
        .onClick(() => {
          this.prevChapter();
        })
      Button('目录')
        .fontSize(13)
        .height(36)
        .layoutWeight(1)
        .backgroundColor('#F2F3F5')
        .fontColor('#182231')
        .onClick(() => {
          this.showCatalog = true;
        })
      Button('下一章')
        .fontSize(13)
        .height(36)
        .layoutWeight(1)
        .backgroundColor(this.theme.mainColor)
        .fontColor('#FFFFFF')
        .onClick(() => {
          this.nextChapter();
        })
    }
    Row({ space: 16 }) {
      Row({ space: 8 }) {
        Button('A-')
          .fontSize(12)
          .height(30)
          .backgroundColor('#F2F3F5')
          .fontColor('#182231')
          .onClick(() => {
            if (this.CurrentFontSize > 12) {
              this.CurrentFontSize -= 2;
            }
          })
        Button('A+')
          .fontSize(12)
          .height(30)
          .backgroundColor('#F2F3F5')
          .fontColor('#182231')
          .onClick(() => {
            if (this.CurrentFontSize < 36) {
              this.CurrentFontSize += 2;
            }
          })
      }
      .alignItems(VerticalAlign.Center)

      Text(`${this.CurrentChapters + 1}/${this.chapters.length} 章`)
        .fontSize(12)
        .fontColor('rgba(0,0,0,0.45)')
        .layoutWeight(1)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6 })
  }

  @Builder
  catalogSheet() {
    Column() {
      Text(`目录（共 ${this.chapters.length} 章）`)
        .fontSize(15)
        .fontWeight(600)
        .fontColor('#182231')
        .padding({ top: 16, bottom: 10 })
      Divider()
      List({ space: 0 }) {
        ForEach(this.toc, (chapter: ServerChapter) => {
          ListItem() {
            Text(chapter.title.length > 0 ? chapter.title : `第${chapter.index + 1}章`)
              .fontSize(14)
              .fontColor(chapter.index === this.CurrentChapters
                ? this.theme.mainColor : '#182231')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .padding({ left: 20, right: 20, top: 12, bottom: 12 })
          }
          .onClick(() => {
            this.showCatalog = false;
            this.gotoChapter(chapter.index);
          })
        }, (chapter: ServerChapter) => chapter.url)
      }
      .layoutWeight(1)
      .divider({
        strokeWidth: 1,
        color: 'rgba(0,0,0,0.06)',
        startMargin: 20,
        endMargin: 20
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  @Builder
  centerOverlay() {
    Column({ space: 12 }) {
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(this.theme.mainColor)
        Text('加载中…').fontSize(13).fontColor('rgba(0,0,0,0.45)')
      } else if (this.errorMsg.length > 0) {
        Text(this.errorMsg).fontSize(13).fontColor('rgba(0,0,0,0.6)')
        Button('重试')
          .fontSize(13)
          .height(34)
          .backgroundColor(this.theme.mainColor)
          .onClick(() => {
            if (this.loadFailedIndex >= 0) {
              this.gotoChapter(this.loadFailedIndex);
            } else {
              this.initBook();
            }
          })
      }
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      this.topBar()
      Stack() {
        TxtContentHandler({
          txtFile: this.chapters,
          CurrentChapters: this.CurrentChapters,
          CurrentFontSize: this.CurrentFontSize,
          LineHeight: this.LineHeight
        })
        // 左右窄条：点击切章（中间留给横滑翻页手势）
        Row() {
          Column()
            .width('9%')
            .height('100%')
            .onClick(() => {
              this.prevChapter();
            })
          Column()
            .layoutWeight(1)
            .height('100%')
          Column()
            .width('9%')
            .height('100%')
            .onClick(() => {
              this.nextChapter();
            })
        }
        .width('100%')
        .height('100%')
        if (this.loading || this.errorMsg.length > 0) {
          this.centerOverlay()
        }
      }
      .layoutWeight(1)
      this.bottomBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .bindSheet($$this.showCatalog, this.catalogSheet(), {
      height: 500,
      showClose: false,
      dragBar: true,
      blurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
      onDisappear: () => {
        this.showCatalog = false;
      }
    })
  }
}
