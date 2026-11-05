import booksUtils from '../../common/utils/booksUtils';
import DbUtil from '../../common/utils/DbUtil';
import toolsUtils from '../../common/utils/ToolsUtils';
import AppDatabaseUtil from '../AppDatabaseUtil';
import { Books } from '../entities/Books';
import { BooksTypeSearchParams } from '../types/BooksType';
import { ColumnInfo } from '../types/ColumnInfo';
import { capturePrivacyGeneration, isPrivacyGenerationValid } from '../../privacy/PrivacyAccessGuard';
import { PRIVACY_BOOK_GROUP } from '../../privacy/PrivacyConstants';
import { PrivacyBookIdentity, PrivacyOwnershipLookup } from '../../privacy/PrivacyOwnershipLookup';

// Leave room for the group predicate below SQLite's bind-parameter limit.
const PRIVACY_ID_QUERY_CHUNK_SIZE: number = 500;

class BooksDao {
  TABLE_NAME: string = 'books'

  // Authorization queries deliberately propagate errors: unknown is not public.
  async hasPrivacyBooks(): Promise<boolean> {
    if (!DbUtil.rdbStore) throw new Error('Privacy ownership database unavailable');
    const predicates = DbUtil.getPredicates(this.TABLE_NAME);
    predicates.equalTo('bookGroup', PRIVACY_BOOK_GROUP).limitAs(1);
    const column = AppDatabaseUtil.getAssignColumn(this.TABLE_NAME, ['id']);
    return (await DbUtil.queryForList<Books>(predicates, column)).length > 0;
  }

  // Callers own this snapshot for one operation; never retain it on the DAO or session.
  async loadPrivacyOwnership(): Promise<PrivacyOwnershipLookup> {
    if (!DbUtil.rdbStore) throw new Error('Privacy ownership database unavailable');
    const predicates = DbUtil.getPredicates(this.TABLE_NAME);
    predicates.equalTo('bookGroup', PRIVACY_BOOK_GROUP);
    const column = AppDatabaseUtil.getAssignColumn(this.TABLE_NAME, ['id', 'bookUrl']);
    return new PrivacyOwnershipLookup(await DbUtil.queryForList<PrivacyBookIdentity>(predicates, column));
  }

  async isPrivateBook(book: Books): Promise<boolean> {
    if (book.bookGroup === PRIVACY_BOOK_GROUP) return true;
    return (await this.loadPrivacyOwnership()).isPrivateBook({
      id: book.id, bookUrl: book.bookUrl, bookGroup: book.bookGroup
    });
  }

  // Direct persisted IDs only: unlike book/history checks, this does not expand path aliases.
  async isPrivateBookIds(ids: number[]): Promise<boolean> {
    if (ids.length === 0) return false;
    const column = AppDatabaseUtil.getAssignColumn(this.TABLE_NAME, ['id']);
    for (let offset = 0; offset < ids.length; offset += PRIVACY_ID_QUERY_CHUNK_SIZE) {
      if (!DbUtil.rdbStore) throw new Error('Privacy ownership database unavailable');
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.equalTo('bookGroup', PRIVACY_BOOK_GROUP);
      predicates.in('id', ids.slice(offset, offset + PRIVACY_ID_QUERY_CHUNK_SIZE)).limitAs(1);
      if ((await DbUtil.queryForList<Books>(predicates, column)).length > 0) return true;
    }
    return false;
  }

  private async canWriteBook(book: Books, generation: number): Promise<boolean> {
    const privateBook = await this.isPrivateBook(book);
    return !privateBook || isPrivacyGenerationValid(generation);
  }

  // 创建books数据表
  async initBooksTable() {
    try {
      const createSql = AppDatabaseUtil.getCreateSql(this.TABLE_NAME);
      if (!createSql) {
        return
      }
      await DbUtil.createTable(createSql)
      await AppDatabaseUtil.existsTable(this.TABLE_NAME)
      return
    } catch (err) {
      console.info('TagInfo', JSON.stringify(err))
    }
  }

