/**
 * @author 2008
 * @datetime 2024/7/25 13:44
 * @className: BookSelectGroupDialog
 * 移动分组弹窗
 */
import CommonConstants from '../../../../../common/constants/CommonConstants'
import PaddingConstants from '../../../../../common/constants/PaddingConstants'
import booksUtils from '../../../../../common/utils/booksUtils'
import addBookTypeDialog from '../../../../../componets/common/addBookTypeDialog'
import { showMessage } from '../../../../../componets/common/promptShow'
import TitleContentDialog from '../../../../../componets/common/TitleContentDialog'
import BookGroupsDao from '../../../../../database/dao/BookGroupsDao'
import { BookGroups } from '../../../../../database/entities/BookGroups'
import BooksDao from '../../../../../database/dao/BooksDao'
import toolsUtils from '../../../../../common/utils/ToolsUtils'
import privacySessionService from '../../../../../privacy/PrivacySessionService'

@Component
@CustomDialog
export default struct BookSelectGroupDialog{
  oldGroupId?:number
  controller?: CustomDialogController
  currentIndex:number = 0
  Ids:number|number[] = 0
  isMoveStatus:number = 0
  moveGroup:Function = ()=>{

  }
  @StorageLink('BOOK_IS_BOOK_GROUPS_REFRESHING') BOOK_IS_BOOK_GROUPS_REFRESHING: number = 0
  aboutToAppear(): void {
    this.getGroupList()
  }

  @State groupList:BookGroups[] = []
  getGroupList(){
    BookGroupsDao.search({
      type:this.currentIndex
    }).then((val)=>{
      this.groupList = val
    })
  }

  build() {
    Column() {
      Column(){
        Text('移动分组')
          .fontSize(16)
          .fontWeight(700)
          .lineHeight(24)

      }.padding({right:20,left:20,top:12,bottom:12})

      Divider().strokeWidth(0.5)
      Scroll(){
        GridRow({
          columns:3
        }){
          GridCol(){
            this.title()
          }
          ForEach(this.groupList,(item:BookGroups)=>{
            if (item.groupId && !item.isSystem && item.show && this.oldGroupId !== item.groupId) {
              GridCol(){
                this.title(item)
              }
            }
          })
        }.padding(PaddingConstants.PADDING_20)
      }
      .align(Alignment.Top)
      .height('65%')
      .scrollBar(BarState.Off)
      Divider().strokeWidth(0.5)
      Column() {
        Text('取消').fontSize(16).fontWeight(400)
          .lineHeight(24)
      }
      .onClick(()=>{
        this.controller?.close()
      })
      .alignItems(HorizontalAlign.Center)
      .padding({
        left: 32,
        right:32,
        top: 16
      })
    }
    .width(CommonConstants.FULL_WIDTH)
    .height(CommonConstants.FULL_HEIGHT)
  }
  @State moveGroupId:number = 0
  @State moveTitle:string = ''
  @Builder title(item?:BookGroups) {
    Column() {
      if (item){
        Text(item.groupName).fontSize(14).textOverflow({
          overflow:TextOverflow.Ellipsis
        }).ellipsisMode(EllipsisMode.END).maxLines(1)
      } else {
        Image($r('app.media.add')).width(24)
      }
    }
    .onClick(()=>{
      if(!item){
        this.addBookType?.open()
        return
      }
      if (item.groupId) {
        this.moveGroupId = item.groupId
        this.moveTitle = item.groupName
        this.clickBookTypeDialog?.open()
      }
    })
    .margin({
      bottom:PaddingConstants.PADDING_16
    })
    .width(85).height(36)
    .backgroundColor('rgba(0, 0, 0,0.06)')
    .padding({
      left:16,
      right:16,
      top:8,
      bottom:8
    })
  }
  //添加分组弹窗
  @State bookType:string = ''
  addBookType: CustomDialogController | null = new CustomDialogController({
    builder: addBookTypeDialog({
      cancel: ()=> { this.onCancel() },
      confirm: ()=> { this.onAccept() },
      bookType: this.bookType
    }),
    cancel: this.onCancel,
    autoCancel: true,
    alignment: DialogAlignment.Center,
    gridCount: 4,
    customStyle: false,
    cornerRadius: 25
  })
  //取消
  onCancel(){
    this.bookType = ''
  }
  //确定
  onAccept(){
    if (this.bookType.length === 0) {
      showMessage('分组名称不能为空')
      return
    }
    let isInsert = true
    //对比bookType看是否BooTypeList数组中存在
    this.groupList.forEach((element:BookGroups) => {
      if (element.groupName === this.bookType) {
        showMessage(`已存${this.bookType}分组`)
        this.bookType= ''
        isInsert = false
      }
    })
    if(isInsert){
      let bookGroups = new BookGroups()
      bookGroups.groupName = this.bookType
      bookGroups.groupType = this.currentIndex
      BookGroupsDao.insert(bookGroups)
      this.bookType= ''
      showMessage(`已添加${this.bookType}分组`)
      setTimeout(()=>{
        this.BOOK_IS_BOOK_GROUPS_REFRESHING++
        this.getGroupList()
      },500)
    }
  }

  //是否确认移动分组
  clickBookTypeDialog: CustomDialogController | null = new CustomDialogController({
    builder: TitleContentDialog({
      confirm: async ()=> {
        if (await this.clickBookAccept()) this.moveGroup()
      },
      title:`移动分组至${this.moveTitle}`
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    gridCount: 4,
    customStyle: false,
    cornerRadius: 25,
  })

  async clickBookAccept(): Promise<boolean> {
    try {
      let ids = toolsUtils.numberArrays(this.Ids)
      if (this.isMoveStatus === 1) {
        // 99 is not a normal manageable group, even from a stale group picker.
        if (ids.includes(99)) return false
        ids = await BooksDao.queryBooksByGroupId(ids)
      }
      if (this.isMoveStatus !== 0 && this.isMoveStatus !== 1) return false
      const privateOperation = this.oldGroupId === 99 || this.moveGroupId === 99 ||
        await BooksDao.isPrivateBookIds(ids)
      if (privateOperation && !await privacySessionService.unlock(this.getUIContext())) return false
      const generation = privacySessionService.getGeneration()
      if (privateOperation && !privacySessionService.isUnlocked()) return false
      if (!await booksUtils.updateBooks(ids, this.moveGroupId, generation)) return false
      if (generation !== privacySessionService.getGeneration() ||
        (privateOperation && !privacySessionService.isUnlocked())) return false
      showMessage(`已移动到${this.moveTitle}`)
      return true
    } catch (_) {
      return false
    }
  }

}