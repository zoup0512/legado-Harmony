
import { SearchBookList } from './SearchBookList'
import { SearchBook } from '../../database/entities/SearchBook'
import { ThemeItem } from '../../common/model/Theme'
import { ThemeStorageKey } from '../../common/constants/Theme'

@Component
export struct SearchDetails{
  @Prop SearchValue:string
  @State typeList: string[] = ["小说","漫画","有声书"]
  @State typeIndex:number=0
  @Consume('searchBookList') books:SearchBook[]
  @Consume('isSearch') isSearch:boolean
  // 主题颜色
  @StorageProp(ThemeStorageKey.THEME) theme: ThemeItem = {} as ThemeItem
  build() {
    Column(){
      //小说类型切换
      Row(){
        Row({space:30}){
          ForEach(this.typeList,(item:string,index:number)=>{
              Text(item)
                .fontSize(16)
                .fontColor(this.typeIndex==index?"#000000":$r('app.string.color_black_45'))
                .onClick(()=>{
                  this.typeIndex=index
                })
          })
        }.width("100%").height("100%")
      }.size({width:"100%",height:40}).padding({left:20,right:20}).margin(10)
      Text(`共搜索到${this.books.length}个相关结果`)
        .fontSize(14)
        .fontColor($r('app.string.color_black_45'))
        .padding({ left: 20, right: 20, bottom: 8 })
      //书籍列表
      SearchBookList({SearchValue:this.SearchValue,booksList:this.books,typeIndex:this.typeIndex,isSearch:this.isSearch})
        .backgroundColor("#ffffff")
        .layoutWeight(1)
        .border({ width: { top: this.isSearch ? 2 : 0 }, color: this.theme.mainColor })
    }
    .layoutWeight(1)
  }
}