  async search(param?:BooksTypeSearchParams) {
    const generation = capturePrivacyGeneration();
    if (param?.bookGroup === PRIVACY_BOOK_GROUP && !isPrivacyGenerationValid(generation)) return [];
    let searchKey = (param?.searchKey ?? '').replace(/'/g, "''");
    let type = param?.type;
    let bookGroup = param?.bookGroup;
    let order = param?.order;
    let sort = 0
    if (order !== undefined){
      sort = booksUtils.getOrder(order)
    }
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      let sql = `SELECT * FROM ${this.TABLE_NAME}`;
      // 动态添加 WHERE 子句
      let whereClause: string[] = [];
      // The privacy folder must stay out of normal queries.
      if (bookGroup !== PRIVACY_BOOK_GROUP) {
        whereClause.push(`bookGroup != ${PRIVACY_BOOK_GROUP}`);
      }
      if (type !== undefined) {
        whereClause.push(`bookType = ${type}`);
      }
      if (bookGroup !== undefined && bookGroup !== 2) {
        whereClause.push(bookGroup === 4 ? `(bookGroup = 4 OR isLocalBook = ${true})` : `bookGroup = ${bookGroup}`);
      }
      if (searchKey) {
        whereClause.push(`(
        bookName LIKE '%${searchKey}%'
        OR author LIKE '%${searchKey}%'
        OR originName LIKE '%${searchKey}%'
      )`);

      }
      // 如果有 where 子句，添加 WHERE 关键字
      if (whereClause.length > 0) {
        sql += ` WHERE ${whereClause.join(' AND ')}`;
      }
      sql += ` ORDER BY`;
      if (order !== undefined) {
        switch (sort){
          case 0:
            sql += ` isTop DESC, durChapterTime DESC`;
            break;
          case 1:
            sql += ` isTop DESC, latestChapterTime DESC`;
            break;
          case 2:
            sql += ` isTop DESC, sort ASC`;
            break;
        }
      } else {
        sql += ` isTop DESC, createTime DESC`;
      }

      const bookDbList = await DbUtil.querySqlForList<Books>(sql, column);
      if (bookGroup === PRIVACY_BOOK_GROUP && !isPrivacyGenerationValid(generation)) return [];
      console.log("TagInfo", '书籍：' + bookDbList.length)
      return bookDbList
    } catch (err) {
      console.log("TagInfo", JSON.stringify(err))
      return []
    }
  }

