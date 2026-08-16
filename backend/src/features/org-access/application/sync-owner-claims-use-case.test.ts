import { ClaimsGateway } from './claims-gateway';
import { SyncOwnerClaimsUseCase } from './sync-owner-claims-use-case';
import { OrgAccessClaims } from '../domain/org-access';

class FakeClaimsGateway implements ClaimsGateway {
  claimsByUserId = new Map<string, OrgAccessClaims>();
  shouldThrow = false;

  getCurrentClaims(userId: string): Promise<OrgAccessClaims> {
    if (this.shouldThrow) throw new Error('simulated failure');
    return Promise.resolve(this.claimsByUserId.get(userId) ?? {});
  }

  setClaims(userId: string, claims: OrgAccessClaims): Promise<void> {
    if (this.shouldThrow) throw new Error('simulated failure');
    this.claimsByUserId.set(userId, claims);
    return Promise.resolve();
  }
}

describe('SyncOwnerClaimsUseCase', () => {
  it('grants org-wide access with no branchId, per docs/07 §7.4', async () => {
    const gateway = new FakeClaimsGateway();
    const useCase = new SyncOwnerClaimsUseCase(gateway);

    const result = await useCase.grant('user-1', 'org-1');

    expect(result).toEqual({ ok: true, value: undefined });
    expect(gateway.claimsByUserId.get('user-1')).toEqual({ 'org-1': { role: 'owner' } });
  });

  it('preserves an existing claim on a different organization for the same user', async () => {
    const gateway = new FakeClaimsGateway();
    gateway.claimsByUserId.set('user-1', { 'org-2': { role: 'receptionist', branchId: 'branch-9' } });
    const useCase = new SyncOwnerClaimsUseCase(gateway);

    await useCase.grant('user-1', 'org-1');

    expect(gateway.claimsByUserId.get('user-1')).toEqual({
      'org-2': { role: 'receptionist', branchId: 'branch-9' },
      'org-1': { role: 'owner' },
    });
  });

  it('returns a Result failure, never throws, when the gateway fails', async () => {
    const gateway = new FakeClaimsGateway();
    gateway.shouldThrow = true;
    const useCase = new SyncOwnerClaimsUseCase(gateway);

    const result = await useCase.grant('user-1', 'org-1');

    expect(result.ok).toBe(false);
  });
});
