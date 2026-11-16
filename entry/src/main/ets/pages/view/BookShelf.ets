import IndexShelf from './bookShelf/IndexShelf'

@Component
export default struct BookShelf {
  @State bookShelf: string = '书架'
  build(){
    Column(){
      IndexShelf()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(255, 255, 255, 0.8)')
  }
}