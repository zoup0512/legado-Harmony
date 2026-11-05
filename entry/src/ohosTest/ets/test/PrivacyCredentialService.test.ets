import { common } from '@kit.AbilityKit';
import { describe, expect, it } from '@ohos/hypium';
import {
  PrivacyCredentialCrypto, PrivacyCredentialService, PrivacyCredentialStore
} from '../../../main/ets/privacy/PrivacyCredentialService';
import { PrivacyCredentialRecord, PrivacyPinPolicy } from '../../../main/ets/privacy/PrivacyPinPolicy';

// These tests use an explicitly fake KDF and fake optimistic preferences cache, never the system KDF.
class MemoryCredentialStore implements PrivacyCredentialStore {
  cached: string | undefined;
  durable: string | undefined;
  readCalls: number = 0;
  putCalls: number = 0;
  flushCalls: number = 0;
  failRead: boolean = false;
  failPutAt: number = -1;
  failFlushAt: number = -1;
  onPut: (() => void) | undefined;
  onFlush: (() => Promise<void>) | undefined;
  events: string[];

  constructor(events: string[]) {
    this.events = events;
  }

  init(_context: common.Context): void {}

  async read(): Promise<string | undefined> {
    this.readCalls++;
    if (this.failRead) {
      throw new Error('untrusted storage error');
    }
    return this.cached;
  }

  async put(record: string): Promise<void> {
    this.events.push('put');
    this.putCalls++;
    this.cached = record;
    const callback = this.onPut;
    if (callback !== undefined) {
      callback();
    }
    if (this.putCalls === this.failPutAt) {
      throw new Error('untrusted put error');
    }
  }

  async flush(): Promise<void> {
    this.events.push('flush');
    this.flushCalls++;
    const callback = this.onFlush;
    if (callback !== undefined) {
      await callback();
    }
    if (this.flushCalls === this.failFlushAt) {
      throw new Error('untrusted flush error');
    }
    this.durable = this.cached;
  }

  record(): PrivacyCredentialRecord {
    if (this.cached === undefined) {
      throw new Error('test record missing');
    }
    return PrivacyPinPolicy.decodeRecord(this.cached);
  }

  diskRecord(): PrivacyCredentialRecord {
    if (this.durable === undefined) {
      throw new Error('test disk record missing');
    }
    return PrivacyPinPolicy.decodeRecord(this.durable);
  }
}

function fakeVerifier(pin: string, salt: Uint8Array): Uint8Array {
  const value = new Uint8Array(32);
  for (let index = 0; index < value.length; index++) {
    value[index] = pin.charCodeAt(index % pin.length) ^ salt[index % salt.length];
  }
  return value;
}

class FakeCredentialCrypto implements PrivacyCredentialCrypto {
  events: string[];
  randomCalls: number = 0;
  deriveCalls: number = 0;
  active: number = 0;
  maxActive: number = 0;
  failDerive: boolean = false;
  badLength: boolean = false;
  onRandom: (() => void) | undefined;
  onDerive: (() => Promise<void>) | undefined;

  constructor(events: string[]) {
    this.events = events;
  }

  async randomSalt(): Promise<Uint8Array> {
    this.randomCalls++;
    const callback = this.onRandom;
    if (callback !== undefined) {
      callback();
    }
    return new Uint8Array(16).fill(this.randomCalls + 1);
  }

  async derive(pin: string, salt: Uint8Array): Promise<Uint8Array> {
    this.events.push('derive');
    this.deriveCalls++;
    this.active++;
    this.maxActive = Math.max(this.maxActive, this.active);
    try {
      const callback = this.onDerive;
      if (callback !== undefined) {
        await callback();
      }
      if (this.failDerive) {
        throw new Error('untrusted crypto error');
      }
      return this.badLength ? new Uint8Array(31) : fakeVerifier(pin, salt);
    } finally {
      this.active--;
    }
  }
}

class TestClock {
  wallMs: number = 1000000;
  uptimeMs: number = 50000;

  advance(elapsedMs: number): void {
    this.wallMs += elapsedMs;
    this.uptimeMs += elapsedMs;
  }
}

class TestGate {
  wait: Promise<void>;
  private release: () => void = () => {};

  constructor() {
    this.wait = new Promise<void>((resolve) => {
      this.release = resolve;
    });
  }

  open(): void {
    this.release();
  }
}

