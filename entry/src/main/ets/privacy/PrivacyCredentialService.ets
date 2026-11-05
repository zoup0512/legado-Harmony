import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { PrivacyCredentialRecord, PrivacyPinPolicy } from './PrivacyPinPolicy';

export class PrivacyCredentialStatus {
  configured: boolean = false;
  biometricEnabled: boolean = false;
  retryAfterMs: number = 0;
}

// Small dependency seams for deterministic Hypium tests. The production store requires init(context).
export interface PrivacyCredentialStore {
  init(context: common.Context): void;
  read(): Promise<string | undefined>;
  put(record: string): Promise<void>;
  flush(): Promise<void>;
}

export interface PrivacyCredentialCrypto {
  randomSalt(): Promise<Uint8Array>;
  derive(pin: string, salt: Uint8Array): Promise<Uint8Array>;
}

class PreferencesCredentialStore implements PrivacyCredentialStore {
  private context: common.Context | undefined;
  private instance: preferences.Preferences | undefined;
  private readonly name: string = 'privacy_pin_credentials_v1';
  private readonly key: string = 'credential_record';

  init(context: common.Context): void {
    if (context === undefined || context === null) {
      throw new Error('隐私安全服务尚未初始化');
    }
    // Never switch preference contexts, evict a dirty cache, or reset a failed service on re-init.
    if (this.context === undefined) {
      this.context = context;
    }
  }

  private async getPreferences(): Promise<preferences.Preferences> {
    const context = this.context;
    if (context === undefined) {
      throw new Error('隐私安全服务尚未初始化');
    }
    let instance = this.instance;
    if (instance === undefined) {
      instance = await preferences.getPreferences(context, { name: this.name });
      this.instance = instance;
    }
    return instance;
  }

  async read(): Promise<string | undefined> {
    const instance = await this.getPreferences();
    if (!await instance.has(this.key)) {
      return undefined;
    }
    const value = await instance.get(this.key, '');
    if (typeof value !== 'string') {
      throw new Error(PrivacyPinPolicy.CORRUPT_MESSAGE);
    }
    return value;
  }

  async put(record: string): Promise<void> {
    const instance = await this.getPreferences();
    await instance.put(this.key, record);
  }

  async flush(): Promise<void> {
    const instance = await this.getPreferences();
    await instance.flush();
  }
}

class NativePrivacyCredentialCrypto implements PrivacyCredentialCrypto {
  async randomSalt(): Promise<Uint8Array> {
    return (await cryptoFramework.createRandom().generateRandom(PrivacyPinPolicy.SALT_BYTES)).data;
  }

  async derive(pin: string, salt: Uint8Array): Promise<Uint8Array> {
    const specification: cryptoFramework.PBKDF2Spec = {
      algName: 'PBKDF2',
      password: pin,
      salt: salt,
      iterations: PrivacyPinPolicy.ITERATIONS,
      keySize: PrivacyPinPolicy.KEY_BYTES
    };
    // Native promise-based KDF, not generateSecretSync or a main-thread JavaScript PBKDF2 loop.
    return (await cryptoFramework.createKdf('PBKDF2|SHA256').generateSecret(specification)).data;
  }
}

export class PrivacyCredentialService {
  private readonly store: PrivacyCredentialStore;
  private readonly crypto: PrivacyCredentialCrypto;
  private readonly now: () => number;
  private tail: Promise<void> = Promise.resolve();
  private failedClosed: boolean = false;
  private observedConfigured: boolean = false;
  private readonly storageMessage: string = '无法安全读写隐私凭据，请关闭并重新打开应用后重试';
  private readonly cryptoMessage: string = '无法安全完成PIN认证，请稍后重试';
  private readonly expiredMessage: string = '认证请求已过期，请重试';

  constructor(store: PrivacyCredentialStore = new PreferencesCredentialStore(),
    crypto: PrivacyCredentialCrypto = new NativePrivacyCredentialCrypto(), now: () => number = () => Date.now()) {
    this.store = store;
    this.crypto = crypto;
    this.now = now;
  }

