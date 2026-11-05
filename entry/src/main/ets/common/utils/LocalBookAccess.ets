import fs from '@ohos.file.fs';

export const LOCAL_BOOK_MISSING_MESSAGE: string = '本地书籍文件不存在，请重新导入';

/** 只做字符串/资源选择，不访问文件系统，也不修改已有书籍元数据。 */
export class LocalBookAccessLogic {
  private static isAbsoluteLocalPath(path: string): boolean {
    return path.startsWith('/') && !path.startsWith('//') && path === path.trim() &&
      !/[\u0000-\u001f\u007f\\]/.test(path);
  }

  static localPathOf(source?: string): string {
    if (!source || source !== source.trim() || /[\u0000-\u001f\u007f\\]/.test(source)) {
      return '';
    }
    if (LocalBookAccessLogic.isAbsoluteLocalPath(source)) {
      return source;
    }
    // 只接受无远端 authority 的 file URI；ReaderKit 使用解码后的绝对路径。
    if (!source.startsWith('file:///') || source.includes('?') || source.includes('#')) {
      return '';
    }
    try {
      const path = decodeURIComponent(source.substring('file://'.length));
      return LocalBookAccessLogic.isAbsoluteLocalPath(path) ? path : '';
    } catch (_) {
      return '';
    }
  }

  static isLocalFilePath(source?: string): boolean {
    return LocalBookAccessLogic.localPathOf(source).length > 0;
  }

  static selectLocalCover(source: ResourceStr | undefined, fallback: ResourceStr): ResourceStr {
    if (source === undefined) {
      return fallback;
    }
    if (typeof source !== 'string') {
      return source;
    }
    if (LocalBookAccessLogic.isLocalFilePath(source)) {
      return source;
    }
    // PhotoViewPicker 返回的系统媒体库 URI 是本地资源，不是 file://host 网络共享。
    if (source.startsWith('file://media/Photo/') && source.length > 'file://media/Photo/'.length &&
      source === source.trim() && !/[\u0000-\u001f\u007f\\?#]/.test(source)) {
      return source;
    }
    return fallback;
  }
}

/** 不依赖 isLocalBook/origin：实际以只读方式打开非空普通文件后才允许解析。 */
export function requireReadableLocalBookPath(source?: string): string {
  const path = LocalBookAccessLogic.localPathOf(source);
  if (path.length === 0) {
    throw new Error(LOCAL_BOOK_MISSING_MESSAGE);
  }
  let file: fs.File | undefined;
  try {
    file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    const stat = fs.statSync(file.fd);
    if (!stat.isFile() || stat.size <= 0 || fs.readSync(file.fd, new ArrayBuffer(1)) <= 0) {
      throw new Error(LOCAL_BOOK_MISSING_MESSAGE);
    }
    return path;
  } catch (_) {
    throw new Error(LOCAL_BOOK_MISSING_MESSAGE);
  } finally {
    if (file) {
      try {
        fs.closeSync(file);
      } catch (_) {
      }
    }
  }
}

export function isReadableLocalBook(source?: string): boolean {
  try {
    requireReadableLocalBookPath(source);
    return true;
  } catch (_) {
    return false;
  }
}
