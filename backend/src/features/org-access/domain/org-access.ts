/**
 * Pure domain types for the orgAccess custom-claims model, per
 * docs/07_Firestore_Schema.md §7.4. Zero firebase-admin/firebase-functions
 * imports — this file mirrors app/lib/core/session/domain/org_access.dart's
 * role in the Flutter client.
 */

export type UserRole = 'owner' | 'receptionist';

export type OrgAccessClaim = { role: 'owner' } | { role: 'receptionist'; branchId: string };

/** The full custom-claims shape issued to a user's Firebase Auth token. */
export type OrgAccessClaims = Record<string, OrgAccessClaim>;
