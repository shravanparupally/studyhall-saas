import { ClaimsGateway } from './claims-gateway';
import { SyncReceptionistClaimsUseCase } from './sync-receptionist-claims-use-case';
import { OrgAccessClaims } from '../domain/org-access';
import { ReceptionistAssignmentLookup } from '../../receptionist/domain/receptionist-assignment-lookup';

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

class FakeReceptionistAssignmentLookup implements ReceptionistAssignmentLookup {
  activeBranchByOrgAndUser = new Map<string, string | null>();

  findActiveBranch(organizationId: string, userId: string): Promise<string | null> {
    return Promise.resolve(this.activeBranchByOrgAndUser.get(`${organizationId}:${userId}`) ?? null);
  }
}

describe('SyncReceptionistClaimsUseCase', () => {
  it("grants access scoped to exactly the Branch the lookup reports as this user's current active assignment", async () => {
    const gateway = new FakeClaimsGateway();
    const assignmentLookup = new FakeReceptionistAssignmentLookup();
    assignmentLookup.activeBranchByOrgAndUser.set('org-1:user-1', 'branch-a');
    const useCase = new SyncReceptionistClaimsUseCase(gateway, assignmentLookup);

    await useCase.sync('user-1', 'org-1');

    expect(gateway.claimsByUserId.get('user-1')).toEqual({
      'org-1': { role: 'receptionist', branchId: 'branch-a' },
    });
  });

  it('removes the organization entry entirely when the lookup reports no active assignment, per the revoke-old/create-new reassignment model (BR-23)', async () => {
    const gateway = new FakeClaimsGateway();
    gateway.claimsByUserId.set('user-1', {
      'org-1': { role: 'receptionist', branchId: 'branch-a' },
      'org-2': { role: 'owner' },
    });
    const assignmentLookup = new FakeReceptionistAssignmentLookup();
    const useCase = new SyncReceptionistClaimsUseCase(gateway, assignmentLookup);

    await useCase.sync('user-1', 'org-1');

    expect(gateway.claimsByUserId.get('user-1')).toEqual({ 'org-2': { role: 'owner' } });
  });

  it('a reassignment to a new Branch replaces the old branchId, never merges the two', async () => {
    const gateway = new FakeClaimsGateway();
    gateway.claimsByUserId.set('user-1', { 'org-1': { role: 'receptionist', branchId: 'branch-a' } });
    const assignmentLookup = new FakeReceptionistAssignmentLookup();
    assignmentLookup.activeBranchByOrgAndUser.set('org-1:user-1', 'branch-b');
    const useCase = new SyncReceptionistClaimsUseCase(gateway, assignmentLookup);

    await useCase.sync('user-1', 'org-1');

    expect(gateway.claimsByUserId.get('user-1')).toEqual({
      'org-1': { role: 'receptionist', branchId: 'branch-b' },
    });
  });

  it("converges on the current Firestore state regardless of which of a reassignment's two trigger events runs first — the race condition this recompute-based design fixes", async () => {
    // Both onReceptionistWrite invocations from a single ReassignReceptionistUseCase
    // batch (revoke branch-a, create branch-b) call sync() independently and in
    // either order; both must land on the same, correct result because both reads
    // happen after both writes have already committed.
    const gateway = new FakeClaimsGateway();
    const assignmentLookup = new FakeReceptionistAssignmentLookup();
    assignmentLookup.activeBranchByOrgAndUser.set('org-1:user-1', 'branch-b');
    const useCaseA = new SyncReceptionistClaimsUseCase(gateway, assignmentLookup);
    const useCaseB = new SyncReceptionistClaimsUseCase(gateway, assignmentLookup);

    await useCaseA.sync('user-1', 'org-1');
    await useCaseB.sync('user-1', 'org-1');

    expect(gateway.claimsByUserId.get('user-1')).toEqual({
      'org-1': { role: 'receptionist', branchId: 'branch-b' },
    });
  });

  it('preserves an existing claim on a different organization for the same user', async () => {
    const gateway = new FakeClaimsGateway();
    gateway.claimsByUserId.set('user-1', { 'org-2': { role: 'owner' } });
    const assignmentLookup = new FakeReceptionistAssignmentLookup();
    assignmentLookup.activeBranchByOrgAndUser.set('org-1:user-1', 'branch-a');
    const useCase = new SyncReceptionistClaimsUseCase(gateway, assignmentLookup);

    await useCase.sync('user-1', 'org-1');

    expect(gateway.claimsByUserId.get('user-1')).toEqual({
      'org-2': { role: 'owner' },
      'org-1': { role: 'receptionist', branchId: 'branch-a' },
    });
  });

  it('returns a Result failure, never throws, when the claims gateway fails', async () => {
    const gateway = new FakeClaimsGateway();
    gateway.shouldThrow = true;
    const assignmentLookup = new FakeReceptionistAssignmentLookup();
    const useCase = new SyncReceptionistClaimsUseCase(gateway, assignmentLookup);

    const result = await useCase.sync('user-1', 'org-1');

    expect(result.ok).toBe(false);
  });
});
