class PageAccessRequest {
  requestId: number;
  generation: number;
  unlocked: boolean;
  pending: boolean = true;
  completed: boolean = false;
  promise: Promise<void> = Promise.resolve();

  constructor(requestId: number, generation: number, unlocked: boolean) {
    this.requestId = requestId;
    this.generation = generation;
    this.unlocked = unlocked;
  }
}

/** Coalesce duplicate lifecycle callbacks, never authorization across hide/lock boundaries. */
export class PageAccessRefresh {
  private nextRequestId: number = 0;
  private current: PageAccessRequest | undefined;
  private tail: Promise<void> = Promise.resolve();

  getRequestId(): number {
    return this.current?.requestId ?? this.nextRequestId;
  }

  invalidate(): void {
    this.nextRequestId++;
    this.current = undefined;
  }

  refresh(generation: number, unlocked: boolean,
    operation: (requestId: number) => Promise<boolean>): Promise<void> {
    const current = this.current;
    if (current !== undefined && current.generation === generation && current.unlocked === unlocked &&
      (current.pending || current.completed)) {
      return current.promise;
    }
    const request = new PageAccessRequest(++this.nextRequestId, generation, unlocked);
    this.current = request;
    request.promise = this.tail.then(async (): Promise<void> => {
      if (this.current !== request) return;
      try {
        const completed = await operation(request.requestId);
        if (this.current === request) request.completed = completed;
      } finally {
        request.pending = false;
      }
    });
    // A stale parser must finish before the next request touches the same ReaderKit controller.
    this.tail = request.promise.then(() => {}, () => {});
    return request.promise;
  }
}
