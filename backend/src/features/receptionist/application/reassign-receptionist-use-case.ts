import { Result, failure, success } from '../../../shared/result';
import { Receptionist } from '../domain/receptionist';
import { ReceptionistAssignmentLookup } from '../domain/receptionist-assignment-lookup';
import { ReceptionistRepository } from '../domain/receptionist-repository';
import { UserDirectory } from '../domain/user-directory';

const E164_PATTERN = /^\+[1-9]\d{7,14}$/;

export interface ReassignReceptionistInput {
  organizationId: string;
  phoneNumber: string;
  toBranchId: string;
  reassignedBy: string;
}

/**
 * Moves an existing Receptionist to a different Branch within the same
 * Organization — the revoke-old/create-new model mandated by BR-23 and
 * docs/06_Database_Design.md §6.3, executed atomically by
 * `ReceptionistRepository.reassign`.
 *
 * Identifies the person by phone number, resolved through `UserDirectory`,
 * the same way `InviteReceptionistUseCase` does: the Owner knows the
 * person's phone number, never their internal userId, and there is no
 * roster lookup for this to resolve against client-side.
 */
export class ReassignReceptionistUseCase {
  constructor(
    private readonly userDirectory: UserDirectory,
    private readonly assignmentLookup: ReceptionistAssignmentLookup,
    private readonly receptionistRepository: ReceptionistRepository,
  ) {}

  async call(input: ReassignReceptionistInput): Promise<Result<Receptionist>> {
    if (!E164_PATTERN.test(input.phoneNumber)) {
      return failure({
        kind: 'validation',
        message: 'Enter a valid phone number, including country code.',
      });
    }

    try {
      const userId = await this.userDirectory.resolveOrCreateUserId(input.phoneNumber);

      const fromBranchId = await this.assignmentLookup.findActiveBranch(input.organizationId, userId);
      if (!fromBranchId) {
        return failure({
          kind: 'notFound',
          message: 'This person has no active Receptionist assignment in this Organization.',
        });
      }
      if (fromBranchId === input.toBranchId) {
        return failure({ kind: 'validation', message: 'Already assigned to this Branch.' });
      }

      const existing = await this.receptionistRepository.findByUserId(input.organizationId, fromBranchId, userId);
      if (!existing) {
        return failure({ kind: 'notFound', message: 'Receptionist record not found.' });
      }

      const reassigned = await this.receptionistRepository.reassign({
        organizationId: input.organizationId,
        userId,
        fromBranchId,
        toBranchId: input.toBranchId,
        name: existing.name,
        phoneNumber: existing.phoneNumber,
        reassignedBy: input.reassignedBy,
      });
      return success(reassigned);
    } catch (error) {
      return failure({ kind: 'network', message: (error as Error).message });
    }
  }
}
