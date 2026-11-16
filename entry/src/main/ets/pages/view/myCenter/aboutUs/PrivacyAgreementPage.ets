import { router } from '@kit.ArkUI';

@Entry
@Component
struct PrivacyAgreementPage {
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @StorageLink('topRectHeight') topRectHeight: number = 0
  @StorageProp('leftRectWidth') leftRectWidth: number = 0
  @StorageProp('rightRectWidth') rightRectWidth: number = 0
  @State rowsData: Array<string> = [
    '隐私阅读器（以下简称“本应用”）是纯本地阅读工具，不提供书源、网页抓取、订阅或服务器同步功能，不申请网络权限，不接入统计或崩溃报告服务。',
    '本应用通过系统文件选择器访问您选择的文件或目录；导入时在应用沙箱内保存书籍副本，不删除原文件。',
    '为实现书籍导入、展示、管理和恢复阅读位置，本应用在本机保存书籍副本及封面、书名和文件信息、书架分组、阅读进度及设置。这些数据不上传至服务器，通常随应用数据保留，可按下述方式管理或清理。',
    '您可以在书架中长按书籍进行删除，或通过批量管理删除书架记录；隐私文件夹中的书籍需先解锁后管理。删除书籍会移除书架记录，并尝试清理应用保存的封面，但已导入的书籍副本、阅读进度和阅读设置不会随之自动清除。',
    '隐私文件夹默认使用系统指纹/人脸认证解锁，本应用不读取或保存生物特征数据。设备未录入指纹或人脸时，使用 6 位数字密码解锁；本应用通过随机盐和 PBKDF2 生成密码派生校验值，并在本机保存该校验值、盐及认证设置、失败次数和重试限制相关记录，用于身份验证和限制连续重试，不保存明文密码。',
    '连续输错密码会暂时限制重试。本应用不提供跳过身份验证直接访问隐私文件夹的入口。隐私文件夹仅提供应用内隐藏和访问控制，不对书籍文件加密，也不改变原始文件的存储位置和访问权限。',
    '删除隐私文件夹中的书籍不会自动删除本机保存的隐私认证记录。本应用目前不提供一键清空全部本地数据或单独删除隐私认证记录的入口；如需整体清理本地数据，可使用系统提供的应用数据清理功能或卸载应用，具体操作和清理范围以系统为准。清理或卸载可能导致本地副本、阅读进度、设置和隐私认证记录丢失，请妥善保管原始书籍文件。',
    '本应用不提供账号注册功能，无需办理账号注销。主动跳转系统应用市场后，相关服务适用其自身的隐私政策。'
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
      .constraintSize({ maxWidth: 840 })

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
      .width("100%")
      .constraintSize({ maxWidth: 840 })
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width("100%")
    .height("100%")
    .padding({
      top: this.topRectHeight,
      left: 20 + this.leftRectWidth,
      right: 20 + this.rightRectWidth
    })
    .backgroundColor("rgb(245, 245, 245)")
  }
}