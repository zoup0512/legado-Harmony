import { ThemeStorageKey } from '../../common/constants/Theme'
import { ThemeItem } from '../../common/model/Theme'
import { statusBarContentColorFor } from '../../common/utils/ThemeManager'

/**
 * 首页三个 Tab（书架 / 隐私文件夹 / 我的）共用的居中标题栏。
 * 标题颜色与状态栏文字一致，保证在主题色渐变背景上清晰可读；右侧可放操作按钮，不影响标题居中。
 */
@Component
export default struct TabPageTitle {
  @Prop title: string = ''
  // 左右内边距；外层已有内边距时传 0
  @Prop horizontalPadding: number = 20
  // 顶部安全区；外层已处理时传 0
  @Prop topInset: number = 0
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem
  @Builder emptyTrailing() {}
  @BuilderParam trailing: () => void = this.emptyTrailing

  build() {
    Stack() {
      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(statusBarContentColorFor(this.theme.mainColor))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '60%' })
      Row() {
        Blank()
        this.trailing()
      }
      .width('100%')
    }
    .width('100%')
    .height(40)
    .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
    .margin({ top: this.topInset, bottom: 12 })
  }
}
