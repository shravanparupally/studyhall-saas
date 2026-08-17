import { Result, failure, success } from '../../../shared/result';
import { Receptionist } from '../domain/receptionist';
import { ReceptionistAssignmentLookup } from '../domain/receptionist-assignment-lookup';
import { ReceptionistRepository } from '../domain/receptionist-repository';
import { UserDirectory } from '../domain/user-directory';

const E164_PATTERN = /^\+[1-9]\d{7,14}$/;

export interface InviteReceptionistInput {
  organizationId: string;
  branchId: string;
  name: string;
  phoneNumber: string;
  invitedBy: string;
}

/**
 * Creates exactly one Receptionist grant, scoped to exactly one Branch —
 * per docs/02_Product_Requirements_Document.md FR-7.1 ("An Owner can
 * invite Receptionists and assign each one to exactly one Branch").
 * Validates input at the Application layer, matching every other use
 * case's own-input-validation convention in this codebase.
 *
 * Rejects a phone number that already resolves to an *active*
 * Receptionist grant elsewhere in this Organization — per
 * docs/07_Firestore_Schema.md §7.2, a person holds at most one active
 * Branch assignment per Organization at a time; moving them to a
 * different Branch is `ReassignReceptionistUseCase`'s job, never a second
 * invitation.
 */
export class InviteReceptionistUseCase {
  constructor(
    private readonly userDirectory: UserDirectory,
    private readonly receptionistRepository: ReceptionistRepository,
    private readonly assignmentLookup: ReceptionistAssignmentLookup,
  ) {}

  async call(input: InviteReceptionistInput): Promise<Result<Receptionist>> {
    const name = input.name.trim();
    if (name.length === 0) {
      return failure({ kind: 'validation', message: "Enter the receptionist's name." });
    }
    if (!E164_PATTERN.test(input.phoneNumber)) {
      return failure({
        kind: 'validation',
        message: 'Enter a valid phone number, including country code.',
      });
    }

    try {
      const userId = await this.userDirectory.resolveOrCreateUserId(input.phoneNumber);

      const existingActiveBranchId = await this.assignmentLookup.findActiveBranch(input.organizationId, userId);
      if (existingActiveBranchId) {
        return failure({
          kind: 'conflict',
          message:
            existingActiveBranchId === input.branchId
              ? 'This person is already an active Receptionist at this Branch.'
              : 'This person is already an active Receptionist at another Branch in ' +
                'this Organization. Reassign them instead of sending a new invitation.',
        });
      }

      const receptionist: Receptionist = {
        userId,
        organizationId: input.organizationId,
        branchId: input.branchId,
        name,
        phoneNumber: input.phoneNumber,
        status: 'active',
        invitedAt: new Date(),
        invitedBy: input.invitedBy,
      };
      await this.receptionistRepository.create(receptionist);
      return success(receptionist);
    } catch (error) {
      return failure({ kind: 'network', message: (error as Error).message });
    }
  }
}
