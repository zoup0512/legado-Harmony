import UIAbility from '@ohos.app.ability.UIAbility';
import BuildProfile from 'BuildProfile';
import Logger from '../common/utils/Logger';
import window from '@ohos.window';
import { AbilityConstant, Configuration, Want } from '@kit.AbilityKit';
import DbUtil from '../common/utils/DbUtil';
import DataBase from '../database'
import { loadWindowContentWhenReady } from './WindowContentStartup';
import { themeManager } from '../common/utils/ThemeManager';
import { AppUtil } from '@pura/harmony-utils';
import { WindowAbility } from './WindowAbility';
import { deviceInfo } from '@kit.BasicServicesKit';
import BrightnessUtil from '../../common/utils/BrightnessUtil';
import privacySessionService from '../privacy/PrivacySessionService';
import privacyCredentialService from '../privacy/PrivacyCredentialService';
import privacyForeground from '../privacy/PrivacyForeground';

export default class EntryAbility extends UIAbility {
  private windowStage: window.WindowStage | undefined;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    Logger.configureDebug(BuildProfile.DEBUG);
    privacyCredentialService.init(this.context);
    Logger.debug('Ability onCreate');
    AppUtil.init(this.context);
    WindowAbility.getInstance().initContext(this.context)
  }

  onDestroy() {
    WindowAbility.getInstance().releaseWindowStage();
    Logger.debug('Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    this.windowStage = windowStage;
    DbUtil.initDB(this.context).then(() => {
      DataBase.initAllTable()
    })
    WindowAbility.getInstance().setWindowStage(windowStage);
    AppStorage.setOrCreate('pathDir', this.context.filesDir);
    Logger.debug('Ability onWindowStageCreate');
    this.loadApplicationContent(windowStage);
  }

  private async loadApplicationContent(windowStage: window.WindowStage): Promise<void> {
    try {
      await loadWindowContentWhenReady(async (): Promise<void> => {
        const mainWindow = await windowStage.getMainWindow();
        if (this.windowStage !== windowStage) return;
        BrightnessUtil.initWindow(mainWindow);
        WindowAbility.getInstance().initWindow(mainWindow);
        try {
          await mainWindow.setWindowLayoutFullScreen(true);
          await mainWindow.setWindowSystemBarProperties({
            statusBarContentColor: this.context.config.colorMode ? '#000000' : '#FFFFFF'
          });
          if (deviceInfo.deviceType === 'tablet') {
            await mainWindow.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
          }
        } catch (error) {
          Logger.error('Window presentation setup failed', Logger.errorSummary(error));
        }
        if (this.windowStage === windowStage) WindowAbility.getInstance().refreshWindowMetrics();
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
    WindowAbility.getInstance().refreshWindowMetrics();
  }

  onWindowStageDestroy() {
    this.windowStage = undefined;
    WindowAbility.getInstance().releaseWindowStage();
    privacyForeground.leave();
    privacySessionService.lock();
    Logger.debug('Ability onWindowStageDestroy');
  }

  onForeground() {
    // Privacy sessions never survive a background transition.
    privacySessionService.lock();
    privacyForeground.enter();
    WindowAbility.getInstance().refreshWindowMetrics();
    Logger.debug('Ability onForeground');
  }

  onBackground() {
    privacyForeground.leave();
    privacySessionService.lock();
    Logger.debug('Ability onBackground');
  }
}
