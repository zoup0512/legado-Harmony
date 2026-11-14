import { pickerAvatar } from '../../../../../common/utils/photoViewPicker'
import coverInfoImageShow from '../../../coverInfoImageShow'
import { BookGroups } from '../../../../../database/entities/BookGroups'
import { showMessage } from '../../../../../componets/common/promptShow'
import buttonCommon from '../../../../../componets/common/buttonCommon'
import bookGroupUtil from '../../../../../common/utils/bookGroupUtils'
import { ThemeItem } from '../../../../../common/model/Theme'
import { ThemeStorageKey } from '../../../../../common/constants/Theme'
import bookCoverStore from '../../../../../common/utils/BookCoverStore'

@CustomDialog
/**
 * 封面弹窗
 */
@Preview
export default struct coverInfoDialog{
  controller?: CustomDialogController
  //推送提醒
  @Prop itemData:BookGroups
  @State coverImages:string = ''
  @StorageLink('BOOK_IS_BOOK_GROUPS_REFRESHING') BOOK_IS_BOOK_GROUPS_REFRESHING: number = 0
  cancel: () => void = () => {
  }
  // 打开弹窗时的封面；确认后若已更换则删除旧文件，取消则删除本次新选的文件
  private originalCover: string = ''
  private saved: boolean = false
  aboutToAppear(): void {
    this.coverImages = this.itemData.coverUrl??''
    this.originalCover = this.coverImages
  }
  aboutToDisappear(): void {
    if (!this.saved && this.coverImages !== this.originalCover) {
      bookCoverStore.deleteCover(this.coverImages)
    }
  }
  @State coverFolder:boolean = false
  // 主题颜色
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem
  build() {
    Column(){
      Flex({
        justifyContent:FlexAlign.SpaceBetween,
        alignItems:ItemAlign.Center
      }){
        Column(){
          Text(this.itemData.groupName).fontColor('rgba(0, 0, 0, 0.88)').fontSize(16).fontWeight(500).lineHeight(24)
          Text(`共${0}本`).fontColor('rgba(0, 0, 0, 0.45)').fontWeight(400).lineHeight(20).fontSize(12)
        }
        Row(){
          Text('仅用于当前分组')
          Toggle({ type: ToggleType.Switch, isOn: this.itemData.coverOnly})
            .selectedColor("#F60").hoverEffect(HoverEffect.None)
            .onChange((val)=>{
              this.itemData.coverOnly = val
            })
        }
      }.padding(20)
      Divider().strokeWidth(0.5)
      Flex({
        direction: FlexDirection.Row,
        justifyContent:FlexAlign.SpaceBetween
      }){
        coverInfoImageShow({
          coverCount:1,
          image:this.itemData.coverUrl,
          selectImage:this.itemData.coverType??0,
          onSelectImageNumber:(number:number)=>{
            this.itemData.coverType = number
          }
        })
        coverInfoImageShow({
          coverCount:2,
          imageString:this.coverImages,
          selectImage:this.itemData.coverType??0,
          onSelectImageNumber:(number:number)=>{
            this.itemData.coverType = number
          }
        }).onClick(()=>{
          this.setCoverImages()
        })
        coverInfoImageShow({
          coverCount:3,
          imageString:this.coverImages,
          selectImage:this.itemData.coverType??0,
          onSelectImageNumber:(number:number)=>{
            this.itemData.coverType = number
          }
        }).onClick(()=>{
          this.setCoverImages()
        })
      }.padding(20)
      Divider().strokeWidth(0.5).padding({bottom:16})
      Column(){
        Flex({
          justifyContent:FlexAlign.SpaceBetween
        }) {
          Column(){
            Text('取消').fontSize(16).fontWeight(400).fontColor(this.theme.mainColor)
              .lineHeight(24)
              .padding({left:32,right:32,bottom:8,top:8})
          }
          .onClick(()=>{
            this.cancel()
          })
          .width('49%')
          .borderRadius(20)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(this.theme.secondColor)
          Column(){
            Text('确定')
              .fontSize(16)
              .fontWeight(400)
              .fontColor(Color.White)
              .lineHeight(24)
              .padding({left:32,right:32,bottom:8,top:8})
              .onClick(async ()=>{
                this.saved = true
                if (this.coverImages !== this.originalCover) {
                  bookCoverStore.deleteCover(this.originalCover)
                }
                bookGroupUtil.updatePartialGroup(this.itemData)
                setTimeout(()=>{
                  this.BOOK_IS_BOOK_GROUPS_REFRESHING++
                  this.controller?.close()
                  showMessage('修改成功!')
                },100)
              })
          }
          .width('49%')
          .borderRadius(20)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(this.theme.mainColor)
        }
      }
      .alignItems(HorizontalAlign.Center)
      .padding({right:20,left:20,bottom:16})
    }
    .borderRadius({topLeft:20,topRight:20})
    .backgroundColor(Color.White)
    .width('100%')
  }

  // 相册授权是临时的：复制一份到应用私有目录再保存
  async setCoverImages(){
    let imageUrl = await pickerAvatar();
    const uri = imageUrl?.photoUris[0] || ''
    if (uri.length === 0) return
    const cover = await bookCoverStore.importImage(uri)
    if (cover.length === 0) {
      showMessage('图片读取失败，请换一张试试')
      return
    }
    if (this.coverImages !== this.originalCover) {
      bookCoverStore.deleteCover(this.coverImages)
    }
    this.coverImages = cover
    this.itemData.coverUrl = this.coverImages
  }
}