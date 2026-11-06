import { BookOwnership } from './BookAccessState';
import { PrivacyForeground } from './PrivacyForeground';

export interface PrivateBookUnlockSnapshot {
  active: boolean;
  ready: boolean;
  ownership: BookOwnership;
  failed: boolean;
  unlocked: boolean;
  authenticating: boolean;
  generation: number;
}

export interface PrivateBookUnlockActions {
  snapshot: () => PrivateBookUnlockSnapshot;
  unlock: () => Promise<boolean>;
  restored: () => Promise<void>;
  returnToShelf: () => void;
  pendingChanged: (pending: boolean) => void;
}

/** A PIN route return is not a new foreground epoch and must never reopen authentication. */
export class PrivateBookAutoUnlock {
  private timer: number = -1;
  private operation: number = 0;
  private consumedEpoch: number = -1;
  private busy: boolean = false;
  private exitPending: boolean = false;
  private disposed: boolean = false;
  private unsubscribe: () => void;

  private foreground: PrivacyForeground;
  private actions: PrivateBookUnlockActions;
  private delayMs: number;

  constructor(foreground: PrivacyForeground, actions: PrivateBookUnlockActions, delayMs: number = 350) {
    this.foreground = foreground;
    this.actions = actions;
    this.delayMs = delayMs;
    this.unsubscribe = foreground.subscribe(() => {
      if (!foreground.isActive()) {
        this.cancelTimer();
        this.operation++;
        this.busy = false;
        this.exitPending = false;
        this.actions.pendingChanged(false);
      } else {
        this.reconcile();
      }
    });
  }

  reconcile(): void {
    if (this.disposed) return;
    const state = this.actions.snapshot();
    if (!this.foreground.isActive() || !state.active || !state.ready) {
      this.cancelTimer();
      return;
    }
    if (this.exitPending) {
      this.exitPending = false;
      this.actions.returnToShelf();
      return;
    }
    if (this.busy) return;
    if (state.ownership !== BookOwnership.PRIVATE || state.failed || state.unlocked) {
      this.cancelTimer();
      this.actions.pendingChanged(false);
      return;
    }
    this.actions.pendingChanged(true);
    if (this.consumedEpoch === this.foreground.getEpoch() || this.timer !== -1 || state.authenticating) return;
    const epoch = this.foreground.getEpoch();
    const generation = state.generation;
    this.timer = setTimeout(() => {
      this.timer = -1;
      const current = this.actions.snapshot();
      if (this.disposed || !this.foreground.isActive() || epoch !== this.foreground.getEpoch() ||
        generation !== current.generation || !current.active || !current.ready ||
        current.ownership !== BookOwnership.PRIVATE || current.failed || current.unlocked || current.authenticating) {
        this.reconcile();
        return;
      }
      this.consumedEpoch = epoch;
      this.busy = true;
      this.authenticate(++this.operation, epoch, generation);
    }, this.delayMs);
  }

  dispose(): void {
    this.disposed = true;
    this.operation++;
    this.cancelTimer();
    this.unsubscribe();
  }

  private cancelTimer(): void {
    if (this.timer !== -1) clearTimeout(this.timer);
    this.timer = -1;
  }

  private async authenticate(operation: number, epoch: number, generation: number): Promise<void> {
    let success = false;
    try {
      success = await this.actions.unlock();
    } catch (_) {
      success = false;
    }
    if (this.disposed || operation !== this.operation || !this.foreground.isActive() ||
      epoch !== this.foreground.getEpoch() || generation !== this.actions.snapshot().generation) return;
    try {
      if (success) {
        await this.actions.restored();
      } else {
        this.exitPending = true;
      }
    } finally {
      if (!this.disposed && operation === this.operation) {
        this.busy = false;
        if (success) this.actions.pendingChanged(false);
        this.reconcile();
      }
    }
  }
}
