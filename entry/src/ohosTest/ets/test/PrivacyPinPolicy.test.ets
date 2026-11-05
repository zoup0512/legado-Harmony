import { describe, expect, it } from '@ohos/hypium';
import { PrivacyCredentialRecord, PrivacyPinPolicy } from '../../../main/ets/privacy/PrivacyPinPolicy';

function policyRecord(nowMs: number = 1000000): PrivacyCredentialRecord {
  return PrivacyPinPolicy.createRecord(new Uint8Array(16).fill(3), new Uint8Array(32).fill(7), nowMs);
}

function expectInvalidRecord(record: PrivacyCredentialRecord): void {
  let rejected = false;
  try {
    PrivacyPinPolicy.decodeRecord(JSON.stringify(record));
  } catch (_) {
    rejected = true;
  }
  expect(rejected).assertTrue();
}

export default function privacyPinPolicyTest() {
  describe('PrivacyPinPolicyTest', () => {
    it('acceptsExactlySixAsciiDigitsIncludingLeadingZero', 0, () => {
      expect(PrivacyPinPolicy.isValidPin('000000')).assertTrue();
      expect(PrivacyPinPolicy.isValidPin('012345')).assertTrue();
      expect(PrivacyPinPolicy.isValidPin('999999')).assertTrue();
      const invalid: string[] = ['', '12345', '1234567', ' 123456', '123456 ', '123456\n',
        '１２３４５６', '١٢٣٤٥٦', '+12345', '1.2345', '12a456'];
      for (let index = 0; index < invalid.length; index++) {
        expect(PrivacyPinPolicy.isValidPin(invalid[index])).assertFalse();
      }
    });

    it('requiresMatchingValidConfirmation', 0, () => {
      PrivacyPinPolicy.requireConfirmation('012345', '012345');
      let mismatch = false;
      try {
        PrivacyPinPolicy.requireConfirmation('012345', '012346');
      } catch (_) {
        mismatch = true;
      }
      expect(mismatch).assertTrue();
    });

    it('roundTripsVersionedParametersAndBinaryValues', 0, () => {
      const record = policyRecord();
      const decoded = PrivacyPinPolicy.decodeRecord(PrivacyPinPolicy.encodeRecord(record));
      expect(decoded.version).assertEqual(1);
      expect(decoded.algorithm).assertEqual('PBKDF2|SHA256');
      expect(decoded.iterations).assertEqual(600000);
      expect(decoded.saltBytes).assertEqual(16);
      expect(decoded.keySize).assertEqual(32);
      expect(decoded.saltHex.length).assertEqual(32);
      expect(decoded.verifierHex.length).assertEqual(64);
      expect(decoded.biometricEnabled).assertFalse();
      const bytes = new Uint8Array([0, 1, 15, 16, 127, 128, 255]);
      const hex = PrivacyPinPolicy.bytesToHex(bytes);
      expect(hex).assertEqual('00010f107f80ff');
      expect(PrivacyPinPolicy.constantTimeEqual(bytes, PrivacyPinPolicy.hexToBytes(hex))).assertTrue();
    });

    it('rejectsMalformedRecordsInsteadOfTreatingThemAsMissing', 0, () => {
      const invalid: string[] = ['', '{', 'null', '[]', '{}', 'false', '"record"',
        JSON.stringify(policyRecord()).replace('"version":1', '"version":2'),
        JSON.stringify(policyRecord()).replace('"iterations":600000', '"iterations":1'),
        JSON.stringify(policyRecord()).replace('"biometricEnabled":false', '"biometricEnabled":"false"'),
        JSON.stringify(policyRecord()).replace('"version":1,', '')];
      for (let index = 0; index < invalid.length; index++) {
        let rejected = false;
        try {
          PrivacyPinPolicy.decodeRecord(invalid[index]);
        } catch (_) {
          rejected = true;
        }
        expect(rejected).assertTrue();
      }
      let record = policyRecord();
      record.saltHex = '00';
      expectInvalidRecord(record);
      record = policyRecord();
      record.verifierHex = 'f'.repeat(64) + '\n';
      expectInvalidRecord(record);
      record = policyRecord();
      record.algorithm = 'PBKDF2|SHA1';
      expectInvalidRecord(record);
      record = policyRecord();
      record.saltBytes = 8;
      expectInvalidRecord(record);
      record = policyRecord();
      record.keySize = 16;
      expectInvalidRecord(record);
      record = policyRecord();
      record.failedAttempts = 1.5;
      expectInvalidRecord(record);
      record = policyRecord();
      record.failedAttempts = 12;
      expectInvalidRecord(record);
      record = policyRecord();
      record.clockFloorMs = -1;
      expectInvalidRecord(record);
      record = policyRecord();
      record.retryUntilMs = 30000;
      expectInvalidRecord(record);
      record = policyRecord();
      record.failedAttempts = 5;
      expectInvalidRecord(record);
    });

    it('comparesEveryEqualLengthCandidateAndRejectsLengthMismatch', 0, () => {
      const expected = new Uint8Array(32).fill(17);
      const equal = new Uint8Array(expected);
      const firstDifferent = new Uint8Array(expected);
      firstDifferent[0] ^= 1;
      const lastDifferent = new Uint8Array(expected);
      lastDifferent[31] ^= 1;
      expect(PrivacyPinPolicy.constantTimeEqual(expected, equal)).assertTrue();
      expect(PrivacyPinPolicy.constantTimeEqual(expected, firstDifferent)).assertFalse();
      expect(PrivacyPinPolicy.constantTimeEqual(expected, lastDifferent)).assertFalse();
      expect(PrivacyPinPolicy.constantTimeEqual(expected, new Uint8Array(31))).assertFalse();
      expect(PrivacyPinPolicy.constantTimeEqual(new Uint8Array(0), new Uint8Array(0))).assertFalse();
    });

    it('startsThirtySecondCooldownOnFifthReservedAttempt', 0, () => {
      let record = policyRecord();
      for (let attempt = 1; attempt <= 4; attempt++) {
        record = PrivacyPinPolicy.reserveAttempt(record, 1000000);
        expect(record.failedAttempts).assertEqual(attempt);
        expect(PrivacyPinPolicy.retryAfterMs(record, 1000000)).assertEqual(0);
      }
      record = PrivacyPinPolicy.reserveAttempt(record, 1000000);
      expect(PrivacyPinPolicy.retryAfterMs(record, 1000000)).assertEqual(30000);
      expect(PrivacyPinPolicy.retryAfterMs(record, 1010000)).assertEqual(20000);
      let blocked = false;
      try {
        PrivacyPinPolicy.reserveAttempt(record, 1029999);
      } catch (_) {
        blocked = true;
      }
      expect(blocked).assertTrue();
      expect(record.failedAttempts).assertEqual(5);
      record = PrivacyPinPolicy.reserveAttempt(record, 1030000);
      expect(record.failedAttempts).assertEqual(6);
      expect(PrivacyPinPolicy.retryAfterMs(record, 1030000)).assertEqual(60000);
    });

    it('doublesFurtherFailuresAndCapsAtThirtyMinutes', 0, () => {
      const delays: number[] = [0, 0, 0, 0, 30000, 60000, 120000, 240000, 480000, 960000, 1800000, 1800000];
      let record = policyRecord();
      let nowMs = 1000000;
      for (let index = 0; index < delays.length; index++) {
        record = PrivacyPinPolicy.reserveAttempt(record, nowMs);
        expect(PrivacyPinPolicy.retryAfterMs(record, nowMs)).assertEqual(delays[index]);
        record = PrivacyPinPolicy.decodeRecord(PrivacyPinPolicy.encodeRecord(record));
        nowMs += delays[index];
      }
      expect(record.failedAttempts).assertEqual(11);
    });

    it('retainsCooldownAcrossSerializationAndWallClockRollback', 0, () => {
      let record = policyRecord();
      for (let attempt = 0; attempt < 5; attempt++) {
        record = PrivacyPinPolicy.reserveAttempt(record, 1000000);
      }
      const restored = PrivacyPinPolicy.decodeRecord(PrivacyPinPolicy.encodeRecord(record));
      expect(PrivacyPinPolicy.retryAfterMs(restored, 500000)).assertEqual(30000);
      expect(PrivacyPinPolicy.retryAfterMs(restored, 1029999)).assertEqual(1);
      expect(PrivacyPinPolicy.retryAfterMs(restored, 1030000)).assertEqual(0);
      const cleared = PrivacyPinPolicy.clearAttempts(restored, 900000);
      expect(cleared.failedAttempts).assertEqual(0);
      expect(cleared.retryUntilMs).assertEqual(0);
      expect(cleared.clockFloorMs).assertEqual(1000000);
      expect(restored.failedAttempts).assertEqual(5);
    });

    it('rejectsUnsafeClockAndWrongKdfOutputLengths', 0, () => {
      const invalidTimes: number[] = [-1, NaN, Infinity, 1.5, Number.MAX_SAFE_INTEGER];
      for (let index = 0; index < invalidTimes.length; index++) {
        let rejected = false;
        try {
          PrivacyPinPolicy.retryAfterMs(policyRecord(), invalidTimes[index]);
        } catch (_) {
          rejected = true;
        }
        expect(rejected).assertTrue();
      }
      let rejected = false;
      try {
        PrivacyPinPolicy.createRecord(new Uint8Array(15), new Uint8Array(32), 1000000);
      } catch (_) {
        rejected = true;
      }
      expect(rejected).assertTrue();
    });
  });
}
