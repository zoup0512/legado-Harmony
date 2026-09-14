import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { ThemeStorageKey } from '../../../common/constants/Theme'
import { ThemeItem } from '../../../common/model/Theme'
import localBookImportService, {
  LOCAL_BOOK_FILE_SUFFIX_FILTERS,
  LOCAL_BOOK_IMPORT_MAX_COUNT,
  LocalBookBatchImportResult,
  LocalBookImportCandidate,
  LocalBookImportScanResult,
  LocalBookImportStatus
} from '../../../common/utils/LocalBookImportService'
import { showMessage } from '../../../componets/common/promptShow'

interface LocalImportRouteParams {
  bookType: number
}

enum LocalImportSortType {
  NAME = 'name',
  SIZE = 'size',
  TIME = 'time'
}

@Entry
@Component
struct LocalImportPage {
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @StorageLink('topRectHeight') topRectHeight: number = 0
  @StorageLink('BOOK_IS_BOOK_REFRESHING') isBookRefreshing: number = 0
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem
  @State bookType: number = (router.getParams() as LocalImportRouteParams)?.bookType ?? 0
  @State searchValue: string = ''
  @State sortType: LocalImportSortType = LocalImportSortType.NAME
  @State includeSubFolders: boolean = false
  @State candidates: LocalBookImportCandidate[] = []
  @State selectedUris: string[] = []
  @State isScanning: boolean = false
  @State isImporting: boolean = false
  @State cancelRequested: boolean = false
  @State completed: number = 0
  @State importTotal: number = 0
  private refreshSentForBatch: boolean = false
  private isPageActive: boolean = true
  private scanVersion: number = 0
  private activeScanResult: LocalBookImportScanResult | undefined

  aboutToAppear(): void {
    this.isPageActive = true
  }

  aboutToDisappear(): void {
    this.isPageActive = false
    this.scanVersion++
    this.cancelRequested = true
    if (!this.isImporting && this.activeScanResult) {
      localBookImportService.cleanupScanResult(this.activeScanResult)
      this.activeScanResult = undefined
    }
  }

  private getContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private async selectFiles(): Promise<void> {
    if (this.isScanning || this.isImporting) {
      return
    }
    const version = ++this.scanVersion
    this.isScanning = true
    let scanResult: LocalBookImportScanResult | undefined
    try {
      const uris = await localBookImportService.pickFileUris(this.getContext())
      if (!this.isPageActive || version !== this.scanVersion || uris.length === 0) {
        return
      }
      scanResult = await localBookImportService.scanPickerUris(uris)
      if (this.isPageActive && version === this.scanVersion) {
        await this.replaceScanResult(scanResult)
      }
    } finally {
      this.isScanning = false
      if (scanResult && (!this.isPageActive || version !== this.scanVersion)) {
        await localBookImportService.cleanupScanResult(scanResult)
      }
    }
  }

  private async selectFolder(): Promise<void> {
    if (this.isScanning || this.isImporting) {
      return
    }
    if (!localBookImportService.canPickDirectory()) {
      showMessage('当前设备不支持直接选择文件夹，已切换为批量选择文件', 2000)
      await this.selectFiles()
      return
    }
    const version = ++this.scanVersion
    this.isScanning = true
    let scanResult: LocalBookImportScanResult | undefined
    try {
      const uris = await localBookImportService.pickDirectoryUris(this.getContext())
      if (!this.isPageActive || version !== this.scanVersion || uris.length === 0) {
        return
      }
      scanResult = await localBookImportService.scanDirectoryUri(
        this.getContext(), uris[0], this.includeSubFolders)
      if (this.isPageActive && version === this.scanVersion) {
        await this.replaceScanResult(scanResult)
      }
    } finally {
      this.isScanning = false
      if (scanResult && (!this.isPageActive || version !== this.scanVersion)) {
        await localBookImportService.cleanupScanResult(scanResult)
      }
    }
  }

  private async replaceScanResult(result: LocalBookImportScanResult): Promise<void> {
    const previousResult = this.activeScanResult
    this.activeScanResult = result
    this.loadScanResult(result)
    if (previousResult) {
      await localBookImportService.cleanupScanResult(previousResult)
    }
  }

  private loadScanResult(result: LocalBookImportScanResult): void {
    if (result.message.length > 0) {
      showMessage(result.message, 3000)
    }
    this.searchValue = ''
    this.cancelRequested = false
    this.completed = 0
    this.importTotal = 0
    this.refreshSentForBatch = false
    this.candidates = result.candidates
    this.selectedUris = []
    this.candidates.forEach((item: LocalBookImportCandidate): void => {
      if (item.status === LocalBookImportStatus.READY) {
        this.selectedUris.push(item.id)
      }
    })
  }

