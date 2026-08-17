import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { appLogger } from '../../../shared/logger';
import { isOwnerOf, resolveCallerAuthContext } from '../../../shared/auth-context';
import { ReassignReceptionistUseCase } from '../application/reassign-receptionist-use-case';
import { FirebaseAdminUserDirectory } from '../infrastructure/firebase-admin-user-directory';
import { FirestoreReceptionistAssignmentLookup } from '../infrastructure/firestore-receptionist-assignment-lookup';
import { FirestoreReceptionistRepository } from '../infrastructure/firestore-receptionist-repository';

interface ReassignReceptionistRequest {
  organizationId: string;
  phoneNumber: string;
  toBranchId: string;
}

function isReassignReceptionistRequest(data: unknown): data is ReassignReceptionistRequest {
  if (typeof data !== 'object' || data === null) return false;
  const record = data as Record<string, unknown>;
  return (
    typeof record.organizationId === 'string' &&
    typeof record.phoneNumber === 'string' &&
    typeof record.toBranchId === 'string'
  );
}

/**
 * HTTPS callable: an Owner moves an existing Receptionist to a different
 * Branch within the same Organization (BR-23's revoke-old/create-new
 * model). Thin shim per docs/08_System_Architecture.md §8.5. The
 * `isOwnerOf` check is this function's own explicit authority check,
 * deliberately independent of firestore.rules, which this Admin-SDK code
 * path bypasses entirely (docs §15.26).
 */
export const reassignReceptionist = onCall(async (request) => {
  const context = resolveCallerAuthContext(request.auth);
  if (!context) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  if (!isReassignReceptionistRequest(request.data)) {
    throw new HttpsError('invalid-argument', 'organizationId, phoneNumber, and toBranchId are required.');
  }
  const { organizationId, phoneNumber, toBranchId } = request.data;

  if (!isOwnerOf(context, organizationId)) {
    appLogger.warn('receptionist.reassign_denied', {
      organizationId,
      branchId: toBranchId,
      actorId: context.uid,
    });
    throw new HttpsError('permission-denied', 'Only an Owner of this Organization can reassign a Receptionist.');
  }

  const useCase = new ReassignReceptionistUseCase(
    new FirebaseAdminUserDirectory(),
    new FirestoreReceptionistAssignmentLookup(),
    new FirestoreReceptionistRepository(),
  );
  const result = await useCase.call({
    organizationId,
    phoneNumber,
    toBranchId,
    reassignedBy: context.uid,
  });

  if (!result.ok) {
    appLogger.warn('receptionist.reassign_failed', {
      organizationId,
      branchId: toBranchId,
      actorId: context.uid,
    });
    const code =
      result.failure.kind === 'validation'
        ? 'invalid-argument'
        : result.failure.kind === 'notFound'
          ? 'not-found'
          : 'internal';
    throw new HttpsError(code, result.failure.message ?? 'Could not reassign receptionist.');
  }

  appLogger.info('receptionist.reassigned', {
    organizationId,
    branchId: toBranchId,
    actorId: context.uid,
  });
  return {
    userId: result.value.userId,
    branchId: result.value.branchId,
    reassignedAt: result.value.invitedAt.toISOString(),
  };
});
