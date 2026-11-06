import { describe, expect, it } from '@ohos/hypium';
import {
  ReaderFontImportFiles, ReaderFontLogic, READER_BUILTIN_FONT_FILE_NAME
} from '../../../main/ets/common/utils/ReaderFontLogic';

const FONTS_DIR: string = '/data/storage/el2/base/haps/entry/files/fonts';
const SELECTED_FONT: string = FONTS_DIR + '/Reader.ttf';

// Only in-memory bytes and a configurable fake hash are used, never platform file or crypto APIs.
class MemoryFontImportFiles implements ReaderFontImportFiles {
  contents: Map<string, Uint8Array> = new Map<string, Uint8Array>();
  events: string[] = [];
  removedPaths: string[] = [];
  validatedPath: string = '';
  validatedSize: number = -1;
  fakeHash: string = 'fake-font-hash';
  failValidation: boolean = false;
  failHash: boolean = false;
  failRename: boolean = false;

  read(path: string): Uint8Array {
    const bytes = this.contents.get(path);
    if (bytes === undefined) {
      throw new Error('test file missing');
    }
    return bytes;
  }

  async validate(path: string, expectedSize: number): Promise<string> {
    this.events.push('validate');
    this.validatedPath = path;
    this.validatedSize = expectedSize;
    if (this.failValidation) {
      throw new Error('validation failed');
    }
    const bytes = this.read(path);
    if (bytes.length === 0) {
      throw new Error('empty font');
    }
    if (!ReaderFontLogic.hasFontSignature(bytes)) {
      throw new Error('invalid font signature');
    }
    if (bytes.length !== expectedSize) {
      throw new Error('font size mismatch');
    }
    this.events.push('hash');
    if (this.failHash) {
      throw new Error('hash failed');
    }
    return this.fakeHash;
  }

  rename(source: string, target: string): void {
    this.events.push('rename');
    if (this.failRename) {
      throw new Error('rename failed');
    }
    const bytes = this.read(source);
    this.contents.set(target, bytes);
    this.contents.delete(source);
  }

  removeTemporary(path: string): void {
    this.events.push('removeTemporary');
    this.removedPaths.push(path);
    this.contents.delete(path);
  }
}

class FontImportFixture {
  files: MemoryFontImportFiles = new MemoryFontImportFiles();
  tempPath: string = FONTS_DIR + '/.Reader.importing';
  targetPath: string;
  unrelatedPath: string = FONTS_DIR + '/Other.otf';
  originalBytes: Uint8Array = new Uint8Array([0, 1, 0, 0, 11, 22, 33, 44]);
  importBytes: Uint8Array = new Uint8Array([79, 84, 84, 79, 55, 66, 77, 88]);
  cachedBuffer: ArrayBuffer = new ArrayBuffer(8);
  unrelatedBuffer: ArrayBuffer = new ArrayBuffer(4);
  bufferCache: Map<string, ArrayBuffer> = new Map<string, ArrayBuffer>();

  constructor(targetPath: string = SELECTED_FONT) {
    this.targetPath = targetPath;
    this.files.contents.set(this.targetPath, new Uint8Array(this.originalBytes));
    this.files.contents.set(this.tempPath, new Uint8Array(this.importBytes));
    new Uint8Array(this.cachedBuffer).set(this.originalBytes);
    this.bufferCache.set(this.targetPath, this.cachedBuffer);
    this.bufferCache.set(this.unrelatedPath, this.unrelatedBuffer);
  }

  commit(expectedSize: number = this.importBytes.length): Promise<string> {
    return ReaderFontLogic.commitImport(this.files, this.tempPath, this.targetPath,
      expectedSize, this.bufferCache);
  }
}

function expectBytes(actual: Uint8Array, expected: Uint8Array): void {
  expect(actual.length).assertEqual(expected.length);
  for (let index = 0; index < expected.length; index++) {
    expect(actual[index]).assertEqual(expected[index]);
  }
}

function expectOriginalPreserved(fixture: FontImportFixture): void {
  expectBytes(fixture.files.read(fixture.targetPath), fixture.originalBytes);
  expect(fixture.bufferCache.get(fixture.targetPath) === fixture.cachedBuffer).assertTrue();
  expectBytes(new Uint8Array(fixture.cachedBuffer), fixture.originalBytes);
  expect(fixture.bufferCache.get(fixture.unrelatedPath) === fixture.unrelatedBuffer).assertTrue();
  expect(fixture.bufferCache.size).assertEqual(2);
}

function expectTemporaryRemoved(fixture: FontImportFixture): void {
  expect(fixture.files.removedPaths.length).assertEqual(1);
  expect(fixture.files.removedPaths[0]).assertEqual(fixture.tempPath);
  expect(fixture.files.contents.has(fixture.tempPath)).assertFalse();
}

