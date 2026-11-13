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
        "tableName": "chapters",
        "createSql": "CREATE TABLE IF NOT EXISTS `${TABLE_NAME}` (`url` TEXT NOT NULL, `title` TEXT NOT NULL, `isVolume` INTEGER NOT NULL, `baseUrl` TEXT NOT NULL, `bookUrl` TEXT NOT NULL, `index` INTEGER NOT NULL, `isVip` INTEGER NOT NULL, `isPay` INTEGER NOT NULL, `resourceUrl` TEXT, `tag` TEXT, `start` INTEGER, `end` INTEGER, `startFragmentId` TEXT, `endFragmentId` TEXT, `variable` TEXT, PRIMARY KEY(`url`, `bookUrl`), FOREIGN KEY(`bookUrl`) REFERENCES `books`(`bookUrl`) ON UPDATE NO ACTION ON DELETE CASCADE )",
        "fields": [
          {
            "fieldPath": "url",
            "columnName": "url",
            "affinity": "TEXT",
            "notNull": true
          },
          {
            "fieldPath": "title",
            "columnName": "title",
            "affinity": "TEXT",
            "notNull": true
          },
          {
            "fieldPath": "isVolume",
            "columnName": "isVolume",
            "affinity": "INTEGER",
            "notNull": true
          },
          {
            "fieldPath": "baseUrl",
            "columnName": "baseUrl",
            "affinity": "TEXT",
            "notNull": true
          },
          {
            "fieldPath": "bookUrl",
            "columnName": "bookUrl",
            "affinity": "TEXT",
            "notNull": true
          },
          {
            "fieldPath": "index",
            "columnName": "index",
            "affinity": "INTEGER",
            "notNull": true
          },
          {
            "fieldPath": "isVip",
            "columnName": "isVip",
            "affinity": "INTEGER",
            "notNull": true
          },
          {
            "fieldPath": "isPay",
            "columnName": "isPay",
            "affinity": "INTEGER",
            "notNull": true
          },
          {
            "fieldPath": "resourceUrl",
            "columnName": "resourceUrl",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "tag",
            "columnName": "tag",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "start",
            "columnName": "start",
            "affinity": "INTEGER",
            "notNull": false
          },
          {
            "fieldPath": "end",
            "columnName": "end",
            "affinity": "INTEGER",
            "notNull": false
          },
          {
            "fieldPath": "startFragmentId",
            "columnName": "startFragmentId",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "endFragmentId",
            "columnName": "endFragmentId",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "variable",
            "columnName": "variable",
            "affinity": "TEXT",
            "notNull": false
          }
        ],
        "primaryKey": {
          "autoGenerate": false,
          "columnNames": [
            "url",
            "bookUrl"
          ]
        },
        "indices": [
          {
            "name": "index_chapters_bookUrl",
            "unique": false,
            "columnNames": [
              "bookUrl"
            ],
            "orders": [],
            "createSql": "CREATE INDEX IF NOT EXISTS `index_chapters_bookUrl` ON `${TABLE_NAME}` (`bookUrl`)"
          },
          {
            "name": "index_chapters_bookUrl_index",
            "unique": true,
            "columnNames": [
              "bookUrl",
              "index"
            ],
            "orders": [],
            "createSql": "CREATE UNIQUE INDEX IF NOT EXISTS `index_chapters_bookUrl_index` ON `${TABLE_NAME}` (`bookUrl`, `index`)"
          }
        ],
        "foreignKeys": [
          {
            "table": "books",
            "onDelete": "CASCADE",
            "onUpdate": "NO ACTION",
            "columns": [
              "bookUrl"
            ],
            "referencedColumns": [
              "bookUrl"
            ]
          }
        ]
      },
      {
        "tableName": "replace_rules",
        "createSql": "CREATE TABLE IF NOT EXISTS `${TABLE_NAME}` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `name` TEXT NOT NULL DEFAULT '', `group` TEXT, `pattern` TEXT NOT NULL DEFAULT '', `replacement` TEXT NOT NULL DEFAULT '', `scope` TEXT, `scopeTitle` INTEGER NOT NULL DEFAULT 0, `scopeContent` INTEGER NOT NULL DEFAULT 1, `excludeScope` TEXT, `isEnabled` INTEGER NOT NULL DEFAULT 1, `isRegex` INTEGER NOT NULL DEFAULT 1, `timeoutMillisecond` INTEGER NOT NULL DEFAULT 3000, `sortOrder` INTEGER NOT NULL DEFAULT 0)",
        "fields": [
          {
            "fieldPath": "id",
            "columnName": "id",
            "affinity": "INTEGER",
            "notNull": true
          },
          {
            "fieldPath": "name",
            "columnName": "name",
            "affinity": "TEXT",
            "notNull": true,
            "defaultValue": "''"
          },
          {
            "fieldPath": "group",
            "columnName": "group",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "pattern",
            "columnName": "pattern",
            "affinity": "TEXT",
            "notNull": true,
            "defaultValue": "''"
          },
          {
            "fieldPath": "replacement",
            "columnName": "replacement",
            "affinity": "TEXT",
            "notNull": true,
            "defaultValue": "''"
          },
          {
            "fieldPath": "scope",
            "columnName": "scope",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "scopeTitle",
            "columnName": "scopeTitle",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "scopeContent",
            "columnName": "scopeContent",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "1"
          },
          {
            "fieldPath": "excludeScope",
            "columnName": "excludeScope",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "isEnabled",
            "columnName": "isEnabled",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "1"
          },
          {
            "fieldPath": "isRegex",
            "columnName": "isRegex",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "1"
          },
          {
            "fieldPath": "timeoutMillisecond",
            "columnName": "timeoutMillisecond",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "3000"
          },
          {
            "fieldPath": "order",
            "columnName": "sortOrder",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          }
        ],
        "primaryKey": {
          "autoGenerate": true,
          "columnNames": [
            "id"
          ]
        },
        "indices": [
          {
            "name": "index_replace_rules_id",
            "unique": false,
            "columnNames": [
              "id"
            ],
            "orders": [],
            "createSql": "CREATE INDEX IF NOT EXISTS `index_replace_rules_id` ON `${TABLE_NAME}` (`id`)"
          }
        ],
        "foreignKeys": []
      },
      {
        "tableName": "bookmarks",
        "createSql": "CREATE TABLE IF NOT EXISTS `${TABLE_NAME}` (`time` INTEGER NOT NULL, `bookName` TEXT NOT NULL, `bookAuthor` TEXT NOT NULL, `chapterIndex` INTEGER NOT NULL, `chapterPos` INTEGER NOT NULL, `chapterName` TEXT NOT NULL, `bookText` TEXT NOT NULL, `content` TEXT NOT NULL, PRIMARY KEY(`time`))",
        "fields": [
          {
            "fieldPath": "time",
            "columnName": "time",
            "affinity": "INTEGER",
            "notNull": true
          },
          {
            "fieldPath": "bookName",
            "columnName": "bookName",
            "affinity": "TEXT",
            "notNull": true
          },
          {
            "fieldPath": "bookAuthor",
            "columnName": "bookAuthor",
            "affinity": "TEXT",
            "notNull": true
          },
          {
            "fieldPath": "chapterIndex",
            "columnName": "chapterIndex",
            "affinity": "INTEGER",
            "notNull": true
          },
          {
            "fieldPath": "chapterPos",
            "columnName": "chapterPos",
            "affinity": "INTEGER",
            "notNull": true
          },
          {
            "fieldPath": "chapterName",
            "columnName": "chapterName",
            "affinity": "TEXT",
            "notNull": true
          },
          {
            "fieldPath": "bookText",
            "columnName": "bookText",
            "affinity": "TEXT",
            "notNull": true
          },
          {
            "fieldPath": "content",
            "columnName": "content",
            "affinity": "TEXT",
            "notNull": true
          }
        ],
        "primaryKey": {
          "autoGenerate": false,
          "columnNames": [
            "time"
          ]
        },
        "indices": [
          {
            "name": "index_bookmarks_bookName_bookAuthor",
            "unique": false,
            "columnNames": [
              "bookName",
              "bookAuthor"
            ],
            "orders": [],
            "createSql": "CREATE INDEX IF NOT EXISTS `index_bookmarks_bookName_bookAuthor` ON `${TABLE_NAME}` (`bookName`, `bookAuthor`)"
          }
        ],
        "foreignKeys": []
      },
      {
        "tableName": "txtTocRules",
        "createSql": "CREATE TABLE IF NOT EXISTS `${TABLE_NAME}` (`id` INTEGER NOT NULL, `name` TEXT NOT NULL, `rule` TEXT NOT NULL, `example` TEXT, `serialNumber` INTEGER NOT NULL, `enable` INTEGER NOT NULL, PRIMARY KEY(`id`))",
        "fields": [
          {
            "fieldPath": "id",
            "columnName": "id",
            "affinity": "INTEGER",
            "notNull": true
          },
          {
            "fieldPath": "name",
            "columnName": "name",
            "affinity": "TEXT",
            "notNull": true
          },
          {
            "fieldPath": "rule",
            "columnName": "rule",
            "affinity": "TEXT",
            "notNull": true
          },
          {
            "fieldPath": "example",
            "columnName": "example",
            "affinity": "TEXT",
            "notNull": false
          },
          {
            "fieldPath": "serialNumber",
            "columnName": "serialNumber",
            "affinity": "INTEGER",
            "notNull": true
          },
          {
            "fieldPath": "enable",
            "columnName": "enable",
            "affinity": "INTEGER",
            "notNull": true
          }
        ],
        "primaryKey": {
          "autoGenerate": false,
          "columnNames": [
            "id"
          ]
        },
        "indices": [],
        "foreignKeys": []
      },
      {
        "tableName": "readRecord",
        "createSql": "CREATE TABLE IF NOT EXISTS `${TABLE_NAME}` (`deviceId` TEXT NOT NULL, `bookName` TEXT NOT NULL, `readTime` INTEGER NOT NULL DEFAULT 0, `lastRead` INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(`deviceId`, `bookName`))",
        "fields": [
          {
            "fieldPath": "deviceId",
            "columnName": "deviceId",
            "affinity": "TEXT",
            "notNull": true
          },
          {
            "fieldPath": "bookName",
            "columnName": "bookName",
            "affinity": "TEXT",
            "notNull": true
          },
          {
            "fieldPath": "readTime",
            "columnName": "readTime",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "lastRead",
            "columnName": "lastRead",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          }
        ],
        "primaryKey": {
          "autoGenerate": false,
          "columnNames": [
            "deviceId",
            "bookName"
          ]
        },
        "indices": [],
        "foreignKeys": []
      },
      {
        "tableName": "keyboardAssists",
        "createSql": "CREATE TABLE IF NOT EXISTS `${TABLE_NAME}` (`type` INTEGER NOT NULL DEFAULT 0, `key` TEXT NOT NULL DEFAULT '', `value` TEXT NOT NULL DEFAULT '', `serialNo` INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(`type`, `key`))",
        "fields": [
          {
            "fieldPath": "type",
            "columnName": "type",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          },
          {
            "fieldPath": "key",
            "columnName": "key",
            "affinity": "TEXT",
            "notNull": true,
            "defaultValue": "''"
          },
          {
            "fieldPath": "value",
            "columnName": "value",
            "affinity": "TEXT",
            "notNull": true,
            "defaultValue": "''"
          },
          {
            "fieldPath": "serialNo",
            "columnName": "serialNo",
            "affinity": "INTEGER",
            "notNull": true,
            "defaultValue": "0"
          }
        ],
        "primaryKey": {
          "autoGenerate": false,
          "columnNames": [
            "type",
            "key"
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