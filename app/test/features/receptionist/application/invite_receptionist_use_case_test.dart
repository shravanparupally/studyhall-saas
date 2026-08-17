import 'package:app/core/domain/ids.dart';
import 'package:app/core/result/result.dart';
import 'package:app/features/receptionist/application/invite_receptionist_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_receptionist_repository.dart';

const _organizationId = OrganizationId('org-1');
const _branchId = BranchId('branch-1');

void main() {
  late FakeReceptionistRepository repository;
  late InviteReceptionistUseCase useCase;

  setUp(() {
    repository = FakeReceptionistRepository();
    useCase = InviteReceptionistUseCase(repository);
  });

  test('rejects an empty name before touching the repository', () async {
    final result = await useCase(
      organizationId: _organizationId,
      branchId: _branchId,
      name: '   ',
      rawPhoneNumber: '+911234567890',
      invitedBy: 'owner-1',
    );

    expect(result, isA<ResultFailure<dynamic>>());
    expect(repository.invited, isEmpty);
  });

  test('rejects a phone number that is not valid E.164', () async {
    final result = await useCase(
      organizationId: _organizationId,
      branchId: _branchId,
      name: 'Priya Sharma',
      rawPhoneNumber: '9876543210',
      invitedBy: 'owner-1',
    );

    expect(result, isA<ResultFailure<dynamic>>());
    expect(repository.invited, isEmpty);
  });

  test(
    'trims the name and invites the Receptionist to exactly one Branch',
    () async {
      final result = await useCase(
        organizationId: _organizationId,
        branchId: _branchId,
        name: '  Priya Sharma  ',
        rawPhoneNumber: '+911234567890',
        invitedBy: 'owner-1',
      );

      expect(result, isA<ResultSuccess<dynamic>>());
      expect(repository.invited, hasLength(1));
      final invited = repository.invited.single;
      expect(invited.name, 'Priya Sharma');
      expect(invited.organizationId, _organizationId);
      expect(invited.branchId, _branchId);
    },
  );

  test(
    'propagates a repository failure as Result.failure rather than throwing',
    () async {
      repository.shouldFail = true;

      final result = await useCase(
        organizationId: _organizationId,
        branchId: _branchId,
        name: 'Priya Sharma',
        rawPhoneNumber: '+911234567890',
        invitedBy: 'owner-1',
      );

      expect(result, isA<ResultFailure<dynamic>>());
    },
  );
}
