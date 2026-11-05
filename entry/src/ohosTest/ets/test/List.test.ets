import abilityTest from './Ability.test'
import localBookAccessTest from './LocalBookAccess.test'
import privacyPinPolicyTest from './PrivacyPinPolicy.test'
import privacyCredentialServiceTest from './PrivacyCredentialService.test'
import privacySessionTest from './PrivacySession.test'
import privacyAccessGuardTest from './PrivacyAccessGuard.test'

export default function testsuite() {
  abilityTest()
  localBookAccessTest()
  privacyPinPolicyTest()
  privacyCredentialServiceTest()
  privacySessionTest()
  privacyAccessGuardTest()
}