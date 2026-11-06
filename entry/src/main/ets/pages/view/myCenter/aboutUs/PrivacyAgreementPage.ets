import { router } from '@kit.ArkUI';

@Entry
@Component
struct PrivacyAgreementPage {
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @StorageLink('topRectHeight') topRectHeight: number = 0
  @State rowsData: Array<string> = [
    '本应用是纯本地阅读工具，不提供书源、网页抓取、订阅或服务器同步功能，不申请网络权限，不接入统计或崩溃报告服务。',
    '通过系统文件选择器访问您选择的文件或目录；导入时在应用沙箱内保存书籍副本，不删除原文件。书架、阅读进度和设置保存在本机，不上传至服务器。',
    '隐私文件夹默认使用系统指纹/人脸认证解锁，本应用不读取或保存生物特征数据。设备未录入指纹或人脸时，使用 6 位数字密码解锁，密码通过随机盐和 PBKDF2 派生后保存在本机，不保存明文。',
    '连续输错密码会暂时限制重试，无法通过认证时不能绕过验证。隐私文件夹仅提供应用内隐藏和访问控制，不对书籍文件加密。',
    '清除应用数据或卸载应用可能导致本地副本、阅读进度和设置丢失，请妥善保管原始书籍文件。主动跳转系统应用市场后，相关服务适用其自身的隐私政策。'
  ]
  build() {
    Column({ space: 16 }) {
      // 标题部分（不滚动，保持固定）
      Flex() {
        Column() {
          Image($r("app.media.return_left"))
            .size({ width: 24, height: 24 })
            .interpolation(ImageInterpolation.Medium)
            .onClick(() => {
              router.back()
            })
        }
        .alignItems(HorizontalAlign.Start)
        .width('30%')

        Column() {
          Text(`用户隐私与协议`)
            .lineHeight(24)
            .font({
              family: "PingFang SC",
              size: 16,
              weight: 500,
              style: FontStyle.Normal,
            })
        }.width('40%')
      }
      .padding({
        top: 12,
        bottom: 12,
      })
      .height(48)
      .width("100%")

      // 内容区域
      Scroll() {
        Column() {
          ForEach(this.rowsData, (item: string) => {
            Row() {
              Text('•')
                .margin({ right: 8 })
              Text(item)
                .layoutWeight(1)
                .lineHeight(22)
                .font({
                  family: "PingFang SC",
                  size: 14,
                  style: FontStyle.Normal,
                  weight: 400,
                })
            }.width("100%")
            .alignItems(VerticalAlign.Top)
            .margin({ top: 12 })
          })
        }
        .width("100%")
        .padding({ bottom: this.bottomRectHeight + 20 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .height("100%") // 设置外部 Column 高度为 100%
    .padding({
      top: this.topRectHeight,
      left: 20,
      right: 20
    })
    .backgroundColor("rgb(245, 245, 245)")
  }
}