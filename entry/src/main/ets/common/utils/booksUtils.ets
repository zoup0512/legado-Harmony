import BooksDao, { BookCoverPatch } from '../../database/dao/BooksDao'
import { Books, BOOK_SEARCH_TYPE } from '../../database/entities/Books'
import bookGroupUtils from './bookGroupUtils'
import toolsUtils from './ToolsUtils'
import { PRIVACY_BOOK_GROUP } from '../../privacy/PrivacyConstants'
import { capturePrivacyGeneration, isPrivacyGenerationValid } from '../../privacy/PrivacyAccessGuard'
import { PreferencesUtil } from '@pura/harmony-utils'
import Logger from './Logger'
import bookCoverStore from './BookCoverStore'

export const BOOK_NAME_MAX_LENGTH: number = 50

// 阅读进度、阅读设置以书名为 key 存储
const BOOK_PREFERENCE_KEY_PREFIXES: string[] = ['BookCurrentData_', 'ReaderSetting_']

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
      const covers = await BooksDao.getCoverPathsByIds(bookIds)
      if (!await BooksDao.deleteBook(bookIds, generation)) return false
      covers.forEach((path: string) => bookCoverStore.deleteCover(path))
      if (privateOperation && !isPrivacyGenerationValid(generation)) return false
      if (Object.keys(oldGroups).length > 0) bookGroupUtils.updateMoveBookIdsByGroupId(oldGroups)
      return !privateOperation || isPrivacyGenerationValid(generation)
    } catch (_) {
      return false
    }
  }

  /**
   * 修改书籍显示名称。书名同时是阅读进度/设置的存储 key，因此要求唯一，并迁移对应缓存
   * @returns 失败原因，成功返回 undefined
   */
  async renameBook(book: Books, newName: string,
    generation: number = capturePrivacyGeneration()): Promise<string | undefined> {
    const name = newName.trim()
    const oldName = book.bookName ?? ''
    if (name.length === 0) return '书名不能为空'
    if (name.length > BOOK_NAME_MAX_LENGTH) return `书名最长${BOOK_NAME_MAX_LENGTH}个字符`
    if (name === oldName) return undefined
    if (!book.id) return '修改失败'
    try {
      const lowerName = name.toLowerCase()
      const existing = await BooksDao.getExistingBookNames()
      if (lowerName !== oldName.trim().toLowerCase() &&
        existing.some((item: string) => item.trim().toLowerCase() === lowerName)) {
        return '书架中已有同名书籍'
      }
      if (!await BooksDao.updateBookName(book.id, name, generation)) return '修改失败'
      this.moveBookPreferences(oldName, name)
      return undefined
    } catch (_) {
      return '修改失败'
    }
  }

  /**
   * 设置用户自定义封面：传图片路径、TEXT_COVER（文字封面）或空串（恢复默认）
   * 成功后删除旧的自定义封面文件；失败时删除新写入的文件
   */
  async setCustomCover(book: Books, customCoverUrl: string,
    generation: number = capturePrivacyGeneration()): Promise<boolean> {
    const oldCover = book.customCoverUrl ?? ''
    if (!book.id) {
      if (customCoverUrl !== oldCover) bookCoverStore.deleteCover(customCoverUrl)
      return false
    }
    const patch: BookCoverPatch = { customCoverUrl: customCoverUrl }
    if (!await BooksDao.updateBookCover(book.id, patch, generation)) {
      if (customCoverUrl !== oldCover) bookCoverStore.deleteCover(customCoverUrl)
      return false
    }
    if (oldCover !== customCoverUrl) bookCoverStore.deleteCover(oldCover)
    book.customCoverUrl = customCoverUrl
    return true
  }

  private moveBookPreferences(oldName: string, newName: string): void {
    BOOK_PREFERENCE_KEY_PREFIXES.forEach((prefix: string) => {
      const oldKey = prefix + oldName
      const newKey = prefix + newName
      try {
        if (PreferencesUtil.hasSync(oldKey)) {
          PreferencesUtil.putSync(newKey, PreferencesUtil.getSync(oldKey, ''))
          PreferencesUtil.deleteSync(oldKey)
        } else if (PreferencesUtil.hasSync(newKey)) {
          // 清理同名旧书残留，避免被当作本书的数据
          PreferencesUtil.deleteSync(newKey)
        }
      } catch (_) {
        Logger.warn('booksUtil.moveBookPreferences failed')
      }
    })
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