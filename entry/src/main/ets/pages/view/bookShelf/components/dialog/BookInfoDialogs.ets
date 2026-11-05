import { buttonList } from '../../../../../componets/dataList/buttonList'
import { Books } from '../../../../../database/entities/Books'
import { router } from '@kit.ArkUI'
import InsideCircleIcon from '../../../../../componets/common/InsideCircleIcon'
import { showMessage } from '../../../../../componets/common/promptShow'
import confirmDialogExample from '../../../../../componets/common/confirmDialog'
import booksUtil from '../../../../../common/utils/booksUtils'
import BookSelectGroupDialog from './BookSelectGroupDialog'
import catalogAddShelf from '../../Manage/components/catalogAddShelf'
import PaddingConstants from '../../../../../common/constants/PaddingConstants'
import CommonConstants from '../../../../../common/constants/CommonConstants'
import BasicDataSource from '../../../../../common/LazyIDataSource/BasicDataSource'
import {
  isReadableLocalBook,
  LocalBookAccessLogic,
  LOCAL_BOOK_MISSING_MESSAGE
} from '../../../../../common/utils/LocalBookAccess'
import privacyFolderService, { PRIVACY_BOOK_GROUP } from '../../../../../privacy/PrivacyFolderService'
import privacySessionService from '../../../../../privacy/PrivacySessionService'
import BooksDao from '../../../../../database/dao/BooksDao'

@CustomDialog
/**
 * 书籍长按
 */
export default struct BookInfoDialogs{
  controller?: CustomDialogController
  //推送提醒
  @Prop bookData:Books
  @State pushReminder:boolean = false
  @State buttonListInfo:buttonList[] = [
    new buttonList(1,this.bookData.isTop?'取消置顶':'置顶',$r('app.media.top')),
    new buttonList(2,'移动至',$r('app.media.folder')),
    new buttonList(3,'加入书单',$r('app.media.shelf')),
    new buttonList(4,'删除',$r('app.media.ic_public_delete'))
  ]
  @Consume('booksDataSource')  booksDataSource: BasicDataSource<Books>
  cancel: () => void = () => {
  }

  private unsubscribePrivacy: (() => void) | undefined
  private active: boolean = false
  @State contentVisible: boolean = false

  aboutToAppear(): void {
    this.active = true
    this.unsubscribePrivacy = privacySessionService.onStateChanged((locked: boolean): void => {
      if (!locked) return
      // An old overlay must not retain its private title/cover or mutation controls.
      this.contentVisible = false
      this.bookMoveGroup?.close()
      this.bookDelDialog?.close()
      this.isCatalogAddShelf = false
      this.controller?.close()
    })
    this.initializePrivacy()
  }

  aboutToDisappear(): void {
    this.active = false
    this.unsubscribePrivacy?.()
    this.unsubscribePrivacy = undefined
  }

  private async initializePrivacy(): Promise<void> {
    const generation = privacySessionService.getGeneration()
    try {
      const privateBook = await BooksDao.isPrivateBook(this.bookData)
      if (!this.active || generation !== privacySessionService.getGeneration()) return
      if (privateBook && !privacySessionService.isUnlocked()) {
        this.controller?.close()
        return
      }
      this.buttonListInfo = this.buttonListInfo.filter(item => item.id !== 5 && item.id !== 6)
      this.buttonListInfo.push(new buttonList(privateBook ? 5 : 6,
        privateBook ? '移出隐私' : '移入隐私', privateBook ? $r('app.media.folder') : $r('app.media.hide')))
      this.contentVisible = true
    } catch (_) {
      this.controller?.close()
    }
  }

  private async authorizeCurrentBook(): Promise<number | undefined> {
    try {
      if (await BooksDao.isPrivateBook(this.bookData) &&
        !await privacySessionService.unlock(this.getUIContext())) return undefined
      const generation = privacySessionService.getGeneration()
      const privateBook = await BooksDao.isPrivateBook(this.bookData)
      if (!this.active || generation !== privacySessionService.getGeneration() ||
        (privateBook && !privacySessionService.isUnlocked())) return undefined
      return generation
    } catch (_) {
      return undefined
    }
  }

  private isCurrent(generation: number): boolean {
    return this.active && generation === privacySessionService.getGeneration()
  }

  @State privacyBusy: boolean = false