  init(context: common.Context): void {
    this.requireHealthy();
    try {
      this.store.init(context);
    } catch (_) {
      this.failedClosed = true;
      throw new Error(this.storageMessage);
    }
  }

  private serialize<T>(operation: () => Promise<T>): Promise<T> {
    const result = this.tail.then(async (): Promise<T> => {
      this.requireHealthy();
      return operation();
    });
    // A rejected request must not break queue ordering or leave an unhandled rejected tail.
    this.tail = result.then(() => {}, () => {});
    return result;
  }

  private requireHealthy(): void {
    if (this.failedClosed) {
      throw new Error(this.storageMessage);
    }
  }

  private requestIsCurrent(isCurrent: () => boolean): boolean {
    try {
      return isCurrent() === true;
    } catch (_) {
      return false;
    }
  }

  private requireCurrent(isCurrent: () => boolean): void {
    if (!this.requestIsCurrent(isCurrent)) {
      throw new Error(this.expiredMessage);
    }
  }

  private async readRecord(): Promise<PrivacyCredentialRecord | undefined> {
    this.requireHealthy();
    let raw: string | undefined;
    try {
      raw = await this.store.read();
    } catch (_) {
      this.failedClosed = true;
      throw new Error(this.storageMessage);
    }
    if (raw === undefined) {
      if (this.observedConfigured) {
        this.failedClosed = true;
        throw new Error(this.storageMessage);
      }
      return undefined;
    }
    try {
      const record = PrivacyPinPolicy.decodeRecord(raw);
      this.observedConfigured = true;
      return record;
    } catch (_) {
      this.failedClosed = true;
      throw new Error(PrivacyPinPolicy.CORRUPT_MESSAGE);
    }
  }

  private requireConfigured(record: PrivacyCredentialRecord | undefined): PrivacyCredentialRecord {
    if (record === undefined) {
      throw new Error('请先设置6位隐私PIN码');
    }
    return record;
  }

  private async persist(record: PrivacyCredentialRecord, isCurrent: () => boolean): Promise<void> {
    this.requireHealthy();
    this.requireCurrent(isCurrent);
    const raw = PrivacyPinPolicy.encodeRecord(record);
    let currentAfterPut = false;
    try {
      await this.store.put(raw);
      currentAfterPut = this.requestIsCurrent(isCurrent);
      // Even if put outlives its request, finish flushing its optimistic cache. Never roll it back.
      await this.store.flush();
    } catch (_) {
      // The cache or disk may now contain either value. Block every subsequent operation, including
      // getStatus/setup/re-init, rather than reload an older value and silently lose an attempt.
      this.failedClosed = true;
      throw new Error(this.storageMessage);
    }
    this.observedConfigured = true;
    if (!currentAfterPut) {
      throw new Error(this.expiredMessage);
    }
    this.requireCurrent(isCurrent);
  }

  private async randomSalt(): Promise<Uint8Array> {
    try {
      const salt = await this.crypto.randomSalt();
      if (!(salt instanceof Uint8Array) || salt.length !== PrivacyPinPolicy.SALT_BYTES) {
        throw new Error(this.cryptoMessage);
      }
      return salt;
    } catch (_) {
      throw new Error(this.cryptoMessage);
    }
  }

  private async derive(pin: string, salt: Uint8Array): Promise<Uint8Array> {
    try {
      const verifier = await this.crypto.derive(pin, salt);
      if (!(verifier instanceof Uint8Array) || verifier.length !== PrivacyPinPolicy.KEY_BYTES) {
        throw new Error(this.cryptoMessage);
      }
      return verifier;
    } catch (_) {
      throw new Error(this.cryptoMessage);
    }
  }

  getStatus(): Promise<PrivacyCredentialStatus> {
    return this.serialize(async (): Promise<PrivacyCredentialStatus> => {
      const record = await this.readRecord();
      const status = new PrivacyCredentialStatus();
      if (record !== undefined) {
        status.configured = true;
        status.biometricEnabled = record.biometricEnabled;
        status.retryAfterMs = PrivacyPinPolicy.retryAfterMs(record, this.now());
      }
      return status;
    });
  }