class CredentialFixture {
  events: string[] = [];
  store: MemoryCredentialStore = new MemoryCredentialStore(this.events);
  crypto: FakeCredentialCrypto = new FakeCredentialCrypto(this.events);
  clock: TestClock = new TestClock();
  service: PrivacyCredentialService = new PrivacyCredentialService(this.store, this.crypto,
    () => this.clock.wallMs, () => this.clock.uptimeMs);
  current: boolean = true;
  isCurrent: () => boolean = () => this.current;

  seed(failures: number = 0): void {
    const salt = new Uint8Array(16).fill(1);
    const record = PrivacyPinPolicy.createRecord(salt, fakeVerifier('012345', salt), this.clock.wallMs);
    record.failedAttempts = failures;
    const delayMs = PrivacyPinPolicy.delayForFailures(failures);
    record.retryUntilMs = delayMs === 0 ? 0 : record.clockFloorMs + delayMs;
    this.store.cached = PrivacyPinPolicy.encodeRecord(record);
    this.store.durable = this.store.cached;
  }

  restart(): void {
    this.store.cached = this.store.durable;
    this.service = new PrivacyCredentialService(this.store, this.crypto,
      () => this.clock.wallMs, () => this.clock.uptimeMs);
  }
}

async function expectFailure(operation: () => Promise<void | boolean | Object>): Promise<string> {
  let message = '';
  try {
    await operation();
  } catch (cause) {
    message = (cause as Error).message;
  }
  expect(message.length > 0).assertTrue();
  expect(message.indexOf('untrusted') < 0).assertTrue();
  return message;
}

