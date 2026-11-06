// Lock-screen style PIN entry: six dots on top, an in-app numeric keypad below.
// The keypad never invokes the system or third-party IME, so digits are not exposed to input methods.
const PIN_LENGTH: number = 6;
const KEY_ROWS: string[][] = [
  ['1', '2', '3'],
  ['4', '5', '6'],
  ['7', '8', '9'],
  ['', '0', 'del']
];
const DOT_INDEXES: number[] = [0, 1, 2, 3, 4, 5];

@Component
export struct PrivacyPinPad {
  @Prop filled: number = 0;
  @Prop inputEnabled: boolean = true;
  @Prop accentColor: string = '#188bff';
  onDigit: (digit: string) => void = (_digit: string): void => {};
  onDelete: () => void = (): void => {};

  @Builder
  pinDot(index: number) {
    Column()
      .width(14)
      .height(14)
      .borderRadius(7)
      .border({ width: 1.5, color: this.accentColor })
      .backgroundColor(index < this.filled ? this.accentColor : Color.Transparent)
  }

  @Builder
  padKey(label: string) {
    if (label === '') {
      Column().width(76).height(76)
    } else if (label === 'del') {
      Text('删除')
        .fontSize(16)
        .fontColor(this.filled > 0 && this.inputEnabled ? '#333333' : '#BBBBBB')
        .width(76)
        .height(76)
        .textAlign(TextAlign.Center)
        .onClick((): void => {
          if (this.inputEnabled && this.filled > 0) this.onDelete();
        })
    } else {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text(label).fontSize(30).fontColor(this.inputEnabled ? '#222222' : '#BBBBBB')
      }
      .width(76)
      .height(76)
      .backgroundColor('#E6E8EC')
      .enabled(this.inputEnabled)
      .onClick((): void => {
        if (this.inputEnabled && this.filled < PIN_LENGTH) this.onDigit(label);
      })
    }
  }

  build() {
    Column({ space: 40 }) {
      Row({ space: 22 }) {
        ForEach(DOT_INDEXES, (index: number) => {
          this.pinDot(index)
        }, (index: number) => `dot-${index}`)
      }
      .justifyContent(FlexAlign.Center)

      Column({ space: 18 }) {
        ForEach(KEY_ROWS, (row: string[], rowIndex: number) => {
          Row({ space: 28 }) {
            ForEach(row, (label: string, columnIndex: number) => {
              this.padKey(label)
            }, (label: string, columnIndex: number) => `key-${rowIndex}-${columnIndex}`)
          }
          .justifyContent(FlexAlign.Center)
        }, (_row: string[], rowIndex: number) => `row-${rowIndex}`)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
