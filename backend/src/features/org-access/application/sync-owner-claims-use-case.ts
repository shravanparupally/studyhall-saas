import { Result, failure, success } from '../../../shared/result';
import { ClaimsGateway } from './claims-gateway';

/**
 * Grants org-wide Owner access, per docs/07_Firestore_Schema.md §7.4: an
 * Owner's claim carries no `branchId` at all — access to every Branch
 * follows from `role == "owner"` alone. Merges into the user's existing
 * claims rather than replacing them wholesale, since the same person may
 * separately hold a Receptionist grant on a different Organization
 * (docs/06_Database_Design.md §6.3 — "uncommon but not forbidden").
 */
export class SyncOwnerClaimsUseCase {
  constructor(private readonly claimsGateway: ClaimsGateway) {}

  async grant(userId: string, organizationId: string): Promise<Result<void>> {
    try {
      const current = await this.claimsGateway.getCurrentClaims(userId);
      const next = { ...current, [organizationId]: { role: 'owner' as const } };
      await this.claimsGateway.setClaims(userId, next);
      return success(undefined);
    } catch (error) {
      return failure({ kind: 'network', message: (error as Error).message });
    }
  }
}
