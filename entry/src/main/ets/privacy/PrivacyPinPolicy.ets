// Pure policy: no platform APIs, preferences, logging, or plaintext PIN persistence.
export class PrivacyCredentialRecord {
  version: number = 1;
  algorithm: string = 'PBKDF2|SHA256';
  iterations: number = 600000;
  saltBytes: number = 16;
  keySize: number = 32;
  saltHex: string;
  verifierHex: string;
  biometricEnabled: boolean = false;
  failedAttempts: number = 0;
  clockFloorMs: number;
  retryUntilMs: number = 0;

  constructor(saltHex: string, verifierHex: string, clockFloorMs: number) {
    this.saltHex = saltHex;
    this.verifierHex = verifierHex;
    this.clockFloorMs = clockFloorMs;
  }
}

export class PrivacyPinPolicy {
  static readonly ITERATIONS: number = 600000;
  static readonly SALT_BYTES: number = 16;
  static readonly KEY_BYTES: number = 32;
  static readonly MAX_RETRY_MS: number = 30 * 60 * 1000;
  // At eleven failures the exponential delay has already reached the cap.
  static readonly MAX_FAILURES: number = 11;
  static readonly CORRUPT_MESSAGE: string = '隐私凭据已损坏，无法安全认证，请勿清除应用数据';
  static readonly RETRY_MESSAGE: string = 'PIN尝试过于频繁，请稍后重试';

  static isValidPin(pin: string): boolean {
    return typeof pin === 'string' && pin.length === 6 && /^[0-9]{6}$/.test(pin);
  }

  static requirePin(pin: string): void {
    if (!PrivacyPinPolicy.isValidPin(pin)) {
      throw new Error('请输入6位数字PIN码');
    }
  }

  static requireConfirmation(pin: string, confirmation: string): void {
    PrivacyPinPolicy.requirePin(pin);
    PrivacyPinPolicy.requirePin(confirmation);
    if (pin !== confirmation) {
      throw new Error('两次输入的PIN码不一致');
    }
  }

  static requireTime(nowMs: number): void {
    if (!Number.isSafeInteger(nowMs) || nowMs < 0 ||
      nowMs > Number.MAX_SAFE_INTEGER - PrivacyPinPolicy.MAX_RETRY_MS) {
      throw new Error('隐私安全时钟异常，请校准时间后重试');
    }
  }

  static delayForFailures(failures: number): number {
    if (failures < 5) {
      return 0;
    }
    return Math.min(PrivacyPinPolicy.MAX_RETRY_MS, 30000 * Math.pow(2, Math.min(failures - 5, 6)));
  }

  static requireRecord(record: PrivacyCredentialRecord): void {
    if (record === null || typeof record !== 'object' || Array.isArray(record) ||
      Object.keys(record).length !== 11 || record.version !== 1 ||
      record.algorithm !== 'PBKDF2|SHA256' || record.iterations !== PrivacyPinPolicy.ITERATIONS ||
      record.saltBytes !== PrivacyPinPolicy.SALT_BYTES || record.keySize !== PrivacyPinPolicy.KEY_BYTES ||
      typeof record.saltHex !== 'string' || !/^[0-9a-f]{32}$/.test(record.saltHex) ||
      record.saltHex.length !== 32 || typeof record.verifierHex !== 'string' ||
      !/^[0-9a-f]{64}$/.test(record.verifierHex) || record.verifierHex.length !== 64 ||
      typeof record.biometricEnabled !== 'boolean' || !Number.isSafeInteger(record.failedAttempts) ||
      record.failedAttempts < 0 || record.failedAttempts > PrivacyPinPolicy.MAX_FAILURES ||
      !Number.isSafeInteger(record.clockFloorMs) || record.clockFloorMs < 0 ||
      record.clockFloorMs > Number.MAX_SAFE_INTEGER - PrivacyPinPolicy.MAX_RETRY_MS ||
      !Number.isSafeInteger(record.retryUntilMs) || record.retryUntilMs < 0) {
      throw new Error(PrivacyPinPolicy.CORRUPT_MESSAGE);
    }
    const delay = PrivacyPinPolicy.delayForFailures(record.failedAttempts);
    const expectedUntil = delay === 0 ? 0 : record.clockFloorMs + delay;
    if (record.retryUntilMs !== expectedUntil) {
      throw new Error(PrivacyPinPolicy.CORRUPT_MESSAGE);
    }
  }

