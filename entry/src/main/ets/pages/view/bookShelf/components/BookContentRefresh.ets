/**
 * @author 2008
 * @datetime 2024/7/23 12:18
 * @className: BookContentRefresh
 */
import { showMessage } from '../../../../componets/common/promptShow'
import RefreshComponent from '../../../../componets/common/RefreshComponent'
import BookFolder from '../BookFolder'
import WorksBookLists from '../Shelf/WorksBookLists'
import BookContent from './BookContent'

@Component
export default struct BookContentRefresh {
  @State @Watch('changeRefreshing')isRefreshing: boolean = false
  @StorageLink('BOOK_IS_BOOK_REFRESHING') isBookRefreshing: number = 0
  @StorageLink('BOOK_IS_BOOK_GROUPS_REFRESHING') isGroupRefreshing: number = 0
  @StorageLink('BOOK_IS_BOOK_WORKS_BOOK_LIST') isWorksBookListRefreshing: number = 0
  @State counter: number = 0
  @State RefreshingTitle: string = '松开刷新'
  @Prop currentIndex: number = 0
  @Link EXHIBIT: string
  @Link GROUP: string
  @Prop searchValue: string
  @Link bookTypeNumber:number
  @Prop showGroupStrip: boolean = true
  @State checkGroup:Record<number, boolean> = {}
  changeRefreshing(){
    if (this.isRefreshing) {
      switch (this.bookTypeNumber){
        case 1:
          this.isGroupRefreshing++
          break;
        case 5:
          this.isWorksBookListRefreshing++
          break;
        default:
          this.isBookRefreshing++
          break
      }
    }
  }
  build() {
    Refresh({ refreshing: $$this.isRefreshing, builder: this.refreshComponent }) {
      if (this.bookTypeNumber !== 5 && this.bookTypeNumber !== 1) {
        BookContent({
          currentIndex:this.currentIndex,
          bookTypeNumber:this.bookTypeNumber,
          EXHIBIT: this.EXHIBIT,
          searchValue: this.searchValue
        })
      } else {
        Scroll() {
          Column() {
            if (this.bookTypeNumber === 5) {
              WorksBookLists({
                checkGroup: this.checkGroup,
                EXHIBIT: this.EXHIBIT,
                currentIndex:this.currentIndex,
                isShowCheck:false
              })
            } else {
              BookFolder({
                EXHIBIT: this.EXHIBIT,
                currentIndex:this.currentIndex
              })
            }
          }
          .padding({ left: 10, right: 10, bottom: 30 })
        }
        .scrollBar(BarState.Off)
      }
    }
    .height('100%')
    .margin({ top: this.showGroupStrip ? 30 : 0 })
    .onStateChange((refreshStatus: RefreshStatus) => {
      if (refreshStatus === 1 || refreshStatus === 2) {
        this.RefreshingTitle = '松开刷新'
      } else {
        this.RefreshingTitle = '刷新中...'
      }
    })
    .onRefreshing(() => {
      setTimeout(() => {
        this.counter++
        this.isRefreshing = false
      }, 1000)
      showMessage('刷新成功')
    })
  }
  @Builder
  refreshComponent() {
    RefreshComponent({
      RefreshingTitle: this.RefreshingTitle,
    })
  }
}