import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { appLogger } from '../../../shared/logger';
import { SyncReceptionistClaimsUseCase } from '../application/sync-receptionist-claims-use-case';
import { FirebaseAdminClaimsGateway } from '../infrastructure/firebase-admin-claims-gateway';

/**
 * Re-issues the affected user's `orgAccess` custom claim whenever a
 * Receptionist grant document is written or its `status` changes, per
 * docs/07_Firestore_Schema.md §7.4. Thin shim, mirroring onOwnerWrite.
 */
export const onReceptionistWrite = onDocumentWritten(
  'organizations/{organizationId}/branches/{branchId}/receptionists/{userId}',
  async (event) => {
    const { organizationId, branchId, userId } = event.params;
    const after = event.data?.after;
    const status = after?.exists ? (after.data()?.status as string | undefined) : undefined;
    const grantStatus: 'active' | 'revoked' = status === 'active' ? 'active' : 'revoked';

    const useCase = new SyncReceptionistClaimsUseCase(new FirebaseAdminClaimsGateway());
    const result = await useCase.grant(userId, organizationId, branchId, grantStatus);

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
