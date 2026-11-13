/**
 * @author 2008
 * @datetime 2024/7/23 12:01
 * @className: BookBodyContent
 */
import groupTypeComponent from '../../../../componets/group/GroupType'
import IndexSearchType from '../../../../componets/head/IndexSearchType'
import BookContentRefresh from './BookContentRefresh'

@Component
export default struct BookBodyContent {
  @Prop index:number
  @Prop currentIndex: number = 0
  @Link EXHIBIT: string
  @Link GROUP: string
  @State searchValue: string = '最近阅读'
  @Link bookTypeNumber:number
  @State title: string = '最近阅读'
  @State groupCoverShow: boolean = false
  // 没有自建分组时不显示分组栏，列表也不再为它预留顶部空间
  @State showGroupStrip: boolean = false
  @State bookBodyIndex: number = 0
  tabsBookBodyController: TabsController = new TabsController();
  build() {
    Column() {
      Row() {
        IndexSearchType({ title: this.title, searchValue: this.searchValue })
        Blank()
        this.ExhibitBuilder()
      }
      .width('100%')
      .padding({ left: 15, right: 9, top: 9, bottom: 9 })

      Stack() {
        groupTypeComponent({
          bookTypeNumber:this.bookTypeNumber,
          currentIndex: this.currentIndex,
          groupCoverShow: this.groupCoverShow,
          GROUP: this.GROUP,
          showGroupStrip: this.showGroupStrip
        }).zIndex(999)
        Tabs({
          controller:this.tabsBookBodyController,
          index: this.bookBodyIndex
        }){
          TabContent(){
            BookContentRefresh({
              EXHIBIT: this.EXHIBIT,
              GROUP: this.GROUP,
              searchValue: this.searchValue,
              currentIndex: this.currentIndex,
              bookTypeNumber:this.bookTypeNumber,
              showGroupStrip: this.showGroupStrip
            })
          }
          .align(Alignment.Top)
        }
        .scrollable(false)
        .barWidth(0)
        .barHeight(0)
        .onChange((index) => {
          this.tabsBookBodyController.changeIndex(index)
          this.bookBodyIndex = index
        })
      }
      .layoutWeight(1)
      .alignContent(Alignment.Top)
    }
  }
  @Builder
  ExhibitBuilder() {
    Row({ space: 4 }) {
      Image($r('app.media.view_list'))
        .width(34).height(34).padding(6)
        .fillColor(this.EXHIBIT === '列表' ? 'rgba(0,0,0,0.85)' : 'rgba(0,0,0,0.35)')
        .accessibilityText('列表视图')
        .onClick(() => { this.EXHIBIT = '列表' })
      Image($r('app.media.view_grid'))
        .width(34).height(34).padding(6)
        .fillColor(this.EXHIBIT === '宫格' ? 'rgba(0,0,0,0.85)' : 'rgba(0,0,0,0.35)')
        .accessibilityText('宫格视图')
        .onClick(() => { this.EXHIBIT = '宫格' })
    }
  }
}