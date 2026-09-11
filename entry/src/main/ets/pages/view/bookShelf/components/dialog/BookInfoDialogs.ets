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
import ServerApi, { SERVER_SHELF_ORIGIN } from '../../../../../common/utils/ServerApi'
import privacyFolderService, { PRIVACY_BOOK_GROUP } from '../../../../../privacy/PrivacyFolderService'
import { common } from '@kit.AbilityKit'

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

  aboutToAppear(): void {
    // 隐私分组的书籍（如隐私文件夹内长按）额外提供“移出隐私”操作
    if (this.bookData && this.bookData.bookGroup === PRIVACY_BOOK_GROUP) {
      this.buttonListInfo.push(new buttonList(5, '移出隐私', $r('app.media.folder')))
    }
  }

  //移出隐私文件夹（回到未分组书架）
  async moveOutPrivacy() {
    if (this.bookData.id) {
      await privacyFolderService.moveOut(this.bookData)
    }
    setTimeout(() => {
      this.isBookRefreshing++
      this.controller?.close()
    }, 200)
    showMessage('已移出至未分组书架')
  }

  @StorageLink('topRectHeight') topRectHeight: number = 0
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @State isCatalogAddShelf:boolean = false

  build() {
    Column(){
      Row(){
        Row({
          space:CommonConstants.SPACE_12
        }){
          Image(this.bookData.coverUrl)
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
        } .onClick(async ()=>{
          // 服务器书不进入依赖 ReaderKit 远端 URL 的详情页，直接下载/打开本地缓存
          if (this.bookData.origin === SERVER_SHELF_ORIGIN) {
            try {
              const context = this.getUIContext().getHostContext() as common.UIAbilityContext
              const local = await ServerApi.ensureLocalBook(context, this.bookData)
              router.pushUrl({
                url: 'pages/view/Reader/ReaderPage3', params: { bookData: local }
              })
            } catch (e) {
              showMessage('服务器书下载失败：' + (e instanceof Error ? e.message : '网络错误'))
            }
            this.controller?.close()
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

  bookInfoButton(id:number){
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
        this.moveOutPrivacy(); break;
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

  deleteGroup() {
    this.deleteBook()
    this.cancel()
  }

  exitApp() {
    this.bookDelDialog?.close()
  }
  @StorageLink('BOOK_IS_BOOK_REFRESHING') isBookRefreshing: number = 0

  async deleteBook(){
    if (this.bookData.id){
      booksUtil.delBooksById(this.bookData.id)
    }
    // let index = this.booksDataSource.getIndex(this.bookData)
    // this.booksDataSource.deleteData(index)
    setTimeout(()=>{
      this.isBookRefreshing++
      this.controller?.close()
    },200)
    showMessage('删除成功')
  }

  async isTopBook(){
    if (this.bookData.id){
      booksUtil.isTopBook(this.bookData.id, !this.bookData.isTop).then((val)=>{
        val?showMessage(!this.bookData.isTop?'置顶成功':'取消置顶成功'):showMessage('数据更新失败')
      })
    }
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
    setTimeout(()=>{
      this.isBookRefreshing++
      this.controller?.close()
    },200)

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