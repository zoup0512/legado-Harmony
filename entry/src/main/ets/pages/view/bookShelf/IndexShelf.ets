import BookMark from '../../../componets/head/BookMark'
import { router } from '@kit.ArkUI'
import BookBodyContent from './components/BookBodyContent'
import { ThemeItem } from '../../../common/model/Theme'
import { ThemeStorageKey } from '../../../common/constants/Theme'
import { IconTitleVo } from '../../../componetsmodel/IconTitleVo'
import dialogTitleFuction from '../../../componets/common/dialogTitleFuction'

@Component
export default struct IndexShelf {
  @State currentIndex: number = 0
  titleArray: Array<string> = ['小说', '漫画', '有声书']
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
  @StorageProp('APP_INDEX_SCROLLABLE') APP_INDEX_SCROLLABLE: boolean = false
  // 主题颜色
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem
  tabsController: TabsController = new TabsController();
  private scrollController: Scroller = new Scroller();

  build() {
    Column() {
      Flex({
        justifyContent: FlexAlign.SpaceBetween,
        alignItems: ItemAlign.End
      }) {
        Row() {
          List({ scroller: this.scrollController }) {
            ListItem() {
              BookMark({ title: '小说', index: 0, currentIndex: this.currentIndex }).onClick(() => {
                this.currentIndex = 0
                this.tabsController.changeIndex(0)
                console.log(this.currentIndex + '')
              })
            }

            ListItem() {
              BookMark({ title: '漫画', index: 1, currentIndex: this.currentIndex }).onClick(() => {
                this.currentIndex = 1
                this.tabsController.changeIndex(1)
                console.log(this.currentIndex + '')
              })
            }

            ListItem() {
              BookMark({ title: '有声书', index: 2, currentIndex: this.currentIndex }).onClick(() => {
                this.currentIndex = 2
                this.tabsController.changeIndex(2)
                console.log(this.currentIndex + '')
              })
            }
          }
          // .align(Alignment.TopStart)
          .height(40)
          .scrollBar(BarState.Off)
          .listDirection(Axis.Horizontal)
        }

        Row({ space: 16 }) {
          // 隐私文件夹入口：书架常驻露出
          Image($r('app.media.privacy_lock')).width(24)
            .accessibilityText('隐私文件夹')
            .onClick(() => {
              router.pushUrl({
                url: 'pages/view/myCenter/PrivacyFolder'
              });
            })
          Image($r('app.media.more')).width(24)
            .bindMenu(this.MenuBuilder())
        }.margin({ bottom: 12 })
      }
      .padding({ top: this.topRectHeight === 0 ? 30 : this.topRectHeight, left: 20, right: 20 })

      Tabs({
        barPosition: BarPosition.Start,
        controller: this.tabsController,
        index: this.currentIndex
      }) {
        ForEach(this.titleArray, () => {
          TabContent() {
            Column() {
              BookBodyContent({
                currentIndex: this.currentIndex,
                EXHIBIT: this.EXHIBIT,
                GROUP: this.GROUP,
                bookTypeNumber: this.bookTypeNumber
              })
            }
          }
        })
      }
      .layoutWeight(1)
      .barWidth(0)
      .barHeight(0)
      .onChange((index) => {
        this.tabsController.changeIndex(index)
        console.log('index:' + index)
        this.currentIndex = index
      })
      .backgroundColor(Color.White)
      .scrollable(this.APP_INDEX_SCROLLABLE)
    }
    .height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom, // 渐变方向
      colors: [[this.theme.mainColor, 0], [this.theme.secondColor, 0.2]] // 数组末尾元素占比小于1时满足重复着色效果
    })
    .borderRadius({ bottomRight: 5, bottomLeft: 5 })
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
