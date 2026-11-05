/**
 * @author 2008
 * @datetime 2024/8/05 22:34
 * @className: BookHistoryDao
 * 书籍浏览历史
 */
import DbUtil from '../../common/utils/DbUtil';
import AppDatabaseUtil from '../AppDatabaseUtil';
import { BookHistory } from '../entities/BookHistory';
import { BookHistoryTypeParams } from '../types/BookHistoryType';
import { ColumnInfo } from '../types/ColumnInfo';
import BooksDao from './BooksDao';
import { getPrivacyGeneration } from '../../privacy/PrivacyAccessGuard';
import { filterPublicHistories } from '../../privacy/PrivacyOwnershipLookup';

class BookHistoryDao {
  TABLE_NAME: string = 'book_history'

  // Standalone checks stay live; history IDs may differ from shelf IDs.
  async isPrivateHistory(history: BookHistory): Promise<boolean> {
    return (await BooksDao.loadPrivacyOwnership()).isPrivateHistory({
      id: history.id, originBookId: history.originBookId, bookUrl: history.bookUrl
    });
  }

  private async publicHistories(histories: BookHistory[], generation: number): Promise<BookHistory[]> {
    return await filterPublicHistories(histories, generation, () => BooksDao.loadPrivacyOwnership(), getPrivacyGeneration);
  }

  // 创建book_history数据表
  async initBookHistoryTable() {
    try {
      const createSql = AppDatabaseUtil.getCreateSql(this.TABLE_NAME);
      if (!createSql) {
        return
      }
      await DbUtil.createTable(createSql)
      AppDatabaseUtil.existsTable(this.TABLE_NAME)
      return
    } catch (err) {
      console.info('TagInfo', JSON.stringify(err))
    }
  }

  async search(params?: BookHistoryTypeParams): Promise<BookHistory[]> {
    const generation = getPrivacyGeneration();
    const type = params?.type
    const sort = params?.sort
    try {
      if (!DbUtil.rdbStore) return [];
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      let sql = `SELECT * FROM ${this.TABLE_NAME}`;
      // 动态添加 WHERE 子句
      let whereClause: string[] = [];
      if (type !== undefined){
        whereClause.push(`bookType = ${type} OR bookType = 123`);
      }
      // 如果有 where 子句，添加 WHERE 关键字
      if (whereClause.length > 0) {
        sql += ` WHERE ${whereClause.join(' AND ')}`;
      }
      sql += ` ORDER BY`;
      if (sort !== undefined) {
        sql += ` ${sort === 0 ? 'durChapterTime' : 'updateTime'} DESC`
      } else {
        sql += ` durChapterTime DESC`;
      }
      const bookHistoryDbList = await DbUtil.querySqlForList<BookHistory>(sql, column);

      return await this.publicHistories(bookHistoryDbList, generation)
    } catch (err) {
      console.log("TagInfo", JSON.stringify(err))
      return []
    }
  }
  async searchLimit(): Promise<BookHistory[]> {
    const generation = getPrivacyGeneration();
    try {
      if (!DbUtil.rdbStore) return [];
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      let sql = `SELECT * FROM ${this.TABLE_NAME}`;
      // 动态添加 WHERE 子句
      let whereClause: string[] = [];

      // 如果有 where 子句，添加 WHERE 关键字
      if (whereClause.length > 0) {
        sql += ` WHERE ${whereClause.join(' AND ')}`;
      }
      sql += ` ORDER BY durChapterTime DESC`;
      const bookHistoryDbList = await DbUtil.querySqlForList<BookHistory>(sql, column);
      // Apply the limit after filtering, so a private last-read row cannot hide public history.
      return (await this.publicHistories(bookHistoryDbList, generation)).slice(0, 1)
    } catch (err) {
      console.log("TagInfo", JSON.stringify(err))
      return []
    }
  }

  async insert(bookHistory: BookHistory, generation: number = getPrivacyGeneration()): Promise<boolean> {
    try {
      if (await this.isPrivateHistory(bookHistory)) return false;
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.equalTo('id', bookHistory.id)
      const count = await DbUtil.queryForCount(predicates, column)
      if (count > 0) return await this.update(bookHistory, generation);
      if (await this.isPrivateHistory(bookHistory) || getPrivacyGeneration() !== generation) return false;
      bookHistory.createTime = Date.now()
      await DbUtil.insert(this.TABLE_NAME, bookHistory, column)
      console.log('TagInfo', '创建成功')
      return true
    } catch (err) {
      console.log('TagInfo, Error, ', JSON.stringify(err))
      return false
    }
  }

  async update(bookHistory: BookHistory, generation: number = getPrivacyGeneration()): Promise<boolean> {
    try {
      if (await this.isPrivateHistory(bookHistory)) return false;
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.equalTo('id', bookHistory.id)
      const count = await DbUtil.queryForCount(predicates, column)
      if (count === 0 && bookHistory instanceof BookHistory) return await this.insert(bookHistory, generation);
      if (await this.isPrivateHistory(bookHistory) || getPrivacyGeneration() !== generation) return false;
      bookHistory.updateTime = Date.now()
      bookHistory.durChapterTime = Date.now()
      await DbUtil.update(predicates, bookHistory, column)
      return true
    } catch (err) {
      console.log('TagInfo, Error, ', JSON.stringify(err))
      return false
    }
  }

  //删除阅读历史记录
  async deleteBookHistory(id: number) {
    try {
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.equalTo('id', id)
      await DbUtil.delete(predicates)
      return true
    }  catch (err) {
      console.log('TagInfo, Error, ', JSON.stringify(err))
      return false
    }
  }

  async deleteAllBookHistory() {
    try {
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      await DbUtil.delete(predicates)
      return true
    }  catch (err) {
      console.log('TagInfo, Error, ', JSON.stringify(err))
      return false
    }
  }

}


const bookHistoryDao = new BookHistoryDao()
export default bookHistoryDao as BookHistoryDao