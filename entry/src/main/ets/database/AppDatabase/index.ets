import { AppDataBaseType } from '../types/AppDatabaseType'

export default {
  "formatVersion": 1,
  "database": {
    "version": 1,
    "identityHash": "6e17b5366286b868f2912c12d6d8e467",
    "entities": [
      {
        "tableName": "books",
        "createSql": "CREATE TABLE IF NOT EXISTS `${TABLE_NAME}` ( `id` INTEGER NOT NULL, `bookUrl` TEXT, `toUrl` TEXT, `origin` TEXT, `originName` TEXT, `bookName` TEXT NOT NULL, `author` TEXT, `cover` TEXT, `customTag` TEXT, `coverUrl` TEXT, `customCoverUrl` TEXT, `intro` TEXT, `customIntro` TEXT, `charset` TEXT, `bookGroup` INTEGER NOT NULL DEFAULT 3, `latestChapterTitle` TEXT, `latestChapterTime` INTEGER NOT NULL DEFAULT 0, `lastCheckTime` INTEGER NOT NULL DEFAULT 0, `lastCheckCount` INTEGER NOT NULL DEFAULT 0, `totalChapterNum` INTEGER NOT NULL DEFAULT 0, `durChapterTitle` TEXT, `durChapterIndex` INTEGER NOT NULL DEFAULT 0, `durChapterPos` INTEGER NOT NULL DEFAULT 0, `durChapterTime` INTEGER NOT NULL DEFAULT 0, `wordCount` TEXT, `canUpdate` INTEGER NOT NULL DEFAULT 1, `sort` INTEGER NOT NULL DEFAULT 0, `originOrder` INTEGER NOT NULL DEFAULT 0, `syncTime` INTEGER NOT NULL DEFAULT 0, `bookType` INTEGER NOT NULL DEFAULT 0, `isTop` INTEGER NOT NULL DEFAULT 0, `createTime` INTEGER NOT NULL DEFAULT 0,`updateTime` INTEGER NOT NULL DEFAULT 0,`isJoin` INTEGER NOT NULL DEFAULT 1, `isLocalBook` INTEGER NOT NULL DEFAULT 0, `localFileSize` INTEGER NOT NULL DEFAULT 0, `localFileModified` INTEGER NOT NULL DEFAULT 0, `localFileHash` TEXT, `serverBookUrl` TEXT, `serverFileSize` INTEGER NOT NULL DEFAULT 0, `serverFileModified` INTEGER NOT NULL DEFAULT 0, `serverFileName` TEXT, `serverUpdateAvailable` INTEGER NOT NULL DEFAULT 0,PRIMARY KEY ( `id` ))",
        "fields": [
          {
            "fieldPath": "id",
            "columnName": "id",
            "affinity": "INTEGER",
            "notNull": true
          },
          {
            "fieldPath": "bookUrl",
            "columnName": "bookUrl",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "toUrl",
            "columnName": "toUrl",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "origin",
            "columnName": "origin",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "originName",
            "columnName": "originName",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "bookName",
            "columnName": "bookName",
            "affinity": "TEXT",
            "notNull": true,
            "defaultValue":""
          },
          {
            "fieldPath": "author",
            "columnName": "author",
            "affinity": "TEXT",
            "notNull": true,
            "defaultValue": ""
          },
          {
            "fieldPath": "cover",
            "columnName": "cover",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "customTag",
            "columnName": "customTag",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "coverUrl",
            "columnName": "coverUrl",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "customCoverUrl",
            "columnName": "customCoverUrl",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "intro",
            "columnName": "intro",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "customIntro",
            "columnName": "customIntro",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "charset",
            "columnName": "charset",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "bookGroup",
            "columnName": "bookGroup",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "3"
          },
          {
            "fieldPath": "latestChapterTitle",
            "columnName": "latestChapterTitle",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "latestChapterTime",
            "columnName": "latestChapterTime",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "lastCheckTime",
            "columnName": "lastCheckTime",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "lastCheckCount",
            "columnName": "lastCheckCount",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "totalChapterNum",
            "columnName": "totalChapterNum",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "durChapterTitle",
            "columnName": "durChapterTitle",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "durChapterIndex",
            "columnName": "durChapterIndex",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "durChapterPos",
            "columnName": "durChapterPos",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "durChapterTime",
            "columnName": "durChapterTime",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "wordCount",
            "columnName": "wordCount",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "canUpdate",
            "columnName": "canUpdate",
            "affinity": "INTEGER",
            "boolean": true,
            "notNull": true,
            "defaultValue": "1"
          },
          {
            "fieldPath": "sort",
            "columnName": "sort",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "originOrder",
            "columnName": "originOrder",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "syncTime",
            "columnName": "syncTime",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "bookType",
            "columnName": "bookType",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "isTop",
            "columnName": "isTop",
            "affinity": "INTEGER",
            "boolean": true,
            "notNull": true,
            "defaultValue": "1"
          },
          {
            "fieldPath": "createTime",
            "columnName": "createTime",
            "affinity": "INTEGER",
            "notNull": false
          },
          {
            "fieldPath": "updateTime",
            "columnName": "updateTime",
            "affinity": "INTEGER",
            "notNull": false
          },
          {
            "fieldPath": "isJoin",
            "columnName": "isJoin",
            "affinity": "INTEGER",
            "boolean": true,
            "notNull": true,
            "defaultValue": "1"
          },
          {
            "fieldPath": "isLocalBook",
            "columnName": "isLocalBook",
            "affinity": "INTEGER",
            "boolean": true,
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "localFileSize",
            "columnName": "localFileSize",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "localFileModified",
            "columnName": "localFileModified",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "localFileHash",
            "columnName": "localFileHash",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "serverBookUrl",
            "columnName": "serverBookUrl",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "serverFileSize",
            "columnName": "serverFileSize",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "serverFileModified",
            "columnName": "serverFileModified",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "serverFileName",
            "columnName": "serverFileName",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "serverUpdateAvailable",
            "columnName": "serverUpdateAvailable",
            "affinity": "INTEGER",
            "boolean": true,
            "notNull": true,
            "defaultValue": "0"
          }
        ],
        "primaryKey": {
          "autoGenerate": false,
          "columnNames": [
            "id"
          ]
        },
        "indices": [
          {
            "name": "index_books_bookName_author",
            "unique": true,
            "columnNames": [
              "bookName",
              "author"
            ],
            "orders": [],
            "createSql": "CREATE UNIQUE INDEX IF NOT EXISTS `index_books_bookName_author` ON `${TABLE_NAME}` (`bookName`, `author`)"
          }
        ],
        "foreignKeys": []
      },
      {
        "tableName": "book_groups",
        "createSql": "CREATE TABLE IF NOT EXISTS `${TABLE_NAME}` (`groupId` INTEGER NOT NULL, `groupName` TEXT NOT NULL, `coverUrl` TEXT, `groupDescribe` TEXT, `sort` INTEGER NOT NULL, `enableRefresh` INTEGER NOT NULL DEFAULT 1, `show` INTEGER NOT NULL DEFAULT 1, `groupType` INTEGER NOT NULL DEFAULT 0, `createTime` INTEGER NOT NULL DEFAULT 0, `updateTime` INTEGER NOT NULL DEFAULT 0, `bookSort` INTEGER NOT NULL DEFAULT -1, `canUpdate` INTEGER NOT NULL DEFAULT 0, `coverOnly` INTEGER NOT NULL DEFAULT 0, `coverType` INTEGER NOT NULL DEFAULT 0, `canDelete` INTEGER NOT NULL DEFAULT 1, `isTop` INTEGER NOT NULL DEFAULT 0,`isSystem` INTEGER NOT NULL DEFAULT 0,`bookIds` TEXT,PRIMARY KEY(`groupId`))",
        "fields": [
          {
            "fieldPath": "groupId",
            "columnName": "groupId",
            "affinity": "INTEGER",
            "notNull": true
          },
          {
            "fieldPath": "groupName",
            "columnName": "groupName",
            "affinity": "TEXT",
            "notNull": true
          },
          {
            "fieldPath": "coverUrl",
            "columnName": "coverUrl",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath":"groupDescribe",
            "columnName": "groupDescribe",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "sort",
            "columnName": "sort",
            "affinity": "INTEGER",
            "notNull": true
          },
          {
            "fieldPath": "enableRefresh",
            "columnName": "enableRefresh",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "1"
          },
          {
            "fieldPath": "show",
            "columnName": "show",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "1"
          },
          {
            "fieldPath": "groupType",
            "columnName": "groupType",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "createTime",
            "columnName": "createTime",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "updateTime",
            "columnName": "updateTime",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "bookSort",
            "columnName": "bookSort",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "-1"
          },
          {
            "fieldPath": "coverOnly",
            "columnName": "coverOnly",
            "affinity": "INTEGER",
            "boolean": true,
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "coverType",
            "columnName": "coverType",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          }
          ,
          {
            "fieldPath": "canUpdate",
            "columnName": "canUpdate",
            "affinity": "INTEGER",
            "boolean": true,
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "canDelete",
            "columnName": "canDelete",
            "affinity": "INTEGER",
            "boolean": true,
            "notNull": true,
            "defaultValue": "1"
          },
          {
            "fieldPath": "isTop",
            "columnName": "isTop",
            "affinity": "INTEGER",
            "boolean": true,
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "isSystem",
            "columnName": "isSystem",
            "affinity": "INTEGER",
            "boolean": true,
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "bookIds",
            "columnName": "bookIds",
            "affinity": "TEXT",
            "notNull": false
          }
        ],
        "primaryKey": {
          "autoGenerate": false,
          "columnNames": [
            "groupId"
          ]
        },
        "indices": [],
        "foreignKeys": []
      },
      {
        "tableName": "works_lists",
        "createSql": "CREATE TABLE IF NOT EXISTS `${TABLE_NAME}` (`worksId` INTEGER NOT NULL, `worksName` TEXT NOT NULL, `worksDescribe` TEXT NOT NULL, `worksRemark` TEXT NOT NULL, `worksCoverUrl` TEXT NOT NULL, `createTime` INTEGER NOT NULL, `updateTime` INTEGER NOT NULL, `worksType` INTEGER NOT NULL, `worksBookNum` INTEGER NOT NULL, `worksBookList` TEXT, `isTop` INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(`worksId`))",
        "fields": [
          {
            "fieldPath": "worksId",
            "columnName": "worksId",
            "affinity": "INTEGER",
            "notNull": true
          },
          {
            "fieldPath": "worksName",
            "columnName": "worksName",
            "affinity": "TEXT",
            "notNull": true
          },
          {
            "fieldPath": "worksDescribe",
            "columnName": "worksDescribe",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "worksRemark",
            "columnName": "worksRemark",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "worksCoverUrl",
            "columnName": "worksCoverUrl",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "createTime",
            "columnName": "createTime",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "updateTime",
            "columnName": "updateTime",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "worksType",
            "columnName": "worksType",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "worksBookNum",
            "columnName": "worksBookNum",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "worksBookList",
            "columnName": "worksBookList",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "isTop",
            "columnName": "isTop",
            "affinity": "isTop",
            "boolean": true,
            "notNull": true,
            "defaultValue": "0"
          },
        ],
        "primaryKey": {
          "autoGenerate": false,
          "columnNames": [
            "worksId"
          ]
        },
        "indices": [
          {
            "name": "index_works_lists_worksName",
            "unique": false,
            "columnNames": [
              "worksName"
            ],
            "orders": [],
            "createSql": "CREATE INDEX IF NOT EXISTS `index_works_lists_worksName` ON `${TABLE_NAME}` (`worksName`)"
          }
        ],
        "foreignKeys": []
      }
    ],
    "views": [],
    "setupQueries": [
      "CREATE TABLE IF NOT EXISTS room_master_table (id INTEGER PRIMARY KEY,identity_hash TEXT)",
      "INSERT OR REPLACE INTO room_master_table (id,identity_hash) VALUES(42, '6e17b5366286b868f2912c12d6d8e467')"
    ]
  }
} as AppDataBaseType