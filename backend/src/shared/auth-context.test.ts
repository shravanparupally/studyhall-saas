import { canAccessBranch, isOwnerOf, resolveCallerAuthContext } from './auth-context';

describe('resolveCallerAuthContext', () => {
  it('returns null for an unauthenticated caller', () => {
    expect(resolveCallerAuthContext(undefined)).toBeNull();
  });

  it('resolves an empty orgAccess map when the token carries none', () => {
    const context = resolveCallerAuthContext({ uid: 'user-1', token: {} });
    expect(context).toEqual({ uid: 'user-1', orgAccess: {} });
  });

  it('ignores a malformed orgAccess claim rather than trusting it blindly', () => {
    const context = resolveCallerAuthContext({
      uid: 'user-1',
      token: { orgAccess: { 'org-1': { role: 'superadmin' } } },
    });
    expect(context?.orgAccess).toEqual({});
  });
});

describe('isOwnerOf', () => {
  it('is true only for an owner claim on the exact organization', () => {
    const context = { uid: 'user-1', orgAccess: { 'org-1': { role: 'owner' as const } } };
    expect(isOwnerOf(context, 'org-1')).toBe(true);
    expect(isOwnerOf(context, 'org-2')).toBe(false);
  });

  it('is false for a receptionist claim, even on the same organization', () => {
    const context = {
      uid: 'user-1',
      orgAccess: { 'org-1': { role: 'receptionist' as const, branchId: 'branch-1' } },
    };
    expect(isOwnerOf(context, 'org-1')).toBe(false);
  });
});

describe('canAccessBranch — the Branch isolation guarantee (docs/06 §6.6, FR-7.4)', () => {
  it('grants an Owner access to every Branch under their Organization uniformly', () => {
    const context = { uid: 'owner-1', orgAccess: { 'org-1': { role: 'owner' as const } } };
    expect(canAccessBranch(context, 'org-1', 'branch-a')).toBe(true);
    expect(canAccessBranch(context, 'org-1', 'branch-b')).toBe(true);
  });

  it('grants a Receptionist access to exactly their one assigned Branch', () => {
    const context = {
      uid: 'receptionist-1',
      orgAccess: { 'org-1': { role: 'receptionist' as const, branchId: 'branch-a' } },
    };
    expect(canAccessBranch(context, 'org-1', 'branch-a')).toBe(true);
  });

  it('denies a Receptionist access to any other Branch, including in the same Organization', () => {
    const context = {
      uid: 'receptionist-1',
      orgAccess: { 'org-1': { role: 'receptionist' as const, branchId: 'branch-a' } },
    };
    expect(canAccessBranch(context, 'org-1', 'branch-b')).toBe(false);
  });

  it('denies access to a different Organization entirely, for either role', () => {
    const ownerContext = { uid: 'owner-1', orgAccess: { 'org-1': { role: 'owner' as const } } };
    const receptionistContext = {
      uid: 'receptionist-1',
      orgAccess: { 'org-1': { role: 'receptionist' as const, branchId: 'branch-a' } },
    };
    expect(canAccessBranch(ownerContext, 'org-2', 'branch-a')).toBe(false);
    expect(canAccessBranch(receptionistContext, 'org-2', 'branch-a')).toBe(false);
  });

  it('denies access entirely when the caller holds no claim for the organization at all', () => {
    const context = { uid: 'stranger', orgAccess: {} };
    expect(canAccessBranch(context, 'org-1', 'branch-a')).toBe(false);
  });
});
