import fs from '@ohos.file.fs';
import { bookParser } from '@kit.ReaderKit';
import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';
import Logger from './Logger';

// 封面统一缩放到长边不超过该值后以 JPEG 存入应用私有目录
const COVER_MAX_SIDE: number = 600;
const COVER_QUALITY: number = 85;
// 封面比例 宽:高 = 3:4
const COVER_ASPECT: number = 3 / 4;

export interface ExtractedBookInfo {
  coverPath: string
  author: string
}

class BookCoverStore {
  private coverDir(): string {
    const dir = getContext().filesDir + '/covers';
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir, true);
    }
    return dir;
  }

  /** 是否为本模块写入的封面文件，只有这类文件允许删除 */
  isStoredCover(path?: string): boolean {
    return !!path && path.startsWith(getContext().filesDir + '/covers/') && !path.includes('..');
  }

  deleteCover(path?: string): void {
    if (!this.isStoredCover(path)) return;
    try {
      if (fs.accessSync(path as string)) {
        fs.unlinkSync(path as string);
      }
    } catch (_) {
    }
  }

  /** 本地书是否可能带有内置封面（TXT 没有） */
  mayHaveEmbeddedCover(bookPath?: string): boolean {
    return !!bookPath && !bookPath.toLowerCase().endsWith('.txt');
  }

  /** 从已创建的解析器中提取书内封面与作者；没有封面时 coverPath 为空串 */
  async extractFromParser(handler: bookParser.BookParserHandler): Promise<ExtractedBookInfo> {
    const result: ExtractedBookInfo = { coverPath: '', author: '' };
    try {
      const info = handler.getBookInfo();
      result.author = (info?.bookCreator ?? '').trim();
      if (info?.bookCoverImage) {
        const buffer = handler.getResourceContent(-1, info.bookCoverImage);
        if (buffer && buffer.byteLength > 0) {
          result.coverPath = await this.saveImage(buffer, false);
        }
      }
    } catch (_) {
      Logger.warn('BookCoverStore.extractFromParser failed');
    }
    return result;
  }

  async extractFromBookFile(bookPath: string): Promise<ExtractedBookInfo> {
    try {
      const handler = await bookParser.getDefaultHandler(bookPath);
      return await this.extractFromParser(handler);
    } catch (_) {
      const empty: ExtractedBookInfo = { coverPath: '', author: '' };
      return empty;
    }
  }

  /** 把相册等外部图片复制进私有目录（居中裁剪为 3:4），返回新文件路径 */
  async importImage(uri: string): Promise<string> {
    let file: fs.File | undefined;
    try {
      file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const size = fs.statSync(file.fd).size;
      const buffer = new ArrayBuffer(size);
      fs.readSync(file.fd, buffer);
      return await this.saveImage(buffer, true);
    } catch (_) {
      Logger.warn('BookCoverStore.importImage failed');
      return '';
    } finally {
      if (file) {
        try {
          fs.closeSync(file);
        } catch (_) {
        }
      }
    }
  }

  private async saveImage(buffer: ArrayBuffer, cropToCover: boolean): Promise<string> {
    const source = image.createImageSource(buffer);
    let pixelMap: image.PixelMap | undefined;
    try {
      const info = await source.getImageInfo();
      let width = info.size.width;
      let height = info.size.height;
      if (width <= 0 || height <= 0) return '';
      pixelMap = await source.createPixelMap();
      if (cropToCover) {
        // 居中裁剪为 3:4
        let cropW = width;
        let cropH = Math.round(width / COVER_ASPECT);
        if (cropH > height) {
          cropH = height;
          cropW = Math.round(height * COVER_ASPECT);
        }
        await pixelMap.crop({
          x: Math.floor((width - cropW) / 2),
          y: Math.floor((height - cropH) / 2),
          size: { width: cropW, height: cropH }
        });
        width = cropW;
        height = cropH;
      }
      const scale = Math.min(1, COVER_MAX_SIDE / Math.max(width, height));
      if (scale < 1) {
        await pixelMap.scale(scale, scale);
      }
      const packer = image.createImagePacker();
      let data: ArrayBuffer;
      try {
        data = await packer.packToData(pixelMap, { format: 'image/jpeg', quality: COVER_QUALITY });
      } finally {
        packer.release();
      }
      const path = this.coverDir() + '/' + util.generateRandomUUID() + '.jpg';
      const out = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(out.fd, data);
      } finally {
        fs.closeSync(out);
      }
      return path;
    } finally {
      pixelMap?.release();
      source.release();
    }
  }
}

const bookCoverStore = new BookCoverStore();
export default bookCoverStore;
