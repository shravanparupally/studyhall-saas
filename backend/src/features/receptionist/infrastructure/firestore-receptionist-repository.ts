import * as admin from 'firebase-admin';
import { ReceptionistRepository } from '../application/invite-receptionist-use-case';
import { Receptionist } from '../domain/receptionist';

/**
 * The only place this feature imports `firebase-admin` for Firestore
 * access. Collection layout matches docs/07_Firestore_Schema.md §7.2:
 * `organizations/{orgId}/branches/{branchId}/receptionists/{userId}`.
 */
export class FirestoreReceptionistRepository implements ReceptionistRepository {
  async create(receptionist: Receptionist): Promise<void> {
    const ref = admin
      .firestore()
      .doc(
        `organizations/${receptionist.organizationId}/branches/${receptionist.branchId}/receptionists/${receptionist.userId}`,
      );
    await ref.set({
      name: receptionist.name,
      phoneNumber: receptionist.phoneNumber,
      status: receptionist.status,
      invitedAt: admin.firestore.Timestamp.fromDate(receptionist.invitedAt),
      acceptedAt: null,
      invitedBy: receptionist.invitedBy,
      // Denormalized, matching Sprint 1's owners-doc pattern — required so
      // resolveAccessForUser's collectionGroup('receptionists') query can
      // find this grant without already knowing the Branch (see
      // app/lib/features/organization/infrastructure/firestore_organization_repository.dart).
      userId: receptionist.userId,
    });
  }
}
