import { ReaderFontManager, ReaderFontOption } from '../../common/utils/ReaderFontManager';

/**
 * 阅读字体选择面板（bindSheet 内容）。
 * 每行用对应字体预览展示；导入字体行内二次确认删除；底部入口导入 .ttf/.otf。
 */
@Component
export struct FontPickerPanel {
  @Link @Watch('onFontOptionsChanged') fontOptions: ReaderFontOption[]
  @Prop currentFontPath: string = ''
  @Prop colorMode: number = 1
  @Prop isImporting: boolean = false
  onSelect: (option: ReaderFontOption) => void = () => {
  }
  onImport: () => void = () => {
  }
  onDelete: (option: ReaderFontOption) => void = () => {
  }
  // 待确认删除的字体路径（按路径而非名称，同名字体不会互相干扰）
  @State pendingDeletePath: string = ''

  private get textColor(): string {
    return this.colorMode == 0 ? 'rgba(248, 249, 250, 1)' : 'rgba(19, 19, 19, 1.00)'
  }

  private get subTextColor(): string {
    return this.colorMode == 0 ? 'rgba(248, 249, 250, 0.6)' : 'rgba(19, 19, 19, 0.6)'
  }

  private get dividerColor(): string {
    return this.colorMode == 0 ? 'rgba(248, 249, 250, 0.12)' : 'rgba(19, 19, 19, 0.08)'
  }

  aboutToAppear(): void {
    this.registerPreviewFonts()
  }

  /** 导入后列表刷新，补注册新字体的预览 */
  onFontOptionsChanged(): void {
    this.registerPreviewFonts()
  }

  private registerPreviewFonts(): void {
    for (let index = 0; index < this.fontOptions.length; index++) {
      const option = this.fontOptions[index];
      ReaderFontManager.registerFontForPreview(option);
    }
  }

  build() {
    Column() {
      Text('字体')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textColor)
        .margin({ top: 20, bottom: 12 })

      List() {
        ForEach(this.fontOptions, (option: ReaderFontOption) => {
          ListItem() {
            this.FontOptionRow(option)
          }
        }, (option: ReaderFontOption) => ReaderFontManager.previewFamilyOf(option) || 'system')
      }
      .width('100%')
      .layoutWeight(1)

      Row({ space: 8 }) {
        if (this.isImporting) {
          LoadingProgress().width(18).height(18).color(this.textColor)
          Text('正在导入…')
            .fontSize(14)
            .fontColor(this.subTextColor)
        } else {
          Image($r('app.media.add'))
            .width(18)
            .height(18)
            .fillColor(this.textColor)
          Text('导入字体（.ttf / .otf）')
            .fontSize(14)
            .fontColor(this.textColor)
        }
      }
      .width('100%')
      .height(48)
      .justifyContent(FlexAlign.Center)
      .borderRadius(12)
      .backgroundColor(this.colorMode == 0 ? 'rgba(248, 249, 250, 0.08)' : 'rgba(19, 19, 19, 0.05)')
      .margin({ top: 8, bottom: 20 })
      .opacity(this.isImporting ? 0.6 : 1)
      .onClick(() => {
        if (!this.isImporting) {
          this.onImport()
        }
      })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20 })
  }

  @Builder
  FontOptionRow(option: ReaderFontOption) {
    Row() {
      // 主体区域：点击选中该字体
      Row({ space: 12 }) {
        Text(option.name)
          .fontSize(20)
          .fontColor(this.textColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          // 空串走默认系统字体；其余用注册的自定义字体族预览
          .fontFamily(option.path.length > 0 ? ReaderFontManager.previewFamilyOf(option) : '')

        if (this.isCurrent(option)) {
          Text('✓')
            .fontSize(18)
            .fontColor('#ff6600')
            .fontWeight(FontWeight.Bold)
        }
      }
      .layoutWeight(1)
      .height('100%')
      .onClick(() => {
        this.pendingDeletePath = ''
        this.onSelect(option)
      })

      // 删除区与选择区并列，避免点击冒泡误触选中
      if (this.isImportedFont(option)) {
        if (this.pendingDeletePath === option.path) {
          // 行内二次确认，避免在 sheet 里再叠一层弹窗
          Row({ space: 8 }) {
            Text('取消')
              .fontSize(14)
              .fontColor(this.subTextColor)
              .padding({ left: 8, right: 8, top: 6, bottom: 6 })
              .onClick(() => {
                this.pendingDeletePath = ''
              })
            Text('确认删除')
              .fontSize(14)
              .fontColor(Color.White)
              .padding({ left: 8, right: 8, top: 6, bottom: 6 })
              .borderRadius(8)
              .backgroundColor('#ff4d4f')
              .onClick(() => {
                this.pendingDeletePath = ''
                this.onDelete(option)
              })
          }
        } else {
          // 扩大点按热区，图标本身只占 20
          Row() {
            Image($r('app.media.delete'))
              .width(20)
              .height(20)
              .fillColor(this.subTextColor)
          }
          .padding(8)
          .onClick(() => {
            this.pendingDeletePath = option.path
          })
        }
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 4, right: 4 })
    .border({ width: { bottom: 0.5 }, color: this.dividerColor })
  }

  private isImportedFont(option: ReaderFontOption): boolean {
    return !option.builtin && option.path.length > 0
  }

  /** 当前选中项按路径判定；系统字体两者都为空 */
  private isCurrent(option: ReaderFontOption): boolean {
    return option.path === this.currentFontPath;
  }
}
