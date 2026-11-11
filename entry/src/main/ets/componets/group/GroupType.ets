import BookGroupsDao from '../../database/dao/BookGroupsDao'
import { BookGroups } from '../../database/entities/BookGroups'
import BookType from '../head/BookType'
import groupTypePanel from './groupTypePanel'

// 系统分组 id 与 BookGroupsDao.initGroupData 的插入顺序一致
const ALL_GROUP_ID: number = 2
const UNGROUPED_GROUP_ID: number = 3

@Component
export default struct groupTypeComponent {
  @State globalPositionY: Length = 0
  @Link @Watch('changeRefresh')currentIndex: number
  @Link groupCoverShow:boolean
  @Link GROUP:string
  @State groupList:BookGroups[] = []
  @Link bookTypeNumber:number
  @Link showGroupStrip: boolean
  @StorageLink('BOOK_IS_BOOK_GROUPS_REFRESHING') @Watch('changeRefresh')BOOK_IS_BOOK_GROUPS_REFRESHING: number = 0
  aboutToAppear(): void {
    this.getGroupList()
  }
  changeRefresh(){
    this.getGroupList()
  }
  getGroupList(){
    BookGroupsDao.search({
      type:this.currentIndex
    }).then((val)=>{
      this.groupList = this.visibleGroups(val)
      this.showGroupStrip = this.groupList.length > 0
      // 当前选中的分组已不在栏里（例如旧版选中的“本地”“书单”），回到“全部”
      if (!this.groupList.some((item: BookGroups): boolean => item.groupId === this.bookTypeNumber)) {
        this.GROUP = '标签'
        this.bookTypeNumber = ALL_GROUP_ID
      }
    })
  }
  // 所有书都是本地书，“本地”等同“全部”；“分组”“书单”入口也不再单独展示。
  // 只有存在自建分组（含已隐藏的，保证还能从面板里恢复）时才显示：全部、未分组 + 可见的自建分组。
  visibleGroups(groups: BookGroups[]): BookGroups[] {
    if (!groups.some((item: BookGroups): boolean => !item.isSystem)) {
      return []
    }
    const userGroups = groups.filter((item: BookGroups): boolean => !item.isSystem && item.show)
    const systemGroups = groups.filter((item: BookGroups): boolean =>
      item.isSystem && (item.groupId === ALL_GROUP_ID || item.groupId === UNGROUPED_GROUP_ID))
    systemGroups.forEach((item: BookGroups) => {
      // 仅改内存副本，保证分组面板也显示这两个系统分组
      item.show = true
    })
    return systemGroups.concat(userGroups)
  }

  build() {
    if (this.groupCoverShow){
      Stack(){
        groupTypePanel({
          groupCoverShow:this.groupCoverShow,
          showGroupList:this.groupList,
          currentIndex:this.currentIndex
        })
          .zIndex(9999)
        Rect()
          .height('100%')
          .width('100%')
          .fill('rgba(0, 0, 0, 0.45)')
          .offset({y:20})

      }.alignContent(Alignment.TopStart)
    } else if (this.showGroupStrip) {
      Flex(
        {
          alignItems: ItemAlign.Center,
          justifyContent: FlexAlign.SpaceBetween
        }
      ) {
        Scroll() {
          Row({ space: 10 }) {
            ForEach(this.groupList,(item:BookGroups)=>{
              BookType({ title: item.groupName,
                index:item.groupId,
                bookTypeNumber:this.bookTypeNumber
              }).onClick(() => {
                this.GROUP = '标签'
                if (item.groupId){
                  this.bookTypeNumber = item.groupId
                }
              })
            })
          }
        }
        .scrollBar(BarState.Off)
        .scrollable(ScrollDirection.Horizontal)
        Row(){
          Image($r('app.media.more_search')).width(25).height(25)
        }.width(
          '10%'
        ).onClick(()=>{
          this.groupCoverShow = true
        })
      }.margin({ left: 15,bottom:10})
    }

  }
}