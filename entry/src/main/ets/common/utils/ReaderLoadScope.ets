/** Bounds reader work without allowing cancelled or late results to escape. */
export class ReaderLoadScope {
  private active: boolean = true;
  private cancelListeners: Set<() => void> = new Set<() => void>();

  isActive(): boolean {
    return this.active;
  }

  wait<T>(operation: Promise<T>, timeoutMs: number, message: string): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      let settled = false;
      let timerId: number = -1;
      const finish = (): boolean => {
        if (settled) return false;
        settled = true;
        if (timerId !== -1) {
          clearTimeout(timerId);
          timerId = -1;
        }
        this.cancelListeners.delete(onCancel);
        return true;
      };
      const onCancel = (): void => {
        if (finish()) reject(new Error('Reader load cancelled'));
      };

      // Observe both outcomes even when already cancelled, including late rejections.
      operation.then((value: T): void => {
        if (finish()) resolve(value);
      }, (error: Error): void => {
        if (finish()) reject(error);
      });
      if (!this.active) {
        onCancel();
        return;
      }
      this.cancelListeners.add(onCancel);
      timerId = setTimeout((): void => {
        if (finish()) reject(new Error(message));
      }, timeoutMs);
    });
  }

  cancel(): void {
    if (!this.active) return;
    this.active = false;
    this.cancelListeners.forEach((listener: () => void): void => { listener(); });
    this.cancelListeners.clear();
  }
}
