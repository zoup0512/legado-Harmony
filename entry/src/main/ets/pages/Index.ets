import Logger from '../common/utils/Logger';
import { showMessage } from '../componets/common/promptShow'
import ReadShow from '../componets/common/ReadShow'
import { NavItem } from '../componets/dataList/type'
import { updateAppData } from '../storage/appData'
import BookShelf from './view/BookShelf'
import MyCenter from './view/myCenter/MyCenter'
import { emitter } from '@kit.BasicServicesKit'
import { JSON } from '@kit.ArkTS'
import { image } from '@kit.ImageKit'
import { ThemeStorageKey } from '../common/constants/Theme'
import { ThemeItem } from '../common/model/Theme'
import { WindowAbility } from '../entryability/WindowAbility'
import BrightnessUtil from '../../common/utils/BrightnessUtil'

@Entry
@Component
struct Main {
  @State showReadShow: boolean = true
  @State currentTabIndex: number = 0
  @State isShow: boolean = true
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @StorageLink('topRectHeight') topRectHeight: number = 0
  @StorageProp('APP_INDEX_SCROLLABLE') APP_INDEX_SCROLLABLE: boolean = true
  tabController: TabsController = new TabsController()
  // 主题颜色
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem

  onPageShow(): void {
    if (AppStorage.get<boolean>('RETURN_TO_BOOKSHELF')) {
      AppStorage.setOrCreate('RETURN_TO_BOOKSHELF', false)
      this.currentTabIndex = 0
      this.tabController.changeIndex(0)
    }
    // 退出阅读页面后恢复系统亮度
    BrightnessUtil.setBrightness('default', -1)
    // 退出阅读页面后显示状态栏
    WindowAbility.getInstance().toggleWindowSystemBar(['status', 'navigation'], this.getUIContext().getHostContext());
    // initBookListData()
    setTimeout(() => {
      this.showReadShow = false
      this.isShow = false
    }, 5000)
  }

  screenShot() {
    // 切换回首页
    let index = this.currentTabIndex
    this.tabController.changeIndex(0)
    this.getUIContext().getComponentSnapshot().get('main', ((err: Error, pixmap: image.PixelMap) => {
      if (err) {
        Logger.error('Index.screenShot failed', Logger.errorSummary(err))
        return
      }
      AppStorage.setOrCreate('screen_shot', pixmap)
    }))
    // 恢复当前页
    this.tabController.changeIndex(index)
  }

  aboutToAppear(): void {
    // 退出阅读页面后显示状态栏
    WindowAbility.getInstance().toggleWindowSystemBar(['status', 'navigation'], this.getUIContext().getHostContext());
    // 注册监听截图事件 用于我的页面下主题设置预览
    emitter.on('screen_shot', () => {
      this.screenShot()
    })
  }

  @Builder
  TabBuilder(index = 0, name: string, icon_select: Resource, unselected: Resource) {
    Column() {
      Flex({
        direction: FlexDirection.Column,
        alignItems: ItemAlign.Center,
        justifyContent: FlexAlign.Center
      }) {
        Image(this.currentTabIndex === index ? icon_select : unselected).height(25)
          .draggable(false)
          .fillColor(this.currentTabIndex === index ? this.theme.mainColor : '#000000')
        Text(name).fontSize(11).margin(5).fontColor(this.currentTabIndex === index ? this.theme.mainColor : '#000000')
      }
    }.gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction((event: GestureEvent) => {
          updateAppData(!this.APP_INDEX_SCROLLABLE)
          showMessage(this.APP_INDEX_SCROLLABLE ? '标签栏锁已开启' : '标签栏已解锁')
        }))
    .width('100%')
    .margin({ top: 4 })
    .height("100%")
  }

  nav: NavItem[] = [
    new NavItem(0, $r("app.media.HOME_theme"), $r('app.media.HOME_line'), '书架'),
    new NavItem(1, $r('app.media.MINE_theme'), $r('app.media.MINE_line'), '我的')
  ]

  build() {
    Column() {
      Tabs({
        index: this.currentTabIndex,
        barPosition: BarPosition.End,
        controller: this.tabController
      }) {
        ForEach(this.nav, (item: NavItem) => {
          TabContent() {
            Column() {
              if (item.index === 0) {
                BookShelf()
              } else if (item.index === 1) {
                MyCenter()
              }
            }
          }.tabBar(
            this.TabBuilder(item.index, item.title, item.selectImg, item.unselected)
          )
        })
      }
      .scrollable(!this.APP_INDEX_SCROLLABLE)
      .padding({ bottom: this.bottomRectHeight })
      .onAnimationStart((index, targetIndex) => {
        this.currentTabIndex = targetIndex
      })

      if (this.showReadShow) {
        ReadShow({ showReadShow: this.showReadShow }).offset({ y: -150 - this.bottomRectHeight })
      }
    }
    .width("100%")
    .height("100%")
    .id('main')
  }
}