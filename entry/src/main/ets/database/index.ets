import BookGroupsDao from './dao/BookGroupsDao'
import BooksDao from './dao/BooksDao'
import worksListsDao from './dao/WorksListsDao'
import DbUtil from '../common/utils/DbUtil'
import Logger from '../common/utils/Logger'

// 书架不再区分小说/漫画/有声书，旧数据统一归为 0（小说）。123 是系统分组/记录的公共类型，保持不变。
const BOOK_TYPE_MIGRATIONS: string[] = [
  'UPDATE books SET bookType = 0 WHERE bookType != 0',
  'UPDATE book_groups SET groupType = 0 WHERE groupType != 0 AND groupType != 123',
  'UPDATE works_lists SET worksType = 0 WHERE worksType != 0',
]

class DataBase {
  async initAllTable() {
    // 仅初始化本地书库；旧版书源、订阅、缓存和阅读历史表保留在数据库中，不再读写。
    await BooksDao.initBooksTable()
    await BookGroupsDao.initGroupTable()
    await worksListsDao.initWorksListsTable()
    await this.migrateBookTypes()
  }

  // 幂等：已经全是 0 时不会改动任何行，每次启动执行即可
  private async migrateBookTypes() {
    for (const sql of BOOK_TYPE_MIGRATIONS) {
      try {
        await DbUtil.executeSql(sql)
      } catch (err) {
        Logger.error('DataBase.migrateBookTypes failed', Logger.errorSummary(err))
      }
    }
  }
}

const dataBase = new DataBase()

export default dataBase as DataBase