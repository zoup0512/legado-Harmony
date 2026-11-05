import { describe, expect, it } from '@ohos/hypium';
import { LocalBookAccessLogic } from '../../../main/ets/common/utils/LocalBookAccess';

export default function localBookAccessTest() {
  describe('LocalBookAccessTest', () => {
    it('acceptsAbsoluteSandboxAndDownloadedPaths', 0, () => {
      const localPath = '/data/storage/el2/base/haps/entry/files/localBooks/本地书.txt';
      const downloadedPath = '/data/storage/el2/base/haps/entry/files/server-cached-book.epub';
      expect(LocalBookAccessLogic.isLocalFilePath(localPath)).assertTrue();
      expect(LocalBookAccessLogic.localPathOf(localPath)).assertEqual(localPath);
      expect(LocalBookAccessLogic.isLocalFilePath(downloadedPath)).assertTrue();
    });

    it('acceptsOnlyLocalFileUrisWithoutChangingStoredValue', 0, () => {
      const source = 'file:///data/storage/el2/base/files/%E4%B9%A6%20%E5%90%8D.epub';
      expect(LocalBookAccessLogic.isLocalFilePath(source)).assertTrue();
      expect(LocalBookAccessLogic.localPathOf(source)).assertEqual('/data/storage/el2/base/files/书 名.epub');
      expect(source).assertEqual('file:///data/storage/el2/base/files/%E4%B9%A6%20%E5%90%8D.epub');
      expect(LocalBookAccessLogic.isLocalFilePath('file://remote-host/share/book.txt')).assertFalse();
      expect(LocalBookAccessLogic.isLocalFilePath('file:////remote-host/share/book.txt')).assertFalse();
      expect(LocalBookAccessLogic.isLocalFilePath('file:///data/%2Fremote/book.txt')).assertTrue();
      expect(LocalBookAccessLogic.isLocalFilePath('file:///%2Fremote-host/book.txt')).assertFalse();
      expect(LocalBookAccessLogic.isLocalFilePath('file:///data/bad%ZZ.txt')).assertFalse();
      expect(LocalBookAccessLogic.isLocalFilePath('file:///data/book.txt?download=1')).assertFalse();
      expect(LocalBookAccessLogic.isLocalFilePath('file:///data/book.txt#chapter')).assertFalse();
    });

    it('rejectsRemoteSchemesPlaceholdersAndRelativePaths', 0, () => {
      const rejected: string[] = [
        '', ' ', 'https://books.example/book.epub', 'http://books.example/book.txt',
        'HTTPS://books.example/book.epub', 'local://legacy-book-id', 'ftp://books.example/book.txt',
        'smb://host/book.txt', 'content://host/book.txt', 'data:text/plain,book',
        'javascript:alert(1)', '//books.example/book.txt', '\\\\host\\share\\book.txt',
        'books/book.txt', '../book.epub', 'https:book.txt', ' /data/book.txt', '/data/book.txt ',
        '/data/book\u0000.txt', '/data/book\n.txt', 'file:///data/book%00.txt',
        'file:///data/book%5C.txt'
      ];
      for (let index = 0; index < rejected.length; index++) {
        expect(LocalBookAccessLogic.isLocalFilePath(rejected[index])).assertFalse();
        expect(LocalBookAccessLogic.localPathOf(rejected[index])).assertEqual('');
      }
      expect(LocalBookAccessLogic.isLocalFilePath(undefined)).assertFalse();
    });

    it('fallsBackForRemoteAndRelativeCovers', 0, () => {
      const fallback: string = '/data/storage/el2/base/files/default-cover.png';
      const rejected: string[] = [
        '', 'https://covers.example/book.jpg', 'http://covers.example/book.jpg',
        'HTTPS://covers.example/book.jpg', '//covers.example/book.jpg', 'covers/book.jpg',
        '../cover.jpg', 'local://cover-id', 'ftp://covers.example/book.jpg',
        'data:image/svg+xml,remote', 'resource://remote-host/cover.jpg',
        'file://remote-host/share/cover.jpg', 'file:////remote-host/share/cover.jpg'
      ];
      for (let index = 0; index < rejected.length; index++) {
        expect(LocalBookAccessLogic.selectLocalCover(rejected[index], fallback)).assertEqual(fallback);
      }
      expect(LocalBookAccessLogic.selectLocalCover(undefined, fallback)).assertEqual(fallback);
    });

    it('keepsLocalCoversAndResourcePlaceholders', 0, () => {
      const fallback: string = '/data/storage/el2/base/files/default-cover.png';
      const localCovers: string[] = [
        '/data/storage/el2/base/files/cover.jpg', 'file:///data/storage/el2/base/files/cover.jpg',
        'file://media/Photo/1/IMG_001/cover.jpg'
      ];
      for (let index = 0; index < localCovers.length; index++) {
        expect(LocalBookAccessLogic.selectLocalCover(localCovers[index], fallback)).assertEqual(localCovers[index]);
      }
      const placeholder: Resource = $r('app.media.icon_book_default_cover_one');
      expect(LocalBookAccessLogic.selectLocalCover(placeholder, fallback)).assertEqual(placeholder);
      expect(LocalBookAccessLogic.selectLocalCover('https://covers.example/book.jpg', placeholder))
        .assertEqual(placeholder);
    });

    it('rejectsMalformedMediaCoverUris', 0, () => {
      const fallback: string = '/data/storage/el2/base/files/default-cover.png';
      expect(LocalBookAccessLogic.selectLocalCover('file://media/Photo/', fallback)).assertEqual(fallback);
      expect(LocalBookAccessLogic.selectLocalCover('file://media.example/Photo/1/cover.jpg', fallback))
        .assertEqual(fallback);
      expect(LocalBookAccessLogic.selectLocalCover('file://media/Photo/1/cover.jpg?url=https://host', fallback))
        .assertEqual(fallback);
      expect(LocalBookAccessLogic.selectLocalCover('file://media/Photo/1/cover.jpg\n', fallback))
        .assertEqual(fallback);
    });
  });
}
