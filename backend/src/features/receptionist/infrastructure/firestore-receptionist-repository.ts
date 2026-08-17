import * as admin from 'firebase-admin';
import { Receptionist } from '../domain/receptionist';
import { ReassignReceptionistWrite, ReceptionistRepository } from '../domain/receptionist-repository';

/**
 * The only place this feature imports `firebase-admin` for Firestore
 * access. Collection layout matches docs/07_Firestore_Schema.md §7.2:
 * `organizations/{orgId}/branches/{branchId}/receptionists/{userId}`.
 *
 * Every write denormalizes `organizationId` onto the document, per
 * docs/07_Firestore_Schema.md §7.1 ("every Branch-scoped document also
 * carries organizationId and branchId as plain fields, even though
 * they're already encoded in the path... required [because] collectionGroup
 * queries can only filter on fields, not path segments") — needed by
 * `FirestoreReceptionistAssignmentLookup`'s collectionGroup query.
 */
export class FirestoreReceptionistRepository implements ReceptionistRepository {
  async create(receptionist: Receptionist): Promise<void> {
    const ref = this.docRef(receptionist.organizationId, receptionist.branchId, receptionist.userId);
    await ref.set({
      name: receptionist.name,
      phoneNumber: receptionist.phoneNumber,
      status: receptionist.status,
      invitedAt: admin.firestore.Timestamp.fromDate(receptionist.invitedAt),
      acceptedAt: null,
      invitedBy: receptionist.invitedBy,
      userId: receptionist.userId,
      organizationId: receptionist.organizationId,
    });
  }

  async findByUserId(organizationId: string, branchId: string, userId: string): Promise<Receptionist | null> {
    const snapshot = await this.docRef(organizationId, branchId, userId).get();
    const data = snapshot.data();
    if (!data) return null;
    return this.fromDocData(organizationId, branchId, userId, data);
  }

  async reassign(input: ReassignReceptionistWrite): Promise<Receptionist> {
    const firestore = admin.firestore();
    const fromRef = this.docRef(input.organizationId, input.fromBranchId, input.userId);
    const toRef = this.docRef(input.organizationId, input.toBranchId, input.userId);
    const now = new Date();

    // Revoke-old/create-new, per BR-23 — a single atomic batch so the two
    // writes commit together or not at all.
    const batch = firestore.batch();
    batch.update(fromRef, { status: 'revoked' });
    batch.set(toRef, {
      name: input.name,
      phoneNumber: input.phoneNumber,
      status: 'active',
      invitedAt: admin.firestore.Timestamp.fromDate(now),
      acceptedAt: null,
      invitedBy: input.reassignedBy,
      userId: input.userId,
      organizationId: input.organizationId,
    });
    await batch.commit();

    return {
      userId: input.userId,
      organizationId: input.organizationId,
      branchId: input.toBranchId,
      name: input.name,
      phoneNumber: input.phoneNumber,
      status: 'active',
      invitedAt: now,
      invitedBy: input.reassignedBy,
    };
  }

  private docRef(organizationId: string, branchId: string, userId: string) {
    return admin.firestore().doc(`organizations/${organizationId}/branches/${branchId}/receptionists/${userId}`);
  }

  private fromDocData(
    organizationId: string,
    branchId: string,
    userId: string,
    data: FirebaseFirestore.DocumentData,
  ): Receptionist {
    const invitedAt = data.invitedAt as FirebaseFirestore.Timestamp;
    return {
      userId,
      organizationId,
      branchId,
      name: data.name as string,
      phoneNumber: data.phoneNumber as string,
      status: (data.status as string) === 'active' ? 'active' : 'revoked',
      invitedAt: invitedAt.toDate(),
      invitedBy: data.invitedBy as string,
    };
  }
}
