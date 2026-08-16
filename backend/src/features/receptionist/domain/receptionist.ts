/**
 * Pure domain type for a Receptionist grant, per
 * docs/07_Firestore_Schema.md §7.2's
 * `organizations/{orgId}/branches/{branchId}/receptionists/{userId}` and
 * docs/06_Database_Design.md §6.3's `BranchReceptionist` form. Mirrors
 * app/lib/features/organization/domain/owner.dart's role for the Owner
 * side. Zero firebase-admin/firebase-functions imports.
 */

export type ReceptionistGrantStatus = 'active' | 'revoked';

export interface Receptionist {
  userId: string;
  organizationId: string;
  branchId: string;
  name: string;
  /** E.164 phone number. */
  phoneNumber: string;
  status: ReceptionistGrantStatus;
  invitedAt: Date;
  invitedBy: string;
}