export default function privacyCredentialServiceTest() {
  describe('PrivacyCredentialServiceTest', () => {
    it('requiresExplicitContextForProductionStore', 0, async () => {
      const service = new PrivacyCredentialService();
      await expectFailure(() => service.getStatus());
      await expectFailure(() => service.setup('012345', '012345', () => true));
    });

    it('reportsOnlyGenuinelyMissingCredentialsAsUnconfigured', 0, async () => {
      const fixture = new CredentialFixture();
      const status = await fixture.service.getStatus();
      expect(status.configured).assertFalse();
      expect(status.biometricEnabled).assertFalse();
      expect(status.retryAfterMs).assertEqual(0);
      expect(fixture.store.putCalls).assertEqual(0);
      expect(fixture.crypto.deriveCalls).assertEqual(0);
    });

    it('setupPersistsOnlyVersionedSaltAndVerifierAndCannotOverwrite', 0, async () => {
      const fixture = new CredentialFixture();
      await fixture.service.setup('012345', '012345', fixture.isCurrent);
      const record = fixture.store.diskRecord();
      expect(record.iterations).assertEqual(600000);
      expect(record.saltHex.length).assertEqual(32);
      expect(record.verifierHex.length).assertEqual(64);
      expect(record.biometricEnabled).assertFalse();
      expect((fixture.store.cached as string).indexOf('012345') < 0).assertTrue();
      expect(fixture.store.putCalls).assertEqual(1);
      expect(fixture.store.flushCalls).assertEqual(1);
      expect((await fixture.service.getStatus()).configured).assertTrue();
      await expectFailure(() => fixture.service.setup('999999', '999999', fixture.isCurrent));
      expect(fixture.store.putCalls).assertEqual(1);
      expect(fixture.crypto.deriveCalls).assertEqual(1);
      expect(await fixture.service.verify('012345', fixture.isCurrent)).assertTrue();
    });

    it('rejectsInvalidInputAndUnconfiguredPrivilegedChangesWithoutWriting', 0, async () => {
      const fixture = new CredentialFixture();
      await expectFailure(() => fixture.service.setup('12345', '12345', fixture.isCurrent));
      await expectFailure(() => fixture.service.setup('012345', '012346', fixture.isCurrent));
      await expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      await expectFailure(() => fixture.service.replacePin('654321', '654321', fixture.isCurrent));
      await expectFailure(() => fixture.service.setBiometricEnabled(true, fixture.isCurrent));
      expect(fixture.store.putCalls).assertEqual(0);
      expect(fixture.crypto.deriveCalls).assertEqual(0);
    });

    it('failsClosedOnCorruptOrUnreadableStorageAndNeverAutoRecreatesIt', 0, async () => {
      const invalid: string[] = ['', '{', 'null', '{}'];
      for (let index = 0; index < invalid.length; index++) {
        const fixture = new CredentialFixture();
        fixture.store.cached = invalid[index];
        await expectFailure(() => fixture.service.getStatus());
        fixture.store.cached = undefined;
        await expectFailure(() => fixture.service.setup('012345', '012345', fixture.isCurrent));
        expect(fixture.store.putCalls).assertEqual(0);
      }
      const fixture = new CredentialFixture();
      fixture.store.failRead = true;
      await expectFailure(() => fixture.service.getStatus());
      fixture.store.failRead = false;
      await expectFailure(() => fixture.service.getStatus());
      expect(fixture.store.readCalls).assertEqual(1);
    });

    it('refusesMissingRecordAfterPreviouslyObservingConfiguredState', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed();
      expect((await fixture.service.getStatus()).configured).assertTrue();
      fixture.store.cached = undefined;
      await expectFailure(() => fixture.service.getStatus());
      await expectFailure(() => fixture.service.setup('012345', '012345', fixture.isCurrent));
      expect(fixture.store.putCalls).assertEqual(0);
    });

    it('flushesReservedFailureBeforeKdfAndLeavesItOnMismatch', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed();
      expect(await fixture.service.verify('999999', fixture.isCurrent)).assertFalse();
      expect(fixture.events.join(',')).assertEqual('put,flush,derive');
      expect(fixture.store.diskRecord().failedAttempts).assertEqual(1);
      expect(fixture.store.flushCalls).assertEqual(1);
      expect(await fixture.service.verify('012345', fixture.isCurrent)).assertTrue();
      expect(fixture.events.join(',')).assertEqual('put,flush,derive,put,flush,derive,put,flush');
      expect(fixture.store.diskRecord().failedAttempts).assertEqual(0);
      expect(fixture.store.diskRecord().retryUntilMs).assertEqual(0);
    });

    it('doesNotReturnSuccessUntilCounterResetFlushFinishes', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed();
      const enteredResetFlush = new TestGate();
      const allowResetFlush = new TestGate();
      fixture.store.onFlush = async () => {
        if (fixture.store.flushCalls === 2) {
          enteredResetFlush.open();
          await allowResetFlush.wait;
        }
      };
      let settled = false;
      const verification = fixture.service.verify('012345', fixture.isCurrent).then((result: boolean) => {
        settled = true;
        return result;
      });
      await enteredResetFlush.wait;
      expect(settled).assertFalse();
      expect(fixture.store.diskRecord().failedAttempts).assertEqual(1);
      allowResetFlush.open();
      expect(await verification).assertTrue();
      expect(fixture.store.diskRecord().failedAttempts).assertEqual(0);
    });

    it('wallClockJumpsCannotShortenOrExtendActiveCooldown', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed();
      for (let attempt = 0; attempt < 5; attempt++) {
        expect(await fixture.service.verify('999999', fixture.isCurrent)).assertFalse();
      }
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(30000);
      fixture.clock.wallMs += 86400000;
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(30000);
      await expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      expect(fixture.crypto.deriveCalls).assertEqual(5);
      fixture.clock.wallMs = 1;
      fixture.clock.uptimeMs += 10000;
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(20000);
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(20000);
      fixture.clock.uptimeMs += 19999;
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(1);
      fixture.clock.uptimeMs++;
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(0);
      expect(await fixture.service.verify('999999', fixture.isCurrent)).assertFalse();
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(60000);
      expect(fixture.store.diskRecord().clockFloorMs).assertEqual(1030000);
      expect(fixture.store.diskRecord().failedAttempts).assertEqual(6);
    });

    it('restartPendingCooldownWaitsFullDelayOnceRegardlessOfWallTime', 0, async () => {
      const changedWalls: number[] = [1, 86400000];
      for (let index = 0; index < changedWalls.length; index++) {
        const fixture = new CredentialFixture();
        fixture.seed();
        for (let attempt = 0; attempt < 5; attempt++) {
          await fixture.service.verify('999999', fixture.isCurrent);
        }
        // Even an expired persisted cooldown must get one conservative wait after a restart.
        fixture.clock.advance(60000);
        expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(0);
        fixture.clock.wallMs = changedWalls[index];
        fixture.clock.uptimeMs = 0;
        fixture.restart();
        expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(30000);
        expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(30000);
        await expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
        fixture.clock.advance(12000);
        expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(18000);
        expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(18000);
        fixture.clock.advance(18000);
        expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(0);
        expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(0);
        expect(fixture.store.putCalls).assertEqual(5);
        expect(fixture.crypto.deriveCalls).assertEqual(5);
        expect(await fixture.service.verify('012345', fixture.isCurrent)).assertTrue();
        expect(fixture.store.diskRecord().retryUntilMs).assertEqual(0);
      }
    });

    it('directVerifyAfterRestartCannotSkipPendingCooldown', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed(5);
      fixture.clock.wallMs += 86400000;
      fixture.restart();
      await expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(30000);
      expect(fixture.store.putCalls).assertEqual(0);
      expect(fixture.crypto.deriveCalls).assertEqual(0);
      fixture.clock.uptimeMs += 30000;
      expect(await fixture.service.verify('012345', fixture.isCurrent)).assertTrue();
    });

    it('maxCooldownExpiresByUptimeWithoutRearmingOrPermanentLockout', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed(PrivacyPinPolicy.MAX_FAILURES);
      fixture.clock.wallMs = 1;
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(PrivacyPinPolicy.MAX_RETRY_MS);
      fixture.clock.uptimeMs += PrivacyPinPolicy.MAX_RETRY_MS - 1;
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(1);
      fixture.clock.wallMs += 86400000;
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(1);
      fixture.clock.uptimeMs++;
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(0);
      expect(await fixture.service.verify('999999', fixture.isCurrent)).assertFalse();
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(PrivacyPinPolicy.MAX_RETRY_MS);
      expect(fixture.store.diskRecord().failedAttempts).assertEqual(PrivacyPinPolicy.MAX_FAILURES);
      fixture.clock.uptimeMs += PrivacyPinPolicy.MAX_RETRY_MS;
      expect(await fixture.service.verify('012345', fixture.isCurrent)).assertTrue();
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(0);
      fixture.restart();
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(0);
    });

    it('preAttemptFlushFailurePreventsKdfAndPoisonsOptimisticCache', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed();
      fixture.store.failFlushAt = 1;
      await expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      expect(fixture.crypto.deriveCalls).assertEqual(0);
      expect(fixture.store.record().failedAttempts).assertEqual(1);
      expect(fixture.store.diskRecord().failedAttempts).assertEqual(0);
      // Simulate a cache rollback: neither an old disk value nor a new cache value may recover it.
      fixture.store.cached = fixture.store.durable;
      await expectFailure(() => fixture.service.getStatus());
      await expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      await expectFailure(() => fixture.service.setup('012345', '012345', fixture.isCurrent));
      await expectFailure(() => fixture.service.setBiometricEnabled(true, fixture.isCurrent));
      expect(fixture.store.putCalls).assertEqual(1);
      expect(fixture.store.readCalls).assertEqual(1);
    });

    it('failedCooldownReservationStaysFailClosedAfterElapsedTimeAndWallJump', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed(4);
      fixture.store.failFlushAt = 1;
      fixture.store.onFlush = async () => {
        fixture.clock.wallMs += 86400000;
        fixture.clock.uptimeMs += 10000;
      };
      await expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      expect(fixture.store.record().failedAttempts).assertEqual(5);
      expect(fixture.store.diskRecord().failedAttempts).assertEqual(4);
      expect(fixture.crypto.deriveCalls).assertEqual(0);
      fixture.clock.uptimeMs += PrivacyPinPolicy.MAX_RETRY_MS;
      fixture.store.cached = fixture.store.durable;
      await expectFailure(() => fixture.service.getStatus());
      await expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      expect(fixture.store.putCalls).assertEqual(1);
    });

    it('resetFlushFailureCannotAuthenticateOrTrustClearedCache', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed();
      fixture.store.failFlushAt = 2;
      await expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      expect(fixture.crypto.deriveCalls).assertEqual(1);
      expect(fixture.store.record().failedAttempts).assertEqual(0);
      expect(fixture.store.diskRecord().failedAttempts).assertEqual(1);
      await expectFailure(() => fixture.service.getStatus());
      await expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      expect(fixture.store.putCalls).assertEqual(2);
    });

    it('partialPutFailureFailsClosedWithoutRunningKdf', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed();
      fixture.store.failPutAt = 1;
      await expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      expect(fixture.store.record().failedAttempts).assertEqual(1);
      expect(fixture.store.flushCalls).assertEqual(0);
      expect(fixture.crypto.deriveCalls).assertEqual(0);
      await expectFailure(() => fixture.service.getStatus());
    });

    it('setupFlushFailureDoesNotReportConfiguredOrAllowAnotherSetup', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.store.failFlushAt = 1;
      await expectFailure(() => fixture.service.setup('012345', '012345', fixture.isCurrent));
      expect(fixture.store.durable === undefined).assertTrue();
      await expectFailure(() => fixture.service.getStatus());
      await expectFailure(() => fixture.service.setup('654321', '654321', fixture.isCurrent));
      expect(fixture.crypto.deriveCalls).assertEqual(1);
      expect(fixture.store.putCalls).assertEqual(1);
    });

    it('serializesConcurrentVerificationsIncludingKdfAndFlush', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed();
      const enteredKdf = new TestGate();
      const allowKdf = new TestGate();
      fixture.crypto.onDerive = async () => {
        enteredKdf.open();
        await allowKdf.wait;
      };
      const first = fixture.service.verify('999999', fixture.isCurrent);
      const second = fixture.service.verify('888888', fixture.isCurrent);
      await enteredKdf.wait;
      expect(fixture.store.putCalls).assertEqual(1);
      expect(fixture.crypto.deriveCalls).assertEqual(1);
      allowKdf.open();
      expect(await first).assertFalse();
      expect(await second).assertFalse();
      expect(fixture.store.diskRecord().failedAttempts).assertEqual(2);
      expect(fixture.crypto.maxActive).assertEqual(1);
    });

    it('serializesSetupSoOnlyOneRequestCanConfigureMissingCredential', 0, async () => {
      const fixture = new CredentialFixture();
      const first = fixture.service.setup('012345', '012345', fixture.isCurrent);
      const second = expectFailure(() => fixture.service.setup('654321', '654321', fixture.isCurrent));
      await first;
      await second;
      expect(fixture.store.putCalls).assertEqual(1);
      expect(fixture.crypto.deriveCalls).assertEqual(1);
      expect(await fixture.service.verify('012345', fixture.isCurrent)).assertTrue();
    });

    it('staleKdfResultNeverAuthenticatesOrClearsReservedAttempt', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed();
      fixture.crypto.onDerive = async () => { fixture.current = false; };
      await expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      expect(fixture.store.diskRecord().failedAttempts).assertEqual(1);
      expect(fixture.store.putCalls).assertEqual(1);
    });

    it('staleFifthKdfKeepsCooldownAdvancingWithoutClearingOrRearming', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed(4);
      const enteredKdf = new TestGate();
      const allowKdf = new TestGate();
      fixture.crypto.onDerive = async () => {
        enteredKdf.open();
        await allowKdf.wait;
      };
      const verification = expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      await enteredKdf.wait;
      const status = fixture.service.getStatus();
      fixture.current = false;
      fixture.clock.wallMs += 86400000;
      fixture.clock.uptimeMs += 10000;
      allowKdf.open();
      await verification;
      expect((await status).retryAfterMs).assertEqual(20000);
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(20000);
      expect(fixture.store.diskRecord().failedAttempts).assertEqual(5);
      expect(fixture.store.putCalls).assertEqual(1);
      fixture.clock.uptimeMs += 20000;
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(0);
      fixture.current = true;
      fixture.crypto.onDerive = undefined;
      expect(await fixture.service.verify('012345', fixture.isCurrent)).assertTrue();
    });

    it('staleFifthReservationFlushesAndRetainsElapsedCooldownWithoutKdf', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed(4);
      fixture.store.onFlush = async () => {
        fixture.clock.wallMs = 1;
        fixture.clock.uptimeMs += 5000;
        fixture.current = false;
      };
      await expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      expect(fixture.store.diskRecord().failedAttempts).assertEqual(5);
      expect(fixture.store.flushCalls).assertEqual(1);
      expect(fixture.crypto.deriveCalls).assertEqual(0);
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(25000);
      fixture.store.onFlush = undefined;
      fixture.current = true;
      fixture.clock.uptimeMs += 25000;
      expect(await fixture.service.verify('012345', fixture.isCurrent)).assertTrue();
    });

    it('staleSetupAndReplacementKdfNeverWriteNewVerifier', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.crypto.onDerive = async () => { fixture.current = false; };
      await expectFailure(() => fixture.service.setup('012345', '012345', fixture.isCurrent));
      expect(fixture.store.putCalls).assertEqual(0);
      fixture.seed();
      fixture.current = true;
      const previous = fixture.store.record().verifierHex;
      await expectFailure(() => fixture.service.replacePin('654321', '654321', fixture.isCurrent));
      expect(fixture.store.record().verifierHex).assertEqual(previous);
      expect(fixture.store.putCalls).assertEqual(0);
    });

    it('rechecksAfterRandomAndBeforeQueuedRequestStarts', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.crypto.onRandom = () => { fixture.current = false; };
      await expectFailure(() => fixture.service.setup('012345', '012345', fixture.isCurrent));
      expect(fixture.crypto.deriveCalls).assertEqual(0);
      expect(fixture.store.putCalls).assertEqual(0);
      fixture.crypto.onRandom = undefined;
      fixture.seed();
      fixture.current = true;
      const enteredKdf = new TestGate();
      const allowKdf = new TestGate();
      fixture.crypto.onDerive = async () => {
        enteredKdf.open();
        await allowKdf.wait;
      };
      const first = fixture.service.verify('999999', () => true);
      const queued = expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      await enteredKdf.wait;
      fixture.current = false;
      allowKdf.open();
      expect(await first).assertFalse();
      await queued;
      expect(fixture.crypto.deriveCalls).assertEqual(1);
      expect(fixture.store.putCalls).assertEqual(1);
    });

    it('staleWriteStillFlushesButCannotReportSuccessOrRollBack', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed();
      fixture.store.onPut = () => { fixture.current = false; };
      await expectFailure(() => fixture.service.setBiometricEnabled(true, fixture.isCurrent));
      expect(fixture.store.flushCalls).assertEqual(1);
      expect(fixture.store.diskRecord().biometricEnabled).assertTrue();
      expect(fixture.crypto.deriveCalls).assertEqual(0);
      fixture.store.onPut = undefined;
      fixture.current = true;
      fixture.store.onFlush = async () => { fixture.current = false; };
      await expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      expect(fixture.store.diskRecord().failedAttempts).assertEqual(1);
      expect(fixture.crypto.deriveCalls).assertEqual(0);
    });

    it('staleResetFlushNeverReportsSuccessfulAuthentication', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed();
      fixture.store.onFlush = async () => {
        if (fixture.store.flushCalls === 2) {
          fixture.current = false;
        }
      };
      await expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      expect(fixture.crypto.deriveCalls).assertEqual(1);
      expect(fixture.store.flushCalls).assertEqual(2);
    });

    it('replacementChangesSaltAndPinWithoutDroppingBiometricPreference', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed();
      await fixture.service.setBiometricEnabled(true, fixture.isCurrent);
      const previousSalt = fixture.store.record().saltHex;
      await fixture.service.replacePin('000042', '000042', fixture.isCurrent);
      expect(fixture.store.diskRecord().saltHex !== previousSalt).assertTrue();
      expect((await fixture.service.getStatus()).biometricEnabled).assertTrue();
      expect(await fixture.service.verify('012345', fixture.isCurrent)).assertFalse();
      expect(await fixture.service.verify('000042', fixture.isCurrent)).assertTrue();
    });

    it('biometricPreferenceDoesNotDerivePinOrClearCooldown', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed();
      for (let attempt = 0; attempt < 5; attempt++) {
        await fixture.service.verify('999999', fixture.isCurrent);
      }
      const verifier = fixture.store.record().verifierHex;
      await fixture.service.setBiometricEnabled(true, fixture.isCurrent);
      expect((await fixture.service.getStatus()).retryAfterMs).assertEqual(30000);
      expect(fixture.store.diskRecord().failedAttempts).assertEqual(5);
      expect(fixture.store.diskRecord().verifierHex).assertEqual(verifier);
      expect(fixture.crypto.deriveCalls).assertEqual(5);
    });

    it('cryptoFailureAndInvalidOutputLeaveDurableAttemptCharged', 0, async () => {
      const fixture = new CredentialFixture();
      fixture.seed();
      fixture.crypto.failDerive = true;
      await expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      expect(fixture.store.diskRecord().failedAttempts).assertEqual(1);
      fixture.crypto.failDerive = false;
      fixture.crypto.badLength = true;
      await expectFailure(() => fixture.service.verify('012345', fixture.isCurrent));
      expect(fixture.store.diskRecord().failedAttempts).assertEqual(2);
      fixture.crypto.badLength = false;
      expect(await fixture.service.verify('012345', fixture.isCurrent)).assertTrue();
    });
  });
}
