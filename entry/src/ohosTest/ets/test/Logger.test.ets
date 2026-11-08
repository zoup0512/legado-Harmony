import { describe, expect, it } from '@ohos/hypium';
import Logger, { SafeLogger, LogSink, LogLevel } from '../../../main/ets/common/utils/Logger';
import { Logger as LibraryLogger } from '@ohos/readerLibrary';

class CapturingLogSink implements LogSink {
  levels: LogLevel[] = [];
  domains: number[] = [];
  tags: string[] = [];
  formats: string[] = [];
  events: string[] = [];
  details: string[] = [];
  codes: number[] = [];

  write(level: LogLevel, domain: number, tag: string, format: string,
    event: string, detail: string, code: number): void {
    this.levels.push(level);
    this.domains.push(domain);
    this.tags.push(tag);
    this.formats.push(format);
    this.events.push(event);
    this.details.push(detail);
    this.codes.push(code);
  }
}

class FailingLogSink implements LogSink {
  write(_level: LogLevel, _domain: number, _tag: string, _format: string,
    _event: string, _detail: string, _code: number): void {
    throw new Error('sink unavailable');
  }
}

class UnsupportedLogObject {
  toString(): string { throw new Error('must not inspect business objects'); }
}

export default function loggerTest() {
  describe('LoggerTest', () => {
    it('entryReExportUsesTheLibrarySingleton', 0, () => {
      expect(Logger === LibraryLogger).assertTrue();
    });

    it('debugAndCompatibilityAliasesAreDisabledByDefault', 0, () => {
      const sink = new CapturingLogSink();
      const logger = new SafeLogger(sink);
      logger.debug('Debug event');
      logger.info('Info event');
      logger.log('Log event');
      expect(sink.events.length).assertEqual(0);
      logger.warn('Warning event');
      logger.error('Error event');
      expect(sink.levels.join(',')).assertEqual('warn,error');
    });

    it('configureDebugCanOpenAndCloseAllDiagnosticOutput', 0, () => {
      const sink = new CapturingLogSink();
      const logger = new SafeLogger(sink);
      logger.configureDebug(true);
      logger.debug('Debug event');
      logger.info('Info event');
      logger.log('Log event');
      logger.configureDebug(false);
      logger.debug('Suppressed event');
      logger.info('Suppressed info');
      logger.log('Suppressed log');
      expect(sink.levels.join(',')).assertEqual('debug,debug,debug');
    });

    it('fixedEventsAndNumericCodesArePublicButDynamicDetailsArePrivateScalars', 0, () => {
      const sink = new CapturingLogSink();
      const logger = new SafeLogger(sink);
      const secret = 'private book /storage/name.epub %{public}s';
      logger.error('Import failed', secret, 42);
      expect(sink.formats[0]).assertEqual('%{public}s; detail=%{private}s; code=%{public}d');
      expect(sink.formats[0].includes(secret)).assertFalse();
      expect(sink.events[0]).assertEqual('Import failed');
      expect(sink.details[0]).assertEqual(secret);
      expect(sink.codes[0]).assertEqual(42);
      expect(sink.domains[0]).assertEqual(0xFF00);
      expect(sink.tags[0]).assertEqual('MiDu');
    });

    it('detailsAreBoundedAndSingleLineAndInvalidNumbersAreNormalized', 0, () => {
      const sink = new CapturingLogSink();
      const logger = new SafeLogger(sink);
      logger.warn('Bounded event', 'line\nnext\r\ttail' + 'x'.repeat(200), Number.NaN);
      expect(sink.details[0].length).assertEqual(160);
      expect(sink.details[0].includes('\n')).assertFalse();
      expect(sink.details[0].includes('\r')).assertFalse();
      expect(sink.details[0].includes('\t')).assertFalse();
      expect(sink.codes[0]).assertEqual(0);
    });

    it('errorSummaryNeverSerializesBusinessObjects', 0, () => {
      const logger = new SafeLogger(new CapturingLogSink());
      expect(logger.errorSummary(new UnsupportedLogObject())).assertEqual('Error details unavailable');
      expect(logger.errorSummary('short\nmessage')).assertEqual('short message');
      expect(logger.errorSummary(new Error('failure'))).assertEqual('Error: failure');
      expect(logger.errorSummary('x'.repeat(200)).length).assertEqual(160);
    });

    it('sinkFailureDoesNotChangeApplicationControlFlow', 0, () => {
      const logger = new SafeLogger(new FailingLogSink());
      logger.configureDebug(true);
      logger.debug('Debug event');
      logger.warn('Warning event');
      logger.error('Error event');
      expect(true).assertTrue();
    });
  });
}
