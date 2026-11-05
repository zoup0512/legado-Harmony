/**
 * Copyright (C), 2024-05-10
 * @author LinXun
 * @date 2024/5/10 13:24
 * @version 1.0
 * @description: 书籍详情页笔记内容
 */
@Component
export default struct NoteIndex {
  build() {
    Column() {
      Image($r('app.media.ic_public_none'))
        .width(200)
        .height(168)
      Text('笔记功能暂未提供')
        .fontSize(14)
        .fontWeight(400)
        .lineHeight(22)
        .fontColor('#73000000')
    }
  }
}
