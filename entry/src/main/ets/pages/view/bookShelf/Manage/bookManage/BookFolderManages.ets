import confirmDialogExample from '../../../../../componets/common/confirmDialog'
import { showMessage } from '../../../../../componets/common/promptShow'
import { BookGroups } from '../../../../../database/entities/BookGroups'
import BookFolderGridManage from './BookFolderGridManage'
import BookFolderInfoManage from './BookFolderInfoManage'
import ThemedEmptyImage from '../../../../../componets/common/ThemedEmptyImage'
import { AdaptiveLayout } from '../../../../../common/utils/AdaptiveLayout'

@Component
export default struct BookFolderManages {
  @Prop bookGroups:BookGroups[] = []
  @Link checkGroup:Record<number, boolean>
  @Prop EXHIBIT:string
  @State delCache:boolean = false
  @State contentWidth: number = 0

  private gridCoverWidth(): number {
    return this.contentWidth > 0 ?
      Math.max(1, Math.min(100, this.contentWidth / AdaptiveLayout.shelfColumns(this.contentWidth) - 16)) : 100
  }

  @Prop isManage:boolean = true
  onSelect:Function = () => {}
  bookInfoDel: CustomDialogController | null = new CustomDialogController({
    builder: confirmDialogExample({
      cancel: ()=> { this.onCancel() },
      confirm: ()=> { this.onAccept() },
      delCache:this.delCache
    }),
    cancel: this.exitApp,
    autoCancel: true,
    alignment: DialogAlignment.Center,
    gridCount: 4,
    customStyle: false,
    cornerRadius: 25,
  })

  onCancel() {
    // this.isClear = false
  }

  onAccept() {
    this.deleteFolder()
  }

  exitApp() {
    // this.isClear = false
  }

  deleteFolder() {
    showMessage('删除成功')
  }

 build() {
   if (this.bookGroups === null || this.bookGroups.length === 0) {
     Column() {
       ThemedEmptyImage({ imageSize: 140 }).margin({ bottom: 16 })
       Text('暂无分组').fontSize(12).fontColor('rgba(96, 96, 96, 0.6)').fontWeight(500).padding(5)
     }
     .margin({ top: 120 })
   } else {
     Column(){
       if (this.EXHIBIT === '列表') {
         ForEach(this.bookGroups, (item: BookGroups) => {
           if (item.show && !item.isSystem) {
             BookFolderInfoManage({
               group:item,
               checkGroup:this.checkGroup,
               isManage:this.isManage,
               onSelect:()=>{
                 this.onSelect()
               }
             })
           }
         })
       } else {
         GridRow({
           columns: AdaptiveLayout.shelfColumns(this.contentWidth)
         }){
           ForEach(this.bookGroups, (item: BookGroups) => {
             if (item.show && !item.isSystem) {
               GridCol(){
                 BookFolderGridManage({
                   group:item,
                   coverWidth: this.gridCoverWidth(),
                   checkGroup:this.checkGroup,
                   isManage:this.isManage,
                   onSelect:()=>{
                     this.onSelect()
                   }
                 })
               }
             }
           })
         }
       }
     }
     .width('100%')
     .onAreaChange((_oldArea: Area, area: Area) => {
       this.contentWidth = Number(area.width)
     })
   }
 }
}