async function expectImportFailure(fixture: FontImportFixture,
  expectedSize: number = fixture.importBytes.length): Promise<string> {
  let rejected = false;
  let message = '';
  try {
    await fixture.commit(expectedSize);
  } catch (cause) {
    rejected = true;
    message = (cause as Error).message;
  }
  expect(rejected).assertTrue();
  expectOriginalPreserved(fixture);
  expectTemporaryRemoved(fixture);
  return message;
}

export default function readerFontLogicTest() {
  describe('ReaderFontLogicTest', () => {
    it('acceptsSupportedTrueTypeAndOpenTypeSignatures', 0, () => {
      const signatures: Uint8Array[] = [new Uint8Array([0, 1, 0, 0]),
        new Uint8Array([116, 114, 117, 101]), new Uint8Array([116, 116, 99, 102]),
        new Uint8Array([79, 84, 84, 79]), new Uint8Array([116, 121, 112, 49])];
      for (let index = 0; index < signatures.length; index++) {
        expect(ReaderFontLogic.hasFontSignature(signatures[index])).assertTrue();
      }
    });

    it('rejectsEmptyShortAndUnrecognizedSignatures', 0, () => {
      const invalid: Uint8Array[] = [new Uint8Array(0), new Uint8Array([0]),
        new Uint8Array([0, 1]), new Uint8Array([0, 1, 0]), new Uint8Array([0, 0, 0, 0]),
        new Uint8Array([119, 79, 70, 70]), new Uint8Array([111, 116, 116, 111])];
      for (let index = 0; index < invalid.length; index++) {
        expect(ReaderFontLogic.hasFontSignature(invalid[index])).assertFalse();
      }
    });

    it('emptyImportPreservesOldBytesAndCachedBufferAndCleansTemporary', 0, async () => {
      const fixture = new FontImportFixture();
      fixture.files.contents.set(fixture.tempPath, new Uint8Array(0));
      expect(await expectImportFailure(fixture, 0)).assertEqual('empty font');
      expect(fixture.files.events.join(',')).assertEqual('validate,removeTemporary');
    });

    it('invalidSignatureImportPreservesOldBytesAndCachedBuffer', 0, async () => {
      const fixture = new FontImportFixture();
      fixture.files.contents.set(fixture.tempPath, new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]));
      expect(await expectImportFailure(fixture)).assertEqual('invalid font signature');
      expect(fixture.files.events.join(',')).assertEqual('validate,removeTemporary');
    });

    it('truncatedImportWithValidSignatureCannotReplaceExistingFont', 0, async () => {
      const fixture = new FontImportFixture();
      fixture.files.contents.set(fixture.tempPath, fixture.importBytes.slice(0, 6));
      expect(await expectImportFailure(fixture)).assertEqual('font size mismatch');
      expect(fixture.files.events.join(',')).assertEqual('validate,removeTemporary');
    });

    it('oversizedImportAlsoRequiresExactExpectedSize', 0, async () => {
      const fixture = new FontImportFixture();
      expect(await expectImportFailure(fixture, fixture.importBytes.length - 1))
        .assertEqual('font size mismatch');
      expect(fixture.files.events.join(',')).assertEqual('validate,removeTemporary');
    });

    it('renameFailurePreservesOldBytesAndCacheAndStillRemovesTemporary', 0, async () => {
      const fixture = new FontImportFixture();
      fixture.files.failRename = true;
      expect(await expectImportFailure(fixture)).assertEqual('rename failed');
      expect(fixture.files.events.join(',')).assertEqual('validate,hash,rename,removeTemporary');
    });

    it('successfulCommitReplacesBytesReturnsHashAndEvictsOnlyTargetCache', 0, async () => {
      const fixture = new FontImportFixture();
      fixture.files.fakeHash = 'fake-new-content-hash';
      expect(await fixture.commit()).assertEqual('fake-new-content-hash');
      expectBytes(fixture.files.read(fixture.targetPath), fixture.importBytes);
      expect(fixture.files.validatedPath).assertEqual(fixture.tempPath);
      expect(fixture.files.validatedSize).assertEqual(fixture.importBytes.length);
      expect(fixture.files.events.join(',')).assertEqual('validate,hash,rename,removeTemporary');
      expect(fixture.bufferCache.has(fixture.targetPath)).assertFalse();
      expect(fixture.bufferCache.get(fixture.unrelatedPath) === fixture.unrelatedBuffer).assertTrue();
      expect(fixture.bufferCache.size).assertEqual(1);
      expectBytes(new Uint8Array(fixture.cachedBuffer), fixture.originalBytes);
      expectTemporaryRemoved(fixture);
    });

    it('validationFailurePreservesOriginalAndCleansTemporaryWithoutRename', 0, async () => {
      const fixture = new FontImportFixture();
      fixture.files.failValidation = true;
      expect(await expectImportFailure(fixture)).assertEqual('validation failed');
      expect(fixture.files.events.join(',')).assertEqual('validate,removeTemporary');
    });

    it('hashFailurePreservesOriginalAndCleansTemporaryWithoutRename', 0, async () => {
      const fixture = new FontImportFixture();
      fixture.files.failHash = true;
      expect(await expectImportFailure(fixture)).assertEqual('hash failed');
      expect(fixture.files.events.join(',')).assertEqual('validate,hash,removeTemporary');
    });

    it('protectsBuiltinImportNameCaseInsensitivelyButAllowsRenamedFiles', 0, () => {
      const reserved: string[] = [READER_BUILTIN_FONT_FILE_NAME, 'DINGTALKJINBUTI.TTF',
        'dInGtAlKjInBuTi.TtF'];
      for (let index = 0; index < reserved.length; index++) {
        let rejected = false;
        try {
          ReaderFontLogic.assertImportName(reserved[index]);
        } catch (_) {
          rejected = true;
        }
        expect(rejected).assertTrue();
      }
      ReaderFontLogic.assertImportName('Reader.ttf');
      ReaderFontLogic.assertImportName('DingTalkJinBuTi-copy.ttf');
    });

    it('commitRefusesProtectedDestinationBeforeValidationAndPreservesBuiltin', 0, async () => {
      const reserved: string[] = [READER_BUILTIN_FONT_FILE_NAME, 'DINGTALKJINBUTI.TTF',
        'dInGtAlKjInBuTi.TtF'];
      for (let index = 0; index < reserved.length; index++) {
        const fixture = new FontImportFixture(FONTS_DIR + '/' + reserved[index]);
        expect((await expectImportFailure(fixture)).length > 0).assertTrue();
        expect(fixture.files.events.join(',')).assertEqual('removeTemporary');
      }
    });

    it('matchesOnlySelectedManagedTtfOrOtfPathAndLocalFileUri', 0, () => {
      const selected: string[] = [SELECTED_FONT, FONTS_DIR + '/Reader.OTF'];
      for (let index = 0; index < selected.length; index++) {
        expect(ReaderFontLogic.matchesResource(FONTS_DIR, selected[index], selected[index])).assertTrue();
        expect(ReaderFontLogic.matchesResource(FONTS_DIR, selected[index], 'file://' + selected[index]))
          .assertTrue();
      }
    });

    it('doesNotServeEpubFontsWithTheSameBasename', 0, () => {
      const epubPath = '/data/storage/el2/base/haps/entry/files/books/book/OEBPS/fonts/Reader.ttf';
      const urls: string[] = ['Reader.ttf', 'fonts/Reader.ttf', '../fonts/Reader.ttf',
        'epub:///OEBPS/fonts/Reader.ttf', epubPath, 'file://' + epubPath];
      for (let index = 0; index < urls.length; index++) {
        expect(ReaderFontLogic.matchesResource(FONTS_DIR, SELECTED_FONT, urls[index])).assertFalse();
      }
    });

    it('rejectsSameBasenameInDifferentDirectoryEvenWhenSelected', 0, () => {
      const otherPath = '/data/storage/el2/base/haps/entry/files/other/Reader.ttf';
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, SELECTED_FONT, otherPath)).assertFalse();
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, SELECTED_FONT, 'file://' + otherPath)).assertFalse();
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, otherPath, otherPath)).assertFalse();
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, otherPath, 'file://' + otherPath)).assertFalse();
    });

    it('doesNotServeUnselectedFontsInsideManagedDirectory', 0, () => {
      const otherPath = FONTS_DIR + '/Other.ttf';
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, SELECTED_FONT, otherPath)).assertFalse();
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, SELECTED_FONT, 'file://' + otherPath)).assertFalse();
    });

    it('rejectsRemoteAuthoritiesAndNonLocalSchemes', 0, () => {
      const urls: string[] = ['file://localhost' + SELECTED_FONT, 'file://remote.example' + SELECTED_FONT,
        'https://remote.example' + SELECTED_FONT, 'http://remote.example' + SELECTED_FONT,
        'content://' + SELECTED_FONT, 'file:////remote.example' + SELECTED_FONT];
      for (let index = 0; index < urls.length; index++) {
        expect(ReaderFontLogic.matchesResource(FONTS_DIR, SELECTED_FONT, urls[index])).assertFalse();
      }
    });

    it('rejectsDirectoryPrefixLookalikesNestedPathsAndTraversal', 0, () => {
      const invalid: string[] = [FONTS_DIR + '-other/Reader.ttf', FONTS_DIR + '2/Reader.ttf',
        FONTS_DIR + '/../Reader.ttf', FONTS_DIR + '/nested/Reader.ttf',
        FONTS_DIR + '/nested\\Reader.ttf'];
      for (let index = 0; index < invalid.length; index++) {
        expect(ReaderFontLogic.matchesResource(FONTS_DIR, invalid[index], invalid[index])).assertFalse();
        expect(ReaderFontLogic.matchesResource(FONTS_DIR, invalid[index], 'file://' + invalid[index]))
          .assertFalse();
      }
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, SELECTED_FONT,
        FONTS_DIR + '/../fonts/Reader.ttf')).assertFalse();
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, SELECTED_FONT,
        'file://' + FONTS_DIR + '/%2e%2e/fonts/Reader.ttf')).assertFalse();
    });

    it('matchesEncodedChineseSpacesHashAndPercentInLocalFileUris', 0, () => {
      const selected = FONTS_DIR + '/中文 字体 #%.ttf';
      const uri = 'file://' + FONTS_DIR + '/%E4%B8%AD%E6%96%87%20%E5%AD%97%E4%BD%93%20%23%25.ttf';
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, selected, selected)).assertTrue();
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, selected, uri)).assertTrue();
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, selected, uri + '?download=1')).assertFalse();
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, selected, uri + '#fragment')).assertFalse();
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, selected, 'file://' + selected)).assertFalse();
    });

    it('keepsPercentEscapesLiteralInRawPathsAndDecodesFileUrisOnlyOnce', 0, () => {
      const selected = FONTS_DIR + '/Reader%20%23%25.ttf';
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, selected, selected)).assertTrue();
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, selected,
        FONTS_DIR + '/Reader #%.ttf')).assertFalse();
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, selected, 'file://' + selected)).assertFalse();
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, selected,
        'file://' + FONTS_DIR + '/Reader%2520%2523%2525.ttf')).assertTrue();
    });

    it('acceptsLiteralInvalidEscapesButRejectsMalformedFileUrisWithoutThrowing', 0, () => {
      const names: string[] = ['Reader%.ttf', 'Reader%2.ttf', 'Reader%GG.ttf', 'Reader%C3%28.ttf'];
      for (let index = 0; index < names.length; index++) {
        const selected = FONTS_DIR + '/' + names[index];
        expect(ReaderFontLogic.matchesResource(FONTS_DIR, selected, selected)).assertTrue();
        expect(ReaderFontLogic.matchesResource(FONTS_DIR, selected, 'file://' + selected)).assertFalse();
      }
    });

    it('rejectsSystemSelectionEmptyNamesAndNonFontFiles', 0, () => {
      expect(ReaderFontLogic.matchesResource(FONTS_DIR, '', SELECTED_FONT)).assertFalse();
      const invalid: string[] = [FONTS_DIR + '/', FONTS_DIR + '/Reader.woff',
        FONTS_DIR + '/Reader.ttf.css', FONTS_DIR + '/Reader\u0000.ttf'];
      for (let index = 0; index < invalid.length; index++) {
        expect(ReaderFontLogic.matchesResource(FONTS_DIR, invalid[index], invalid[index])).assertFalse();
      }
    });

    it('previewFamiliesDifferForSameStemWithDifferentExtensionOrDirectory', 0, () => {
      const family = ReaderFontLogic.previewFamily(SELECTED_FONT, 'hash-a');
      expect(family.length > 0).assertTrue();
      expect(family !== ReaderFontLogic.previewFamily(FONTS_DIR + '/Reader.otf', 'hash-a')).assertTrue();
      expect(family !== ReaderFontLogic.previewFamily('/other/fonts/Reader.ttf', 'hash-a')).assertTrue();
    });

    it('previewFamilyChangesWhenSamePathHasDifferentContentHash', 0, () => {
      expect(ReaderFontLogic.previewFamily(SELECTED_FONT, 'hash-a') !==
        ReaderFontLogic.previewFamily(SELECTED_FONT, 'hash-b')).assertTrue();
    });

    it('previewFamilyIsStableForRepeatedPathAndContentIdentity', 0, () => {
      const family = ReaderFontLogic.previewFamily(SELECTED_FONT, 'hash-a');
      expect(family.length > 0).assertTrue();
      expect(ReaderFontLogic.previewFamily(SELECTED_FONT, 'hash-a')).assertEqual(family);
      expect(ReaderFontLogic.previewFamily(SELECTED_FONT, 'hash-a')).assertEqual(family);
    });

    it('systemFontPreviewFamilyIsEmptyRegardlessOfHash', 0, () => {
      expect(ReaderFontLogic.previewFamily('', '')).assertEqual('');
      expect(ReaderFontLogic.previewFamily('', 'hash-a')).assertEqual('');
    });
  });
}
