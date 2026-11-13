import abilityTest from './Ability.test'
import localBookAccessTest from './LocalBookAccess.test'
import privacyPinPolicyTest from './PrivacyPinPolicy.test'
import privacyCredentialServiceTest from './PrivacyCredentialService.test'
import privacySessionTest from './PrivacySession.test'
import privacyAccessGuardTest from './PrivacyAccessGuard.test'
import pageAccessRefreshTest from './PageAccessRefresh.test'
import windowContentStartupTest from './WindowContentStartup.test'
import privacyMonotonicClockTest from './PrivacyMonotonicClock.test'
import privacyOwnershipLookupTest from './PrivacyOwnershipLookup.test'
import readerFontLogicTest from './ReaderFontLogic.test'
import readerProgressTest from './ReaderProgress.test'
import readerLoadScopeTest from './ReaderLoadScope.test'
import bookAccessCheckTest from './BookAccessCheck.test'
import bookAccessStateTest from './BookAccessState.test'
import privateBookAutoUnlockTest from './PrivateBookAutoUnlock.test'
import dbUtilQueryTest from './DbUtilQuery.test'
import databaseInitTest from './DatabaseInit.test'
import loggerTest from './Logger.test'
import marketUpdateControllerTest from './MarketUpdateController.test'

export default function testsuite() {
  abilityTest()
  localBookAccessTest()
  privacyPinPolicyTest()
  privacyCredentialServiceTest()
  privacySessionTest()
  privacyAccessGuardTest()
  pageAccessRefreshTest()
  windowContentStartupTest()
  privacyMonotonicClockTest()
  privacyOwnershipLookupTest()
  readerFontLogicTest()
  readerProgressTest()
  readerLoadScopeTest()
  bookAccessCheckTest()
  bookAccessStateTest()
  privateBookAutoUnlockTest()
  dbUtilQueryTest()
  databaseInitTest()
  loggerTest()
  marketUpdateControllerTest()
}