import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { appLogger } from '../../../shared/logger';
import { SyncOwnerClaimsUseCase } from '../application/sync-owner-claims-use-case';
import { FirebaseAdminClaimsGateway } from '../infrastructure/firebase-admin-claims-gateway';

/**
 * Re-issues the affected user's `orgAccess` custom claim whenever an Owner
 * grant document is written, per docs/07_Firestore_Schema.md §7.4 and
 * docs/08_System_Architecture.md §8.5 ("onOwnerWrite ... re-issue that
 * user's Auth custom claims"). Thin shim: resolve trigger params, invoke
 * exactly one use case, log the outcome — no business logic here
 * (docs §8.5/§15.8).
 */
export const onOwnerWrite = onDocumentWritten('organizations/{organizationId}/owners/{userId}', async (event) => {
  const { organizationId, userId } = event.params;
  const afterExists = event.data?.after.exists ?? false;

  if (!afterExists) {
    // No client-side Owner-grant deletion exists yet (firestore.rules
    // denies update/delete on this path) — nothing to react to.
    return;
  }

  const useCase = new SyncOwnerClaimsUseCase(new FirebaseAdminClaimsGateway());
  const result = await useCase.grant(userId, organizationId);

  if (!result.ok) {
    appLogger.error(
      'orgAccess.owner_claim_sync_failed',
      { organizationId, actorId: userId },
      result.failure,
    );
    return;
  }
  appLogger.info('orgAccess.owner_claim_synced', { organizationId, actorId: userId });
});