  confirmMoveToPrivacy() {
    if (this.privacyBusy) return
    if (!this.bookData.id || !LocalBookAccessLogic.isLocalFilePath(this.bookData.bookUrl)) {
      showMessage('仅支持移入本地书籍')
      return
    }
    this.privacyBusy = true
    AlertDialog.show({
      title: '移入隐私文件夹',
      message: '确定将该本地书籍移入隐私文件夹？目前仅在应用内隐藏分组，不是加密。原文件和缓存不会删除。',
      autoCancel: false,
      primaryButton: { value: '取消', action: () => { this.privacyBusy = false } },
      secondaryButton: { value: '确认移入', action: () => { this.moveToPrivacy() } },
      cancel: () => { this.privacyBusy = false }
    })
  }

  async moveToPrivacy() {
    try {
      if (!await privacySessionService.unlock(this.getUIContext())) return
      const generation = privacySessionService.getGeneration()
      if (!privacySessionService.isUnlocked() || !this.isCurrent(generation)) return
      if (!await privacyFolderService.moveIn(this.bookData, generation)) {
        showMessage('移入隐私文件夹失败')
        return
      }
      if (!this.isCurrent(generation) || !privacySessionService.isUnlocked()) return
      this.isBookRefreshing++
      this.controller?.close()
      showMessage('已移入隐私文件夹')
    } catch (_) {
      showMessage('移入隐私文件夹失败')
    } finally {
      this.privacyBusy = false
    }
  }

  confirmMoveOutPrivacy(): void {
    if (this.privacyBusy) return
    this.privacyBusy = true
    AlertDialog.show({
      title: '移出隐私文件夹',
      message: '移出后该书将在未分组书架中公开显示，确定继续？',
      autoCancel: false,
      primaryButton: { value: '取消', action: () => { this.privacyBusy = false } },
      secondaryButton: { value: '确认移出', action: () => { this.moveOutPrivacy() } },
      cancel: () => { this.privacyBusy = false }
    })
  }

  async moveOutPrivacy(): Promise<void> {
    try {
      if (!await privacySessionService.unlock(this.getUIContext())) return
      const generation = privacySessionService.getGeneration()
      if (!this.isCurrent(generation) || !privacySessionService.isUnlocked()) return
      if (!await privacyFolderService.moveOut(this.bookData, generation) || !this.isCurrent(generation) ||
        !privacySessionService.isUnlocked()) return
      this.isBookRefreshing++
      this.controller?.close()
      showMessage('已移出至未分组书架')
    } catch (_) {
      showMessage('移出失败')
    } finally {
      this.privacyBusy = false
    }
  }

  @StorageLink('topRectHeight') topRectHeight: number = 0
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @State isCatalogAddShelf:boolean = false