  private isSelected(item: LocalBookImportCandidate): boolean {
    return this.selectedUris.includes(item.id)
  }

  private isSelectable(item: LocalBookImportCandidate): boolean {
    return item.status === LocalBookImportStatus.READY && !this.isImporting
  }

  private updateSelection(item: LocalBookImportCandidate, selected: boolean): void {
    if (!this.isSelectable(item)) {
      return
    }
    const index = this.selectedUris.indexOf(item.id)
    if (selected && index < 0) {
      this.selectedUris.push(item.id)
      this.selectedUris = this.selectedUris.slice()
    } else if (!selected && index >= 0) {
      this.selectedUris.splice(index, 1)
      this.selectedUris = this.selectedUris.slice()
    }
  }

  private readyCandidates(): LocalBookImportCandidate[] {
    return this.candidates.filter((item: LocalBookImportCandidate): boolean => item.status === LocalBookImportStatus.READY)
  }

  private allReadySelected(): boolean {
    const readyItems = this.readyCandidates()
    return readyItems.length > 0 && readyItems.every((item: LocalBookImportCandidate): boolean => this.isSelected(item))
  }

  private toggleSelectAll(): void {
    if (this.isImporting) {
      return
    }
    if (this.allReadySelected()) {
      this.selectedUris = []
      return
    }
    this.selectedUris = this.readyCandidates().map((item: LocalBookImportCandidate): string => item.id)
  }

  private getVisibleCandidates(): LocalBookImportCandidate[] {
    const keyword = this.searchValue.trim().toLowerCase()
    const result = this.candidates.filter((item: LocalBookImportCandidate): boolean => {
      return keyword.length === 0 || item.displayName.toLowerCase().includes(keyword)
    }).slice()
    result.sort((left: LocalBookImportCandidate, right: LocalBookImportCandidate) => {
      if (this.sortType === LocalImportSortType.SIZE) {
        return right.size - left.size
      }
      if (this.sortType === LocalImportSortType.TIME) {
        return right.modifiedTime - left.modifiedTime
      }
      return left.displayName.localeCompare(right.displayName)
    })
    return result
  }

  private statusCount(status: string): number {
    return this.candidates.filter((item: LocalBookImportCandidate): boolean => item.status === status).length
  }

  private invalidCount(): number {
    return this.statusCount('unsupported') + this.statusCount('failed')
  }

  private formatSize(size: number): string {
    if (size < 1024) {
      return `${size} B`
    }
    if (size < 1024 * 1024) {
      return `${(size / 1024).toFixed(1)} KB`
    }
    if (size < 1024 * 1024 * 1024) {
      return `${(size / 1024 / 1024).toFixed(1)} MB`
    }
    return `${(size / 1024 / 1024 / 1024).toFixed(1)} GB`
  }

  private formatTime(time: number): string {
    if (time <= 0) {
      return '时间未知'
    }
    const date = new Date(time)
    const month = `${date.getMonth() + 1}`.padStart(2, '0')
    const day = `${date.getDate()}`.padStart(2, '0')
    const hour = `${date.getHours()}`.padStart(2, '0')
    const minute = `${date.getMinutes()}`.padStart(2, '0')
    return `${date.getFullYear()}-${month}-${day} ${hour}:${minute}`
  }

  private formatSuffix(item: LocalBookImportCandidate): string {
    const suffix = item.extension || item.displayName.substring(item.displayName.lastIndexOf('.') + 1)
    return suffix.replace('.', '').toUpperCase()
  }

  private statusText(status: string): string {
    switch (status) {
      case 'ready':
        return '待导入'
      case 'duplicate':
        return '重复'
      case 'unsupported':
        return '格式不支持'
      case 'failed':
        return '读取失败'
      case 'importing':
        return '导入中'
      case 'imported':
        return '已导入'
      case 'cancelled':
        return '已取消'
      default:
        return status
    }
  }

  private statusColor(status: string): ResourceColor {
    if (status === 'imported') {
      return '#28A745'
    }
    if (status === 'failed' || status === 'unsupported') {
      return '#D9485F'
    }
    if (status === 'duplicate' || status === 'cancelled') {
      return '#8A8A8A'
    }
    return this.theme.mainColor
  }

  private requestCancel(): void {
    if (!this.isImporting || this.cancelRequested) {
      return
    }
    this.cancelRequested = true
    showMessage('将在当前书籍处理完成后取消')
  }

