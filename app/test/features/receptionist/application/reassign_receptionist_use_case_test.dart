import 'package:app/core/domain/ids.dart';
import 'package:app/core/result/result.dart';
import 'package:app/features/receptionist/application/reassign_receptionist_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_receptionist_repository.dart';

const _organizationId = OrganizationId('org-1');
const _toBranchId = BranchId('branch-b');

void main() {
  late FakeReceptionistRepository repository;
  late ReassignReceptionistUseCase useCase;

  setUp(() {
    repository = FakeReceptionistRepository();
    useCase = ReassignReceptionistUseCase(repository);
  });

  test('rejects an empty name before touching the repository', () async {
    final result = await useCase(
      organizationId: _organizationId,
      name: '   ',
      rawPhoneNumber: '+911234567890',
      toBranchId: _toBranchId,
      reassignedBy: 'owner-1',
    );

    expect(result, isA<ResultFailure<dynamic>>());
    expect(repository.reassigned, isEmpty);
  });

  test('rejects a phone number that is not valid E.164', () async {
    final result = await useCase(
      organizationId: _organizationId,
      name: 'Priya Sharma',
      rawPhoneNumber: '9876543210',
      toBranchId: _toBranchId,
      reassignedBy: 'owner-1',
    );

    expect(result, isA<ResultFailure<dynamic>>());
    expect(repository.reassigned, isEmpty);
  });

  test(
    'trims the name and reassigns the Receptionist to the target Branch',
    () async {
      final result = await useCase(
        organizationId: _organizationId,
        name: '  Priya Sharma  ',
        rawPhoneNumber: '+911234567890',
        toBranchId: _toBranchId,
        reassignedBy: 'owner-1',
      );

      expect(result, isA<ResultSuccess<dynamic>>());
      expect(repository.reassigned, hasLength(1));
      final reassigned = repository.reassigned.single;
      expect(reassigned.name, 'Priya Sharma');
      expect(reassigned.branchId, _toBranchId);
    },
  );

  test(
    'propagates a repository failure as Result.failure rather than throwing',
    () async {
      repository.shouldFail = true;

      final result = await useCase(
        organizationId: _organizationId,
        name: 'Priya Sharma',
        rawPhoneNumber: '+911234567890',
        toBranchId: _toBranchId,
        reassignedBy: 'owner-1',
      );

      expect(result, isA<ResultFailure<dynamic>>());
    },
  );
}
