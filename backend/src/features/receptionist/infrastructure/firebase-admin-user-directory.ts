import * as admin from 'firebase-admin';
import { UserDirectory } from '../domain/user-directory';

/** The only place this feature resolves a Firebase Auth user by phone number. */
export class FirebaseAdminUserDirectory implements UserDirectory {
  async resolveOrCreateUserId(phoneNumber: string): Promise<string> {
    try {
      const existing = await admin.auth().getUserByPhoneNumber(phoneNumber);
      return existing.uid;
    } catch (error) {
      if ((error as { code?: string }).code === 'auth/user-not-found') {
        const created = await admin.auth().createUser({ phoneNumber });
        return created.uid;
      }
      throw error;
    }
  }
}
