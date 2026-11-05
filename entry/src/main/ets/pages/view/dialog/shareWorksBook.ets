/**
 * @author 2008
 * @datetime 2024/5/23 22:21
 * @className: shareShelfBook
 */
import InsideCircleIcon from '../../../componets/common/InsideCircleIcon'
import componentSnapshot from '@ohos.arkui.componentSnapshot'
import image from '@ohos.multimedia.image'
import fs from '@ohos.file.fs';
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { showMessage } from '../../../componets/common/promptShow'
import { abilityAccessCtrl, common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { WorksLists } from '../../../database/entities/WorksLists'
import worksListsUtils from '../../../common/utils/WorksListsUtils'
import BooksDao from '../../../database/dao/BooksDao'
import { Books } from '../../../database/entities/Books'
import PaddingConstants from '../../../common/constants/PaddingConstants'
import { LocalBookAccessLogic } from '../../../common/utils/LocalBookAccess'
import { getPrivacyGeneration } from '../../../privacy/PrivacyAccessGuard'

@CustomDialog
@Preview
@Component
export default struct shareWorksBook {
  controller?: CustomDialogController
  @Prop works:WorksLists
  @State bookList:Books[] = []
  @StorageLink('BOOK_IS_BOOK_REFRESHING') @Watch('onBooksChanged') bookRefresh: number = 0
  private active: boolean = false
  private requestId: number = 0

  onBooksChanged(): void {
    this.requestId++
    this.bookList = []
    this.controller?.close()
  }

  async aboutToAppear(): Promise<void> {
    this.active = true
    if (this.works.worksBookList) {
      const bookIds = worksListsUtils.getBookIds(this.works.worksBookList)
      if (bookIds.length > 0) await this.getBookIds(bookIds)
    }
  }

  aboutToDisappear(): void {
    this.active = false
    this.requestId++
    this.bookList = []
  }
  private appContext: common.Context = getContext(this);
  private atManager = abilityAccessCtrl.createAtManager();
  async getBookIds(ids: number[]): Promise<void> {
    const requestId = ++this.requestId
    const generation = getPrivacyGeneration()
    this.bookList = []
    try {
      const books = await BooksDao.getBookByIds(ids)
      const publicBooks: Books[] = []
      for (const book of books) {
        if (!await BooksDao.isPrivateBook(book)) publicBooks.push(book)
      }
      if (this.active && requestId === this.requestId && generation === getPrivacyGeneration()) {
        this.bookList = publicBooks
      }
    } catch (_) {
      if (requestId === this.requestId) this.bookList = []
    }
  }

  build() {
    Stack() {
      Rect()
        .height('100%')
        .width('100%')
        .backgroundColor(Color.Black)
        .onClick(() => {
          this.controller?.close()
        })
        .opacity(0.15)
        .zIndex(1)
      Flex({
        direction:FlexDirection.Column,
        justifyContent:FlexAlign.SpaceBetween
      }){
        Column({
          space:PaddingConstants.PADDING_10
        }){
          Text(this.works.worksName)
            .textAlign(TextAlign.Center)
            .fontSize(16).fontWeight(500).lineHeight(24).fontColor($r('app.string.color_black_88'))
          Text(this.works.worksDescribe)
            .textAlign(TextAlign.Center)
            .fontSize(12).fontWeight(400).lineHeight(20).fontColor($r('app.string.color_black_88'))
          Column({
            space:PaddingConstants.PADDING_15
          }){
            ForEach(this.bookList,(item:Books,index)=>{
              this.BookShelfInfo(item,index)
            })
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
      .margin(40)
      .padding({ top: 24, left: 20, right: 20, bottom: 24 })
      .backgroundColor(Color.White)
      .zIndex(2)
      //用于图片保存不做显示
      Column(){
        Column({
          space:10
        }){
          Text(this.works.worksName)
            .textAlign(TextAlign.Center)
            .fontSize(16)
            .fontWeight(500)
            .lineHeight(24)
            .fontColor($r('app.string.color_black_88'))
          Text(this.works.worksDescribe)
            .textAlign(TextAlign.Center)
            .fontSize(12)
            .fontWeight(400)
            .lineHeight(20)
            .fontColor($r('app.string.color_black_88'))

          Column({
            space:PaddingConstants.PADDING_15
          }){
            ForEach(this.bookList.slice(0, 4),(item:Books,index)=>{
              this.BookShelfInfo(item,index)
            })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ top: 24, left: 20, right: 20, bottom: 24 })
        .backgroundColor('#FFF7EC')
        this.footerSaveImage()
      }
      .id('shareBook')
      .margin(40)
      .position({y: 0})
      .visibility(Visibility.Hidden)

      Column() {
        Column() {
          Row().width(36).height(4).backgroundColor($r('app.string.color_black_15')).borderRadius(12)
        }
        .padding({ top: 12, bottom: 28 })

        InsideCircleIcon({
          icon: $r('app.media.save_img'),
          title: '保存图片'
        }).onClick(() => {
          this.requestPermissionSaveImage();
        })
      }
      .zIndex(3)
      .borderRadius({ topLeft: 20, topRight: 20 })
      .backgroundColor(Color.White)
    }
    .align(Alignment.Bottom)
  }
  @State pixmap: image.PixelMap | undefined = undefined
  //申请权限,保存图片
  async requestPermissionSaveImage() {
    try {
      this.atManager.requestPermissionsFromUser(this.appContext,['ohos.permission.WRITE_IMAGEVIDEO']).then(async ()=>{
       componentSnapshot.get('shareBook').then((pixmap: image.PixelMap)=>{
          this.pixmap = pixmap
          const imagePackerApi = image.createImagePacker();
          let packOpts : image.PackingOption = { format:"image/jpeg", quality:98 };

          imagePackerApi.packing(pixmap, packOpts).then(async (data : ArrayBuffer) => {
            let context = getContext();
            let helper = photoAccessHelper.getPhotoAccessHelper(context);
            let uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg');
            let file = await fs.open(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
            await fs.write(file.fd, data);
            await fs.close(file.fd);
            showMessage('保存成功');
          }).catch((error : BusinessError) => {
            showMessage('保存失败,未获取权限');
            console.error('Failed to pack the image. And the error is: ' + error);
          })
        });
      })
    } catch (e) {
      showMessage('保存失败,未获取权限');
    }
  }

  @Builder footerSaveImage(){
    Flex({
      justifyContent:FlexAlign.SpaceBetween,
      direction:FlexDirection.Row,
      alignItems:ItemAlign.Center
    }
    ){
      Column(){
        Row({
          space:5
        }){
          Image($r('app.media.legado_icon')).width(32).height(20)
          Image($r('app.media.legado')).width(65).height(15)
        }
        Text('扫描二维码下载 开源阅读').fontSize(10).fontWeight(400).lineHeight(18).textAlign(TextAlign.Center)
      }
      Image($r('app.media.QR_Code')).width(46).height(46)
    }
    .backgroundColor(Color.White)
    .padding({ top: 24,bottom:24, left: 20, right: 20 })
  }


  @Builder BookShelfInfo(book:Books,index:number){
    Column(){
      Row({
        space:PaddingConstants.PADDING_10
      }){
        Image(LocalBookAccessLogic.selectLocalCover(book.coverUrl, $r('app.media.icon_book_default_cover_one')))
          .draggable(false)
          .alt($r('app.media.icon_book_default_cover_one'))
          .width(69)
          .height(92)

        Column({
          space:10
        }) {
          Text(book.bookName).fontSize(16).fontWeight(500).lineHeight(24)
            .textOverflow({
              overflow:TextOverflow.Ellipsis
            })
            .ellipsisMode(EllipsisMode.END)
            .maxLines(2)
            .position({y: 0})
          Text(book.intro)
            .fontSize(12)
            .lineHeight(20)
            .fontColor('rgba(0, 0, 0, 0.45)')
            .textOverflow({
              overflow:TextOverflow.Ellipsis
            })
            .height(50)
            .ellipsisMode(EllipsisMode.END)
            .maxLines(2)
          if (book.author?.trim()) {
            Text(book.author).fontSize(10).fontWeight(400).fontColor($r('app.string.color_black_45'))
          }
        }
      }

      if (this.works.worksBookList && this.works.worksBookList[index].recommend){
        Column(){
          Text(this.works.worksBookList[index].recommend ?? '')
            .padding({
              top:PaddingConstants.PADDING_8,
              bottom:PaddingConstants.PADDING_8,
              left:PaddingConstants.PADDING_12,
              right:PaddingConstants.PADDING_12
            })
        }
        .borderRadius(8)
        .margin({
          top:PaddingConstants.PADDING_16
        })
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .backgroundColor($r('app.string.color_black_4'))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}