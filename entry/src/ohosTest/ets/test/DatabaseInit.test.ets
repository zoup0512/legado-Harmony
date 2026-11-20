import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { afterEach, beforeEach, describe, expect, it, MockKit, when } from '@ohos/hypium';
import dbUtil from '../../../main/ets/common/utils/DbUtil';
import dataBase from '../../../main/ets/database';
import appDatabaseUtil from '../../../main/ets/database/AppDatabaseUtil';
import { Books } from '../../../main/ets/database/entities/Books';
import bookGroupsDao from '../../../main/ets/database/dao/BookGroupsDao';
import booksDao from '../../../main/ets/database/dao/BooksDao';
import { BooksTypeSearchParams } from '../../../main/ets/database/types/BooksType';

let storeSequence: number = 0;

export default function databaseInitTest() {
  describe('DatabaseInitTest', () => {
    let originalStore: relationalStore.RdbStore | undefined;
    let testStore: relationalStore.RdbStore | undefined;
    let mock: MockKit = new MockKit();

    beforeEach(() => {
      originalStore = dbUtil.rdbStore;
      dbUtil.rdbStore = undefined;
      testStore = undefined;
      mock = new MockKit();
      // Default-group seeding is fire-and-forget; keep it out of the isolated schema tests.
      const seedGroups = mock.mockFunc(bookGroupsDao, bookGroupsDao.initGroupData);
      when(seedGroups)().afterAction((): Promise<void> => Promise.resolve());
    });

    afterEach(async () => {
      mock.clear(bookGroupsDao);
      dbUtil.rdbStore = originalStore;
      const store = testStore;
      testStore = undefined;
      if (store !== undefined) await store.close();
    });

    // Match DbUtilQueryTest: use a unique in-memory store, never the application database.
    const openMemoryStore = async (): Promise<relationalStore.RdbStore> => {
      const config: relationalStore.StoreConfig = {
        name: `DatabaseInitTest_${++storeSequence}.db`,
        securityLevel: relationalStore.SecurityLevel.S1,
        persist: false
      };
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      const contexts: common.Context[] = [];
      const topAbility = await delegator.getCurrentTopAbility();
      if (topAbility && topAbility.context) contexts.push(topAbility.context);
      const appContext = delegator.getAppContext();
      if (appContext && appContext !== topAbility?.context) contexts.push(appContext);
      let failure: Error | undefined;
      for (const context of contexts) {
        try {
          const store = await relationalStore.getRdbStore(context, config);
          testStore = store;
          dbUtil.rdbStore = store;
          return store;
        } catch (error) {
          failure = error as Error;
        }
      }
      throw failure ?? new Error('No usable test context');
    };

    const readNumber = async (store: relationalStore.RdbStore, sql: string): Promise<number> => {
      const result = await store.querySql(sql);
      try {
        if (!result.goToFirstRow()) throw new Error('Expected a database result');
        return result.getLong(0);
      } finally {
        result.close();
      }
    };

    it('freshDatabaseInitializesWithoutReadingHistory', 0, async () => {
      const store = await openMemoryStore();
      await dataBase.initAllTable();
      expect(await readNumber(store,
        "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name IN ('books', 'book_groups', 'works_lists')"))
        .assertEqual(3);
      expect(await readNumber(store,
        "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'book_history'"))
        .assertEqual(0);
      expect(appDatabaseUtil.getCreateSql('book_history') === undefined).assertTrue();
    });

    it('existingDatabaseKeepsShelfProgressAndLeavesRetiredHistoryUntouched', 0, async () => {
      const store = await openMemoryStore();
      // The retired table is intentionally not part of the current schema.
      await store.executeSql('CREATE TABLE book_history (id INTEGER PRIMARY KEY, bookType INTEGER)');
      await store.executeSql('INSERT INTO book_history (id, bookType) VALUES (7, 2)');
      const createBooksSql = appDatabaseUtil.getCreateSql('books');
      if (createBooksSql === undefined) throw new Error('Missing shelf schema');
      await store.executeSql(createBooksSql);
      await store.executeSql("INSERT INTO books (id, bookName, bookUrl, bookGroup, durChapterIndex, durChapterPos, durChapterTime, isTop) VALUES (7, 'saved book', '/data/local.epub', 3, 5, 123, 1000, 1)");
      await dataBase.initAllTable();
      await dataBase.initAllTable();
      expect(await readNumber(store, 'SELECT COUNT(*) FROM book_history')).assertEqual(1);
      expect(await readNumber(store, 'SELECT bookType FROM book_history WHERE id = 7')).assertEqual(2);
      const books = await dbUtil.querySqlForList<Books>('SELECT * FROM books', appDatabaseUtil.getColumn('books'));
      expect(books.length).assertEqual(1);
      expect(books[0].bookName).assertEqual('saved book');
      expect(books[0].bookUrl).assertEqual('/data/local.epub');
      expect(books[0].bookGroup).assertEqual(3);
      expect(books[0].durChapterIndex).assertEqual(5);
      expect(books[0].durChapterPos).assertEqual(123);
      expect(books[0].durChapterTime).assertEqual(1000);
      expect(books[0].isTop).assertTrue();
    });

    it('shelfSearchFallsBackToLatestReadAndPreservesKnownOrders', 0, async () => {
      const store = await openMemoryStore();
      await dataBase.initAllTable();
      // Each sort yields a different ID order, and the pinned book sorts first in every mode.
      await store.executeSql(`INSERT INTO books
        (id, bookName, isTop, durChapterTime, latestChapterTime, sort, createTime) VALUES
        (1, 'most recently read', 0, 300, 100, 2, 100),
        (2, 'most recently updated', 0, 200, 300, 3, 200),
        (3, 'most recently created', 0, 100, 200, 1, 300),
        (4, 'pinned book', 1, 0, 0, 4, 0)`);
      const columns = appDatabaseUtil.getColumn('books');
      const readShelf = (): Promise<Books[]> => dbUtil.querySqlForList<Books>('SELECT * FROM books ORDER BY id', columns);
      const before = await readShelf();
      expect(before.length).assertEqual(4);

      const expectOrder = async (ids: number[], params?: BooksTypeSearchParams): Promise<void> => {
        const books = await booksDao.search(params);
        expect(books.map((book: Books) => book.id).join(',')).assertEqual(ids.join(','));
        const firstPage = await booksDao.searchPage(params, 1, 2);
        expect(firstPage.map((book: Books) => book.id).join(',')).assertEqual(ids.slice(0, 2).join(','));
        const secondPage = await booksDao.searchPage(params, 2, 2);
        expect(secondPage.map((book: Books) => book.id).join(',')).assertEqual(ids.slice(2).join(','));
      };

      await expectOrder([4, 1, 2, 3], { order: 'unknown order' });
      await expectOrder([4, 1, 2, 3], { order: '最近阅读' });
      await expectOrder([4, 2, 3, 1], { order: '更新排序' });
      await expectOrder([4, 3, 1, 2], { order: '手动排序' });
      await expectOrder([4, 3, 2, 1]);
      expect(JSON.stringify(await readShelf())).assertEqual(JSON.stringify(before));
    });
  });
}
