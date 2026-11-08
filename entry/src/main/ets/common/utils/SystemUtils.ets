import Logger from './Logger';
/**
 * @author 2008
 * @datetime 2024/8/13 22:04
 * @className: SystemUtils
 */
import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

class SystemUtils {
  //浏览器打开
  async startBrowsableAbility(context: common.UIAbilityContext, uri: string): Promise<void> {
    let want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: uri
    };
    context.startAbility(want)
      .then(() => {
      })
      .catch((err: BusinessError) => {
        Logger.error('SystemUtils.startBrowsableAbility failed', Logger.errorSummary(err));
      });
  }
}

const systemUtil = new SystemUtils();
export default systemUtil as SystemUtils;