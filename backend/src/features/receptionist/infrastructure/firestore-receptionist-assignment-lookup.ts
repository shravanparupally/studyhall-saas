import * as admin from 'firebase-admin';
import { ReceptionistAssignmentLookup } from '../domain/receptionist-assignment-lookup';

/**
 * Backed by the `organizationId`/`status`/`userId` fields denormalized
 * onto every receptionist document (see `FirestoreReceptionistRepository`)
 * and the matching `firestore.indexes.json` collection-group index.
 */
export class FirestoreReceptionistAssignmentLookup implements ReceptionistAssignmentLookup {
  async findActiveBranch(organizationId: string, userId: string): Promise<string | null> {
    const snapshot = await admin
      .firestore()
      .collectionGroup('receptionists')
      .where('userId', '==', userId)
      .where('organizationId', '==', organizationId)
      .where('status', '==', 'active')
      .limit(1)
      .get();
    if (snapshot.empty) return null;
    const branchRef = snapshot.docs[0]?.ref.parent.parent;
    return branchRef ? branchRef.id : null;
  }
}
