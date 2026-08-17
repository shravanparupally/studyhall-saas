import { Receptionist } from './receptionist';

export interface ReassignReceptionistWrite {
  organizationId: string;
  userId: string;
  fromBranchId: string;
  toBranchId: string;
  name: string;
  phoneNumber: string;
  reassignedBy: string;
}

/**
 * A repository-shaped port for the Receptionist Aggregate, per
 * docs/15_Technical_Architecture.md §15.15. Mirrors
 * app/lib/features/receptionist/domain/receptionist_repository.dart's role
 * on the Flutter side.
 */
export interface ReceptionistRepository {
  create(receptionist: Receptionist): Promise<void>;

  findByUserId(organizationId: string, branchId: string, userId: string): Promise<Receptionist | null>;

  /**
   * Atomically revokes the grant at `fromBranchId` and creates a new
   * active grant at `toBranchId` for the same person — the revoke-old/
   * create-new reassignment model (docs/06_Database_Design.md §6.3,
   * BR-23), executed as a single Firestore batch so the two writes
   * commit together or not at all.
   */
  reassign(input: ReassignReceptionistWrite): Promise<Receptionist>;
}
