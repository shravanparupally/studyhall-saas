/**
 * Resolves the Firebase Auth uid for a phone number, creating a new Auth
 * user if none exists yet. This is an Admin-SDK-only capability — per
 * docs/07_Firestore_Schema.md §7.2, the `receptionists/{userId}` document
 * ID *is* the userId, which the client cannot resolve for a phone number
 * that has never signed in, so invitation must happen server-side.
 */
export interface UserDirectory {
  resolveOrCreateUserId(phoneNumber: string): Promise<string>;
}
