import { Result, failure, success } from '../../../shared/result';
import { ReceptionistAssignmentLookup } from '../../receptionist/domain/receptionist-assignment-lookup';
import { ClaimsGateway } from './claims-gateway';

/**
 * Re-derives and issues the `orgAccess` claim for a Receptionist by
 * re-querying Firestore for their *current* active Branch assignment
 * within the Organization, rather than trusting the single document
 * write that triggered this run.
 *
 * This is deliberately idempotent/convergent, not a blind merge of "this
 * one event's before/after diff": `ReassignReceptionistUseCase` writes
 * two receptionist documents for the same (organizationId, userId) in one
 * atomic batch (revoke the old Branch's doc, create the new Branch's
 * doc), which fires two independent `onReceptionistWrite` trigger
 * invocations. Two triggers each trusting only their own event's
 * status/branchId can race and clobber each other's result — e.g. the
 * "revoke old branch" trigger deleting the claim entry *after* the
 * "create new branch" trigger had already set it correctly, a lost-update
 * bug. Recomputing "what is this user's current active Branch in this
 * Organization, right now, from Firestore" instead means both triggers
 * converge on the same correct answer regardless of firing order, because
 * both documents in the batch have already committed by the time either
 * trigger runs (Firestore triggers fire post-commit).
 */
export class SyncReceptionistClaimsUseCase {
  constructor(
    private readonly claimsGateway: ClaimsGateway,
    private readonly assignmentLookup: ReceptionistAssignmentLookup,
  ) {}

  async sync(userId: string, organizationId: string): Promise<Result<void>> {
    try {
      const activeBranchId = await this.assignmentLookup.findActiveBranch(organizationId, userId);
      const current = await this.claimsGateway.getCurrentClaims(userId);
      const next = { ...current };
      if (activeBranchId) {
        next[organizationId] = { role: 'receptionist', branchId: activeBranchId };
      } else {
        delete next[organizationId];
      }
      await this.claimsGateway.setClaims(userId, next);
      return success(undefined);
    } catch (error) {
      return failure({ kind: 'network', message: (error as Error).message });
    }
  }
}
