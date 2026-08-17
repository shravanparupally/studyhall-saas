/**
 * A repository-shaped port for finding a user's current *active*
 * Receptionist Branch assignment within an Organization, per
 * docs/15_Technical_Architecture.md §15.15.
 *
 * Used for two purposes: preventing duplicate/conflicting invitations
 * (docs/07_Firestore_Schema.md §7.2's "a person can be a Receptionist of
 * at most one Branch at a time by construction"), and by org-access's
 * claims sync to recompute the correct `orgAccess` claim from the current
 * authoritative Firestore state rather than trusting a single trigger
 * event's diff — see SyncReceptionistClaimsUseCase's doc comment for why
 * that distinction matters.
 */
export interface ReceptionistAssignmentLookup {
  /**
   * Returns the branchId of the user's current active Receptionist grant
   * within `organizationId`, or `null` if they hold none.
   */
  findActiveBranch(organizationId: string, userId: string): Promise<string | null>;
}
