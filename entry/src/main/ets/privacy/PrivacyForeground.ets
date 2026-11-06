export class PrivacyForeground {
  private active: boolean = false;
  private epoch: number = 0;
  private listeners: (() => void)[] = [];

  isActive(): boolean { return this.active; }
  getEpoch(): number { return this.epoch; }

  enter(): void {
    if (!this.active) this.epoch++;
    this.active = true;
    this.notify();
  }

  leave(): void {
    this.active = false;
    this.notify();
  }

  subscribe(listener: () => void): () => void {
    this.listeners.push(listener);
    return (): void => { this.listeners = this.listeners.filter(item => item !== listener); };
  }

  private notify(): void {
    this.listeners.slice().forEach(listener => listener());
  }
}

export default new PrivacyForeground();
