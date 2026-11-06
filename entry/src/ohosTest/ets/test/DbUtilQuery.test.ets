import { relationalStore } from '@kit.ArkData';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { afterEach, ArgumentMatchers, beforeEach, describe, expect, it, MockKit, when } from '@ohos/hypium';
import dbUtil from '../../../main/ets/common/utils/DbUtil';
import { ColumnInfo, ColumnType } from '../../../main/ets/database/types/ColumnInfo';

interface DbQueryRow {
  id: number;
  name: string;
}

const QUERY_COLUMNS: ColumnInfo[] = [
  { name: 'id', columnName: 'id', type: ColumnType.LONG },
  { name: 'name', columnName: 'name', type: ColumnType.STRING }
];

class QueryResultCapture {
  result: relationalStore.ResultSet | undefined;

  expectClosed(): void {
    const result = this.result;
    if (result === undefined) throw new Error('Query did not reach the parser');
    expect(result.isClosed).assertTrue();
  }
}

// Bound the wait so a regression to a pending Promise fails instead of hanging the suite.
async function expectQueryFailure(operation: () => Promise<DbQueryRow[]>, expectedError?: Error): Promise<void> {
  let outcome = 'pending';
  let timer = -1;
  const timeout = new Promise<void>((resolve) => { timer = setTimeout(resolve, 1000); });
  try {
    await Promise.race([
      operation().then(() => { outcome = 'resolved'; }, (error: Error) => {
        outcome = 'rejected';
        if (expectedError !== undefined) expect(error).assertEqual(expectedError);
      }),
      timeout
    ]);
    expect(outcome).assertEqual('rejected');
  } finally {
    clearTimeout(timer);
  }
}

export default function dbUtilQueryTest() {
  describe('DbUtilQueryTest', () => {
    let originalStore: relationalStore.RdbStore | undefined;
    let testStore: relationalStore.RdbStore | undefined;
    let mock: MockKit = new MockKit();

    beforeEach(() => {
      originalStore = dbUtil.rdbStore;
      dbUtil.rdbStore = undefined;
      testStore = undefined;
      mock = new MockKit();
    });

    afterEach(async () => {
      mock.clear(dbUtil);
      dbUtil.rdbStore = originalStore;
      const store = testStore;
      testStore = undefined;
      if (store !== undefined) await store.close();
    });

    // persist:false requires API 18+; no application database is opened or deleted.
    const openMemoryStore = async (): Promise<relationalStore.RdbStore> => {
      const context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
      const config: relationalStore.StoreConfig = {
        name: 'DbUtilQueryTest.db',
        securityLevel: relationalStore.SecurityLevel.S1,
        persist: false
      };
      const store = await relationalStore.getRdbStore(context, config);
      testStore = store;
      dbUtil.rdbStore = store;
      await store.executeSql('CREATE TABLE query_rows (id INTEGER PRIMARY KEY, name TEXT)');
      return store;
    };

    const captureParser = (failure?: Error): QueryResultCapture => {
      const capture = new QueryResultCapture();
      const parseResultSet = dbUtil.parseResultSet;
      const parser = mock.mockFunc(dbUtil, dbUtil.parseResultSet);
      when(parser)(ArgumentMatchers.any).afterAction(
        (result: relationalStore.ResultSet, columns: ColumnInfo[]): DbQueryRow[] => {
          capture.result = result;
          if (failure !== undefined) throw failure;
          return parseResultSet<DbQueryRow>(result, columns);
        });
      return capture;
    };

    const queryRows = (): Promise<DbQueryRow[]> => {
      return dbUtil.queryForList<DbQueryRow>(dbUtil.getPredicates('query_rows'), QUERY_COLUMNS);
    };

    const querySqlRows = (): Promise<DbQueryRow[]> => {
      return dbUtil.querySqlForList<DbQueryRow>('SELECT id, name FROM query_rows', QUERY_COLUMNS);
    };

    const expectRowsAndClosed = async (operation: () => Promise<DbQueryRow[]>): Promise<void> => {
      const store = await openMemoryStore();
      const capture = captureParser();
      expect((await operation()).length).assertEqual(0);
      capture.expectClosed();
      await store.executeSql("INSERT INTO query_rows (id, name) VALUES (7, 'book')");
      const rows = await operation();
      expect(rows.length).assertEqual(1);
      expect(rows[0].id).assertEqual(7);
      expect(rows[0].name).assertEqual('book');
      capture.expectClosed();
    };

    const expectParserFailureAndClosed = async (operation: () => Promise<DbQueryRow[]>): Promise<void> => {
      const store = await openMemoryStore();
      await store.executeSql("INSERT INTO query_rows (id, name) VALUES (7, 'book')");
      const failure = new Error('query parser failed');
      const capture = captureParser(failure);
      await expectQueryFailure(operation, failure);
      capture.expectClosed();
    };

    it('queryForListRejectsWhenStoreIsUninitialized', 0, async () => {
      await expectQueryFailure(queryRows);
    });

    it('querySqlForListRejectsWhenStoreIsUninitialized', 0, async () => {
      await expectQueryFailure(querySqlRows);
    });

    it('queryForListReturnsRowsAndClosesEmptyAndNonemptyResults', 0, async () => {
      await expectRowsAndClosed(queryRows);
    });

    it('querySqlForListReturnsRowsAndClosesEmptyAndNonemptyResults', 0, async () => {
      await expectRowsAndClosed(querySqlRows);
    });

    it('queryForListRejectsParserErrorAndClosesResult', 0, async () => {
      await expectParserFailureAndClosed(queryRows);
    });

    it('querySqlForListRejectsParserErrorAndClosesResult', 0, async () => {
      await expectParserFailureAndClosed(querySqlRows);
    });

    it('queryForListRejectsDatabaseError', 0, async () => {
      await openMemoryStore();
      await expectQueryFailure(() => dbUtil.queryForList<DbQueryRow>(
        dbUtil.getPredicates('missing_query_table'), QUERY_COLUMNS));
    });

    it('querySqlForListRejectsDatabaseError', 0, async () => {
      await openMemoryStore();
      await expectQueryFailure(() => dbUtil.querySqlForList<DbQueryRow>(
        'SELECT id, name FROM missing_query_table', QUERY_COLUMNS));
    });
  });
}