  static decodeRecord(raw: string): PrivacyCredentialRecord {
    if (typeof raw !== 'string' || raw.length === 0 || raw.length > 2048) {
      throw new Error(PrivacyPinPolicy.CORRUPT_MESSAGE);
    }
    try {
      const record = JSON.parse(raw) as PrivacyCredentialRecord;
      PrivacyPinPolicy.requireRecord(record);
      return record;
    } catch (_) {
      throw new Error(PrivacyPinPolicy.CORRUPT_MESSAGE);
    }
  }

  static encodeRecord(record: PrivacyCredentialRecord): string {
    PrivacyPinPolicy.requireRecord(record);
    return JSON.stringify(record);
  }

  static bytesToHex(bytes: Uint8Array): string {
    let hex = '';
    for (let index = 0; index < bytes.length; index++) {
      hex += bytes[index].toString(16).padStart(2, '0');
    }
    return hex;
  }

  static hexToBytes(hex: string): Uint8Array {
    if (hex.length === 0 || hex.length % 2 !== 0 || !/^[0-9a-f]+$/.test(hex)) {
      throw new Error(PrivacyPinPolicy.CORRUPT_MESSAGE);
    }
    const bytes = new Uint8Array(hex.length / 2);
    for (let index = 0; index < bytes.length; index++) {
      bytes[index] = parseInt(hex.substring(index * 2, index * 2 + 2), 16);
    }
    return bytes;
  }

  // Equal-length comparisons always visit every byte; no mismatch-position early return.
  static constantTimeEqual(left: Uint8Array, right: Uint8Array): boolean {
    if (left.length !== right.length || left.length === 0) {
      return false;
    }
    let difference = 0;
    for (let index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference === 0;
  }

  static createRecord(salt: Uint8Array, verifier: Uint8Array, nowMs: number): PrivacyCredentialRecord {
    PrivacyPinPolicy.requireTime(nowMs);
    if (salt.length !== PrivacyPinPolicy.SALT_BYTES || verifier.length !== PrivacyPinPolicy.KEY_BYTES) {
      throw new Error('无法安全生成隐私凭据，请重试');
    }
    const record = new PrivacyCredentialRecord(PrivacyPinPolicy.bytesToHex(salt),
      PrivacyPinPolicy.bytesToHex(verifier), nowMs);
    PrivacyPinPolicy.requireRecord(record);
    return record;
  }

  static copyRecord(record: PrivacyCredentialRecord): PrivacyCredentialRecord {
    PrivacyPinPolicy.requireRecord(record);
    const copy = new PrivacyCredentialRecord(record.saltHex, record.verifierHex, record.clockFloorMs);
    copy.biometricEnabled = record.biometricEnabled;
    copy.failedAttempts = record.failedAttempts;
    copy.retryUntilMs = record.retryUntilMs;
    return copy;
  }

  static retryAfterMs(record: PrivacyCredentialRecord, nowMs: number): number {
    PrivacyPinPolicy.requireRecord(record);
    PrivacyPinPolicy.requireTime(nowMs);
    // A backwards wall clock can extend a cooldown, never erase it or increase its advertised cap.
    return Math.max(0, record.retryUntilMs - Math.max(record.clockFloorMs, nowMs));
  }

  static reserveAttempt(record: PrivacyCredentialRecord, nowMs: number): PrivacyCredentialRecord {
    if (PrivacyPinPolicy.retryAfterMs(record, nowMs) > 0) {
      throw new Error(PrivacyPinPolicy.RETRY_MESSAGE);
    }
    const reserved = PrivacyPinPolicy.copyRecord(record);
    reserved.failedAttempts = Math.min(PrivacyPinPolicy.MAX_FAILURES, reserved.failedAttempts + 1);
    reserved.clockFloorMs = Math.max(record.clockFloorMs, nowMs);
    const delay = PrivacyPinPolicy.delayForFailures(reserved.failedAttempts);
    reserved.retryUntilMs = delay === 0 ? 0 : reserved.clockFloorMs + delay;
    return reserved;
  }

  static clearAttempts(record: PrivacyCredentialRecord, nowMs: number): PrivacyCredentialRecord {
    PrivacyPinPolicy.requireTime(nowMs);
    const cleared = PrivacyPinPolicy.copyRecord(record);
    cleared.failedAttempts = 0;
    cleared.retryUntilMs = 0;
    cleared.clockFloorMs = Math.max(record.clockFloorMs, nowMs);
    return cleared;
  }
}
