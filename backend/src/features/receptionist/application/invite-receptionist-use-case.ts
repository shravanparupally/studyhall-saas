import { Result, failure, success } from '../../../shared/result';
import { Receptionist } from '../domain/receptionist';

const E164_PATTERN = /^\+[1-9]\d{7,14}$/;

/**
 * Resolves the Firebase Auth uid for a phone number, creating a new Auth
 * user if none exists yet. This is an Admin-SDK-only capability — per
 * docs/07_Firestore_Schema.md §7.2, the `receptionists/{userId}` document
 * ID *is* the userId, which the client cannot resolve for a phone number
 * that has never signed in, so invitation must happen server-side.
 */
export interface UserDirectory {
  resolveOrCreateUserId(phoneNumber: string): Promise<string>;
}

/** A repository-shaped port, per docs/15_Technical_Architecture.md §15.15. */
export interface ReceptionistRepository {
  create(receptionist: Receptionist): Promise<void>;
}

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
 * case's own-input-validation convention in this codebase
 * (app/lib/features/organization/application/create_organization_use_case.dart).
 */
export class InviteReceptionistUseCase {
  constructor(
    private readonly userDirectory: UserDirectory,
    private readonly receptionistRepository: ReceptionistRepository,
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
