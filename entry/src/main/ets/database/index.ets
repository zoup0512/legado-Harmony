import BookGroupsDao from './dao/BookGroupsDao'
import bookHistoryDao from './dao/BookHistoryDao'
import BooksDao from './dao/BooksDao'
import worksListsDao from './dao/WorksListsDao'

class DataBase {
  async initAllTable() {
    // 仅初始化本地书库；旧版书源、订阅和缓存表保留在数据库中，不删除用户数据。
    await BooksDao.initBooksTable()
    await BookGroupsDao.initGroupTable()
    await worksListsDao.initWorksListsTable()
    await bookHistoryDao.initBookHistoryTable()
  }
}

const dataBase = new DataBase()

export default dataBase as DataBase