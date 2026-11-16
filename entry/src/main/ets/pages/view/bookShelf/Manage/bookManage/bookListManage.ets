import BookInfoManage from './BookInfoManage'
import BookInfoGridManage from './BookInfoGridManage'
import { Books } from '../../../../../database/entities/Books'
import ThemedEmptyImage from '../../../../../componets/common/ThemedEmptyImage'
import { AdaptiveLayout } from '../../../../../common/utils/AdaptiveLayout'

@Component
export default struct bookListManage{
  @Prop EXHIBIT:string
  @Prop bookList:Books[]
  @Prop isManage:boolean = true
  @Link checkGroup:Record<number, boolean>
  @State delCache:boolean = false
  @State contentWidth: number = 0

  private gridCoverWidth(): number {
    return this.contentWidth > 0 ?
      Math.max(1, Math.min(100, this.contentWidth / AdaptiveLayout.shelfColumns(this.contentWidth) - 16)) : 100
  }
  onSelect:Function = () => {}
  build() {
    if (this.bookList === null || this.bookList.length === 0) {
      Column() {
        ThemedEmptyImage({ imageSize: 140 }).margin({ bottom: 16 })
        Text('书架暂无书籍').fontSize(12).fontColor('rgba(96, 96, 96, 0.6)').fontWeight(500).padding(5)
      }
      .margin({ top: 120 })

    } else {
      Column(
        {space:10}
      ){
        if (this.EXHIBIT === '宫格') {
         GridRow({
           columns: AdaptiveLayout.shelfColumns(this.contentWidth)
         }){
           ForEach(this.bookList, (item: Books,index:number) => {
             GridCol(){
               BookInfoGridManage({
                 bookData:item,
                 coverWidth: this.gridCoverWidth(),
                 isManage:this.isManage,
                 checkGroup:this.checkGroup,
                 onSelect: ()=>{
                   this.onSelect()
                 }
               })
             }
           })
         }
        } else {
          Column({
            space: 10
          }) {
            ForEach(this.bookList, (item: Books,index:number) => {
              BookInfoManage({
                bookData:item,
                isManage:this.isManage,
                checkGroup:this.checkGroup,
                onSelect: ()=>{
                  this.onSelect()
                }
              })
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