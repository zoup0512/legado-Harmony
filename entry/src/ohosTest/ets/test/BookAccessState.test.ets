import { describe, expect, it } from '@ohos/hypium';
import { BookAccessState, BookOwnership } from '../../../main/ets/privacy/BookAccessState';
import { PageAccessRefresh } from '../../../main/ets/privacy/PageAccessRefresh';

class LifecycleGate {
  wait: Promise<void>;
  private release: () => void = (): void => {};
  constructor() { this.wait = new Promise<void>((resolve) => { this.release = resolve; }); }
  open(): void { this.release(); }
}

// Exercise the same ownership and request guards used by both pages.
class AccessLifecycle {
  ownership: BookOwnership = BookOwnership.PUBLIC;
  active: boolean = true;
  generation: number = 1;
  verifiedGeneration: number = 1;
  failed: boolean = false;
  checking: boolean = false;
  published: number = 0;
  refresh: PageAccessRefresh = new PageAccessRefresh();

  sessionChanged(): void {
    this.generation++;
    this.refresh.invalidate();
    this.verifiedGeneration = -1;
    this.checking = !this.failed;
  }

  isCurrent(requestId: number, generation: number): boolean {
    return BookAccessState.isCurrent(this.active, true, requestId, this.refresh.getRequestId(),
      generation, this.generation);
  }

  check(wait: Promise<void>, fail: boolean = false): Promise<void> {
    const generation = this.generation;
    return this.refresh.refresh(generation, false, async (requestId: number): Promise<boolean> => {
      this.checking = true;
      this.failed = false;
      try {
        await wait;
        if (fail) throw new Error('old lookup failed');
        if (!this.isCurrent(requestId, generation)) return false;
        this.ownership = BookAccessState.fromPrivate(false);
        this.verifiedGeneration = generation;
        this.published++;
        return true;
      } catch (_) {
        if (this.isCurrent(requestId, generation)) {
          this.ownership = BookOwnership.UNKNOWN;
          this.failed = true;
        }
        return false;
      } finally {
        if (this.isCurrent(requestId, generation)) this.checking = false;
      }
    });
  }
}

export default function bookAccessStateTest() {
  describe('BookAccessStateTest', () => {
    it('unknownOwnershipIsNeverPresentedAsPrivateLock', 0, () => {
      expect(BookAccessState.isLocked(BookOwnership.UNKNOWN, false, false)).assertFalse();
      expect(BookAccessState.coverTitle(BookOwnership.UNKNOWN, true, false)).assertEqual('正在确认访问权限…');
      expect(BookAccessState.canAccess(BookOwnership.UNKNOWN, true, 1, 1)).assertFalse();
    });

    it('publicBookDoesNotRequireUnlockedPrivacySession', 0, () => {
      expect(BookAccessState.canAccess(BookOwnership.PUBLIC, false, 2, 2)).assertTrue();
      expect(BookAccessState.isLocked(BookOwnership.PUBLIC, false, false)).assertFalse();
      expect(BookAccessState.canAccess(BookOwnership.PUBLIC, false, 1, 2)).assertFalse();
    });

    it('privateBookStillLocksAndRequiresCurrentAuthentication', 0, () => {
      expect(BookAccessState.isLocked(BookOwnership.PRIVATE, false, false)).assertTrue();
      expect(BookAccessState.canAccess(BookOwnership.PRIVATE, false, 2, 2)).assertFalse();
      expect(BookAccessState.canAccess(BookOwnership.PRIVATE, true, 1, 2)).assertFalse();
      expect(BookAccessState.canAccess(BookOwnership.PRIVATE, true, 2, 2)).assertTrue();
    });

    it('lookupErrorRemainsErrorAcrossSessionChanges', 0, () => {
      const page = new AccessLifecycle();
      page.ownership = BookOwnership.UNKNOWN;
      page.failed = true;
      page.sessionChanged();
      expect(page.checking).assertFalse();
      expect(BookAccessState.isLocked(page.ownership, page.checking, page.failed)).assertFalse();
      expect(BookAccessState.coverTitle(page.ownership, page.checking, page.failed)).assertEqual('访问权限检查失败');
    });

    it('rejectsHiddenOldRequestAndChangedGeneration', 0, () => {
      expect(BookAccessState.isCurrent(false, true, 1, 1, 2, 2)).assertFalse();
      expect(BookAccessState.isCurrent(true, false, 1, 1, 2, 2)).assertFalse();
      expect(BookAccessState.isCurrent(true, true, 1, 2, 2, 2)).assertFalse();
      expect(BookAccessState.isCurrent(true, true, 1, 1, 1, 2)).assertFalse();
      expect(BookAccessState.isCurrent(true, true, 1, 1, 2, 2)).assertTrue();
    });

    it('showBeforeForegroundDiscardsOldSuccessAndFinally', 0, async () => {
      const page = new AccessLifecycle();
      const gate = new LifecycleGate();
      const old = page.check(gate.wait);
      await Promise.resolve();
      await Promise.resolve();
      page.sessionChanged();
      const current = page.check(Promise.resolve());
      gate.open();
      await Promise.all([old, current]);
      expect(page.published).assertEqual(1);
      expect(page.checking).assertFalse();
      expect(page.failed).assertFalse();
      expect(BookAccessState.canAccess(page.ownership, false, page.verifiedGeneration, page.generation)).assertTrue();
    });

    it('oldFailureCannotReplaceNewPublicOwnershipWithError', 0, async () => {
      const page = new AccessLifecycle();
      const gate = new LifecycleGate();
      const old = page.check(gate.wait, true);
      await Promise.resolve();
      await Promise.resolve();
      page.sessionChanged();
      const current = page.check(Promise.resolve());
      gate.open();
      await Promise.all([old, current]);
      expect(page.failed).assertFalse();
      expect(page.ownership).assertEqual(BookOwnership.PUBLIC);
      expect(page.published).assertEqual(1);
    });

    it('foregroundBeforeShowCoalescesSameGenerationChecks', 0, async () => {
      const page = new AccessLifecycle();
      page.sessionChanged();
      const foreground = page.check(Promise.resolve());
      const show = page.check(Promise.resolve());
      expect(foreground === show).assertTrue();
      await Promise.all([foreground, show]);
      expect(page.published).assertEqual(1);
      page.active = false;
      page.sessionChanged();
      expect(BookAccessState.isLocked(page.ownership, page.checking, page.failed)).assertFalse();
      page.active = true;
      page.sessionChanged();
      await page.check(Promise.resolve());
      expect(page.published).assertEqual(2);
      expect(page.checking).assertFalse();
    });
  });
}
