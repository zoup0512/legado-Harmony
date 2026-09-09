/**
 * reader-dev 服务器书架 API 客户端
 *
 * 对接服务器 legacy reader3 接口（全部需 accessToken=用户名:token 鉴权）：
 *   GET  /reader3/getBookshelf                          → 书架（含 Web 端上传的本地书）
 *   GET  /reader3/getBookToc?url=<bookUrl>/toc          → 目录 [{title,url,index,...}]
 *   GET  /reader3/getBookContent?url=<chapterUrl>&index=→ {content}
 *   POST /reader3/saveBookProgress                      → 保存阅读进度
 */
import axios, { AxiosResponse } from '@ohos/axios';
import bookDataPreferences from './DataPreferencesUtils';

const PREF_SERVER_URL = 'server_shelf_url';
const PREF_SERVER_TOKEN = 'server_shelf_token';

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

  private base(): string {
    return this.getConfig().baseUrl;
  }

  private authQuery(): string {
    return 'accessToken=' + encodeURIComponent(this.getConfig().token);
  }

  async getBookshelf(): Promise<ServerBook[]> {
    const res: AxiosResponse<object> = await axios.get(
      `${this.base()}/reader3/getBookshelf?${this.authQuery()}`, { timeout: this.timeout });
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
}

const serverApi = new ServerApiClass();
export default serverApi;
