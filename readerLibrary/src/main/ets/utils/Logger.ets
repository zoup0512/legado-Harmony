import hilog from '@ohos.hilog';

export type LogLevel = 'debug' | 'warn' | 'error';

// Scalar arguments stay separate all the way to HiLog; never pass an args array.
export interface LogSink {
  write(level: LogLevel, domain: number, tag: string, format: string,
    event: string, detail: string, code: number): void;
}

class HiLogSink implements LogSink {
  write(level: LogLevel, domain: number, tag: string, format: string,
    event: string, detail: string, code: number): void {
    switch (level) {
      case 'debug':
        hilog.debug(domain, tag, format, event, detail, code);
        break;
      case 'warn':
        hilog.warn(domain, tag, format, event, detail, code);
        break;
      case 'error':
        hilog.error(domain, tag, format, event, detail, code);
        break;
    }
  }
}

export class SafeLogger {
  private debugEnabled: boolean = false;
  private sink: LogSink;
  private readonly domain: number = 0xFF00;
  private readonly tag: string = 'MiDu';
  private readonly format: string = '%{public}s; detail=%{private}s; code=%{public}d';

  constructor(sink: LogSink = new HiLogSink()) {
    this.sink = sink;
  }

  configureDebug(enabled: boolean): void {
    this.debugEnabled = enabled;
  }

  // Only fixed event literals belong in event. All dynamic text belongs in detail.
  debug(event: string, detail: string = '', code: number = 0): void {
    if (!this.debugEnabled) return;
    this.write('debug', event, detail, code);
  }

  // Compatibility aliases: diagnostic info/log must never bypass the debug gate.
  info(event: string, detail: string = '', code: number = 0): void {
    this.debug(event, detail, code);
  }

  log(event: string, detail: string = '', code: number = 0): void {
    this.debug(event, detail, code);
  }

  warn(event: string, detail: string = '', code: number = 0): void {
    this.write('warn', event, detail, code);
  }

  error(event: string, detail: string = '', code: number = 0): void {
    this.write('error', event, detail, code);
  }

  // No business-object traversal, JSON conversion, stack or custom toString calls.
  errorSummary(error: Object): string {
    if (error instanceof Error) {
      return this.limitDetail(error.name + ': ' + error.message);
    }
    if (typeof error === 'string') return this.limitDetail(error);
    return 'Error details unavailable';
  }

  private limitDetail(detail: string): string {
    return detail.replace(/[\r\n\t]/g, ' ').slice(0, 160);
  }

  private write(level: LogLevel, event: string, detail: string, code: number): void {
    try {
      this.sink.write(level, this.domain, this.tag, this.format, event, this.limitDetail(detail),
        Number.isFinite(code) ? code : 0);
    } catch (_) {
      // Logging failures must not change application control flow.
    }
  }
}

export default new SafeLogger();
