import Logger from '../../ets/common/utils/Logger';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';


/**
 * @author miniscale
 * @date 2025/5/6
 * @version 1.0
 * @description: 屏幕亮度工具类，提供设置屏幕亮度的方法
 */
export default class BrightnessUtil {
  private static windowClass: window.Window | undefined = undefined;
  private static brightnessMap: Map<string, number> =
    new Map([]);

  /**
   * init windowClass
   *
   * @param windowClass Window object
   */
  public static initWindow(windowClass: window.Window) {
    BrightnessUtil.windowClass = windowClass;
  }

  /**
   * 获取屏幕亮度
   * @param brightnessMapName 窗口名称，用作亮度映射的键
   * @returns brightness 亮度值，范围为0到1，其中0表示最暗，1表示最亮，-1为跟随系统亮度
   */
  public static getBrightness(brightnessMapName: string): number {
    try {
      const brightness = BrightnessUtil.brightnessMap.get(brightnessMapName)
      return brightness ?? -1
    } catch (err) {
      Logger.error('BrightnessUtil.getBrightness failed', Logger.errorSummary(err));
      return -1
    }
  }

  /**
   * 设置屏幕亮度
   * @param brightnessMapName 窗口名称，用作亮度映射的键
   * @param brightness 亮度值，范围为0到1，其中0表示最暗，1表示最亮，-1为跟随系统亮度
   */
  public static setBrightness(brightnessMapName: string, brightness: number): void {
    try {
      BrightnessUtil.windowClass?.setWindowBrightness(brightness as number);
      BrightnessUtil.brightnessMap.set(brightnessMapName, brightness);
    } catch (err) {
      Logger.error('BrightnessUtil.setBrightness failed', Logger.errorSummary(err));
    }
  }

  /**
   * 设置屏幕是否常亮
   *
   * @param isKeepOn true：屏幕常亮；false:正常熄屏
   */
  public static setScreenState(isKeepOn: boolean): void {
    try {
      BrightnessUtil.windowClass?.setWindowKeepScreenOn(isKeepOn, (err: BusinessError) => {
        const errCode: number = err.code;
        if (errCode) {
          Logger.error('BrightnessUtil.setScreenState failed', Logger.errorSummary(err));
          return;
        }
      });
    } catch (err) {
      Logger.error('BrightnessUtil.setScreenState failed', Logger.errorSummary(err));
    }
  }
}
