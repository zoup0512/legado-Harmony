import { LocalBookAccessLogic } from '../common/utils/LocalBookAccess';
import { PRIVACY_BOOK_GROUP } from './PrivacyConstants';

export interface PrivacyBookIdentity {
  id?: number;
  bookUrl?: string;
  bookGroup?: number;
}

export interface PrivacyHistoryIdentity extends PrivacyBookIdentity {
  originBookId?: number;
}

/** An operation-local copy of rows already restricted to the privacy group. */
export class PrivacyOwnershipLookup {
  private ids: Set<number> = new Set<number>();
  private localPaths: Set<string> = new Set<string>();

  constructor(privateBooks: PrivacyBookIdentity[]) {
    for (const book of privateBooks) {
      if (book.id !== undefined) this.ids.add(book.id);
      const path = LocalBookAccessLogic.localPathOf(book.bookUrl);
      if (path.length > 0) this.localPaths.add(path);
    }
  }

  isPrivateBook(book: PrivacyBookIdentity): boolean {
    if (book.bookGroup === PRIVACY_BOOK_GROUP || (book.id !== undefined && this.ids.has(book.id))) return true;
    const path = LocalBookAccessLogic.localPathOf(book.bookUrl);
    return path.length > 0 && this.localPaths.has(path);
  }

  isPrivateHistory(history: PrivacyHistoryIdentity): boolean {
    return this.isPrivateBook(history) ||
      (history.originBookId !== undefined && this.ids.has(history.originBookId));
  }
}

/** Bound the read-only lookup, never treat a failed or timed-out lookup as public. */
export function checkPrivateBook(book: PrivacyBookIdentity,
  loadOwnership: () => Promise<PrivacyOwnershipLookup>, timeoutMs: number = 10000): Promise<boolean> {
  if (book.bookGroup === PRIVACY_BOOK_GROUP) return Promise.resolve(true);
  return new Promise<boolean>((resolve, reject) => {
    let settled = false;
    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      reject(new Error('Privacy ownership lookup timed out'));
    }, timeoutMs);
    try {
      loadOwnership().then((ownership: PrivacyOwnershipLookup) => {
        if (settled) return;
        try {
          const required = ownership.isPrivateBook(book);
          settled = true;
          clearTimeout(timer);
          resolve(required);
        } catch (error) {
          settled = true;
          clearTimeout(timer);
          reject(error);
        }
      }, (error: Error) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        reject(error);
      });
    } catch (error) {
      settled = true;
      clearTimeout(timer);
      reject(error);
    }
  });
}

/** Load once, filter synchronously, then reject results from a changed generation.
 * Lookup failures propagate: an unknown owner must never be classified as public.
 */
export async function filterPublicHistories<T extends PrivacyHistoryIdentity>(histories: T[], generation: number,
  loadOwnership: () => Promise<PrivacyOwnershipLookup>, getGeneration: () => number): Promise<T[]> {
  if (histories.length === 0 || generation < 0) return [];
  const ownership = await loadOwnership();
  const result = histories.filter(history => !ownership.isPrivateHistory(history));
  return getGeneration() === generation ? result : [];
}
