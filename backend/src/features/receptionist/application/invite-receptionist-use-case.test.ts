import {
  InviteReceptionistUseCase,
  ReceptionistRepository,
  UserDirectory,
} from './invite-receptionist-use-case';
import { Receptionist } from '../domain/receptionist';

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

  create(receptionist: Receptionist): Promise<void> {
    this.created.push(receptionist);
    return Promise.resolve();
  }
}

const baseInput = {
  organizationId: 'org-1',
  branchId: 'branch-1',
  name: 'Priya Sharma',
  phoneNumber: '+911234567890',
  invitedBy: 'owner-1',
};

describe('InviteReceptionistUseCase', () => {
  it('rejects an empty name before touching the user directory', async () => {
    const directory = new FakeUserDirectory();
    const repository = new FakeReceptionistRepository();
    const useCase = new InviteReceptionistUseCase(directory, repository);

    const result = await useCase.call({ ...baseInput, name: '   ' });

    expect(result).toEqual({ ok: false, failure: { kind: 'validation', message: "Enter the receptionist's name." } });
    expect(repository.created).toHaveLength(0);
  });

  it('rejects a phone number that is not valid E.164', async () => {
    const directory = new FakeUserDirectory();
    const repository = new FakeReceptionistRepository();
    const useCase = new InviteReceptionistUseCase(directory, repository);

    const result = await useCase.call({ ...baseInput, phoneNumber: '9876543210' });

    expect(result.ok).toBe(false);
    expect(repository.created).toHaveLength(0);
  });

  it('resolves the phone number to a userId and creates exactly one Receptionist scoped to one Branch', async () => {
    const directory = new FakeUserDirectory();
    const repository = new FakeReceptionistRepository();
    const useCase = new InviteReceptionistUseCase(directory, repository);

    const result = await useCase.call(baseInput);

    expect(result.ok).toBe(true);
    expect(repository.created).toHaveLength(1);
    const created = repository.created[0]!;
    expect(created.userId).toBe('user-42');
    expect(created.organizationId).toBe('org-1');
    expect(created.branchId).toBe('branch-1');
    expect(created.status).toBe('active');
  });

  it('returns a Result failure, never throws, when the user directory fails', async () => {
    const directory = new FakeUserDirectory();
    directory.shouldThrow = true;
    const repository = new FakeReceptionistRepository();
    const useCase = new InviteReceptionistUseCase(directory, repository);

    const result = await useCase.call(baseInput);

    expect(result.ok).toBe(false);
    expect(repository.created).toHaveLength(0);
  });
});
