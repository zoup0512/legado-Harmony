export const READER_BUILTIN_FONT_FILE_NAME: string = 'DingTalkJinBuTi.ttf';

/** 文件系统适配器：提交前完成校验和内容版本计算，不以删除旧文件的方式覆盖。 */
export interface ReaderFontImportFiles {
  validate(path: string, expectedSize: number): Promise<string>;
  rename(source: string, target: string): void;
  removeTemporary(path: string): void;
}

/** 与平台无关的字体身份、资源匹配和导入事务。 */
export class ReaderFontLogic {
  static assertImportName(fileName: string): void {
    if (fileName.toLowerCase() === READER_BUILTIN_FONT_FILE_NAME.toLowerCase()) {
      throw new Error('不能覆盖内置字体，请重命名后导入');
    }
  }

  static hasFontSignature(bytes: Uint8Array): boolean {
    if (bytes.length < 4) {
      return false;
    }
    const tag = String.fromCharCode(bytes[0], bytes[1], bytes[2], bytes[3]);
    const isTrueType = bytes[0] === 0 && bytes[1] === 1 && bytes[2] === 0 && bytes[3] === 0;
    return isTrueType || tag === 'true' || tag === 'ttcf' || tag === 'OTTO' || tag === 'typ1';
  }

  /** 只允许当前选中的受管文件；不将 EPUB 里的同名文件当作应用字体。 */
  static matchesResource(fontsDir: string, selectedPath: string, url: string): boolean {
    const prefix = fontsDir + '/';
    if (!selectedPath.startsWith(prefix)) {
      return false;
    }
    const fileName = selectedPath.substring(prefix.length);
    if (fileName.length === 0 || /[\/\\\u0000-\u001f]/.test(fileName) ||
      !/\.(ttf|otf)$/i.test(fileName)) {
      return false;
    }
    if (url === selectedPath) {
      return true;
    }
    // 只解码无 authority/query/fragment 的 file URI，原始本地路径不做 URL 解码。
    if (!url.startsWith('file:///') || url.includes('?') || url.includes('#')) {
      return false;
    }
    try {
      return decodeURIComponent(url.substring('file://'.length)) === selectedPath;
    } catch (_) {
      return false;
    }
  }

  /** 编码完整路径与内容版本，字体名相同或文件原地更新时也不会共用预览 family。 */
  static previewFamily(path: string, contentHash: string): string {
    if (path.length === 0) {
      return '';
    }
    let pathIdentity = '';
    for (let index = 0; index < path.length; index++) {
      pathIdentity += path.charCodeAt(index).toString(16).padStart(4, '0');
    }
    return 'reader_font_' + pathIdentity + '_' + contentHash;
  }

  /** rename 失败时不删旧目标；仅在提交成功后使缓存失效。 */
  static async commitImport(files: ReaderFontImportFiles, tempPath: string, targetPath: string,
    expectedSize: number, bufferCache: Map<string, ArrayBuffer>): Promise<string> {
    try {
      ReaderFontLogic.assertImportName(targetPath.substring(targetPath.lastIndexOf('/') + 1));
      const contentHash = await files.validate(tempPath, expectedSize);
      files.rename(tempPath, targetPath);
      bufferCache.delete(targetPath);
      return contentHash;
    } finally {
      files.removeTemporary(tempPath);
    }
  }
}
