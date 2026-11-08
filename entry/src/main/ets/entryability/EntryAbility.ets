import UIAbility from '@ohos.app.ability.UIAbility';
import BuildProfile from 'BuildProfile';
import Logger from '../common/utils/Logger';
import window from '@ohos.window';
import { BusinessError } from '@kit.BasicServicesKit';
import { AbilityConstant, Configuration, Want } from '@kit.AbilityKit';
import display from '@ohos.display';
import DbUtil from '../common/utils/DbUtil';
import DataBase from '../database'
import { loadWindowContentWhenReady } from './WindowContentStartup';
import { themeManager, ThemeManager } from '../common/utils/ThemeManager';
import { AppUtil } from '@pura/harmony-utils';
import { WindowAbility } from './WindowAbility';
import { deviceInfo } from '@kit.BasicServicesKit';
import BrightnessUtil from '../../common/utils/BrightnessUtil';
import privacySessionService from '../privacy/PrivacySessionService';
import privacyCredentialService from '../privacy/PrivacyCredentialService';
import privacyForeground from '../privacy/PrivacyForeground';

export default class EntryAbility extends UIAbility {
  private curBp: string = ''
  private windowStage: window.WindowStage | undefined;

  // 根据当前窗口尺寸更新断点
  private updateBreakpoint(windowWidth: number): void {
    // 将长度的单位由px换算为vp
    let windowWidthVp = windowWidth / display.getDefaultDisplaySync().densityPixels
    let newBp: string = ''
    if (windowWidthVp < 320) {
      newBp = 'xs'
    } else if (windowWidthVp < 600) {
      newBp = 'sm'
    } else if (windowWidthVp < 840) {
      newBp = 'md'
    } else {
      newBp = 'lg'
    }
    if (this.curBp !== newBp) {
      this.curBp = newBp
      // 使用状态变量记录当前断点值
      AppStorage.setOrCreate('currentBreakpoint', this.curBp)
    }
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    Logger.configureDebug(BuildProfile.DEBUG);
    privacyCredentialService.init(this.context);
    Logger.debug('Ability onCreate');
    AppUtil.init(this.context);
    WindowAbility.getInstance().initContext(this.context)
  }

  onDestroy() {
    Logger.debug('Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    this.windowStage = windowStage;
    // 初始化db数据库/创建相关数据表
    DbUtil.initDB(this.context).then(() => {
      DataBase.initAllTable()
    })
    WindowAbility.getInstance().setWindowStage(windowStage);
    this.initWindowProcess(windowStage);
    // 获取本地文件存储路径
    const pathDir = this.context.filesDir;
    AppStorage.setOrCreate('pathDir', pathDir);
    // Main window is created, set main page for this ability
    Logger.debug('Ability onWindowStageCreate');
    // 全屏
    windowStage.getMainWindow((err, windowClass) => {
      if (err.code) {
        Logger.error('Failed to load application content', String(err.code));
        return
      }
      // 初始化屏幕亮度设置
      BrightnessUtil.initWindow(windowClass);

      //全屏
      windowClass.setWindowLayoutFullScreen(true)
        .then(() => {
          Logger.debug('Window layout set to full-screen mode');
        })
        .catch((err: BusinessError) => {
          Logger.error('Failed to set full-screen layout', String(err.code));
        });
      //获取上下遮挡区域
      let type = window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR; //导航栏
      let avoidArea = windowClass.getWindowAvoidArea(type);
      let bottomRectHeight = avoidArea.bottomRect.height;
      AppStorage.setOrCreate('bottomRectHeight', px2vp(bottomRectHeight));

      // 2. 获取导航栏避让遮挡的区域
      type = window.AvoidAreaType.TYPE_SYSTEM; // 状态栏
      avoidArea = windowClass.getWindowAvoidArea(type);
      let topRectHeight = avoidArea.topRect.height;
      AppStorage.setOrCreate('topRectHeight', px2vp(topRectHeight));

      //手机屏幕高度和宽度
      let defaultDisplay = display.getDefaultDisplaySync()
      let WindowHeight = defaultDisplay.height
      let WindowWidth = defaultDisplay.width


      AppStorage.setOrCreate('WindowHeight', px2vp(WindowHeight));
      AppStorage.setOrCreate('WindowWidth', px2vp(WindowWidth));

      let avoidAreaSys = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      let navi = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      let total = avoidAreaSys.topRect.height + navi.bottomRect.height;
      AppStorage.setOrCreate('avoidHeight', total);
      AppStorage.setOrCreate('stateHeight', px2vp(avoidAreaSys.topRect.height));
      // 注册监听函数，动态获取避让区域数据
      windowClass.on('avoidAreaChange', (data) => {
        if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
          let topRectHeight = data.area.topRect.height;
          AppStorage.setOrCreate('topRectHeight', px2vp(topRectHeight));
        } else if (data.type == window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          let bottomRectHeight = data.area.bottomRect.height;
          AppStorage.setOrCreate('bottomRectHeight', px2vp(bottomRectHeight));
        }
      });
    })

    this.loadApplicationContent(windowStage);
  }

  private async loadApplicationContent(windowStage: window.WindowStage): Promise<void> {
    try {
      await loadWindowContentWhenReady(async (): Promise<void> => {
        await windowStage.getMainWindow();
      }, (): boolean => this.windowStage === windowStage, (): void => {
        windowStage.loadContent('pages/welcomePage', (err) => {
          if (this.windowStage !== windowStage) return;
          if (err.code) {
            Logger.error('Failed to load application content', String(err.code));
            return;
          }
          themeManager.init();
          Logger.debug('Application content loaded');
        });
      });
    } catch (error) {
      if (this.windowStage !== windowStage) return;
      Logger.error('Application window startup failed', Logger.errorSummary(error));
    }
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    AppStorage.setOrCreate('colorMode', newConfig.colorMode);
  }

  initWindowProcess(windowStage: window.WindowStage): void {
    windowStage.getMainWindow((err, windowClass: window.Window) => {
      WindowAbility.getInstance().initAvoidArea(windowClass);
      let systemBarProperties: window.SystemBarProperties = {
        statusBarContentColor: this.context.config.colorMode ? '#000000' : '#FFFFFF'
      };
      windowClass.setWindowSystemBarProperties(systemBarProperties);
    });
    WindowAbility.getInstance().setWindowLayoutFullScreen(true);
    if (deviceInfo.deviceType === 'tablet') {
      WindowAbility.getInstance().setOrientation(windowStage, window.Orientation.AUTO_ROTATION_RESTRICTED);
    }
    WindowAbility.getInstance().initWindowSize();
  }

  onWindowStageDestroy() {
    this.windowStage = undefined;
    privacyForeground.leave();
    privacySessionService.lock();
    // Main window is destroyed, release UI related resources
    Logger.debug('Ability onWindowStageDestroy');
  }

  onForeground() {
    // Privacy sessions never survive a background transition.
    privacySessionService.lock();
    privacyForeground.enter();
    Logger.debug('Ability onForeground');
  }

  onBackground() {
    privacyForeground.leave();
    privacySessionService.lock();
    Logger.debug('Ability onBackground');
  }
}
