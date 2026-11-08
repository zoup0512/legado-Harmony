/** Ignore stale stages before and after waiting for the native window to become ready. */
export async function loadWindowContentWhenReady(waitForWindow: () => Promise<void>,
  isCurrent: () => boolean, loadContent: () => void): Promise<void> {
  if (!isCurrent()) return;
  await waitForWindow();
  if (isCurrent()) loadContent();
}