  setup(pin: string, confirmation: string, isCurrent: () => boolean): Promise<void> {
    return this.serialize(async (): Promise<void> => {
      this.requireCurrent(isCurrent);
      PrivacyPinPolicy.requireConfirmation(pin, confirmation);
      const existing = await this.readRecord();
      this.requireCurrent(isCurrent);
      if (existing !== undefined) {
        throw new Error('隐私PIN码已设置，请解锁后修改');
      }
      await this.writeNewPin(pin, undefined, isCurrent);
    });
  }

  verify(pin: string, isCurrent: () => boolean): Promise<boolean> {
    return this.serialize(async (): Promise<boolean> => {
      this.requireCurrent(isCurrent);
      PrivacyPinPolicy.requirePin(pin);
      const record = this.requireConfigured(await this.readRecord());
      this.requireCurrent(isCurrent);
      const reserved = PrivacyPinPolicy.reserveAttempt(record, this.now());
      // Charge before KDF: interruption, KDF failure, and stale requests cannot get a free guess.
      await this.persist(reserved, isCurrent);
      let salt = new Uint8Array(0);
      let candidate = new Uint8Array(0);
      let expected = new Uint8Array(0);
      try {
        salt = PrivacyPinPolicy.hexToBytes(record.saltHex);
        expected = PrivacyPinPolicy.hexToBytes(record.verifierHex);
        this.requireCurrent(isCurrent);
        candidate = await this.derive(pin, salt);
        this.requireCurrent(isCurrent);
        if (!PrivacyPinPolicy.constantTimeEqual(candidate, expected)) {
          return false;
        }
        const cleared = PrivacyPinPolicy.clearAttempts(reserved, this.now());
        await this.persist(cleared, isCurrent);
        this.requireCurrent(isCurrent);
        return true;
      } finally {
        salt.fill(0);
        candidate.fill(0);
        expected.fill(0);
      }
    });
  }

  // Authorization is owned by PrivacySessionService. Call only after a current session proves it.
  replacePin(pin: string, confirmation: string, isCurrent: () => boolean): Promise<void> {
    return this.serialize(async (): Promise<void> => {
      this.requireCurrent(isCurrent);
      PrivacyPinPolicy.requireConfirmation(pin, confirmation);
      const record = this.requireConfigured(await this.readRecord());
      this.requireCurrent(isCurrent);
      await this.writeNewPin(pin, record, isCurrent);
    });
  }

  private async writeNewPin(pin: string, previous: PrivacyCredentialRecord | undefined,
    isCurrent: () => boolean): Promise<void> {
    let salt = new Uint8Array(0);
    let verifier = new Uint8Array(0);
    try {
      this.requireCurrent(isCurrent);
      salt = await this.randomSalt();
      this.requireCurrent(isCurrent);
      verifier = await this.derive(pin, salt);
      this.requireCurrent(isCurrent);
      const nowMs = previous === undefined ? this.now() : Math.max(previous.clockFloorMs, this.now());
      const record = PrivacyPinPolicy.createRecord(salt, verifier, nowMs);
      if (previous !== undefined) {
        record.biometricEnabled = previous.biometricEnabled;
      }
      await this.persist(record, isCurrent);
      this.requireCurrent(isCurrent);
    } finally {
      salt.fill(0);
      verifier.fill(0);
    }
  }

  setBiometricEnabled(enabled: boolean, isCurrent: () => boolean): Promise<void> {
    return this.serialize(async (): Promise<void> => {
      this.requireCurrent(isCurrent);
      const record = this.requireConfigured(await this.readRecord());
      this.requireCurrent(isCurrent);
      const updated = PrivacyPinPolicy.copyRecord(record);
      updated.biometricEnabled = enabled;
      await this.persist(updated, isCurrent);
      this.requireCurrent(isCurrent);
    });
  }
}

const privacyCredentialService = new PrivacyCredentialService();
export default privacyCredentialService;
