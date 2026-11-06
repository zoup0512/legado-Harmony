import { describe, expect, it } from '@ohos/hypium';
import { ReaderLoadScope } from '../../../main/ets/common/utils/ReaderLoadScope';
import { PageAccessRefresh } from '../../../main/ets/privacy/PageAccessRefresh';

class LoadGate {
  promise: Promise<number>;
  private resolveValue: (value: number) => void = (_value: number): void => {};
  private rejectError: (error: Error) => void = (_error: Error): void => {};

  constructor() {
    this.promise = new Promise<number>((resolve, reject) => {
      this.resolveValue = resolve;
      this.rejectError = reject;
    });
  }

  resolve(value: number): void { this.resolveValue(value); }
  reject(error: Error): void { this.rejectError(error); }
}

function pause(milliseconds: number): Promise<void> {
  return new Promise<void>((resolve) => { setTimeout(resolve, milliseconds); });
}

async function rejected(operation: Promise<number>): Promise<Error> {
  let failure: Error | undefined;
  await operation.then((): void => {}, (error: Error): void => { failure = error; });
  expect(failure instanceof Error).assertTrue();
  return failure as Error;
}

export default function readerLoadScopeTest() {
  describe('ReaderLoadScopeTest', () => {
    it('cancelledPendingInitDoesNotBlockNextPageAccessRefresh', 0, async () => {
      const refresh = new PageAccessRefresh();
      const oldScope = new ReaderLoadScope();
      const pendingInit = new LoadGate();
      const entered = new LoadGate();
      let publications = 0;
      const old = refresh.refresh(1, true, async (_requestId: number): Promise<boolean> => {
        const initializing = oldScope.wait(pendingInit.promise, 100, 'init timeout');
        entered.resolve(1);
        await initializing;
        publications++;
        return true;
      });
      let oldRejected = false;
      const oldDone = old.then((): void => {}, (): void => { oldRejected = true; });
      await entered.promise;
      oldScope.cancel();
      refresh.invalidate();
      const newScope = new ReaderLoadScope();
      await refresh.refresh(1, true, async (_requestId: number): Promise<boolean> => {
        await newScope.wait(Promise.resolve(2), 100, 'new init timeout');
        publications++;
        return true;
      });
      await oldDone;
      expect(oldRejected).assertTrue();
      expect(publications).assertEqual(1);
      pendingInit.resolve(1);
      await pause(5);
      expect(publications).assertEqual(1);
    });

    it('timeoutRejectsWithMessageAndNewScopeCanRetryRefresh', 0, async () => {
      const refresh = new PageAccessRefresh();
      const firstScope = new ReaderLoadScope();
      const pendingInit = new LoadGate();
      let failure: Error | undefined;
      await refresh.refresh(1, true, async (_requestId: number): Promise<boolean> => {
        await firstScope.wait(pendingInit.promise, 5, 'reader init timed out');
        return true;
      }).then((): void => {}, (error: Error): void => { failure = error; });
      expect(failure instanceof Error).assertTrue();
      expect((failure as Error).message).assertEqual('reader init timed out');
      const retryScope = new ReaderLoadScope();
      let completed = false;
      await refresh.refresh(1, true, async (_requestId: number): Promise<boolean> => {
        await retryScope.wait(Promise.resolve(1), 100, 'retry timeout');
        completed = true;
        return true;
      });
      expect(completed).assertTrue();
      pendingInit.reject(new Error('late init failure'));
      await pause(5);
    });

    it('lateResolveAfterCancellationDoesNotPublish', 0, async () => {
      const scope = new ReaderLoadScope();
      const operation = new LoadGate();
      let published = 0;
      let failures = 0;
      const done = scope.wait(operation.promise, 100, 'timeout').then((value: number): void => {
        published = value;
      }, (): void => { failures++; });
      scope.cancel();
      await done;
      operation.resolve(42);
      await pause(5);
      expect(published).assertEqual(0);
      expect(failures).assertEqual(1);
    });

    it('lateRejectAfterCancellationIsObserved', 0, async () => {
      const scope = new ReaderLoadScope();
      const operation = new LoadGate();
      const done = rejected(scope.wait(operation.promise, 100, 'timeout'));
      scope.cancel();
      const failure = await done;
      operation.reject(new Error('late failure'));
      await pause(5);
      expect(failure.message).assertEqual('Reader load cancelled');
    });

    it('waitAfterCancellationNeverReleasesEvenResolvedOperation', 0, async () => {
      const scope = new ReaderLoadScope();
      scope.cancel();
      const failure = await rejected(scope.wait(Promise.resolve(42), 5, 'timeout'));
      expect(failure.message).assertEqual('Reader load cancelled');
      expect(scope.isActive()).assertFalse();
      const late = new LoadGate();
      const done = rejected(scope.wait(late.promise, 5, 'timeout'));
      late.reject(new Error('already cancelled failure'));
      expect((await done).message).assertEqual('Reader load cancelled');
      await pause(5);
    });

    it('normalCompletionPropagatesValueAndLeavesScopeActive', 0, async () => {
      const scope = new ReaderLoadScope();
      const value = await scope.wait(Promise.resolve(42), 5, 'timeout');
      expect(value).assertEqual(42);
      expect(scope.isActive()).assertTrue();
      await pause(10);
      expect(await scope.wait(Promise.resolve(7), 5, 'timeout')).assertEqual(7);
      scope.cancel();
      expect(value).assertEqual(42);
    });

    it('operationRejectionPropagatesOriginalError', 0, async () => {
      const scope = new ReaderLoadScope();
      const error = new Error('reader init failed');
      const failure = await rejected(scope.wait(Promise.reject<number>(error), 5, 'timeout'));
      expect(failure === error).assertTrue();
      expect(scope.isActive()).assertTrue();
      await pause(10);
      expect(await scope.wait(Promise.resolve(3), 5, 'timeout')).assertEqual(3);
    });

    it('repeatedCancellationRejectsEveryPendingWaitOnlyOnce', 0, async () => {
      const scope = new ReaderLoadScope();
      const first = new LoadGate();
      const second = new LoadGate();
      const firstDone = rejected(scope.wait(first.promise, 100, 'first timeout'));
      const secondDone = rejected(scope.wait(second.promise, 100, 'second timeout'));
      expect(scope.isActive()).assertTrue();
      scope.cancel();
      expect(scope.isActive()).assertFalse();
      scope.cancel();
      expect((await firstDone).message).assertEqual('Reader load cancelled');
      expect((await secondDone).message).assertEqual('Reader load cancelled');
      first.resolve(1);
      second.reject(new Error('late second failure'));
      await pause(5);
      scope.cancel();
      expect(scope.isActive()).assertFalse();
    });
  });
}
