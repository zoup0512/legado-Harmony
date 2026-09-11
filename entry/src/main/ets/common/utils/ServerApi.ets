/**
 * reader-dev 服务器书架 API 客户端
 *
 * 对接服务器 legacy reader3 接口（全部需 accessToken=用户名:token 鉴权）：
 *   GET  /reader3/getBookshelf                          → 书架（含 Web 端上传的本地书）
 *   GET  /reader3/getBookToc?url=<bookUrl>/toc          → 目录 [{title,url,index,...}]
 *   GET  /reader3/getBookContent?url=<chapterUrl>&index=→ {content}
 *   POST /reader3/saveBookProgress                      → 保存阅读进度
 */
import axios, { AxiosResponse, AxiosRequestConfig } from '@ohos/axios';
import bookDataPreferences from './DataPreferencesUtils';
import BooksDao from '../../database/dao/BooksDao';
import { Books } from '../../database/entities/Books';
import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import { buffer } from '@kit.ArkTS';

const PREF_SERVER_URL = 'server_shelf_url';
const PREF_SERVER_TOKEN = 'server_shelf_token';

// 本地书架中服务器书的来源标记（books.origin 列）
export const SERVER_SHELF_ORIGIN = 'server-shelf';
export const SERVER_SHELF_ORIGIN_NAME = '服务器书架';

export class ServerBook {
  name: string = '';
  author: string = '';
  bookUrl: string = '';
  tocUrl: string = '';
  coverUrl: string = '';
  intro: string = '';
  originName: string = '';
  totalChapterNum: number = 0;
  durChapterIndex: number = 0;
  durChapterTitle: string = '';
  latestChapterTitle: string = '';
  // server local://uuid 的原始文件通常位于 OPDS opds_files 目录
  serverFileName: string = '';
  serverFileSize: number = 0;
  serverFileModified: number = 0;
  // 本地缓存状态（由同步逻辑填充）
  downloaded: boolean = false;
  updateAvailable: boolean = false;
}

export class ServerFileMeta {
  name: string = '';
  size: number = 0;
  lastModified: number = 0;
}

export class ServerBookState {
  exists: boolean = false;
  updated: boolean = false;
  meta: ServerFileMeta | null = null;
}

export class ServerChapter {
  title: string = '';
  url: string = '';
  index: number = 0;
  chapterWordCount: number = 0;
}

export class ServerShelfResult {
  isSuccess: boolean = false;
  errorMsg: string = '';
  data: ServerBook[] = [];
}

export class ServerTocResult {
  isSuccess: boolean = false;
  errorMsg: string = '';
  data: ServerChapter[] = [];
}

export class ServerContentData {
  content: string = '';
}

export class ServerContentResult {
  isSuccess: boolean = false;
  errorMsg: string = '';
  data: ServerContentData | null = null;
}

class ServerFileEntry {
  name: string = '';
  size: number = 0;
  lastModified: number = 0;
  isDirectory: boolean = false;
}

class ServerFileListResult {
  isSuccess: boolean = false;
  errorMsg: string = '';
  data: ServerFileEntry[] = [];
}

class ProgressBody {
  bookUrl: string = '';
  name: string = '';
  author: string = '';
  durChapterIndex: number = 0;
  durChapterPos: number = 0;
  durChapterTime: number = 0;
  durChapterTitle: string = '';
}

export class ServerConfig {
  baseUrl: string = '';
  token: string = '';
}

class ServerApiClass {
  private timeout = 20000;

  getConfig(): ServerConfig {
    const config = new ServerConfig();
    const url = bookDataPreferences.shared.get(PREF_SERVER_URL);
    const token = bookDataPreferences.shared.get(PREF_SERVER_TOKEN);
    if (typeof url === 'string') {
      config.baseUrl = url;
    }
    if (typeof token === 'string') {
      config.token = token;
    }
    return config;
  }

  saveConfig(url: string, token: string): void {
    // 去掉末尾斜杠，统一拼接
    const normalized = url.trim().replace(/\/+$/, '');
    bookDataPreferences.shared.set(PREF_SERVER_URL, normalized);
    bookDataPreferences.shared.set(PREF_SERVER_TOKEN, token.trim());
  }

  hasConfig(): boolean {
    const config = this.getConfig();
    return config.baseUrl.length > 0 && config.token.length > 0;
  }

