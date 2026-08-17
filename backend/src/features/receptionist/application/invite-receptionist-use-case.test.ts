import { InviteReceptionistUseCase } from './invite-receptionist-use-case';
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

class FakeReceptionistRepository implements ReceptionistRepository {
  created: Receptionist[] = [];
  existingByKey = new Map<string, Receptionist>();

  create(receptionist: Receptionist): Promise<void> {
    this.created.push(receptionist);
    return Promise.resolve();
  }

  findByUserId(organizationId: string, branchId: string, userId: string): Promise<Receptionist | null> {
    return Promise.resolve(this.existingByKey.get(`${organizationId}:${branchId}:${userId}`) ?? null);
  }

  reassign(_input: ReassignReceptionistWrite): Promise<Receptionist> {
    throw new Error('not exercised by these tests');
  }
}

class FakeReceptionistAssignmentLookup implements ReceptionistAssignmentLookup {
  activeBranchByOrgAndUser = new Map<string, string | null>();

  findActiveBranch(organizationId: string, userId: string): Promise<string | null> {
    return Promise.resolve(this.activeBranchByOrgAndUser.get(`${organizationId}:${userId}`) ?? null);
  }
}

const baseInput = {
  organizationId: 'org-1',
  branchId: 'branch-1',
  name: 'Priya Sharma',
  phoneNumber: '+911234567890',
  invitedBy: 'owner-1',
};

function makeUseCase(
  directory = new FakeUserDirectory(),
  repository = new FakeReceptionistRepository(),
  assignmentLookup = new FakeReceptionistAssignmentLookup(),
) {
  return {
    useCase: new InviteReceptionistUseCase(directory, repository, assignmentLookup),
    directory,
    repository,
    assignmentLookup,
  };
}

describe('InviteReceptionistUseCase', () => {
  it('rejects an empty name before touching the user directory', async () => {
    const { useCase, repository } = makeUseCase();

    const result = await useCase.call({ ...baseInput, name: '   ' });

    expect(result).toEqual({ ok: false, failure: { kind: 'validation', message: "Enter the receptionist's name." } });
    expect(repository.created).toHaveLength(0);
  });

  it('rejects a phone number that is not valid E.164', async () => {
    const { useCase, repository } = makeUseCase();

    const result = await useCase.call({ ...baseInput, phoneNumber: '9876543210' });

    expect(result.ok).toBe(false);
    expect(repository.created).toHaveLength(0);
  });

  it('resolves the phone number to a userId and creates exactly one Receptionist scoped to one Branch', async () => {
    const { useCase, repository } = makeUseCase();

    const result = await useCase.call(baseInput);

    expect(result.ok).toBe(true);
    expect(repository.created).toHaveLength(1);
    const created = repository.created[0]!;
    expect(created.userId).toBe('user-42');
    expect(created.organizationId).toBe('org-1');
    expect(created.branchId).toBe('branch-1');
    expect(created.status).toBe('active');
  });

  it('rejects when the phone number already resolves to an active Receptionist at this same Branch', async () => {
    const { useCase, repository, assignmentLookup } = makeUseCase();
    assignmentLookup.activeBranchByOrgAndUser.set('org-1:user-42', 'branch-1');

    const result = await useCase.call(baseInput);

    expect(result).toEqual({
      ok: false,
      failure: { kind: 'conflict', message: 'This person is already an active Receptionist at this Branch.' },
    });
    expect(repository.created).toHaveLength(0);
  });

  it('rejects when the phone number already resolves to an active Receptionist at a different Branch in the same Organization, directing the caller to reassign instead', async () => {
    const { useCase, repository, assignmentLookup } = makeUseCase();
    assignmentLookup.activeBranchByOrgAndUser.set('org-1:user-42', 'branch-9');

    const result = await useCase.call(baseInput);

    expect(result.ok).toBe(false);
    expect(result).toEqual({
      ok: false,
      failure: {
        kind: 'conflict',
        message:
          'This person is already an active Receptionist at another Branch in this Organization. ' +
          'Reassign them instead of sending a new invitation.',
      },
    });
    expect(repository.created).toHaveLength(0);
  });

  it('returns a Result failure, never throws, when the user directory fails', async () => {
    const { useCase, repository, directory } = makeUseCase();
    directory.shouldThrow = true;

    const result = await useCase.call(baseInput);

    expect(result.ok).toBe(false);
    expect(repository.created).toHaveLength(0);
  });
});
