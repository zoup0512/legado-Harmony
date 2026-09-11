// Canvas方案，按行拆分，行内按字拆分
import { chaptersItem } from 'ets/componets/dataList/ReaderChaptersItem';

@Component
export struct TxtContentHandler {
  @Prop @Watch('txtFileChange') txtFile: chaptersItem[] = [];
  @Prop @Watch('CurrentChaptersChange') CurrentChapters: number = 0;
  @Prop @Watch('CurrentFontSizeChange') CurrentFontSize: number = 0;
  @Prop LineHeight: number = 1.8;
  @Prop ParagraphSpacing: number = 0;
  @State currentPage: number = 0;
  @State ShowHeight: number = 0
  @State ShowWidth: number = 0
  @State linesPerPage: number = 0;
  private timer: number = 0;
  @State offsetX: number = 0;
  @State CurrentChaptersContent: Array<string> = []; // 当前章节内容
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private panOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Left | PanDirection.Right })

  // 获取总页数
  GetTotalPages() {
    if (this.linesPerPage <= 0) {
      return 0;
    }
    return Math.ceil(this.CurrentChaptersContent.length / this.linesPerPage);
  }

  private scheduleReflow(resetPage: boolean = false) {
    if (resetPage) {
      this.currentPage = 0
      this.offsetX = 0
    }
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      if (this.ShowWidth > 0 && this.ShowHeight > 0 && this.CurrentFontSize > 0) {
        this.wrapText(this.context, this.ShowWidth);
      }
    }, 50)
  }

  // 章节数组整体替换（如服务器阅读页正文异步到达）时重新排版
  txtFileChange() {
    this.scheduleReflow()
  }

  CurrentChaptersChange() {
    this.scheduleReflow(true)
  }

  CurrentFontSizeChange() {
    this.scheduleReflow()
  }

  drawPage() {
    this.context.font = `${vp2px(this.CurrentFontSize)}px`;
    this.linesPerPage = Math.max(1, Math.floor(this.ShowHeight / (this.CurrentFontSize * this.LineHeight)));
    const totalPages = this.GetTotalPages()
    if (totalPages === 0) {
      this.currentPage = 0
    } else if (this.currentPage >= totalPages) {
      this.currentPage = totalPages - 1
    }
    if (this.context) {
      this.context.clearRect(0, 0, this.ShowWidth, this.ShowHeight);
      this.context.font = `${vp2px(this.CurrentFontSize)}px`;
      this.context.fillStyle = 'black';

      const start = this.currentPage * this.linesPerPage;
      const end = start + this.linesPerPage;
      const CurrentPageLines = this.CurrentChaptersContent.slice(start, end);

      // 上一页和下一页的内容
      const PreStart = start - this.linesPerPage;
      const NextEnd = start + this.linesPerPage * 2;
      const PrePageLines = this.CurrentChaptersContent.slice(PreStart, start);
      const NextPageLines = this.CurrentChaptersContent.slice(end, NextEnd);
      CurrentPageLines.forEach((line, index) => {
        this.context.fillText(line, 0 + this.offsetX, (index + 1) * this.CurrentFontSize * Number(this.LineHeight));
      });

      // 下一页内容
      PrePageLines.forEach((line, index) => {
        this.context.fillText(line, 0 - this.ShowWidth + this.offsetX,
          (index + 1) * this.CurrentFontSize * Number(this.LineHeight));
      });

      // 下一页内容
      NextPageLines.forEach((line, index) => {
        this.context.fillText(line, this.ShowWidth + this.offsetX,
          (index + 1) * this.CurrentFontSize * Number(this.LineHeight));
      });
    }
  }

  // 当前章节内容折行：先按换行分段，段内按可用宽度逐字折行
  wrapText(context: CanvasRenderingContext2D, maxWidth: number = this.ShowWidth) {
    const chapter = this.txtFile[this.CurrentChapters];
    const content: string = chapter && typeof chapter.content === 'string' ? chapter.content : '';
    const chaptersItemLines: string[] = []
    context.font = `${vp2px(this.CurrentFontSize)}px`;
    const limit = vp2px(Math.max(0, maxWidth - 10))
    if (content.length > 0 && limit > 0) {
      for (const paragraph of content.split('\n')) {
        let currentLine: string = ''
        for (let i = 0; i < paragraph.length; i++) {
          const ch = paragraph[i]
          if (currentLine.length === 0 || context.measureText(currentLine + ch).width < limit) {
            currentLine += ch
          } else {
            chaptersItemLines.push(currentLine)
            currentLine = ch
          }
        }
        chaptersItemLines.push(currentLine)
      }
    }
    this.CurrentChaptersContent = chaptersItemLines
    this.drawPage();
  }

  aboutToDisappear() {
    clearTimeout(this.timer)
  }

  build() {
    Canvas(this.context)
      .width("100%")
      .height("100%")
      .onReady(() => {
        this.scheduleReflow()
      })
      .onSizeChange((oldValue: SizeOptions, newValue: SizeOptions) => {
        this.ShowHeight = Number(newValue.height)
        this.ShowWidth = Number(newValue.width)
        this.scheduleReflow()
        console.log('ShowHeight:' + this.ShowHeight)
        console.log('ShowWidth:' + this.ShowWidth)
      })
      .gesture(
        PanGesture(this.panOption)
          .onActionUpdate((event?: GestureEvent) => {
            if (!event) {
              return;
            }
            this.offsetX = event.offsetX;
            this.drawPage();
          })
          .onActionEnd((event: GestureEvent) => {
            console.log('currentPage:' + this.currentPage)
            if (event.offsetX > 200 && this.currentPage > 0) {
              this.currentPage--;
              console.log('prevPage')
              this.offsetX = 0
              this.drawPage();
            } else if (event.offsetX < -200 && this.currentPage + 1 < this.GetTotalPages()) {
              this.currentPage++;
              console.log('nextPage')
              this.offsetX = 0
              this.drawPage();
            } else {
              this.offsetX = 0
              this.drawPage();
            }
          })
      )
  }
}