import { abilityDelegatorRegistry } from '@kit.TestKit';
import { relationalStore } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import DbUtil from '../../../main/ets/common/utils/DbUtil';
import bookSourceDao from '../../../main/ets/database/dao/BookSourceDao';

export default function bookSourceSortTest() {
  describe('BookSourceSortTest', () => {
    it('sortByNumericScoreInsteadOfGroup', 0, async () => {
      const context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
      const config: relationalStore.StoreConfig = {
        name: 'book_source_sort_test.db',
        securityLevel: relationalStore.SecurityLevel.S1
      };
      const previousStore = DbUtil.rdbStore;
      const store = await relationalStore.getRdbStore(context, config);
      try {
        await store.executeSql('DROP TABLE IF EXISTS book_sources');
        await store.executeSql(`CREATE TABLE book_sources (
          bookSourceUrl TEXT PRIMARY KEY, bookSourceName TEXT, bookSourceGroup TEXT,
          bookSourceGrade INTEGER DEFAULT 2, bookSourceScore TEXT, customOrder INTEGER,
          enabled INTEGER DEFAULT 1, enabledExplore INTEGER DEFAULT 1, loginUrl TEXT,
          lastUpdateTime INTEGER, respondTime INTEGER DEFAULT 0, weight INTEGER DEFAULT 0,
          exploreUrl TEXT, isTop INTEGER DEFAULT 0, showRecentIcon INTEGER DEFAULT 0,
          showExplore INTEGER DEFAULT 1
        )`);
        await store.insert('book_sources', {
          bookSourceUrl: 'test://low', bookSourceName: 'low', bookSourceGroup: 'Z',
          bookSourceScore: '2.0分', lastUpdateTime: 40, customOrder: 2, isTop: 0
        });
        await store.insert('book_sources', {
          bookSourceUrl: 'test://high', bookSourceName: 'high', bookSourceGroup: 'A',
          bookSourceScore: '5.0分', lastUpdateTime: 30, customOrder: 3, isTop: 0
        });
        await store.insert('book_sources', {
          bookSourceUrl: 'test://plain', bookSourceName: 'plain', bookSourceGroup: 'B',
          bookSourceScore: '3.5', lastUpdateTime: 20, customOrder: 1, isTop: 0
        });
        await store.insert('book_sources', {
          bookSourceUrl: 'test://empty', bookSourceName: 'empty', bookSourceGroup: 'Y',
          bookSourceScore: '', lastUpdateTime: 10, customOrder: 0, isTop: 1
        });
        await store.insert('book_sources', {
          bookSourceUrl: 'test://missing', bookSourceName: 'missing', bookSourceGroup: 'X',
          lastUpdateTime: 0, customOrder: 4, isTop: 0
        });
        DbUtil.rdbStore = store;
        const byScore = await bookSourceDao.flowSearch({ order: 0 });
        expect(byScore.map(source => source.bookSourceName).join(','))
          .assertEqual('high,plain,low,empty,missing');
        const byTime = await bookSourceDao.flowSearch({ order: 1 });
        expect(byTime.map(source => source.bookSourceName).join(','))
          .assertEqual('low,high,plain,empty,missing');
        const byDefault = await bookSourceDao.flowSearch();
        expect(byDefault.map(source => source.bookSourceName).join(','))
          .assertEqual('empty,plain,low,high,missing');
      } finally {
        DbUtil.rdbStore = previousStore;
        await store.close();
        await relationalStore.deleteRdbStore(context, config);
      }
    });
  });
}
