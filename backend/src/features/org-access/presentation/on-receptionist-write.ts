import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { appLogger } from '../../../shared/logger';
import { FirestoreReceptionistAssignmentLookup } from '../../receptionist/infrastructure/firestore-receptionist-assignment-lookup';
import { SyncReceptionistClaimsUseCase } from '../application/sync-receptionist-claims-use-case';
import { FirebaseAdminClaimsGateway } from '../infrastructure/firebase-admin-claims-gateway';

/**
 * Re-issues the affected user's `orgAccess` custom claim whenever a
 * Receptionist grant document is written (created, status-toggled, or
 * revoked as part of a reassignment), per
 * docs/07_Firestore_Schema.md §7.4. Thin shim, mirroring onOwnerWrite.
 *
 * Deliberately ignores the specific event payload (created/updated/
 * deleted, before/after) and always fully recomputes — see
 * `SyncReceptionistClaimsUseCase`'s doc comment for why that's required
 * for reassignment's two-document batch write to converge correctly.
 */
export const onReceptionistWrite = onDocumentWritten(
  'organizations/{organizationId}/branches/{branchId}/receptionists/{userId}',
  async (event) => {
    const { organizationId, branchId, userId } = event.params;

    const useCase = new SyncReceptionistClaimsUseCase(
      new FirebaseAdminClaimsGateway(),
      new FirestoreReceptionistAssignmentLookup(),
    );
    const result = await useCase.sync(userId, organizationId);

    if (!result.ok) {
      appLogger.error(
        'orgAccess.receptionist_claim_sync_failed',
        { organizationId, branchId, actorId: userId },
        result.failure,
      );
      return;
    }
    appLogger.info('orgAccess.receptionist_claim_synced', { organizationId, branchId, actorId: userId });
  },
);
