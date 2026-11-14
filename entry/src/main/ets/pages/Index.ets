import Logger from '../common/utils/Logger';
import { NavItem } from '../componets/dataList/type'
import BookShelf from './view/BookShelf'
import PrivacyFolderView from './view/myCenter/PrivacyFolderView'
import MyCenter from './view/myCenter/MyCenter'
import { emitter } from '@kit.BasicServicesKit'
import { image } from '@kit.ImageKit'
import { ThemeStorageKey } from '../common/constants/Theme'
import { ThemeItem } from '../common/model/Theme'
import { WindowAbility } from '../entryability/WindowAbility'
import { statusBarContentColorFor } from '../common/utils/ThemeManager'
import BrightnessUtil from '../../common/utils/BrightnessUtil'

const SHELF_TAB: number = 0
const PRIVACY_TAB: number = 1
const MINE_TAB: number = 2

@Entry
@Component
struct Main {
  @State currentTabIndex: number = 0
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @StorageLink('topRectHeight') topRectHeight: number = 0
  tabController: TabsController = new TabsController()
  // 主题颜色
  @StorageProp(ThemeStorageKey.THEME) @Watch('applyStatusBarColor') theme: ThemeItem = {} as ThemeItem
  // 首页是否在前台；隐私 Tab 只有在首页可见且选中时才加载私密书籍
  @State pageVisible: boolean = true
  // 每次主动切到隐私 Tab 时递增，触发一次指纹/人脸自动解锁
  @State privacyEnterSeq: number = 0

  onPageHide(): void {
    this.pageVisible = false
    // 其他页面都是浅色背景，离开首页时恢复黑色状态栏文字
    WindowAbility.getInstance().setStatusBarContentColor('#000000', this.getUIContext().getHostContext())
  }

  // 首页顶部是主题色沉浸式背景，状态栏文字随主题深浅切换黑/白
  applyStatusBarColor() {
    if (!this.pageVisible) return
    WindowAbility.getInstance().setStatusBarContentColor(statusBarContentColorFor(this.theme.mainColor),
      this.getUIContext().getHostContext())
  }

  switchTab(targetIndex: number) {
    if (targetIndex === this.currentTabIndex) return
    if (targetIndex === PRIVACY_TAB) this.privacyEnterSeq++
    this.currentTabIndex = targetIndex
  }

  onPageShow(): void {
    this.pageVisible = true
    if (AppStorage.get<boolean>('RETURN_TO_BOOKSHELF')) {
      AppStorage.setOrCreate('RETURN_TO_BOOKSHELF', false)
      this.currentTabIndex = 0
      this.tabController.changeIndex(0)
    }
    // 退出阅读页面后恢复系统亮度
    BrightnessUtil.setBrightness('default', -1)
    // 退出阅读页面后显示状态栏
    WindowAbility.getInstance().toggleWindowSystemBar(['status', 'navigation'], this.getUIContext().getHostContext());
    this.applyStatusBarColor()
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
    if (index === PRIVACY_TAB) {
      // 隐私入口用圆形底突出显示：未选中为浅色底 + 主题色锁，选中为主题色底 + 白色锁
      Column() {
        Row() {
          Image(icon_select).width(18).height(18)
            .draggable(false)
            .fillColor(this.currentTabIndex === index ? Color.White : this.theme.mainColor)
        }
        .width(34)
        .height(34)
        .borderRadius(17)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.currentTabIndex === index ? this.theme.mainColor : this.theme.secondColor)

        Text(name).fontSize(11).margin({ top: 3 })
          .fontColor(this.currentTabIndex === index ? this.theme.mainColor : '#000000')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .accessibilityText('隐私文件夹')
    } else {
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
      }
      .width('100%')
      .margin({ top: 4 })
      .height("100%")
    }
  }

  nav: NavItem[] = [
    new NavItem(SHELF_TAB, $r("app.media.HOME_theme"), $r('app.media.HOME_line'), '书架'),
    new NavItem(PRIVACY_TAB, $r('app.media.privacy_lock'), $r('app.media.privacy_lock'), '隐私'),
    new NavItem(MINE_TAB, $r('app.media.MINE_theme'), $r('app.media.MINE_line'), '我的')
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
              if (item.index === SHELF_TAB) {
                BookShelf()
              } else if (item.index === PRIVACY_TAB) {
                PrivacyFolderView({
                  visible: this.pageVisible && this.currentTabIndex === PRIVACY_TAB,
                  enterSeq: this.privacyEnterSeq,
                  embedded: true
                })
              } else if (item.index === MINE_TAB) {
                MyCenter({
                  visible: this.pageVisible && this.currentTabIndex === MINE_TAB
                })
              }
            }
          }.tabBar(
            this.TabBuilder(item.index, item.title, item.selectImg, item.unselected)
          )
        })
      }
      // 不允许左右滑动切换，避免误滑进隐私页
      .scrollable(false)
      // 内容区与底部导航之间的分隔线
      .divider({ strokeWidth: 0.5, color: 'rgba(0, 0, 0, 0.12)' })
      .barBackgroundColor(Color.White)
      .padding({ bottom: this.bottomRectHeight })
      .onAnimationStart((index, targetIndex) => {
        this.switchTab(targetIndex)
      })
      .onChange((index: number) => {
        this.switchTab(index)
      })
    }
    .width("100%")
    .height("100%")
    .id('main')
  }
}