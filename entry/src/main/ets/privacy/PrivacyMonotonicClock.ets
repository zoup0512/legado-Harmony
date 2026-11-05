import { systemDateTime } from '@kit.BasicServicesKit';
import { PrivacyPinPolicy } from './PrivacyPinPolicy';

// STARTUP includes deep sleep; milliseconds are available since API 10. Never fall back to wall time.
export function privacyUptimeMs(): number {
  return systemDateTime.getUptime(systemDateTime.TimeType.STARTUP, false);
}

export class PrivacyMonotonicClock {
  private readonly uptime: () => number;
  private lastMs: number = 0;

  constructor(uptime: () => number = privacyUptimeMs) {
    this.uptime = uptime;
  }

  now(): number {
    const nowMs = this.uptime();
    if (!Number.isSafeInteger(nowMs) || nowMs < this.lastMs) {
      throw new Error('隐私安全时钟异常，请稍后重试');
    }
    this.lastMs = nowMs;
    return nowMs;
  }
}

// Keep the v1 record's timestamp domain, but use wall time only when seeding a non-pending record.
export class PrivacyCooldownClock {
  private readonly wallNow: () => number;
  private readonly elapsed: PrivacyMonotonicClock;
  private seeded: boolean = false;
  private seedMs: number = 0;
  private startedAtMs: number = 0;

  constructor(wallNow: () => number = () => Date.now(), uptime: () => number = privacyUptimeMs) {
    this.wallNow = wallNow;
    this.elapsed = new PrivacyMonotonicClock(uptime);
  }

  seed(clockFloorMs: number, pendingCooldown: boolean): void {
    if (this.seeded) return;
    // A restarted process cannot prove elapsed time from persisted wall timestamps. Wait the full
    // capped delay once, even if the wall clock says it expired. Status reads must never rearm it.
    const seedMs = pendingCooldown ? clockFloorMs : Math.max(clockFloorMs, this.wallNow());
    PrivacyPinPolicy.requireTime(seedMs);
    const startedAtMs = this.elapsed.now();
    this.seedMs = seedMs;
    this.startedAtMs = startedAtMs;
    this.seeded = true;
  }

  now(): number {
    if (!this.seeded) {
      throw new Error('隐私安全时钟尚未初始化');
    }
    const nowMs = this.seedMs + (this.elapsed.now() - this.startedAtMs);
    PrivacyPinPolicy.requireTime(nowMs);
    return nowMs;
  }
}
