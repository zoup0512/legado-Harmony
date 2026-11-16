import Logger from '../common/utils/Logger';
import { display, window } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { AdaptiveLayout } from '../common/utils/AdaptiveLayout';

export class WindowAbility {
  private static readonly INSTANCE: WindowAbility = new WindowAbility();
  private context: common.UIAbilityContext | null = null;
  private windowStage: window.WindowStage | null = null;
  private windowClass: window.Window | null = null;
  private sizeCallback: Callback<window.Size> | undefined;
  private avoidCallback: Callback<window.AvoidAreaOptions> | undefined;
  private sizeSubscribers: Map<number, () => void> = new Map();
  private nextSubscriberId: number = 0;

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

  initWindow(mainWindow: window.Window): void {
    this.disposeWindow();
    this.windowClass = mainWindow;
    this.refreshWindowMetrics();
    this.sizeCallback = (size: window.Size): void => {
      if (this.windowClass !== mainWindow) return;
      this.publishWindowSize(size.width, size.height);
      this.refreshAvoidArea();
      this.sizeSubscribers.forEach((callback: () => void): void => callback());
    };
    this.avoidCallback = (_data: window.AvoidAreaOptions): void => {
      if (this.windowClass === mainWindow) this.refreshAvoidArea();
    };
    mainWindow.on('windowSizeChange', this.sizeCallback);
    mainWindow.on('avoidAreaChange', this.avoidCallback);
  }

  private density(): number {
    const density = display.getDefaultDisplaySync().densityPixels;
    return density > 0 ? density : 1;
  }

  private publishWindowSize(width: number, height: number): void {
    const density = this.density();
    const widthVp = width / density;
    const heightVp = height / density;
    // Legacy ReaderKit dimensions are pixels; layout dimensions are explicitly vp.
    AppStorage.setOrCreate<number>('windowWidth', width);
    AppStorage.setOrCreate<number>('windowHeight', height);
    AppStorage.setOrCreate<number>('windowWidthVp', widthVp);
    AppStorage.setOrCreate<number>('windowHeightVp', heightVp);
    AppStorage.setOrCreate<number>('WindowWidth', widthVp);
    AppStorage.setOrCreate<number>('WindowHeight', heightVp);
    AppStorage.setOrCreate<string>('currentBreakpoint', AdaptiveLayout.breakpoint(widthVp));
  }

  refreshWindowMetrics(): void {
    if (!this.windowClass) return;
    try {
      const rect = this.windowClass.getWindowProperties().windowRect;
      this.publishWindowSize(rect.width, rect.height);
      this.refreshAvoidArea();
    } catch (error) {
      Logger.error('Window metrics update failed', Logger.errorSummary(error));
    }
  }

  private refreshAvoidArea(): void {
    if (!this.windowClass) return;
    try {
      const system = this.windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navigation = this.windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const density = this.density();
      const top = Math.max(system.topRect.height, navigation.topRect.height) / density;
      const bottom = Math.max(system.bottomRect.height, navigation.bottomRect.height) / density;
      AppStorage.setOrCreate<number>('topRectHeight', top);
      AppStorage.setOrCreate<number>('bottomRectHeight', bottom);
      AppStorage.setOrCreate<number>('leftRectWidth', Math.max(system.leftRect.width, navigation.leftRect.width) / density);
      AppStorage.setOrCreate<number>('rightRectWidth', Math.max(system.rightRect.width, navigation.rightRect.width) / density);
      AppStorage.setOrCreate<number>('statusBarHeight', top);
      AppStorage.setOrCreate<number>('navigationAiBarHeight', bottom);
      AppStorage.setOrCreate<number>('Paf.TopHeight', top);
      AppStorage.setOrCreate<number>('NavigationBarHeight', bottom);
      AppStorage.setOrCreate<number>('stateHeight', top);
      AppStorage.setOrCreate<number>('avoidHeight', (top + bottom) * density);
    } catch (error) {
      Logger.error('Window avoid area update failed', Logger.errorSummary(error));
    }
  }

  onWindowSizeChange(callback: () => void): () => void {
    const id = this.nextSubscriberId++;
    this.sizeSubscribers.set(id, callback);
    return (): void => { this.sizeSubscribers.delete(id); };
  }

  disposeWindow(): void {
    if (this.windowClass) {
      try {
        if (this.sizeCallback) this.windowClass.off('windowSizeChange', this.sizeCallback);
        if (this.avoidCallback) this.windowClass.off('avoidAreaChange', this.avoidCallback);
      } catch (error) {
        Logger.error('Window listener cleanup failed', Logger.errorSummary(error));
      }
    }
    this.sizeCallback = undefined;
    this.avoidCallback = undefined;
    this.windowClass = null;
    this.sizeSubscribers.clear();
  }

  releaseWindowStage(): void {
    this.disposeWindow();
    this.windowStage = null;
  }

  async setWindowLayoutFullScreen(isFullScreen: boolean): Promise<void> {
    if (deviceInfo.deviceType === '2in1' || !this.context) return;
    const wnd = await window.getLastWindow(this.context);
    await wnd.setWindowLayoutFullScreen(isFullScreen);
  }

  setOrientation(windowStage: window.WindowStage, orientation: window.Orientation): void {
    windowStage.getMainWindow().then((win) => {
      return win.setPreferredOrientation(orientation);
    }).catch((error: Error) => {
      Logger.error('WindowAbility.setOrientation failed', Logger.errorSummary(error));
    });
  }

  setStatusBarContentColor(color: string, windowContext: Context | undefined): void {
    window.getLastWindow(windowContext, (err, windowClass) => {
      if (err.code) return;
      windowClass.setWindowSystemBarProperties({ statusBarContentColor: color }).catch((error: Error) => {
        Logger.error('WindowAbility.setStatusBarContentColor failed', Logger.errorSummary(error));
      });
    });
  }

  toggleWindowSystemBar(names: Array<'status' | 'navigation'>, windowContext: Context | undefined): void {
    window.getLastWindow(windowContext, (err, data) => {
      try {
        if (err.code) return;
        AppStorage.setOrCreate('Grid.tabPro.enableAvoidAreaListener', names.length > 0);
        data.setWindowSystemBarEnable(names).catch((error: Error) => {
          Logger.error('WindowAbility.toggleWindowSystemBar failed', Logger.errorSummary(error));
        });
      } catch (error) {
        Logger.error('WindowAbility.toggleWindowSystemBar failed', Logger.errorSummary(error));
      }
    });
  }
}
