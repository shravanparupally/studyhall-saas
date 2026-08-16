import { ClaimsGateway } from './claims-gateway';
import { SyncReceptionistClaimsUseCase } from './sync-receptionist-claims-use-case';
import { OrgAccessClaims } from '../domain/org-access';

class FakeClaimsGateway implements ClaimsGateway {
  claimsByUserId = new Map<string, OrgAccessClaims>();

  getCurrentClaims(userId: string): Promise<OrgAccessClaims> {
    return Promise.resolve(this.claimsByUserId.get(userId) ?? {});
  }

  setClaims(userId: string, claims: OrgAccessClaims): Promise<void> {
    this.claimsByUserId.set(userId, claims);
    return Promise.resolve();
  }
}

describe('SyncReceptionistClaimsUseCase', () => {
  it('grants access scoped to exactly the assigned Branch', async () => {
    const gateway = new FakeClaimsGateway();
    const useCase = new SyncReceptionistClaimsUseCase(gateway);

    await useCase.grant('user-1', 'org-1', 'branch-a', 'active');

    expect(gateway.claimsByUserId.get('user-1')).toEqual({
      'org-1': { role: 'receptionist', branchId: 'branch-a' },
    });
  });

  it('removes the organization entry entirely on revoke, per the revoke-old/create-new reassignment model (BR-23)', async () => {
    const gateway = new FakeClaimsGateway();
    gateway.claimsByUserId.set('user-1', {
      'org-1': { role: 'receptionist', branchId: 'branch-a' },
      'org-2': { role: 'owner' },
    });
    const useCase = new SyncReceptionistClaimsUseCase(gateway);

    await useCase.grant('user-1', 'org-1', 'branch-a', 'revoked');

    expect(gateway.claimsByUserId.get('user-1')).toEqual({ 'org-2': { role: 'owner' } });
  });

  it('a reassignment to a new Branch replaces the old branchId, never merges the two', async () => {
    const gateway = new FakeClaimsGateway();
    gateway.claimsByUserId.set('user-1', { 'org-1': { role: 'receptionist', branchId: 'branch-a' } });
    const useCase = new SyncReceptionistClaimsUseCase(gateway);

    await useCase.grant('user-1', 'org-1', 'branch-b', 'active');

    expect(gateway.claimsByUserId.get('user-1')).toEqual({
      'org-1': { role: 'receptionist', branchId: 'branch-b' },
    });
  });
});
