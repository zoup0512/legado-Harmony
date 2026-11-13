/**
 * @author 2008
 * @datetime 2024/7/23 12:01
 * @className: BookBodyContent
 */
import groupTypeComponent from '../../../../componets/group/GroupType'
import IndexSearchType from '../../../../componets/head/IndexSearchType'
import { router } from '@kit.ArkUI'
import BookContentRefresh from './BookContentRefresh'

@Component
export default struct BookBodyContent {
  @Prop index:number
  @Prop currentIndex: number = 0
  @State EXHIBIT_NAMES: string[] = ['列表', '宫格']
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
      Flex(
        {
          alignContent: FlexAlign.Center,
          alignItems: ItemAlign.Center,
          justifyContent: FlexAlign.SpaceBetween
        }
      ) {
        Scroll() {
          Flex({
            alignItems: ItemAlign.Center,
            justifyContent: FlexAlign.SpaceBetween
          }) {
            Row({ space: 15 }) {
              IndexSearchType({ title: this.title, searchValue: this.searchValue })
              this.ExhibitBuilder()
              Text('管理')
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/view/bookShelf/Manage/BookManagePage',
                    params: {
                      currentIndex: this.currentIndex,
                      EXHIBIT: this.EXHIBIT,
                      bookTypeNumber: this.bookTypeNumber
                    }
                  })
                })
                .fontColor('rgba(0,0,0,0.5)')
                .fontSize(15)
                .fontWeight(400)
            }
          }
        }
        .scrollBar(BarState.Off)
        .scrollable(ScrollDirection.Horizontal)
      }
      .padding(15)

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
    Row({ space: 10 }) {
      ForEach(this.EXHIBIT_NAMES, (item: string) => {
        if (item !== this.EXHIBIT) {
          IndexSearchType({ title: item, searchValue: this.searchValue })
            .onClick(() => {
              this.EXHIBIT = item
            })
          Divider()
            .vertical(true)
            .height(15)
            .color('#989797')
            .opacity(0.5)
            .strokeWidth(1)
        }
      })
    }
  }
}