  private async importSelected(): Promise<void> {
    if (this.isImporting || this.selectedUris.length === 0) {
      if (this.selectedUris.length === 0) {
        showMessage('请至少选择一本可导入书籍')
      }
      return
    }
    const selected = this.candidates.filter((item: LocalBookImportCandidate): boolean => {
      return item.status === LocalBookImportStatus.READY && this.selectedUris.includes(item.id)
    })
    if (selected.length === 0) {
      showMessage('没有可导入的书籍')
      return
    }
    this.isImporting = true
    this.cancelRequested = false
    this.completed = 0
    this.importTotal = selected.length
    this.refreshSentForBatch = false
    try {
      selected.forEach((item: LocalBookImportCandidate): void => {
        item.selected = true
      })
      const result: LocalBookBatchImportResult = await localBookImportService.importCandidates(
        this.getContext(),
        selected,
        this.bookType,
        (completed: number, total: number, _candidate: LocalBookImportCandidate): void => {
          this.completed = completed
          this.importTotal = total
          this.candidates = this.candidates.slice()
        },
        (): boolean => this.cancelRequested)
      this.completed = result.completed
      this.importTotal = result.selected
      this.candidates = this.candidates.slice()
      this.selectedUris = this.selectedUris.filter((id: string): boolean => {
        return this.candidates.some((item: LocalBookImportCandidate): boolean => {
          return item.id === id && item.status === LocalBookImportStatus.READY
        })
      })
      if (!this.refreshSentForBatch && result.imported > 0) {
        this.isBookRefreshing++
        this.refreshSentForBatch = true
      }
      showMessage(`导入完成：成功 ${result.imported}，重复 ${result.duplicate}，失败 ${result.failed}，取消 ${result.cancelled}`, 2500)
    } catch (_) {
      showMessage('批量导入未完成，请查看列表状态')
    } finally {
      this.isImporting = false
      const hasPendingCandidates = this.candidates.some((item: LocalBookImportCandidate): boolean => {
        return item.status === LocalBookImportStatus.READY
      })
      if ((!this.isPageActive || !hasPendingCandidates) && this.activeScanResult) {
        localBookImportService.cleanupScanResult(this.activeScanResult)
        this.activeScanResult = undefined
      }
    }
  }

  @Builder
  SortMenu() {
    Column() {
      this.SortMenuItem('按名称排序', LocalImportSortType.NAME)
      Divider().width('80%')
      this.SortMenuItem('按大小排序', LocalImportSortType.SIZE)
      Divider().width('80%')
      this.SortMenuItem('按时间排序', LocalImportSortType.TIME)
    }
    .width(148)
  }

