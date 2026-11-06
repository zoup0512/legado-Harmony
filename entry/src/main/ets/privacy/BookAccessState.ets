export enum BookOwnership {
  UNKNOWN,
  PUBLIC,
  PRIVATE
}

/** Ownership is not authorization: every visible entry still needs a current check. */
export class BookAccessState {
  static fromPrivate(required: boolean): BookOwnership {
    return required ? BookOwnership.PRIVATE : BookOwnership.PUBLIC;
  }

  static canAccess(ownership: BookOwnership, unlocked: boolean,
    verifiedGeneration: number, generation: number): boolean {
    return verifiedGeneration === generation && verifiedGeneration >= 0 &&
      (ownership === BookOwnership.PUBLIC || (ownership === BookOwnership.PRIVATE && unlocked));
  }

  static isCurrent(active: boolean, ready: boolean, requestId: number, currentRequestId: number,
    generation: number, currentGeneration: number): boolean {
    return active && ready && requestId === currentRequestId && generation === currentGeneration;
  }

  static isLocked(ownership: BookOwnership, checking: boolean, failed: boolean): boolean {
    return ownership === BookOwnership.PRIVATE && !checking && !failed;
  }

  static coverTitle(ownership: BookOwnership, checking: boolean, failed: boolean): string {
    if (failed) return '访问权限检查失败';
    return BookAccessState.isLocked(ownership, checking, failed) ? '隐私内容已锁定' : '正在确认访问权限…';
  }
}