  // 本地书架行（origin=server-shelf）→ ServerBook（兼容旧缓存记录）
  toServerBook(book: Books): ServerBook {
    const sb = new ServerBook();
    sb.name = book.bookName;
    sb.author = book.author ?? '';
    // 兼容上一版：当时远端 local://uuid 被错误写进了 bookUrl
    sb.bookUrl = book.serverBookUrl ?? (book.bookUrl?.startsWith('local://') ? book.bookUrl : '');
    sb.tocUrl = book.toUrl ?? '';
    sb.coverUrl = book.coverUrl ?? '';
    sb.intro = book.intro ?? '';
    sb.originName = book.originName ?? SERVER_SHELF_ORIGIN_NAME;
    sb.totalChapterNum = book.totalChapterNum;
    sb.durChapterIndex = book.durChapterIndex;
    sb.durChapterTitle = book.durChapterTitle ?? '';
    sb.serverFileName = book.serverFileName ?? '';
    sb.serverFileSize = book.serverFileSize;
    sb.serverFileModified = book.serverFileModified;
    sb.downloaded = !!book.bookUrl && !book.bookUrl.startsWith('local://') && fs.accessSync(book.bookUrl);
    sb.updateAvailable = book.serverUpdateAvailable || !sb.downloaded;
    return sb;
  }

  private base(): string {
    return this.getConfig().baseUrl;
  }

  private authQuery(): string {
    return 'accessToken=' + encodeURIComponent(this.getConfig().token);
  }

  async getBookshelf(refresh: boolean = false): Promise<ServerBook[]> {
    const refreshQuery = refresh ? '&refresh=1' : '';
    const res: AxiosResponse<object> = await axios.get(
      `${this.base()}/reader3/getBookshelf?${this.authQuery()}${refreshQuery}`, { timeout: this.timeout });
    const ret = res.data as ServerShelfResult;
    if (!ret.isSuccess) {
      throw new Error(ret.errorMsg || '获取书架失败');
    }
    return ret.data || [];
  }

  // 用给定配置试连（不落盘）——保存前校验用
  async getBookshelfAt(url: string, token: string): Promise<ServerBook[]> {
    const normalized = url.trim().replace(/\/+$/, '');
    const query = 'accessToken=' + encodeURIComponent(token.trim());
    const res: AxiosResponse<object> = await axios.get(
      `${normalized}/reader3/getBookshelf?${query}`, { timeout: this.timeout });
    const ret = res.data as ServerShelfResult;
    if (!ret.isSuccess) {
      throw new Error(ret.errorMsg || '获取书架失败');
    }
    return ret.data || [];
  }

  private encodeBookId(bookUrl: string): string {
    return buffer.from(bookUrl, 'utf8').toString('base64url');
  }

