import Logger from '../common/utils/Logger';
import { window } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';


export class WindowAbility {
  private static readonly INSTANCE: WindowAbility = new WindowAbility();
  private context: common.UIAbilityContext | null = null;
  private windowStage: window.WindowStage | null = null;
  private windowClass: window.Window | null = null;
  private windowType: window.WindowStatusType | null = null;

  private constructor() {
  }

  public static getInstance(): WindowAbility {
    return WindowAbility.INSTANCE;
  }

  initContext(context: common.UIAbilityContext) {
    this.context = context;
  }

  setWindowStage(windowStage: window.WindowStage): void {
    this.windowStage = windowStage;
  }

  getWindowStage(): window.WindowStage | null {
    return this.windowStage;
  }

  /**
   * 初始化避开区域参数
   * @param - mainWindow windows
   * @returns void
   */
  async initAvoidArea(mainWindow: window.Window): Promise<void> {
    // Initialize default values
    AppStorage.setOrCreate<number>('statusBarHeight', 36);
    AppStorage.setOrCreate<number>('navigationAiBarHeight', 28);
    const defaultDisplay = display.getDefaultDisplaySync();
    let scaledDensity = (defaultDisplay.scaledDensity > 0) ? defaultDisplay.scaledDensity : 1;
    const systemArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    const navArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
    if (systemArea) {
      const statusBarHeight = systemArea.topRect.height / scaledDensity;
      AppStorage.setOrCreate<number>('statusBarHeight', statusBarHeight);

      if (deviceInfo.deviceType === 'tablet') {
        AppStorage.setOrCreate<number>("Paf.TopHeight", 56);
      } else if (deviceInfo.deviceType === '2in1') {
        AppStorage.setOrCreate<number>("Paf.TopHeight", 0);
      } else {
        AppStorage.setOrCreate<number>("Paf.TopHeight", systemArea.topRect.height);
      }
    }
    if (navArea) {
      const navigationAiBarHeight = navArea.bottomRect.height / scaledDensity;
      AppStorage.setOrCreate<number>('navigationAiBarHeight', navigationAiBarHeight);

      if (deviceInfo.deviceType === 'tablet') {
        AppStorage.setOrCreate<number>("NavigationBarHeight", navArea.bottomRect.height);
      } else if (deviceInfo.deviceType === '2in1') {
        AppStorage.setOrCreate<number>("NavigationBarHeight", 0);
      } else {
        AppStorage.setOrCreate<number>("NavigationBarHeight", navArea.bottomRect.height);
      }
    }
  }

  initWindowSize(): void {
    window.getLastWindow(this.context, (err, windowClass) => {
      if (err.code) {
        Logger.error('WindowAbility.initWindowSize failed', Logger.errorSummary(err));
        return;
      }
      let windowProperty = windowClass.getWindowProperties();
      AppStorage.setOrCreate<number>('windowWidth', windowProperty.windowRect.width);
      AppStorage.setOrCreate<number>('windowHeight', windowProperty.windowRect.height);
      this.windowClass = windowClass;
      this.onWindowSizeChange();
      // this.onWindowStatusChange();
      this.onWindowRectChange();
    });
  }

  private onWindowStatusChange(): void {
    if (!this.windowClass) {
      return;
    }
    this.windowClass.on('windowStatusChange', (type: window.WindowStatusType) => {
      this.windowType = type;
      this.initAvoidArea(this.windowClass!);
      if (type === window.WindowStatusType.FLOATING) {
        AppStorage.setOrCreate<number>("NavigationBarHeight", 0);
      }
    })
  }

  private onWindowRectChange(): void {
    if (!this.windowClass) {
      return;
    }
    this.windowClass.on('windowRectChange', (option) => {
      if (this.windowType === window.WindowStatusType.SPLIT_SCREEN ||
        this.windowType === window.WindowStatusType.FULL_SCREEN) {
        // 重新获取导航栏高度
        this.setNavigationBar();
      }
    })
  }

  private setNavigationBar(): void {
    if (!this.windowClass) {
      return;
    }
    const nav: window.AvoidArea = this.windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
    if (nav) {
      AppStorage.setOrCreate<number>("NavigationBarHeight", nav.bottomRect.height);
    }
  }

  async setWindowLayoutFullScreen(isFullScreen: boolean): Promise<void> {
    if (deviceInfo.deviceType === '2in1') {
      return;
    }
    window.getLastWindow(this.context).then(async (wnd: window.Window) => {
      await wnd.setWindowLayoutFullScreen(isFullScreen);
    });
  }

  onWindowSizeChange(callback?: () => void): void {
    if (!this.windowClass) {
      return;
    }
    try {
      this.windowClass.on('windowSizeChange', (size) => {
        AppStorage.setOrCreate<number>('windowWidth', size.width);
        AppStorage.setOrCreate<number>('windowHeight', size.height);
        callback && callback();
      });
    } catch (exception) {
      Logger.error('WindowAbility.onWindowSizeChange failed', Logger.errorSummary(exception));
    }
  }

  setOrientation(windowStage: window.WindowStage, orientation: window.Orientation): void {
    windowStage.getMainWindow().then((win) => {
      win.setPreferredOrientation(orientation).then((data) => {
      }).catch((err: Error) => {
        Logger.error('WindowAbility.setOrientation failed', Logger.errorSummary(err));
      });
    }).catch((err: Error) => {
      Logger.error('WindowAbility.setOrientation failed', Logger.errorSummary(err));
    });
  }

  /**
   * 设置状态栏文字/图标颜色（沉浸式页面根据背景深浅切换黑/白）。
   */
  setStatusBarContentColor(color: string, windowContext: Context | undefined): void {
    window.getLastWindow(windowContext, (err, windowClass) => {
      if (err.code) {
        return;
      }
      windowClass.setWindowSystemBarProperties({ statusBarContentColor: color }).catch((error: Error) => {
        Logger.error('WindowAbility.setStatusBarContentColor failed', Logger.errorSummary(error));
      });
    });
  }

  /**
   * 将系统栏设置为可见。
   *
   * @param { Array<'status' | 'navigation'> } names - 系统栏的设置
   * @param context - 当前应用程序上下文
   */
  toggleWindowSystemBar(names: Array<'status' | 'navigation'>, windowContext: Context | undefined): void {
    window.getLastWindow(windowContext, (err, data) => {
      try {
        if (err.code) {
          return;
        }
        let windowClass = data;
        if (names.length === 0) {
          AppStorage.setOrCreate('Grid.tabPro.enableAvoidAreaListener', false);
        }
        windowClass.setWindowSystemBarEnable(names).then(() => {
        }, (error: Error) => {
          if (error) {
            Logger.error('WindowAbility.toggleWindowSystemBar failed', Logger.errorSummary(error));
          }
        })
        if (names.length > 0) {
          AppStorage.setOrCreate('Grid.tabPro.enableAvoidAreaListener', true);
        }
      } catch (exception) {
        Logger.error('WindowAbility.toggleWindowSystemBar failed', Logger.errorSummary(exception));
      }
    });
  }
}