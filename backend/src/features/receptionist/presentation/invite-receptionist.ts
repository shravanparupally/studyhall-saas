import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { appLogger } from '../../../shared/logger';
import { canAccessBranch, isOwnerOf, resolveCallerAuthContext } from '../../../shared/auth-context';
import { InviteReceptionistUseCase } from '../application/invite-receptionist-use-case';
import { FirebaseAdminUserDirectory } from '../infrastructure/firebase-admin-user-directory';
import { FirestoreReceptionistAssignmentLookup } from '../infrastructure/firestore-receptionist-assignment-lookup';
import { FirestoreReceptionistRepository } from '../infrastructure/firestore-receptionist-repository';

interface InviteReceptionistRequest {
  organizationId: string;
  branchId: string;
  name: string;
  phoneNumber: string;
}

function isInviteReceptionistRequest(data: unknown): data is InviteReceptionistRequest {
  if (typeof data !== 'object' || data === null) return false;
  const record = data as Record<string, unknown>;
  return (
    typeof record.organizationId === 'string' &&
    typeof record.branchId === 'string' &&
    typeof record.name === 'string' &&
    typeof record.phoneNumber === 'string'
  );
}

/**
 * HTTPS callable: an Owner invites a Receptionist and assigns them to
 * exactly one Branch (FR-7.1). Thin shim per
 * docs/08_System_Architecture.md §8.5: validate input, resolve caller
 * authority, invoke exactly one use case, map the result — no business
 * logic here.
 *
 * The `isOwnerOf` check is this function's own, explicit
 * `orgAccess`/`canAccessBranch`-equivalent check (docs §15.26) —
 * deliberately independent of firestore.rules, which this Admin-SDK code
 * path bypasses entirely.
 */
export const inviteReceptionist = onCall(async (request) => {
  const context = resolveCallerAuthContext(request.auth);
  if (!context) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  if (!isInviteReceptionistRequest(request.data)) {
    throw new HttpsError(
      'invalid-argument',
      'organizationId, branchId, name, and phoneNumber are required.',
    );
  }
  const { organizationId, branchId, name, phoneNumber } = request.data;

  if (!isOwnerOf(context, organizationId) && !canAccessBranch(context, organizationId, branchId)) {
    appLogger.warn('receptionist.invite_denied', { organizationId, branchId, actorId: context.uid });
    throw new HttpsError('permission-denied', 'You do not have access to this Branch.');
  }
  if (!isOwnerOf(context, organizationId)) {
    // Receptionist assignment is an Owner-only write, per
    // docs/07_Firestore_Schema.md §7.4's Branch-configuration rule —
    // restated here since this callable bypasses firestore.rules.
    appLogger.warn('receptionist.invite_denied', { organizationId, branchId, actorId: context.uid });
    throw new HttpsError('permission-denied', 'Only an Owner of this Organization can invite a Receptionist.');
  }

  const useCase = new InviteReceptionistUseCase(
    new FirebaseAdminUserDirectory(),
    new FirestoreReceptionistRepository(),
    new FirestoreReceptionistAssignmentLookup(),
  );
  const result = await useCase.call({
    organizationId,
    branchId,
    name,
    phoneNumber,
    invitedBy: context.uid,
  });

  if (!result.ok) {
    appLogger.warn('receptionist.invite_failed', { organizationId, branchId, actorId: context.uid });
    const code =
      result.failure.kind === 'validation'
        ? 'invalid-argument'
        : result.failure.kind === 'conflict'
          ? 'already-exists'
          : 'internal';
    throw new HttpsError(code, result.failure.message ?? 'Could not invite receptionist.');
  }

  appLogger.info('receptionist.invited', { organizationId, branchId, actorId: context.uid });
  return { userId: result.value.userId, invitedAt: result.value.invitedAt.toISOString() };
});