  @Builder
  SortMenuItem(title: string, sortType: LocalImportSortType) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontWeight(this.sortType === sortType ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.sortType === sortType ? this.theme.mainColor : '#222222')
    }
    .width('100%')
    .height(44)
    .padding({ left: 18, right: 18 })
    .onClick(() => {
      this.sortType = sortType
    })
  }

  @Builder
  Header() {
    Row({ space: 14 }) {
      Image($r('app.media.return_left'))
        .width(24)
        .height(24)
        .onClick(() => {
          router.back()
        })
      Text('本地导入')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
      Image($r('app.media.sort'))
        .width(24)
        .height(24)
        .fillColor('#66000000')
        .bindMenu(this.SortMenu())
    }
    .width('100%')
    .height(52)
  }

  @Builder
  SourceActions() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Button('选择文件')
          .layoutWeight(1)
          .height(42)
          .fontSize(14)
          .backgroundColor(this.theme.mainColor)
          .enabled(!this.isScanning && !this.isImporting)
          .onClick(() => {
            this.selectFiles()
          })
        Button('选择文件夹')
          .layoutWeight(1)
          .height(42)
          .fontSize(14)
          .fontColor(this.theme.mainColor)
          .backgroundColor(this.theme.secondColor)
          .enabled(!this.isScanning && !this.isImporting)
          .onClick(() => {
            this.selectFolder()
          })
      }
      Row() {
        Text('包含子文件夹')
          .fontSize(14)
          .fontColor('#73000000')
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.includeSubFolders })
          .selectedColor(this.theme.mainColor)
          .enabled(localBookImportService.canPickDirectory() && !this.isScanning && !this.isImporting)
          .onChange((value: boolean) => {
            this.includeSubFolders = value
          })
      }
      .width('100%')
      Text(`支持格式：${LOCAL_BOOK_FILE_SUFFIX_FILTERS.join('/').replace(/\./g, '').toUpperCase()}，单次最多 ${LOCAL_BOOK_IMPORT_MAX_COUNT} 本`)
        .fontSize(12)
        .fontColor('#73000000')
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(12)
    .backgroundColor(Color.White)
  }

  @Builder
  EmptyState() {
    Column({ space: 14 }) {
      if (this.isScanning) {
        LoadingProgress()
          .width(48)
          .height(48)
          .color(this.theme.mainColor)
        Text('正在扫描文件…')
          .fontSize(15)
          .fontColor('#73000000')
      } else {
        Image($r('app.media.no_record'))
          .width(180)
          .height(180)
        Text('选择本地书籍后，可在导入前检查并勾选')
          .fontSize(14)
          .fontColor('#73000000')
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  SummaryItem(value: number, label: string, color: ResourceColor) {
    Column({ space: 4 }) {
      Text(`${value}`)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
      Text(label)
        .fontSize(11)
        .fontColor('#73000000')
    }
    .layoutWeight(1)
  }

  @Builder
  ScanSummary() {
    Row() {
      this.SummaryItem(this.candidates.length, '发现', '#222222')
      this.SummaryItem(this.statusCount('ready'), '可导入', this.theme.mainColor)
      this.SummaryItem(this.statusCount('duplicate'), '重复', '#8A8A8A')
      this.SummaryItem(this.invalidCount(), '不支持/失败', '#D9485F')
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .borderRadius(10)
    .backgroundColor(Color.White)
  }

  @Builder
  CandidateItem(item: LocalBookImportCandidate) {
    Row({ space: 12 }) {
      Column() {
        Text(this.formatSuffix(item))
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#188BFF')
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .borderRadius(8)
      .backgroundColor('#D8ECFF')

      Column({ space: 5 }) {
        Text(item.displayName)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`${this.formatSize(item.size)}  ${this.formatTime(item.modifiedTime)}`)
          .fontSize(11)
          .fontColor('#73000000')
          .maxLines(1)
          .width('100%')
        Text(this.statusText(item.status))
          .fontSize(11)
          .fontColor(this.statusColor(item.status))
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Checkbox({ name: item.id, group: 'localImportCandidates' })
        .select(this.isSelected(item))
        .selectedColor(this.theme.mainColor)
        .enabled(this.isSelectable(item))
        .onChange((selected: boolean) => {
          this.updateSelection(item, selected)
        })
    }
    .width('100%')
    .padding({ top: 12, bottom: 12, left: 12, right: 12 })
    .borderRadius(10)
    .backgroundColor(Color.White)
  }

  @Builder
  CandidateList() {
    if (this.getVisibleCandidates().length === 0) {
      Column({ space: 12 }) {
        Image($r('app.media.no_record')).width(120).height(120)
        Text('没有匹配的书籍').fontSize(14).fontColor('#73000000')
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 8 }) {
        ForEach(this.getVisibleCandidates(), (item: LocalBookImportCandidate) => {
          ListItem() {
            this.CandidateItem(item)
          }
        }, (item: LocalBookImportCandidate) => item.id)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
  }

  @Builder
  BottomBar() {
    Column({ space: 10 }) {
      if (this.isImporting) {
        Row() {
          Text(`导入进度 ${this.completed}/${this.importTotal}`)
            .fontSize(13)
            .fontColor('#73000000')
          Blank()
          Text(this.cancelRequested ? '正在取消…' : '请勿退出页面')
            .fontSize(12)
            .fontColor('#73000000')
        }
        .width('100%')
        Progress({ value: this.completed, total: Math.max(this.importTotal, 1) })
          .width('100%')
          .height(6)
          .color(this.theme.mainColor)
      }
      Row({ space: 14 }) {
        Row({ space: 6 }) {
          Checkbox({ name: 'selectAllLocalBooks', group: 'selectAllLocalBooks' })
            .select(this.allReadySelected())
            .selectedColor(this.theme.mainColor)
            .enabled(!this.isImporting && this.readyCandidates().length > 0)
            .onChange(() => {
              this.toggleSelectAll()
            })
          Text(`全选  已选 ${this.selectedUris.length}`)
            .fontSize(14)
            .fontColor('#99000000')
        }
        .layoutWeight(1)
        Button(this.isImporting ? (this.cancelRequested ? '取消中' : '取消') : '导入书架')
          .width(116)
          .height(40)
          .fontSize(14)
          .backgroundColor(this.isImporting ? '#D9485F' : this.theme.mainColor)
          .enabled(this.isImporting ? !this.cancelRequested : this.selectedUris.length > 0)
          .onClick(() => {
            if (this.isImporting) {
              this.requestCancel()
            } else {
              this.importSelected()
            }
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 12, bottom: 12, left: 20, right: 20 })
    .backgroundColor(Color.White)
  }

  build() {
    Column() {
      Column({ space: 12 }) {
        this.Header()
        Search({ value: this.searchValue, placeholder: '搜索文件名', icon: '/common/images/search.svg' })
          .height(40)
          .onChange((value: string) => {
            this.searchValue = value
          })
        this.SourceActions()
        if (this.candidates.length > 0) {
          this.ScanSummary()
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20 })

      if (this.candidates.length === 0) {
        this.EmptyState()
      } else {
        Column() {
          this.CandidateList()
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ top: 10, left: 20, right: 20 })
        this.BottomBar()
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topRectHeight, bottom: this.bottomRectHeight })
    .backgroundColor('#F6F7F9')
  }
}