  private safeFileName(name: string, serverBookUrl: string): string {
    let value = name.trim().replace(/[\\/:*?"<>|]/g, '_').replace(/\\.\\./g, '_');
    if (!value.toLowerCase().endsWith('.txt')) {
      value += '.txt';
    }
    if (value.length <= 4) {
      value = 'server-book-' + this.encodeBookId(serverBookUrl).substring(0, 12) + '.txt';
    }
    return value;
  }

  private serverFileUuid(serverBookUrl: string): string {
    const prefix = 'local://';
    return serverBookUrl.startsWith(prefix) ? serverBookUrl.substring(prefix.length) : serverBookUrl;
  }

  async getServerFileMeta(serverBookUrl: string): Promise<ServerFileMeta | null> {
    const uuid = this.serverFileUuid(serverBookUrl);
    const res: AxiosResponse<object> = await axios.get(
      `${this.base()}/reader3/file/list?${this.authQuery()}&home=__HOME__&path=/opds_files`,
      { timeout: this.timeout });
    const ret = res.data as ServerFileListResult;
    if (!ret.isSuccess) {
      throw new Error(ret.errorMsg || '获取服务器文件信息失败');
    }
    const entry = (ret.data || []).find((item: ServerFileEntry) =>
      !item.isDirectory && item.name.startsWith(uuid + '.'));
    if (!entry) {
      return null;
    }
    const meta = new ServerFileMeta();
    meta.name = entry.name;
    meta.size = Number(entry.size) || 0;
    meta.lastModified = Number(entry.lastModified) || 0;
    return meta;
  }

  async getServerBookState(book: Books): Promise<ServerBookState> {
    const state = new ServerBookState();
    if (!book.serverBookUrl) {
      return state;
    }
    const meta = await this.getServerFileMeta(book.serverBookUrl);
    state.meta = meta;
    state.exists = meta !== null;
    state.updated = !this.hasLocalCache(book) || (!!meta &&
      (book.serverFileSize !== meta.size || book.serverFileModified !== meta.lastModified));
    return state;
  }

  // 检查远端原文件并把结果写回本地书架行；网络失败不影响已有缓存离线阅读
  async refreshLocalStatus(book: Books): Promise<boolean> {
    if (!book.serverBookUrl) {
      return false;
    }
    try {
      const meta = await this.getServerFileMeta(book.serverBookUrl);
      if (meta) {
        book.serverFileName = meta.name;
        book.serverUpdateAvailable = !this.hasLocalCache(book) ||
          book.serverFileSize !== meta.size || book.serverFileModified !== meta.lastModified;
      } else {
        book.serverUpdateAvailable = !this.hasLocalCache(book);
      }
      await BooksDao.partialUpdate(book);
      return book.serverUpdateAvailable;
    } catch (e) {
      console.log('refreshLocalStatus failed: ' + JSON.stringify(e));
      return false;
    }
  }

  hasLocalCache(book?: Books): boolean {
    return !!book?.bookUrl && !book.bookUrl.startsWith('local://') && fs.accessSync(book.bookUrl);
  }

  async ensureLocalBook(context: common.UIAbilityContext, local: Books): Promise<Books> {
    // 兼容旧版记录：远端 local://uuid 曾被错误写入 bookUrl
    if (!local.serverBookUrl && local.bookUrl?.startsWith('local://')) {
      local.serverBookUrl = local.bookUrl;
      local.bookUrl = '';
    }
    if (!local.serverBookUrl) {
      if (this.hasLocalCache(local)) {
        return local;
      }
      throw new Error('服务器书籍记录缺少远端地址，请刷新服务器书架后重试');
    }
    const serverBook = this.toServerBook(local);
    let meta: ServerFileMeta | null = null;
    let checkCompleted = false;
    try {
      meta = await this.getServerFileMeta(local.serverBookUrl);
      checkCompleted = true;
      if (meta) {
        serverBook.serverFileName = meta.name;
        serverBook.serverFileSize = meta.size;
        serverBook.serverFileModified = meta.lastModified;
        local.serverUpdateAvailable = !this.hasLocalCache(local) ||
          local.serverFileSize !== meta.size || local.serverFileModified !== meta.lastModified;
      }
    } catch (e) {
      // 检查更新失败时，已有本地缓存仍可离线打开
      console.log('ensureLocalBook meta check failed: ' + JSON.stringify(e));
    }
    if (this.hasLocalCache(local) && (!checkCompleted || !meta || !local.serverUpdateAvailable)) {
      return local;
    }
    if (!meta || (serverBook.serverFileSize === 0 && serverBook.serverFileModified === 0)) {
      throw new Error('服务器文件不存在或尚未准备好');
    }
    return await this.downloadServerBook(context, serverBook, local);
  }

  async downloadServerBook(context: common.UIAbilityContext, serverBook: ServerBook, existing?: Books): Promise<Books> {
    if (!context || !context.filesDir || !serverBook.bookUrl) {
      throw new Error('下载参数不完整');
    }
    const fileName = this.safeFileName(serverBook.serverFileName || serverBook.name, serverBook.bookUrl);
    // 新书按远端 ID 生成稳定且不冲突的本地文件名，展示名仍由 bookName 保存
    const cacheName = 'server-' + this.encodeBookId(serverBook.bookUrl).substring(0, 16) + '-' + fileName;
    const destination = existing?.bookUrl && !existing.bookUrl.startsWith('local://')
      ? existing.bookUrl : context.filesDir + '/' + cacheName;
    const tempPath = destination + '.download';
    const request: AxiosRequestConfig = {
      responseType: 'array_buffer',
      timeout: 120000,
      headers: { 'Accept': 'text/plain,application/octet-stream' }
    };
    const id = this.encodeBookId(serverBook.bookUrl);
    const res: AxiosResponse<ArrayBuffer> = await axios.get(
      `${this.base()}/opds/download/${id}?${this.authQuery()}&format=txt`, request);
    const bytes = res.data;
    if (!(bytes instanceof ArrayBuffer) || bytes.byteLength === 0) {
      throw new Error('服务器返回空文件');
    }
    let file: fs.File | undefined;
    try {
      file = fs.openSync(tempPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, bytes);
      fs.closeSync(file);
      file = undefined;
      if (fs.accessSync(destination)) {
        fs.unlinkSync(destination);
      }
      fs.renameSync(tempPath, destination);
    } catch (e) {
      if (file) {
        fs.closeSync(file);
      }
      try {
        if (fs.accessSync(tempPath)) fs.unlinkSync(tempPath);
      } catch (_) {
      }
      throw new Error('本地文件保存失败');
    }
    const book = existing || new Books();
    book.bookName = serverBook.name;
    book.author = serverBook.author || '暂无';
    book.bookUrl = destination;
    book.toUrl = serverBook.tocUrl;
    book.origin = SERVER_SHELF_ORIGIN;
    book.originName = SERVER_SHELF_ORIGIN_NAME;
    book.coverUrl = serverBook.coverUrl;
    book.intro = serverBook.intro;
    book.serverBookUrl = serverBook.bookUrl;
    book.serverFileName = serverBook.serverFileName || fileName;
    book.serverFileSize = serverBook.serverFileSize;
    book.serverFileModified = serverBook.serverFileModified;
    book.serverUpdateAvailable = false;
    book.bookGroup = 4;
    book.bookType = 0;
    book.isJoin = true;
    book.isLocalBook = true;
    book.canUpdate = false;
    if (!existing) {
      await BooksDao.insert(book);
    } else {
      await BooksDao.update(book);
    }
    return book;
  }

  async getBookToc(book: ServerBook): Promise<ServerChapter[]> {
    // 优先书架返回的 tocUrl，兜底 bookUrl + /toc
    const tocUrl = book.tocUrl && book.tocUrl.length > 0 ? book.tocUrl : `${book.bookUrl}/toc`;
    const res: AxiosResponse<object> = await axios.get(
      `${this.base()}/reader3/getBookToc?${this.authQuery()}&url=${encodeURIComponent(tocUrl)}`,
      { timeout: this.timeout });
    const ret = res.data as ServerTocResult;
    if (!ret.isSuccess) {
      throw new Error(ret.errorMsg || '获取目录失败');
    }
    return ret.data || [];
  }

  async getBookContent(chapter: ServerChapter): Promise<string> {
    const res: AxiosResponse<object> = await axios.get(
      `${this.base()}/reader3/getBookContent?${this.authQuery()}`
      + `&url=${encodeURIComponent(chapter.url)}&index=${chapter.index}&cache=1`,
      { timeout: this.timeout });
    const ret = res.data as ServerContentResult;
    if (!ret.isSuccess || !ret.data || ret.data.content.length === 0) {
      throw new Error(ret.errorMsg || '获取正文失败');
    }
    return ret.data.content;
  }

  // 进度保存为尽力而为（best-effort）：失败不抛错不打断阅读
  async saveBookProgress(book: ServerBook, index: number, title: string): Promise<void> {
    try {
      const body = new ProgressBody();
      body.bookUrl = book.bookUrl;
      body.name = book.name;
      body.author = book.author;
      body.durChapterIndex = index;
      body.durChapterTitle = title;
      body.durChapterTime = Date.now();
      await axios.post(`${this.base()}/reader3/saveBookProgress?${this.authQuery()}`, body,
        { timeout: this.timeout });
    } catch (e) {
      console.log('saveBookProgress failed: ' + JSON.stringify(e));
    }
  }

  /**
   * 服务器书架 → 本地书架同步：
   *  - bookUrl 永远是设备上的本地文件路径；serverBookUrl 保存远端 local://uuid
   *  - 新书只同步元数据，首次点击时才下载完整 TXT
   *  - 已下载书只比较服务器 size/lastModified，不在同步时覆盖正在阅读的文件
   *  - 服务器删除的书同步删除本地缓存和书架记录
   */
  async syncToShelf(serverBooks: ServerBook[]): Promise<void> {
    try {
      const localRows = await BooksDao.getServerShelfBooks();
      const byServerUrl = new Map<string, Books>();
      const legacyByUrl = new Map<string, Books>();
      localRows.forEach((b: Books) => {
        if (b.serverBookUrl) {
          byServerUrl.set(b.serverBookUrl, b);
        }
        // 兼容上一版：当时把远端 local://uuid 错误写入了 bookUrl
        if (!b.serverBookUrl && b.bookUrl && b.bookUrl.startsWith('local://')) {
          legacyByUrl.set(b.bookUrl, b);
        }
      });
      const serverUrls = new Set<string>();
      for (const sb of serverBooks) {
        serverUrls.add(sb.bookUrl);
        let local = byServerUrl.get(sb.bookUrl) || legacyByUrl.get(sb.bookUrl);
        let remoteMeta: ServerFileMeta | null = null;
        try {
          remoteMeta = await this.getServerFileMeta(sb.bookUrl);
          if (remoteMeta) {
            sb.serverFileName = remoteMeta.name;
            sb.serverFileSize = remoteMeta.size;
            sb.serverFileModified = remoteMeta.lastModified;
          }
        } catch (e) {
          console.log('getServerFileMeta failed: ' + JSON.stringify(e));
        }
        if (local) {
          // 旧版错误记录没有真正本地文件，清空逻辑 URL，等待首次下载
          if (!local.serverBookUrl) {
            local.bookUrl = '';
          }
          local.bookName = sb.name;
          local.author = sb.author || '暂无';
          local.coverUrl = sb.coverUrl;
          local.intro = sb.intro;
          local.toUrl = sb.tocUrl;
          local.totalChapterNum = sb.totalChapterNum;
          local.latestChapterTitle = sb.latestChapterTitle;
          local.origin = SERVER_SHELF_ORIGIN;
          local.originName = SERVER_SHELF_ORIGIN_NAME;
          local.serverBookUrl = sb.bookUrl;
          local.isLocalBook = true;
          local.bookGroup = local.bookGroup === 99 ? 99 : 4;
          local.canUpdate = false;
          local.updateTime = Date.now();
          const hasLocalFile = this.hasLocalCache(local);
          local.serverUpdateAvailable = !hasLocalFile || (!!remoteMeta &&
            (local.serverFileSize !== remoteMeta.size || local.serverFileModified !== remoteMeta.lastModified));
          if (!local.serverFileName && remoteMeta) {
            local.serverFileName = remoteMeta.name;
          }
          if (local.durChapterTime === 0) {
            local.durChapterIndex = sb.durChapterIndex;
            local.durChapterTitle = sb.durChapterTitle;
          }
          await BooksDao.update(local);
        } else {
          local = new Books();
          local.bookName = sb.name;
          local.author = sb.author || '暂无';
          local.bookUrl = '';
          local.toUrl = sb.tocUrl;
          local.origin = SERVER_SHELF_ORIGIN;
          local.originName = SERVER_SHELF_ORIGIN_NAME;
          local.coverUrl = sb.coverUrl;
          local.intro = sb.intro;
          local.totalChapterNum = sb.totalChapterNum;
          local.latestChapterTitle = sb.latestChapterTitle;
          local.durChapterIndex = sb.durChapterIndex;
          local.durChapterTitle = sb.durChapterTitle;
          local.durChapterPos = 0;
          local.durChapterTime = 0;
          local.bookGroup = 4;
          local.bookType = 0;
          local.isJoin = true;
          local.isLocalBook = true;
          local.canUpdate = false;
          local.serverBookUrl = sb.bookUrl;
          local.serverFileName = remoteMeta?.name || sb.serverFileName;
          local.serverFileSize = 0;
          local.serverFileModified = 0;
          local.serverUpdateAvailable = true;
          const inserted = await BooksDao.insert(local);
          if (!inserted) {
            console.log('server book insert skipped (possible name/author conflict): ' + sb.name);
          }
        }
        // 回传给服务器书架页面，用于显示“未下载/有更新”状态
        const hasFile = !!local.bookUrl && !local.bookUrl.startsWith('local://') && fs.accessSync(local.bookUrl);
        sb.downloaded = hasFile;
        sb.updateAvailable = !hasFile || (!!remoteMeta &&
          (local.serverFileSize !== remoteMeta.size || local.serverFileModified !== remoteMeta.lastModified));
      }
      const removed: number[] = [];
      localRows.forEach((b: Books) => {
        const remoteUrl = b.serverBookUrl || (b.bookUrl && b.bookUrl.startsWith('local://') ? b.bookUrl : '');
        if (b.id !== undefined && remoteUrl && !serverUrls.has(remoteUrl)) {
          if (b.bookUrl && !b.bookUrl.startsWith('local://') && fs.accessSync(b.bookUrl)) {
            try {
              fs.unlinkSync(b.bookUrl);
            } catch (e) {
              console.log('server cache delete failed: ' + JSON.stringify(e));
            }
          }
          removed.push(b.id);
        }
      });
      if (removed.length > 0) {
        await BooksDao.deleteBook(removed);
      }
    } catch (e) {
      console.log('syncToShelf failed: ' + JSON.stringify(e));
    }
  }
}

const serverApi = new ServerApiClass();
export default serverApi;
