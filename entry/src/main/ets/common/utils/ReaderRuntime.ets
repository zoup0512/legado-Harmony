import { bookParser, readerCore } from '@kit.ReaderKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ReaderLoadScope } from './ReaderLoadScope';

/** One controller belongs to exactly one mounted reading surface. Never reuse it after disposal. */
export class ReaderRuntime {
  id: number;
  requestId: number;
  generation: number;
  controller: readerCore.ReaderComponentController = new readerCore.ReaderComponentController();
  scope: ReaderLoadScope = new ReaderLoadScope();
  parser: bookParser.BookParserHandler | undefined;
  ready: Promise<void>;
  firstFrame: Promise<void>;
  fontListenerRegistered: boolean = false;
  private initializing: boolean = false;
  private resolveReady: () => void = (): void => {};
  private rejectReady: (error: Error) => void = (_error: Error): void => {};
  private resolveFrame: () => void = (): void => {};
  private rejectFrame: (error: Error) => void = (_error: Error): void => {};

  constructor(id: number, requestId: number, generation: number) {
    this.id = id;
    this.requestId = requestId;
    this.generation = generation;
    this.ready = new Promise<void>((resolve, reject) => {
      this.resolveReady = resolve;
      this.rejectReady = reject;
    });
    this.firstFrame = new Promise<void>((resolve, reject) => {
      this.resolveFrame = resolve;
      this.rejectFrame = reject;
    });
    // The panel can fail before its parent has attached the bounded waits.
    this.ready.catch(() => {});
    this.firstFrame.catch(() => {});
  }

  initialize(context: common.UIAbilityContext): void {
    if (this.initializing || !this.scope.isActive()) return;
    this.initializing = true;
    try {
      this.controller.init(context).then(() => {
        if (this.scope.isActive()) this.resolveReady();
      }, () => {
        if (this.scope.isActive()) this.rejectReady(new Error('阅读器初始化失败'));
      });
    } catch (_) {
      this.rejectReady(new Error('阅读器初始化失败'));
    }
  }

  componentReady(error: BusinessError, controller: readerCore.ReaderComponentController): void {
    if (!this.scope.isActive()) return;
    if ((error && error.code) || (controller && controller !== this.controller)) {
      const failure = new Error('阅读组件初始化失败，请重试');
      this.rejectReady(failure);
      this.rejectFrame(failure);
    }
  }

  frameShown(): void { if (this.scope.isActive()) this.resolveFrame(); }
  frameFailed(): void { if (this.scope.isActive()) this.rejectFrame(new Error('正文排版失败，请重试')); }

  dispose(): void {
    if (!this.scope.isActive()) return;
    this.scope.cancel();
    try { this.controller.off('pageShow'); } catch (_) {}
    try { this.controller.off('resourceRequest'); } catch (_) {}
    try { this.controller.releaseBook(); } catch (_) {}
    this.parser = undefined;
  }
}
