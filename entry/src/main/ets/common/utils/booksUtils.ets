import BooksDao from '../../database/dao/BooksDao'
import { Books, BOOK_SEARCH_TYPE } from '../../database/entities/Books'
import bookGroupUtils from './bookGroupUtils'
import toolsUtils from './ToolsUtils'
import { PRIVACY_BOOK_GROUP } from '../../privacy/PrivacyConstants'
import { capturePrivacyGeneration, isPrivacyGenerationValid } from '../../privacy/PrivacyAccessGuard'

class booksUtils{
  async isTopBook(id: number | number[], isTop: boolean,
    generation: number = capturePrivacyGeneration()): Promise<boolean> {
    const ids = toolsUtils.numberArrays(id)
    try {
      const privateOperation = await BooksDao.isPrivateBookIds(ids)
      if (privateOperation && !isPrivacyGenerationValid(generation)) return false
      for (const bookId of ids) {
        if (privateOperation && !isPrivacyGenerationValid(generation)) return false
        if (!await BooksDao.isUpdateBookTop(bookId, isTop, generation)) return false
      }
      return !privateOperation || isPrivacyGenerationValid(generation)
    } catch (_) {
      return false
    }
  }
  async addBooks(books: Books, generation: number = capturePrivacyGeneration()): Promise<boolean> {
    try {
      if (await BooksDao.isPrivateBook(books) && !isPrivacyGenerationValid(generation)) return false
      books.isJoin = true
      books.bookGroup = books.bookGroup ?? 3
      return await BooksDao.insert(books, generation)
    } catch (_) {
      return false
    }
  }
  //校验当前书籍是否存在书架中
  async isExistBooks(bookUrl?:string,bookName?:string): Promise<boolean>{
    let books: Books[] = await BooksDao.isExistBooks(bookUrl, bookName)
    return books.length > 0
  }
  //更新部分书籍信息
  async partialUpdate(books: Books){
    await BooksDao.partialUpdate(books)
  }
  /**
   * @author 2008
   * @param id 需要移动的书籍Id
   * @param group 移动到的分组Id
   * updateBooks 书籍批量移动
   */
  async updateBooks(id: number | number[], group: number,
    generation: number = capturePrivacyGeneration()): Promise<boolean> {
    try {
      const bookIds = toolsUtils.numberArrays(id)
      const privateOperation = group === PRIVACY_BOOK_GROUP || await BooksDao.isPrivateBookIds(bookIds)
      if (privateOperation && !isPrivacyGenerationValid(generation)) return false
      const oldGroups = await BooksDao.getBookIdsByGroupId(bookIds)
      if (privateOperation && !isPrivacyGenerationValid(generation)) return false
      if (!await BooksDao.updateBookGroup(bookIds, group, generation)) return false
      if (privateOperation && !isPrivacyGenerationValid(generation)) return false
      // Group indexes must never change before the authoritative books mutation succeeds.
      if (Object.keys(oldGroups).length > 0) bookGroupUtils.updateMoveBookIdsByGroupId(oldGroups)
      await bookGroupUtils.updateAddBookIds(group, bookIds)
      return !privateOperation || isPrivacyGenerationValid(generation)
    } catch (_) {
      return false
    }
  }

  async delBooksById(id: number | number[],
    generation: number = capturePrivacyGeneration()): Promise<boolean> {
    try {
      const bookIds = toolsUtils.numberArrays(id)
      const privateOperation = await BooksDao.isPrivateBookIds(bookIds)
      if (privateOperation && !isPrivacyGenerationValid(generation)) return false
      const oldGroups = await BooksDao.getBookIdsByGroupId(bookIds)
      if (privateOperation && !isPrivacyGenerationValid(generation)) return false
      if (!await BooksDao.deleteBook(bookIds, generation)) return false
      if (privateOperation && !isPrivacyGenerationValid(generation)) return false
      if (Object.keys(oldGroups).length > 0) bookGroupUtils.updateMoveBookIdsByGroupId(oldGroups)
      return !privateOperation || isPrivacyGenerationValid(generation)
    } catch (_) {
      return false
    }
  }

  async getBookByIds(ids:number|number[]){
    let bookId: number[] = toolsUtils.numberArrays(ids)
    return await BooksDao.getBookByIds(bookId)
  }

  //校验类型数据查询数组内容
  getOrder(type:string){
    return BOOK_SEARCH_TYPE.indexOf(type) ?? 0;
  }
}
let booksUtil = new booksUtils();
export default booksUtil as booksUtils;