import FontConstants from '../../../../../common/constants/FontConstants'
import { ThemeStorageKey } from '../../../../../common/constants/Theme'
import { ThemeItem } from '../../../../../common/model/Theme'
import { Books } from '../../../../../database/entities/Books'
import BookCover from '../../../../../componets/common/BookCover'

@Component


export default struct BookInfoManage{
  @Prop isManage:boolean
  @Prop bookData:Books
  @Link checkGroup:Record<number, boolean>
  onSelect:Function = () => {}
  // 主题颜色
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem
  build() {
    Flex(
      {
        alignItems:ItemAlign.Center,
        justifyContent:FlexAlign.SpaceBetween
      }
    ) {
      Row({
        space:20
      }){
        Stack(){
          Stack(){
            if (this.bookData.isTop){
              Text('置顶').fontColor(Color.White).fontWeight(FontConstants.FONT_WEIGHT_400).fontSize(9).padding(3).borderRadius(5)
                .backgroundColor('rgba(0, 0, 0, 0.45)').zIndex(1)
            }
            BookCover({
              coverUrl: this.bookData.coverUrl ?? '',
              customCoverUrl: this.bookData.customCoverUrl ?? '',
              bookName: this.bookData.bookName ?? '',
              author: this.bookData.author ?? '',
              coverWidth: 60,
              coverHeight: 80
            })
          }
          .alignContent(Alignment.BottomStart)
        }
        .alignContent(Alignment.TopEnd)

        Column({
          space:24
        })
        {
          Text(this.bookData.bookName)
            .fontWeight(700)
          Column(){
            Text(this.bookData.intro).fontSize(12).fontColor('rgb(174,174,174)')
              .textOverflow({
                overflow:TextOverflow.Ellipsis
              })
              .ellipsisMode(EllipsisMode.END)
              .fontWeight(500)
              .maxLines(1)
            Text(this.bookData.durChapterTitle).fontSize(12).fontColor('rgb(174,174,174)')
              .textOverflow({
                overflow:TextOverflow.Ellipsis
              })
              .ellipsisMode(EllipsisMode.END)
              .fontWeight(500)
              .maxLines(1)
          }
          .width('40%')
          .alignItems(HorizontalAlign.Start)
        }
        .alignItems(HorizontalAlign.Start)
      }
      if (this.isManage){
        Row() {
          Checkbox({
            name: JSON.stringify(this.bookData.id)
          })
            .onClick(()=>{
              this.onSelect()
            })
            .select(this.bookData.id?this.checkGroup[this.bookData.id] ?? false:false)
            .onChange((val:boolean)=>{
              if (this.bookData.id) {
                this.checkGroup[this.bookData.id] = val
              }
            })
            .selectedColor(this.theme.mainColor)
            .unselectedColor('rgba(0, 0, 0, 0.35)')
        }
        .padding({ left: 15, right: 15, bottom: 5, top: 5 })
      }
    }
    .padding(10)
    .borderRadius(10)
  }
}