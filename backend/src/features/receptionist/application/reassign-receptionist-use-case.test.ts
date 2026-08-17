import { ReassignReceptionistUseCase } from './reassign-receptionist-use-case';
import { Receptionist } from '../domain/receptionist';
import { ReceptionistAssignmentLookup } from '../domain/receptionist-assignment-lookup';
import { ReassignReceptionistWrite, ReceptionistRepository } from '../domain/receptionist-repository';
import { UserDirectory } from '../domain/user-directory';

class FakeUserDirectory implements UserDirectory {
  nextUserId = 'user-42';
  shouldThrow = false;

  resolveOrCreateUserId(_phoneNumber: string): Promise<string> {
    if (this.shouldThrow) throw new Error('directory unavailable');
    return Promise.resolve(this.nextUserId);
  }
}

class FakeReceptionistAssignmentLookup implements ReceptionistAssignmentLookup {
  activeBranchByOrgAndUser = new Map<string, string | null>();

  findActiveBranch(organizationId: string, userId: string): Promise<string | null> {
    return Promise.resolve(this.activeBranchByOrgAndUser.get(`${organizationId}:${userId}`) ?? null);
  }
}

class FakeReceptionistRepository implements ReceptionistRepository {
  existingByKey = new Map<string, Receptionist>();
  reassignCalls: ReassignReceptionistWrite[] = [];
  shouldThrow = false;

  create(_receptionist: Receptionist): Promise<void> {
    throw new Error('not exercised by these tests');
  }

  findByUserId(organizationId: string, branchId: string, userId: string): Promise<Receptionist | null> {
    return Promise.resolve(this.existingByKey.get(`${organizationId}:${branchId}:${userId}`) ?? null);
  }

  reassign(input: ReassignReceptionistWrite): Promise<Receptionist> {
    if (this.shouldThrow) throw new Error('simulated failure');
    this.reassignCalls.push(input);
    return Promise.resolve({
      userId: input.userId,
      organizationId: input.organizationId,
      branchId: input.toBranchId,
      name: input.name,
      phoneNumber: input.phoneNumber,
      status: 'active',
      invitedAt: new Date('2026-01-01T00:00:00Z'),
      invitedBy: input.reassignedBy,
    });
  }
}

const baseInput = {
  organizationId: 'org-1',
  phoneNumber: '+911234567890',
  toBranchId: 'branch-b',
  reassignedBy: 'owner-1',
};

const existingReceptionist: Receptionist = {
  userId: 'user-42',
  organizationId: 'org-1',
  branchId: 'branch-a',
  name: 'Priya Sharma',
  phoneNumber: '+911234567890',
  status: 'active',
  invitedAt: new Date('2025-01-01T00:00:00Z'),
  invitedBy: 'owner-1',
};

function makeUseCase() {
  const directory = new FakeUserDirectory();
  const assignmentLookup = new FakeReceptionistAssignmentLookup();
  const repository = new FakeReceptionistRepository();
  return {
    useCase: new ReassignReceptionistUseCase(directory, assignmentLookup, repository),
    directory,
    assignmentLookup,
    repository,
  };
}

describe('ReassignReceptionistUseCase', () => {
  it('rejects a phone number that is not valid E.164 before touching the user directory', async () => {
    const { useCase, repository } = makeUseCase();

    const result = await useCase.call({ ...baseInput, phoneNumber: '9876543210' });

    expect(result.ok).toBe(false);
    expect(repository.reassignCalls).toHaveLength(0);
  });

  it('fails with notFound when the resolved person has no active Receptionist assignment in this Organization', async () => {
    const { useCase, repository } = makeUseCase();

    const result = await useCase.call(baseInput);

    expect(result).toEqual({
      ok: false,
      failure: {
        kind: 'notFound',
        message: 'This person has no active Receptionist assignment in this Organization.',
      },
    });
    expect(repository.reassignCalls).toHaveLength(0);
  });

  it('fails with validation when the target Branch is the same as the current one', async () => {
    const { useCase, assignmentLookup, repository } = makeUseCase();
    assignmentLookup.activeBranchByOrgAndUser.set('org-1:user-42', 'branch-b');

    const result = await useCase.call(baseInput);

    expect(result).toEqual({
      ok: false,
      failure: { kind: 'validation', message: 'Already assigned to this Branch.' },
    });
    expect(repository.reassignCalls).toHaveLength(0);
  });

  it('reassigns from the Branch the lookup reports as current, never a caller-supplied one — the same recompute-from-Firestore guarantee the claims sync relies on', async () => {
    const { useCase, assignmentLookup, repository } = makeUseCase();
    assignmentLookup.activeBranchByOrgAndUser.set('org-1:user-42', 'branch-a');
    repository.existingByKey.set('org-1:branch-a:user-42', existingReceptionist);

    const result = await useCase.call(baseInput);

    expect(result.ok).toBe(true);
    expect(repository.reassignCalls).toHaveLength(1);
    const call = repository.reassignCalls[0]!;
    expect(call.fromBranchId).toBe('branch-a');
    expect(call.toBranchId).toBe('branch-b');
    expect(call.userId).toBe('user-42');
    expect(call.name).toBe(existingReceptionist.name);
    expect(call.phoneNumber).toBe(existingReceptionist.phoneNumber);
  });

  it('fails with notFound when the assignment lookup reports a Branch but no matching Receptionist record exists there', async () => {
    const { useCase, assignmentLookup, repository } = makeUseCase();
    assignmentLookup.activeBranchByOrgAndUser.set('org-1:user-42', 'branch-a');
    // Deliberately not seeding repository.existingByKey.

    const result = await useCase.call(baseInput);

    expect(result).toEqual({
      ok: false,
      failure: { kind: 'notFound', message: 'Receptionist record not found.' },
    });
    expect(repository.reassignCalls).toHaveLength(0);
  });

  it('returns a Result failure, never throws, when the repository write fails', async () => {
    const { useCase, assignmentLookup, repository } = makeUseCase();
    assignmentLookup.activeBranchByOrgAndUser.set('org-1:user-42', 'branch-a');
    repository.existingByKey.set('org-1:branch-a:user-42', existingReceptionist);
    repository.shouldThrow = true;

    const result = await useCase.call(baseInput);

    expect(result.ok).toBe(false);
  });
});
