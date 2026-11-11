import { router } from '@kit.ArkUI'
import BookBodyContent from './components/BookBodyContent'
import { IconTitleVo } from '../../../componetsmodel/IconTitleVo'
import dialogTitleFuction from '../../../componets/common/dialogTitleFuction'

@Component
export default struct IndexShelf {
  // 书架只保留一种书籍类型（0 小说）；仍向下传递，供各 DAO 查询使用
  @State currentIndex: number = 0
  @State bookTypeNumber: number = 2
  @State EXHIBIT: string = '列表'
  @State @Watch('changeGroup') GROUP: string = '标签'
  private moreList: IconTitleVo[] = [
    new IconTitleVo($r('app.media.import_svg'), '书籍导入'),
    new IconTitleVo($r('app.media.batch_svg'), '批量管理'),
  ]
  changeGroup() {
    if (this.GROUP === '文件夹') {
      this.bookTypeNumber = 1
    } else {
      this.bookTypeNumber = 2
    }
  }

  @StorageLink('topRectHeight') topRectHeight: number = 0

  build() {
    Column() {
      Row() {
        Text('书架')
          .fontSize(24)
          .fontWeight(700)
          .fontColor('rgba(0,0,0,0.9)')
        Blank()
        Image($r('app.media.more')).width(24)
          .bindMenu(this.MenuBuilder())
      }
      .width('100%')
      .height(44)
      .margin({ top: this.topRectHeight === 0 ? 30 : this.topRectHeight })
      .padding({ left: 20, right: 20 })

      Column() {
        BookBodyContent({
          currentIndex: this.currentIndex,
          EXHIBIT: this.EXHIBIT,
          GROUP: this.GROUP,
          bookTypeNumber: this.bookTypeNumber
        })
      }
      .layoutWeight(1)
    }
    .height('100%')
    .backgroundColor(Color.White)
  }

  @Builder
  MenuBuilder() {
    Column() {
      ForEach(this.moreList, (item: IconTitleVo, index) => {
        dialogTitleFuction({
          title: item.title,
          icon: item.icon,
          isBorder: this.moreList.length !== index + 1
        })
          .onClick(() => {
            this.handleMoreAction(index)
          })
      })
    }
  }

  handleMoreAction(index: number) {
    switch (index) {
      case 0:
        router.pushUrl({
          url: 'pages/view/bookShelf/LocalImportPage',
          params: {
            bookType: this.currentIndex
          }
        })
        break
      case 1:
        router.pushUrl({
          url: 'pages/view/bookShelf/Manage/BookManagePage',
          params: {
            currentIndex: this.currentIndex,
            EXHIBIT: this.EXHIBIT,
            bookTypeNumber: this.bookTypeNumber
          }
        })
        break
    }
  }
}
