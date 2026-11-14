import { ThemeStorageKey } from '../../common/constants/Theme'
import { ThemeItem } from '../../common/model/Theme'

/**
 * 空状态插图：浅主题色圆底 + 主题色书本，随主题切换颜色。
 */
@Component
export default struct ThemedEmptyImage {
  @Prop imageSize: number = 140
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {
    mainColor: '#24b277', secondColor: '#e4f5ee', text: '主题3'
  }

  build() {
    Stack() {
      Circle()
        .width(this.imageSize)
        .height(this.imageSize)
        .fill(this.theme.secondColor)
      Image($r('app.media.empty_books'))
        .width(this.imageSize * 0.56)
        .height(this.imageSize * 0.56)
        .fillColor(this.theme.mainColor)
        .draggable(false)
    }
    .width(this.imageSize)
    .height(this.imageSize)
    .accessibilityLevel('no')
  }
}
