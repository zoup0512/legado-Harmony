import { router } from '@kit.ArkUI'
import BookBodyContent from './components/BookBodyContent'
import { IconTitleVo } from '../../../componetsmodel/IconTitleVo'
import dialogTitleFuction from '../../../componets/common/dialogTitleFuction'
import { ThemeItem } from '../../../common/model/Theme'
import { ThemeStorageKey } from '../../../common/constants/Theme'

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
  // 主题颜色：顶部（含状态栏）为主题色渐变沉浸式背景
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem

  build() {
    Column() {
      Row() {
        Text('书架')
          .fontSize(25)
          .fontWeight(700)
          .lineHeight(30)
          .fontColor(this.theme.mainColor)
        Blank()
        Image($r('app.media.more')).width(24)
          .bindMenu(this.MenuBuilder())
      }
      .width('100%')
      .height(40)
      .alignItems(VerticalAlign.Center)
      .margin({ top: this.topRectHeight === 0 ? 30 : this.topRectHeight, bottom: 12 })
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
      .backgroundColor(Color.White)
    }
    .height('100%')
    // 沉浸式主题：从状态栏开始由主色渐变到浅色，内容区为白底
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [[this.theme.mainColor, 0], [this.theme.secondColor, 0.2]]
    })
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