  //获取书籍总数量
  async getBookCount(param?: BooksTypeSearchParams) {
    const generation = capturePrivacyGeneration();
    if (param?.bookGroup === PRIVACY_BOOK_GROUP && !isPrivacyGenerationValid(generation)) return 0;
    let type = param?.type;
    let bookGroup = param?.bookGroup;
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      if (type !== undefined) predicates.equalTo('bookType', type)
      if (bookGroup !== PRIVACY_BOOK_GROUP) predicates.notEqualTo('bookGroup', PRIVACY_BOOK_GROUP)
      if (bookGroup === 4) {
        predicates.beginWrap().equalTo('bookGroup', 4).or().equalTo('isLocalBook', true).endWrap()
      } else if (bookGroup !== undefined && bookGroup !== 2) {
        predicates.equalTo('bookGroup', bookGroup)
      }
      const count = await DbUtil.queryForCount(predicates, column)
      if (bookGroup === PRIVACY_BOOK_GROUP && !isPrivacyGenerationValid(generation)) return 0;
      return count
    } catch (e){
      console.log("TagInfo", JSON.stringify(e))
      return 0
    }
  }

  async searchPage(param?: BooksTypeSearchParams, pageNumber: number = 1, pageSize: number = 21) {
    const generation = capturePrivacyGeneration();
    if (param?.bookGroup === PRIVACY_BOOK_GROUP && !isPrivacyGenerationValid(generation)) return [];
    let searchKey = (param?.searchKey ?? '').replace(/'/g, "''");
    let type = param?.type;
    let bookGroup = param?.bookGroup;
    let order = param?.order;
    let sort = 0;
    if (order !== undefined) {
      sort = booksUtils.getOrder(order);
    }

    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      let sql = `SELECT * FROM ${this.TABLE_NAME}`;
      let whereClause: string[] = [];

      if (type !== undefined) {
        whereClause.push(`bookType = ${type}`);
      }
      if (bookGroup !== PRIVACY_BOOK_GROUP) {
        whereClause.push(`bookGroup != ${PRIVACY_BOOK_GROUP}`);
      }
      if (bookGroup !== undefined && bookGroup !== 2) {
        if (bookGroup === 4) {
          whereClause.push(`(bookGroup = ${bookGroup} OR isLocalBook = ${true})`);
        } else {
          whereClause.push(`bookGroup = ${bookGroup}`);
        }
      }
      if (searchKey) {
        whereClause.push(`(
                bookName LIKE '%${searchKey}%'
                OR author LIKE '%${searchKey}%'
                OR originName LIKE '%${searchKey}%'
            )`);
      }

      if (whereClause.length > 0) {
        sql += ` WHERE ${whereClause.join(' AND ')}`;
      }

      sql += ` ORDER BY`;
      if (order !== undefined) {
        switch (sort) {
          case 0:
            sql += ` isTop DESC, durChapterTime DESC, createTime DESC`;
            break;
          case 1:
            sql += ` isTop DESC, latestChapterTime DESC,updateTime DESC`;
            break;
          case 2:
            sql += ` isTop DESC, sort ASC`;
            break;
        }
      } else {
        sql += ` isTop DESC, createTime DESC`;
      }

      const offset = (pageNumber - 1) * pageSize;
      sql += ` LIMIT ${pageSize} OFFSET ${offset}`;

      const bookDbList = await DbUtil.querySqlForList<Books>(sql, column);
      if (bookGroup === PRIVACY_BOOK_GROUP && !isPrivacyGenerationValid(generation)) return [];
      console.log("TagInfo", '书籍：' + bookDbList.length)
      return bookDbList;
    } catch (err) {
      console.log("TagInfo", JSON.stringify(err))
      return [];
    }
  }

  async batchInsert(books: Books[]) {
    const generation = capturePrivacyGeneration();
    try {
      for (const book of books) {
        if (await this.isPrivateBook(book) && !isPrivacyGenerationValid(generation)) return false;
        if (!await this.insert(book, generation)) return false;
      }
      return true;
    } catch (err) {
      console.log('TagInfo, Error, ', JSON.stringify(err));
      return false;
    }
  }

  async insert(books: Books, generation: number = capturePrivacyGeneration()): Promise<boolean> {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      if (books.id) {
        const predicates = DbUtil.getPredicates(this.TABLE_NAME);
        predicates.equalTo('id', books.id);
        const count = await DbUtil.queryForCount(predicates, column);
        if (count > 0) return await this.update(books, generation);
      }
      if (!await this.canWriteBook(books, generation)) return false;
      if (books.bookGroup === PRIVACY_BOOK_GROUP && !isPrivacyGenerationValid(generation)) return false;
      books.createTime = Date.now();
      books.id = await DbUtil.insert(this.TABLE_NAME, books, column);
      // Report a committed insert even if lock arrived during the database await.
      // Import rollback must never remove the file of an already-persisted book.
      return true;
    } catch (err) {
      console.log('TagInfo, Error, ', JSON.stringify(err));
      return false;
    }
  }

  async update(books: Books, generation: number = capturePrivacyGeneration()): Promise<boolean> {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.equalTo('id', books.id);
      const count = await DbUtil.queryForCount(predicates, column);
      if (count === 0 && books instanceof Books) return await this.insert(books, generation);
      if (!await this.canWriteBook(books, generation)) return false;
      if (books.bookGroup === PRIVACY_BOOK_GROUP && !isPrivacyGenerationValid(generation)) return false;
      return await DbUtil.update(predicates, books, column) === 1;
    } catch (err) {
      console.log('TagInfo, Error, ', JSON.stringify(err));
      return false;
    }
  }
  //置顶
  async isUpdateBookTop(id: number, isTop: boolean,
    generation: number = capturePrivacyGeneration()): Promise<boolean> {
    try {
      const column = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.equalTo('id', id);
      const books = await DbUtil.queryForList<Books>(predicates, column);
      for (const book of books) {
        if (!await this.canWriteBook(book, generation)) return false;
        book.isTop = isTop;
        book.updateTime = Date.now();
        if (!await this.update(book, generation)) return false;
      }
      return books.length > 0;
    } catch (err) {
      console.log('isUpdateBookTop, Error, ', JSON.stringify(err));
      return false;
    }
  }

  async batchUpdateBookGroup(ids: number[], groupId: number): Promise<boolean> {
    return await this.updateBookGroup(ids, groupId);
  }

  // Guard both persisted source ownership and the target group, not stale route data.
  async updateBookGroup(bookIds: number | number[], groupId: number,
    generation: number = capturePrivacyGeneration()): Promise<boolean> {
    try {
      const validIds = toolsUtils.numberArrays(bookIds).filter(id => typeof id === 'number');
      if (validIds.length === 0) return false;
      const column = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.in('id', validIds);
      const books = await DbUtil.queryForList<Books>(predicates, column);
      if (books.length !== new Set(validIds).size) return false;
      const privateOperation = groupId === PRIVACY_BOOK_GROUP || await this.isPrivateBookIds(validIds);
      if (privateOperation && !isPrivacyGenerationValid(generation)) return false;
      for (const book of books) {
        if (privateOperation && !isPrivacyGenerationValid(generation)) return false;
        if (!await this.canWriteBook(book, generation)) return false;
        if (privateOperation && !isPrivacyGenerationValid(generation)) return false;
        // Only change group membership; do not write a stale snapshot over reading progress.
        const updateColumn = AppDatabaseUtil.getAssignColumn(this.TABLE_NAME, ['bookGroup']);
        const updatePredicates = DbUtil.getPredicates(this.TABLE_NAME);
        updatePredicates.equalTo('id', book.id);
        book.bookGroup = groupId;
        if (await DbUtil.update(updatePredicates, book, updateColumn) !== 1) return false;
        if (privateOperation && !isPrivacyGenerationValid(generation)) return false;
      }
      return true;
    } catch (err) {
      console.log('updateBookGroup, Error, ', JSON.stringify(err));
      return false;
    }
  }

  //根据书籍获取旧的分组Id
  async getBookIdsByGroupId(ids: number[]) {
    let BookGroupId: Record<number, number> = {};
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);

      // 确保 ids 数组的每个元素都是数字
      const validIds = ids.filter(id => typeof id === 'number');

      // 创建查询条件，查找所有给定的 id
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.in('id', validIds);  // 使用 in 条件一次性查找多个 id

      // 执行一次查询获取所有匹配的书籍
      const books = await DbUtil.queryForList<Books>(predicates, column);

      // 遍历查询结果，将书籍的 bookGroup 分组
      books.forEach(book => {
        const bookId = book.id;  // 获取书籍的 id
        if (bookId !== undefined) {
          if (!BookGroupId[bookId]) {
            BookGroupId[bookId] = 0;
          }
          BookGroupId[bookId] = book.bookGroup ?? 0;
        }
      });

      return BookGroupId;
    } catch (e) {
      console.log('getBookIdsByGroupId, Error, ', JSON.stringify(e));
      return [];
    }
  }

  //根据分组获取书籍id
  async queryBooksByGroupId(groupId: number[]){
    const generation = capturePrivacyGeneration();
    if (groupId.includes(PRIVACY_BOOK_GROUP) && !isPrivacyGenerationValid(generation)) return [];
    let GroupBookId: number[] = [];
    try {
      // 确保 ids 数组的每个元素都是数字
      const validIds = groupId.filter(id => typeof id === 'number');
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.in('bookGroup', validIds)
      // 执行一次查询获取所有匹配的书籍
      const books = await DbUtil.queryForList<Books>(predicates, column);
      // 遍历查询结果，将书籍的 bookGroup 分组
      books.forEach(book => {
        const bookId = book.id;  // 获取书籍的 id
        if (bookId !== undefined) {
          GroupBookId.push(bookId)
        }
      });
      if (groupId.includes(PRIVACY_BOOK_GROUP) && !isPrivacyGenerationValid(generation)) return [];
      return GroupBookId
    } catch (e) {
      console.log('queryBooksByGroupId, Error, ', JSON.stringify(e));
      return []
    }
  }

  //删除订阅源历史记录
  async deleteBook(ids: number[], generation: number = capturePrivacyGeneration()): Promise<boolean> {
    try {
      if (ids.length === 0) return false;
      const privateOperation = await this.isPrivateBookIds(ids);
      if (privateOperation && !isPrivacyGenerationValid(generation)) return false;
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.in('id', ids);
      await DbUtil.delete(predicates);
      return !privateOperation || isPrivacyGenerationValid(generation);
    } catch (err) {
      console.log('TagInfo, Error, ', JSON.stringify(err));
      return false;
    }
  }

  //根据分组id统计书籍数量
  async countBookByGroup(groupId: number) {
    const generation = capturePrivacyGeneration();
    if (groupId === PRIVACY_BOOK_GROUP && !isPrivacyGenerationValid(generation)) return 0;
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.equalTo('bookGroup', groupId)
      const count = await DbUtil.queryForCount(predicates, column)
      if (groupId === PRIVACY_BOOK_GROUP && !isPrivacyGenerationValid(generation)) return 0;
      return count
    } catch (err) {
      console.log('TagInfo, Error, ', JSON.stringify(err))
      return 0
    }
  }

  //分组删除情况下根据删除分组id查询书籍更新未分组
  async queryBookByGroup(groupId: number[], updateGroupId: number): Promise<boolean> {
    const generation = capturePrivacyGeneration();
    try {
      if ((groupId.includes(PRIVACY_BOOK_GROUP) || updateGroupId === PRIVACY_BOOK_GROUP) && !isPrivacyGenerationValid(generation)) return false;
      const column = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.in('bookGroup', groupId);
      const books = await DbUtil.queryForList<Books>(predicates, column);
      const ids: number[] = [];
      for (const book of books) {
        if (book.id !== undefined) ids.push(book.id);
      }
      return ids.length === 0 || await this.updateBookGroup(ids, updateGroupId, generation);
    } catch (e) {
      console.log('TagInfo, Error, ', JSON.stringify(e));
      return false;
    }
  }

  // 校验当前书籍是否存在书架中
  async isExistBooks(bookUrl?: string, bookName?: string): Promise<Books[]> {
    if (!bookUrl || !bookName) {
      console.warn('bookUrl or bookName is missing.');
      return [];
    }

    const column = AppDatabaseUtil.getColumn(this.TABLE_NAME);
    const predicates = DbUtil.getPredicates(this.TABLE_NAME);
    predicates.equalTo('bookUrl', bookUrl);
    predicates.equalTo('bookName', bookName);

    try {
      const books = await DbUtil.queryForList<Books>(predicates, column);
      return books || [];
    } catch (err) {
      console.error('isExistBooks, Error:', err);
      return [];
    }
  }

  //本地导入重复检测所需记录；服务器书缓存使用独立远端标识，不参与普通本地文件重复判断
  async getLocalBooksForImportDuplicateCheck(): Promise<Books[]> {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.equalTo('isLocalBook', true);
      predicates.beginWrap().notEqualTo('origin', 'server-shelf').or().isNull('origin').endWrap();
      const books = await DbUtil.queryForList<Books>(predicates, column);
      return books || [];
    } catch (err) {
      console.error('getLocalBooksForImportDuplicateCheck, Error:', err);
      return [];
    }
  }

  //用于本地导入生成不碰撞的展示书名，覆盖所有分组（包括隐私分组）
  async getExistingBookNames(): Promise<string[]> {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getAssignColumn(this.TABLE_NAME, ['bookName']);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      const books = await DbUtil.queryForList<Books>(predicates, column);
      const names: string[] = [];
      for (let index = 0; index < books.length; index++) {
        if (books[index].bookName) {
          names.push(books[index].bookName);
        }
      }
      return names;
    } catch (err) {
      console.error('getExistingBookNames, Error:', err);
      return [];
    }
  }

  //根据书籍Id获取书籍
  async getBookByIds(ids: number[]) {

    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);

      // 确保 ids 数组的每个元素都是数字
      const validIds = ids.filter(id => typeof id === 'number');
      if (validIds.length === 0) return []
      // 创建查询条件，查找所有给定的 id
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.in('id', validIds);
      predicates.notEqualTo('bookGroup', PRIVACY_BOOK_GROUP);  // 使用 in 条件一次性查找多个 id

      // 执行一次查询获取所有匹配的书籍
      const books = await DbUtil.queryForList<Books>(predicates, column);

      return books;
    } catch (e) {
      console.log('getBookIds, Error, ', JSON.stringify(e));
      return [];
    }
  }
  //部分更新
  async partialUpdate(books: Books) {
    const generation = capturePrivacyGeneration();
    if (!books || books.id === undefined) {
      console.warn('Invalid Books data.');
      return;
    }

    const column = this.getPartialColumn();
    const predicates = DbUtil.getPredicates(this.TABLE_NAME);
    predicates.equalTo('id', books.id);

    try {
      const count = await DbUtil.queryForCount(predicates, column);

      if (count > 0) {
        if (!await this.canWriteBook(books, generation)) return;
        await DbUtil.update(predicates, books, column);
      } else {
        console.warn('No records found for update.');
      }
    } catch (err) {
      console.error('Error in partialUpdate:', err);
    }
  }

  getPartialColumn(): ColumnInfo[] {
    return AppDatabaseUtil.getAssignColumn(this.TABLE_NAME, ['id',
      'latestChapterTitle', 'latestChapterTime', 'lastCheckTime',
      'lastCheckCount', 'totalChapterNum', 'durChapterTitle',
      'durChapterIndex', 'durChapterPos', 'durChapterTime',
      'wordCount', 'syncTime', 'updateTime',
      'bookUrl', 'origin', 'originName', 'isLocalBook', 'localFileSize',
      'localFileModified', 'localFileHash', 'serverBookUrl', 'serverFileSize', 'serverFileModified',
      'serverFileName', 'serverUpdateAvailable'
    ]);
  }
}


const booksDao = new BooksDao()
export default booksDao as BooksDao