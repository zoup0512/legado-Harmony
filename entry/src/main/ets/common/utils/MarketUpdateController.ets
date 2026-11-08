export interface MarketUpdateCallbacks {
  onError: () => void;
  onAppear: () => void;
  onDisappear: () => void;
}

export enum MarketUpdateFailure {
  OPEN_FAILED,
  TIMEOUT
}

export interface MarketUpdateTimer {
  schedule(callback: () => void, delayMs: number): number;
  cancel(timerId: number): void;
}

class SystemMarketUpdateTimer implements MarketUpdateTimer {
  schedule(callback: () => void, delayMs: number): number {
    return setTimeout(callback, delayMs);
  }

  cancel(timerId: number): void {
    clearTimeout(timerId);
  }
}

/** loadProduct returns void: only callbacks (not its return) establish market lifecycle. */
export class MarketUpdateController {
  private active: boolean = false;
  private sequence: number = 0;
  private currentRequest: number = 0;
  private timerId: number = -1;
  private timer: MarketUpdateTimer;

  constructor(timer: MarketUpdateTimer = new SystemMarketUpdateTimer()) {
    this.timer = timer;
  }

  activate(): void {
    this.active = true;
  }

  deactivate(): void {
    this.active = false;
    this.currentRequest = 0;
    this.clearTimer();
  }

  open(load: (callbacks: MarketUpdateCallbacks) => void,
    feedback: (failure: MarketUpdateFailure) => void): boolean {
    if (!this.active || this.currentRequest !== 0) return false;
    const requestId = ++this.sequence;
    this.currentRequest = requestId;
    const fail = (failure: MarketUpdateFailure): void => {
      if (!this.isCurrent(requestId)) return;
      this.finish();
      feedback(failure);
    };
    let appeared = false;
    // Bound the wait for onAppear, including platforms which omit lifecycle callbacks.
    this.timerId = this.timer.schedule((): void => {
      if (!appeared) fail(MarketUpdateFailure.TIMEOUT);
    }, 10000);
    try {
      load({
        onError: (): void => { fail(MarketUpdateFailure.OPEN_FAILED); },
        onAppear: (): void => {
          // Keep duplicate clicks locked while the product page is displayed.
          if (!this.isCurrent(requestId)) return;
          appeared = true;
          this.clearTimer();
        },
        onDisappear: (): void => {
          if (this.isCurrent(requestId)) this.finish();
        }
      });
    } catch (_) {
      fail(MarketUpdateFailure.OPEN_FAILED);
    }
    return true;
  }

  private isCurrent(requestId: number): boolean {
    return this.active && this.currentRequest === requestId;
  }

  private finish(): void {
    this.currentRequest = 0;
    this.clearTimer();
  }

  private clearTimer(): void {
    if (this.timerId === -1) return;
    this.timer.cancel(this.timerId);
    this.timerId = -1;
  }
}
