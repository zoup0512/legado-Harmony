import { promptAction } from '@kit.ArkUI';

export enum PrivacySessionState {
  LOCKED = 'locked',
  UNLOCKED = 'unlocked'
}

class PrivacySessionService {
  private state: PrivacySessionState = PrivacySessionState.LOCKED;
  private listeners: Array<(locked: boolean) => void> = [];

  isUnlocked(): boolean { return this.state === PrivacySessionState.UNLOCKED; }

  async unlock(): Promise<boolean> {
    // The first version uses an explicit in-app confirmation gate. The session is
    // memory-only and is always revoked when the app backgrounds.
    this.state = PrivacySessionState.UNLOCKED;
    this.notify();
    return true;
  }

  lock(): void {
    this.state = PrivacySessionState.LOCKED;
    this.notify();
  }

  onStateChanged(listener: (locked: boolean) => void): void { this.listeners.push(listener); }
  private notify(): void {
    const locked = !this.isUnlocked();
    this.listeners.forEach(listener => listener(locked));
  }

  async requireUnlock(): Promise<boolean> {
    if (this.isUnlocked()) return true;
    await promptAction.showToast({ message: '请先解锁隐私文件夹' });
    return false;
  }
}

export default new PrivacySessionService();
