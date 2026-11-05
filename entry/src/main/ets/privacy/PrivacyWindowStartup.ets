/** Do not load even the first route before native screenshot/task-snapshot protection is ready. */
export async function loadPrivacyProtectedContent(enablePrivacy: () => Promise<void>,
  isCurrent: () => boolean, loadContent: () => void): Promise<void> {
  if (!isCurrent()) return;
  await enablePrivacy();
  if (isCurrent()) loadContent();
}
