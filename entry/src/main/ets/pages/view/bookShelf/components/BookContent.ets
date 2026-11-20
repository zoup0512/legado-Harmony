import { ThemeStorageKey } from '../../../../common/constants/Theme'
import { ThemeItem } from '../../../../common/model/Theme'
import booksDao from '../../../../database/dao/BooksDao'
import { Books } from '../../../../database/entities/Books'
import BookInfoGrids from './BookInfoGrids'
import BookInfos from './BookInfos'
import bookCoverBackfill from '../../../../common/utils/BookCoverBackfill'
import ThemedEmptyImage from '../../../../componets/common/ThemedEmptyImage'
import { AdaptiveLayout } from '../../../../common/utils/AdaptiveLayout'

@Component
export default struct BookContent {
  @State bookList:Books[] = []
  @State contentWidth: number = 0

  private gridCoverWidth(): number {
    return this.contentWidth > 0 ?
      Math.max(1, Math.min(100, this.contentWidth / AdaptiveLayout.shelfColumns(this.contentWidth) - 16)) : 100
  }
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0

  async aboutToAppear(): Promise<void> {
    this.getBookCount()
    if (this.bookList.length === 0) {
      this.getBookList()
    }
  }

  async getBookCount(){
    this.bookCount =  await booksDao.getBookCount({
      type:this.currentIndex,
      bookGroup:this.bookTypeNumber,
    })
  }
  @State bookCount:number = 0
  @Prop EXHIBIT:string
  @Prop @Watch('changeBookType')searchValue:string
  @Prop @Watch('changeBookType')currentIndex: number
  @Prop @Watch('changeBookType')bookTypeNumber:number
  //更新数据累加刷新数据页面
  @StorageLink('BOOK_IS_BOOK_REFRESHING') @Watch("isRefresh")isBookRefreshing: number = 0
  async isRefresh(): Promise<void> {
    this.currentPage = 1
    if (this.isBookRefreshing >= 0) {
      await Promise.all([this.getBookCount(), this.getBookList()])
    }
  }

  // 老书导入时未提取封面：后台补齐后刷新列表
  async backfillCovers(): Promise<void> {
    const books = this.bookList
    if (await bookCoverBackfill.run(books) && books === this.bookList) {
      this.bookList = this.bookList.slice()
    }
  }

  changeBookType(){
    this.currentPage = 1
    if (this.bookTypeNumber !== 1 && this.bookTypeNumber !== 5) {
      if (this.bookCount === 0){
        this.getBookCount()
      }
      this.getBookList()
    }
  }

  async getBookList(){
    this.bookList =  await booksDao.searchPage({
      type:this.currentIndex,
      bookGroup:this.bookTypeNumber,
      order:this.searchValue
    }, this.currentPage)
    this.backfillCovers()
  }

  @State isLoading: boolean = false
  @State currentPage:number = 1
  // 主题颜色
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem
  async loadMoreBooks() {
    if (!this.isLoading) {
      this.isLoading = true;
      this.currentPage += 1;

      const moreBooks = await booksDao.searchPage({
        type:this.currentIndex,
        bookGroup:this.bookTypeNumber,
        order:this.searchValue,
      }, this.currentPage);
      if (moreBooks.length > 0) {
        this.bookList.push(...moreBooks);
        this.backfillCovers();
      }
      this.isLoading = false;
    }
  }
  scroller: Scroller = new Scroller()
  build() {
    if (this.isLoading) {
      Row(){
        LoadingProgress()
          .color(this.theme.mainColor)
          .width('50%')
        Text('加载中...')
      }
    } else if (this.bookList.length === 0){
      Column() {
        ThemedEmptyImage({ imageSize: 140 }).margin({ bottom: 16 })
        Text('书架暂无书籍')
          .fontSize(12)
          .fontColor('rgba(96, 96, 96, 0.6)')
          .fontWeight(500)
          .padding(5)
      }
      .margin({ top: 120 })
    } else {
      Column() {
        List({
          space:this.EXHIBIT === '宫格' ? 10 : 0,
          scroller:this.scroller
        }){
          ForEach(this.bookList, (item: Books,index:number) => {
            ListItem(){
              if (this.EXHIBIT === '宫格') {
                BookInfoGrids({
                  book:item,
                  coverWidth: this.gridCoverWidth()
                })
              } else {
                BookInfos({
                  book:item
                })
              }
            }
          })
        }
        .alignListItem(ListItemAlign.Center)
        .layoutWeight(1)
        .width(this.EXHIBIT === '宫格' || this.contentWidth <= 0 ? '100%' : AdaptiveLayout.contentWidth(this.contentWidth))
        .lanes(this.EXHIBIT === '宫格' ? AdaptiveLayout.shelfColumns(this.contentWidth) : 1)
        .divider(this.EXHIBIT === '宫格' ? null : { strokeWidth: 0.5, color: '#F0F0F0', startMargin: 90, endMargin: 16 })
        .scrollBar(BarState.Off)
        .onReachEnd(() => {
          if (this.bookList.length < this.bookCount) {
            this.loadMoreBooks()
          }
        })
        .margin({ bottom: 20 })
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .onAreaChange((_oldArea: Area, area: Area) => {
        this.contentWidth = Number(area.width)
      })
    }
  }
}