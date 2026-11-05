/** No session/DAO imports: the session binds its live accessors after construction. */
export class PrivacyAccessGuard {
  private unlockedProvider: (() => boolean) | undefined;
  private generationProvider: (() => number) | undefined;

  bind(isUnlocked: () => boolean, getGeneration: () => number): void {
    this.unlockedProvider = isUnlocked;
    this.generationProvider = getGeneration;
  }

  getGeneration(): number {
    try {
      return this.generationProvider ? this.generationProvider() : -1;
    } catch (_) {
      return -1;
    }
  }

  capture(): number {
    try {
      if (!this.unlockedProvider || !this.unlockedProvider()) return -1;
      const generation = this.getGeneration();
      return generation >= 0 ? generation : -1;
    } catch (_) {
      return -1;
    }
  }

  isValid(generation: number): boolean {
    return generation >= 0 && this.capture() === generation;
  }
}

const privacyAccessGuard = new PrivacyAccessGuard();

export function bindPrivacySession(isUnlocked: () => boolean, getGeneration: () => number): void {
  privacyAccessGuard.bind(isUnlocked, getGeneration);
}

export function capturePrivacyGeneration(): number {
  return privacyAccessGuard.capture();
}

export function isPrivacyGenerationValid(generation: number): boolean {
  return privacyAccessGuard.isValid(generation);
}

export function getPrivacyGeneration(): number {
  return privacyAccessGuard.getGeneration();
}
