import abilityTest from './Ability.test'
import localBookAccessTest from './LocalBookAccess.test'
import privacyPinPolicyTest from './PrivacyPinPolicy.test'
import privacyCredentialServiceTest from './PrivacyCredentialService.test'
import privacySessionTest from './PrivacySession.test'
import privacyAccessGuardTest from './PrivacyAccessGuard.test'
import pageAccessRefreshTest from './PageAccessRefresh.test'
import privacyWindowStartupTest from './PrivacyWindowStartup.test'
import privacyMonotonicClockTest from './PrivacyMonotonicClock.test'
import privacyOwnershipLookupTest from './PrivacyOwnershipLookup.test'
import readerFontLogicTest from './ReaderFontLogic.test'

export default function testsuite() {
  abilityTest()
  localBookAccessTest()
  privacyPinPolicyTest()
  privacyCredentialServiceTest()
  privacySessionTest()
  privacyAccessGuardTest()
  pageAccessRefreshTest()
  privacyWindowStartupTest()
  privacyMonotonicClockTest()
  privacyOwnershipLookupTest()
  readerFontLogicTest()
}