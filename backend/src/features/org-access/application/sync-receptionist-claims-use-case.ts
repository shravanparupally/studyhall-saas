import { Result, failure, success } from '../../../shared/result';
import { ClaimsGateway } from './claims-gateway';

/**
 * Grants or revokes single-Branch Receptionist access, per
 * docs/07_Firestore_Schema.md §7.4. A `revoked` status removes the
 * Organization's entry from the claims map entirely — matching the
 * revoke-old/create-new reassignment model
 * (docs/06_Database_Design.md §6.3, BR-23) rather than mutating a
 * `branchId` field on an existing grant.
 */
export class SyncReceptionistClaimsUseCase {
  constructor(private readonly claimsGateway: ClaimsGateway) {}

  async grant(
    userId: string,
    organizationId: string,
    branchId: string,
    status: 'active' | 'revoked',
  ): Promise<Result<void>> {
    try {
      const current = await this.claimsGateway.getCurrentClaims(userId);
      const next = { ...current };
      if (status === 'active') {
        next[organizationId] = { role: 'receptionist', branchId };
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