  build() {
    if (this.contentVisible) {
    Column(){
      Row(){
        Row({
          space:CommonConstants.SPACE_12
        }){
          Image(LocalBookAccessLogic.selectLocalCover(this.bookData.coverUrl, $r('app.media.icon_book_default_cover_one')))
            .alt($r('app.media.icon_book_default_cover_one'))
            .width(45).height(65)
          Column({
            space:PaddingConstants.PADDING_20
          }){
            Text(this.bookData.bookName).fontSize(16).fontWeight(500).fontColor($r('app.string.color_black_88'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('75%')
            Text(this.bookData.author).fontSize(12).fontWeight(400).fontColor($r('app.string.color_black_45'))
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('80%')

        Row({
          space:8
        }){
          Text('书籍详情').fontSize(12).fontWeight(400).fontColor($r('app.string.color_black_45'))
          Image($r('app.media.icon_right')).width(20).height(20).fillColor($r('app.string.color_black_45'))
        } .onClick(async () => {
          if (await this.authorizeCurrentBook() === undefined) return
          if (!isReadableLocalBook(this.bookData.bookUrl)) {
            showMessage(LOCAL_BOOK_MISSING_MESSAGE)
            return
          }
          router.pushUrl({
            url: 'pages/view/BookDetailPage',
            params: this.bookData
          })
          this.controller?.close()
        })
      }
      .justifyContent(FlexAlign.SpaceBetween)
      .margin(20)
      Divider().strokeWidth(0.5).padding({bottom:16})
      GridRow({
        columns:4
      }){
        ForEach(this.buttonListInfo,(item:buttonList)=>{
          GridCol(){
            InsideCircleIcon({
              icon:item.icon,
              title:item.title
            })
              .onClick(()=>{
                this.bookInfoButton(item.id)
              })
          }
        })
      }
      Divider().strokeWidth(0.5).padding({bottom:16})
      Column(){
        Text('取消').fontColor('rgba(0, 0, 0, 0.88)').fontSize(16).fontWeight(400).lineHeight(24).textAlign(TextAlign.Center)
      }
      .onClick(()=>{
        this.cancel()
        this.controller?.close()
      })
      .alignItems(HorizontalAlign.Center)
      .padding({bottom:16})

      Flex()
        .bindSheet($$this.isCatalogAddShelf, this.dialogCatalogAddShelf(), {
          height:400,
          dragBar: true,
          showClose: false,
          onDisappear: () => {
            this.isCatalogAddShelf = false
          }
        })
    }
    .borderRadius({topLeft:20,topRight:20})
    .backgroundColor(Color.White)
    .width('100%')
    }
  }

  //书单弹窗
  @Builder dialogCatalogAddShelf(){
    Column(){
      catalogAddShelf({
        onClickShelf:(val:boolean)=>{
          this.isCatalogAddShelf = val
        },
        currentIndex:this.bookData.bookType,
        ids:this.bookData.id ? [this.bookData.id]:[]
      })
    }
  }

  async bookInfoButton(id: number): Promise<void> {
    if (this.privacyBusy) return
    if (id !== 5 && id !== 6 && await this.authorizeCurrentBook() === undefined) return
    switch (id){
      case 1 :
        this.isTopBook(); break;
      case 2 :
        this.bookMoveGroup?.open(); break;
      case 3 :
        this.isCatalogAddShelf = true;break;
      case 4 :
        this.bookDelDialog?.open(); break;
      case 5 :
        this.confirmMoveOutPrivacy(); break;
      case 6 :
        this.confirmMoveToPrivacy(); break;
    }
  }

  @State delCache:boolean = false
  //弹窗
 bookDelDialog: CustomDialogController | null = new CustomDialogController({
    builder: confirmDialogExample({
      confirm: ()=> { this.deleteGroup() },
      delCache:this.delCache
    }),
    cancel: this.exitApp,
    autoCancel: true,
    alignment: DialogAlignment.Center,
    gridCount: 4,
    customStyle: false,
    cornerRadius: 25,
  })

  async deleteGroup(): Promise<void> {
    await this.deleteBook()
  }

  exitApp() {
    this.bookDelDialog?.close()
  }
  @StorageLink('BOOK_IS_BOOK_REFRESHING') isBookRefreshing: number = 0

  async deleteBook(): Promise<void> {
    const generation = await this.authorizeCurrentBook()
    if (generation === undefined || !this.bookData.id) return
    if (!await booksUtil.delBooksById(this.bookData.id, generation) || !this.isCurrent(generation)) return
    this.isBookRefreshing++
    this.cancel()
    this.controller?.close()
    showMessage('删除成功')
  }

  async isTopBook(){
    const generation = await this.authorizeCurrentBook()
    if (generation === undefined || !this.bookData.id) return
    const success = await booksUtil.isTopBook(this.bookData.id, !this.bookData.isTop, generation)
    if (!success || !this.isCurrent(generation)) return
    showMessage(!this.bookData.isTop ? '置顶成功' : '取消置顶成功')
    // let index = this.booksDataSource.getIndex(this.bookData)
    // this.bookData.isTop = !this.bookData.isTop
    // if (this.bookData.isTop){
    //   this.booksDataSource.deleteData(index)
    //   this.booksDataSource.unshiftData(this.bookData)
    // } else {
    //   let newIndex = this.getIndexByIsTopFalse()
    //   if (newIndex > 1) {
    //     this.booksDataSource.moveDataUpdate(index, newIndex-1,this.bookData)
    //   }
    //   this.booksDataSource.changeData(newIndex > 1?newIndex - 1:index,this.bookData)
    // }
    this.isBookRefreshing++
    this.controller?.close()
  }
  //从booksDataSource数据中查询从第一位查询最先出现isTop为false下标返回
  getIndexByIsTopFalse() {
    const dataArray = this.booksDataSource.getOriginDataArray();
    const index = dataArray.findIndex(item => !item.isTop);
    return index;
  }

  //移动分组
  //弹窗
  bookMoveGroup: CustomDialogController | null = new CustomDialogController({
    builder: BookSelectGroupDialog({
      moveGroup: ()=> {
        // setTimeout(()=>{
        //   // this.booksDataSource.deleteData(this.bookData)
        // },500)
        setTimeout(()=>{
          this.bookMoveGroup?.close()
          this.controller?.close()
          this.isBookRefreshing++
        },200)
      },
      oldGroupId:this.bookData.bookGroup,
      currentIndex:this.bookData.bookType,
      Ids:this.bookData.id
    }),
    height: 400,
    cancel: this.exitApp,
    autoCancel: true,
    alignment: DialogAlignment.Center,
    gridCount: 4,
    customStyle: false,
    cornerRadius: 25,
  })

  //刷新懒加载数据
  async refreshLazyData(){
    // this.booksDataSource.reloadNewData([this.bookData])
  }

}