/**
 * ReaderKitShim — 仅用于模拟器测试构建的本地桩（test-only stub）。
 *
 * 背景：应用静态依赖 @kit.ReaderKit（HMS Kit，运行时解析为 com.huawei.hmsapp.readerkit
 * 的 kitview.hsp）。所有 DevEco 模拟器系统镜像均未随附该 HSP（真机系统应用），应用在
 * 模拟器上启动即 SIGABRT。本文件按 SDK 中 @hms.core.readerservice.bookParser.d.ts 与
 * @hms.core.readerservice.readerComponent.d.ets 的声明提供同名同签名的本地实现，使应用
 * 可在模拟器上启动。
 *
 * 边界说明：本桩不改变任何业务逻辑代码；隐私文件夹功能（认证/PIN/解锁）的代码路径
 * 完全不引用本文件中的任何运行时符号。阅读器页面在模拟器测试中不会被打开，桩中
 * 运行时方法要么空实现要么返回拒绝的 Promise。
 */
import { common } from '@kit.AbilityKit';
import { AsyncCallback, BusinessError } from '@kit.BasicServicesKit';

export namespace bookParser {
  /**
   * Book parser handler stub（类型与 SDK 声明一致）。
   */
  export class BookParserHandler {
    public getBookInfo(): BookInfo {
      throw new Error('ReaderKit 桩：模拟器环境不提供书籍解析');
    }

    public getCatalogList(): CatalogItem[] {
      return [];
    }

    public getSpineList(): SpineItem[] {
      return [];
    }

    public getSpineItemContent(spineIndex: number): Promise<string> {
      return Promise.reject(new Error('ReaderKit 桩：模拟器环境不提供书籍解析'));
    }

    public getResourceContent(spineIndex: number, filePath: string): ArrayBuffer {
      return new ArrayBuffer(0);
    }

    public getDomPosByCatalogHref(href: string): string {
      return '';
    }

    public getAbsoluteResourcePath(spineIndex: number): string {
      return '';
    }
  }

  export interface SpineItem {
    idRef: string;
    index: number;
    href: string;
    properties: string;
  }

  export interface CatalogItem {
    catalogId: number;
    catalogName: string;
    catalogLevel?: number;
    playOrder?: number;
    idRef?: string;
    href?: string;
    resourceFile?: string;
  }

  export interface BookInfo {
    bookTitle: string;
    bookCreator?: string;
    bookPublishDate?: string;
    bookLanguage?: string;
    bookCoverImage?: string;
    bookCharset?: string;
    bookType?: string;
    isRtl?: boolean;
    renditionLayout?: string;
    renditionOrientation?: string;
    renditionSpread?: string;
  }

  export type CallbackRes<T, V> = (data: T) => V;

  export function getDefaultHandler(path: string): Promise<BookParserHandler> {
    return Promise.reject(new Error('ReaderKit 桩：模拟器环境不提供书籍解析'));
  }
}

export namespace readerCore {
  export enum PageState {
    PAGE_WAITING = 1,
    PAGE_LOADING = 2,
    PAGE_ON_SHOW = 3,
    OPEN_BOOK_FAIL = 4
  }

  export class PageDatabaseBean {
    public nodeType: string = '';
    public dataId: string = '';

    public constructor(nodeType: string, nodeDataId: string) {
      this.nodeType = nodeType;
      this.dataId = nodeDataId;
    }
  }

  export class PageDataInfo extends PageDatabaseBean {
    public pageHeaderContent: string = '';
    public pageFooterContent: string = '';
    public startDomPos: string = '';
    public endDomPos: string = '';
    public state: PageState = PageState.PAGE_WAITING;
    public resourceIndex: number = 0;
    public pageOffset: number = 0;

    public constructor(nodeType: string = '', nodeId: string = '') {
      super(nodeType, nodeId);
    }
  }

  export interface ReaderSetting {
    fontName: string;
    fontSize: number;
    fontWeight: number;
    fontColor: string;
    fontPath: string;
    lineHeight: number;
    nightMode: boolean;
    themeColor: string;
    themeBgImg: string;
    flipMode: string;
    scaledDensity: number;
    viewPortWidth: number;
    viewPortHeight: number;
  }

  /**
   * Reader component controller stub（类型与 SDK 声明一致，运行时为空实现）。
   */
  export class ReaderComponentController {
    public init(context: common.UIAbilityContext): Promise<void> {
      return Promise.reject(new Error('ReaderKit 桩：模拟器环境不提供阅读组件'));
    }

    public startPlay(spineIndex: number, domPos: string): Promise<void> {
      return Promise.reject(new Error('ReaderKit 桩：模拟器环境不提供阅读组件'));
    }

    public flipPage(isNext: boolean): void {
    }

    public setPageConfig(pageConfig: ReaderSetting): void {
    }

    public releaseBook(): void {
    }

    public registerBookParser(bookParserHandler: bookParser.BookParserHandler): void {
    }

    public on(type: 'pageShow' | 'resourceRequest',
      callback: ((data: PageDataInfo) => void) | ((url: string) => ArrayBuffer)): void {
    }

    public off(type: 'pageShow' | 'resourceRequest',
      callback?: ((data: PageDataInfo) => void) | ((url: string) => ArrayBuffer)): void {
    }
  }
}

@Component
export struct ReadPageComponent {
  controller: readerCore.ReaderComponentController = new readerCore.ReaderComponentController();
  readerCallback: AsyncCallback<readerCore.ReaderComponentController> =
    (_err: BusinessError, _data: readerCore.ReaderComponentController): void => {};

  build() {
    Blank()
  }
}
