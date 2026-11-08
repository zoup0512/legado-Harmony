import Logger from '../../common/utils/Logger';
/**
 * @author 2008
 * @datetime 2024/7/24 21:16
 * @className: BookGroupsDao
 */
import DbUtil from '../../common/utils/DbUtil';
import AppDatabaseUtil from '../AppDatabaseUtil';
import { BookGroupDb, BookGroups, ToBookGroups, ToBookGroupsDb } from '../entities/BookGroups';
import { BookGroupTypeParams } from '../types/BookGroupType';
import { ColumnInfo } from '../types/ColumnInfo';

class BookGroupsDao{
  TABLE_NAME: string = 'book_groups'

  // 创建books数据表
  async initGroupTable() {
    try {
      const createSql = AppDatabaseUtil.getCreateSql(this.TABLE_NAME);
      if (!createSql) {
        return
      }
      await DbUtil.createTable(createSql)
      await AppDatabaseUtil.existsTable(this.TABLE_NAME)
      this.initGroupData()
    } catch (err) {
      Logger.error('BookGroupsDao.initGroupTable failed', Logger.errorSummary(err))
    }

  }

  async search(params?:BookGroupTypeParams) {
    const type = params?.type
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      let sql = `SELECT * FROM ${this.TABLE_NAME}`;
      // 动态添加 WHERE 子句
      let whereClause: string[] = [];
      if (type !== undefined){
        whereClause.push(`groupType = ${type} OR groupType = 123`);
      }
      // 如果有 where 子句，添加 WHERE 关键字
      if (whereClause.length > 0) {
        sql += ` WHERE ${whereClause.join(' AND ')}`;
      }

      sql += `
  ORDER BY
    isSystem DESC,
    isTop DESC,
    sort ASC
`;
      const groupDbList = await DbUtil.querySqlForList<BookGroupDb>(sql, column);
      const groupList = groupDbList.map((item): BookGroups => ToBookGroups(item));
      return groupList
    } catch (err) {
      Logger.error('BookGroupsDao.search failed', Logger.errorSummary(err))
      return []
    }
  }

  async searchHide(params?:BookGroupTypeParams) {
    const type = params?.type
    const show = params?.show
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      let sql = `SELECT * FROM ${this.TABLE_NAME}`;
      // 动态添加 WHERE 子句
      let whereClause: string[] = [];

      if (type !== undefined){
        whereClause.push(`groupType = ${type}`);
      }
      if (show !== undefined){
        whereClause.push(`show = ${show}`);
      }
      // 如果有 where 子句，添加 WHERE 关键字
      if (whereClause.length > 0) {
        sql += ` WHERE ${whereClause.join(' AND ')}`;
      }

      sql += `
  ORDER BY
    sort ASC
`;
      const groupDbList = await DbUtil.querySqlForList<BookGroupDb>(sql, column);
      const groupList = groupDbList.map((item): BookGroups => ToBookGroups(item));
      return groupList
    } catch (err) {
      Logger.error('BookGroupsDao.searchHide failed', Logger.errorSummary(err))
      return []
    }
  }


  async batchInsert(group: BookGroups[]) {
    try {
      for (let index = 0; index < group.length; index++) {
        const data = group[index];
        await this.insert(data)
      }
      return true
    } catch (err) {
      Logger.error('BookGroupsDao.batchInsert failed', Logger.errorSummary(err))
      return false
    }
  }

  async insert(group: BookGroups) {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      if (group.groupId) {
        const predicates = DbUtil.getPredicates(this.TABLE_NAME);
        predicates.equalTo('groupId', group.groupId)
        const count = await DbUtil.queryForCount(predicates, column)
        if (count > 0) {
          this.update(group)
          return true
        }
      }
      const bookGroupsDb = ToBookGroupsDb(group)
      bookGroupsDb.createTime = Date.now()
      await DbUtil.insert(this.TABLE_NAME, bookGroupsDb, column)
      return true
    } catch (err) {
      Logger.error('BookGroupsDao.insert failed', Logger.errorSummary(err))
      return false
    }
  }

  async update(group: BookGroups) {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.equalTo('groupId', group.groupId)
      const count = await DbUtil.queryForCount(predicates, column)
      if (count === 0) {
        this.insert(group)
        return true
      }
      const bookGroupsDb = ToBookGroupsDb(group)
      bookGroupsDb.updateTime = Date.now()
      await DbUtil.update(predicates, bookGroupsDb, column)
      return true
    } catch (err) {
      Logger.error('BookGroupsDao.update failed', Logger.errorSummary(err))
      return false
    }

  }

  //删除订阅源历史记录
  async deleteBook(id: number[]) {
    try {
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.in('groupId', id)
      await DbUtil.delete(predicates)
      return true
    }  catch (err) {
      Logger.error('BookGroupsDao.deleteBook failed', Logger.errorSummary(err))
      return false
    }
  }

  //置顶
  async isUpdateGroupTop(id: number, isTop: boolean) {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.equalTo('groupId', id)
      const count = await DbUtil.queryForList<BookGroups>(predicates, column)
      if (column.length > 0) {
        count.forEach((item) => {
          item.isTop = isTop
          item.updateTime = Date.now()
          this.update(item)
        })
        return true
      }
      return false
    } catch (err) {
      Logger.error('BookGroupsDao.isUpdateGroupTop failed', Logger.errorSummary(err))
      return false
    }
  }

  //更新分组显示状态
  async updateGroupShow(id: number, show?: boolean) {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.equalTo('groupId', id)
      const count = await DbUtil.queryForList<BookGroups>(predicates, column)
      if (column.length > 0)
        count.forEach((item) => {
          item.show = show||!item.show
          item.updateTime = Date.now()
          this.update(item)
        })
    } catch (e){
      Logger.error('BookGroupsDao.updateGroupShow failed', Logger.errorSummary(e))
    }
  }

  //系统初始分组数据
  async initGroupData() {
    let initGroup = ['分组','全部','未分组','本地','书单']
    try {
      const groupList = await this.search()
      if (groupList.length > 0) {
        return
      }
      for (let index = 0; index < initGroup.length; index++) {
          let group = new BookGroups()
          group.groupName = initGroup[index]
          group.sort = 0
          group.show = true
          group.groupType = 123
          group.canDelete = false
          group.isSystem = true
          group.isTop = true
          group.bookIds = []
          await bookGroupsDao.insert(group)
      }
    }catch (e){
      Logger.error('BookGroupsDao.initGroupData failed', Logger.errorSummary(e))
    }
  }
  //根据分组groupId更新bookIds书籍id存在不做更新
  updateAddBookIds(groupId: number, bookIds: string[]) {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.equalTo('groupId', groupId)
      //查询出来只有一个值
      DbUtil.queryForList<BookGroupDb>(predicates, column).then((data) => {
        data.forEach((item) => {
          const groupList = ToBookGroups(item);
          bookIds.forEach((bookId) => {
            //存在将bookId不做添加
            if (groupList.bookIds?.includes(bookId)) {
              return
            }
            if (groupList.bookIds) {
              groupList.bookIds.push(bookId)
            } else {
              groupList.bookIds = [bookId]
            }
          })
          this.update(groupList)
        })
      })
    } catch (e){
      Logger.error('BookGroupsDao.updateAddBookIds failed', Logger.errorSummary(e))
    }
  }
  //同时在更新后将旧的分组的bookIds中的书籍id移除
  async updateMoveBookIdsByGroupId(data: Record<number, number>) {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);

      const bookIds = Object.keys(data);

      for (const bookIdStr of bookIds) {
        const bookId = Number(bookIdStr);
        const oldGroupId = data[bookId];

        const predicates = DbUtil.getPredicates(this.TABLE_NAME);
        predicates.equalTo('groupId', oldGroupId);

        // 查询旧分组
        const groups = await DbUtil.queryForList<BookGroupDb>(predicates, column);
        if (groups.length > 0) {
          const group = groups[0];
          const groupList = ToBookGroups(group);

          if (groupList.bookIds?.includes(bookId.toString())) {
            // 移除旧分组中的 bookId
            groupList.bookIds = groupList.bookIds.filter(item => item !== bookId.toString());
            await this.update(groupList);
          }
        }
      }
    } catch (e) {
      Logger.error('BookGroupsDao.updateMoveBookIdsByGroupId failed', Logger.errorSummary(e));
    }
  }

  async updateMoveGroupBookIds(ids: number[]) {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      // 确保 ids 数组的每个元素都是数字
      const validIds = ids.filter(id => typeof id === 'number');
      predicates.in('groupId', validIds);  // 使用 in 条件一次性查找多个 id
      // 执行一次查询获取所有匹配的分组
      const groups = await DbUtil.queryForList<BookGroupDb>(predicates, column);

      if (groups.length > 0) {
        for (const group of groups) {
          const groupList = ToBookGroups(group);
          groupList.bookIds = [];
          await this.update(groupList); // 确保逐个更新
        }
      }
    } catch (e) {
      Logger.error('BookGroupsDao.updateMoveGroupBookIds failed', Logger.errorSummary(e));
    }
  }
  //校验唯一性,同时进行更新
  async onlyGroupUpdateName(groupId: number, newGroupName: string) {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.equalTo('groupName', newGroupName)
      const groups = await DbUtil.queryForList<BookGroupDb>(predicates, column);
      if (groups.length > 1) return false
      if (groups.length === 0){
        const predicates = DbUtil.getPredicates(this.TABLE_NAME);
        predicates.equalTo('groupId', groupId)
        const groupDate = await DbUtil.queryForList<BookGroupDb>(predicates, column);
        groupDate[0].groupName = newGroupName
        return await this.update(ToBookGroups(groupDate[0]))
      }
      if ((groups.length === 1 && groups[0].groupId && groups[0].groupId === groupId)) {
        groups[0].groupName = newGroupName
        return await this.update(ToBookGroups(groups[0]))
      }
      return false
    } catch (e){
      Logger.error('BookGroupsDao.onlyGroupUpdateName failed', Logger.errorSummary(e))
      return false
    }
  }
  /**
   * 分组id查询分组下的书籍Id然后去重
   * @param ids
   */
  async queryBookByGroup(ids:number[]){
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      const validIds = ids.filter(id => typeof id === 'number');
      predicates.in('groupId', validIds);
      const groups = await DbUtil.queryForList<BookGroupDb>(predicates, column);
      const bookIds:number[] = []
      if (groups.length > 0) {
        groups.forEach((item) => {
          ToBookGroups(item).bookIds?.forEach((bookId) => {
            if (!bookIds.includes(Number(bookId))) {
              bookIds.push(Number(bookId))
            }
          })
        })
      }
      return bookIds
    } catch (e){
      Logger.error('BookGroupsDao.queryBookByGroup failed', Logger.errorSummary(e))
      return []
    }
  }

  async updatePartialGroup(group: BookGroups) {
    // if (!(group instanceof BookGroups)) {
    //   return;
    // }

    const column = this.getPartialColumn();
    const predicates = DbUtil.getPredicates(this.TABLE_NAME);
    predicates.equalTo('groupId', group.groupId);

    try {
      const count = await DbUtil.queryForCount(predicates, column);
      if (count > 0) {
        await DbUtil.update(predicates, ToBookGroupsDb(group), column);
      } else {
        Logger.warn('BookGroupsDao.updatePartialGroup found no records');
      }
    } catch (err) {
      Logger.error('BookGroupsDao.updatePartialGroup failed', Logger.errorSummary(err));
    }
  }

  getPartialColumn(): ColumnInfo[] {
    return AppDatabaseUtil.getAssignColumn(this.TABLE_NAME, ['groupId',
      'groupName', 'coverOnly', 'coverType','coverUrl','groupDescribe',
      'enableRefresh','canUpdate'
    ]);
  }

}

const bookGroupsDao = new BookGroupsDao()
export default bookGroupsDao as BookGroupsDao