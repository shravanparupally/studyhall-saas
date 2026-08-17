import 'package:app/core/domain/auth_user.dart';
import 'package:app/core/domain/ids.dart';
import 'package:app/core/domain/phone_number.dart';
import 'package:app/core/result/result.dart';
import 'package:app/core/session/application/resolve_session_use_case.dart';
import 'package:app/core/session/domain/org_access.dart';
import 'package:app/core/session/domain/session_state.dart';
import 'package:app/features/branch/domain/branch.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_branch_repository.dart';

const _user = AuthUser(
  uid: 'user-1',
  phoneNumber: PhoneNumber('+911234567890'),
);
const _organizationId = OrganizationId('org-1');
const _branchId = BranchId('branch-1');

Branch _branch({required BranchId id}) => Branch(
  id: id,
  organizationId: _organizationId,
  name: 'Test Branch',
  city: 'Kota',
  address: '123 Main Street',
  contactPhone: '+911234567891',
  timezone: 'Asia/Kolkata',
  status: BranchStatus.active,
  createdAt: DateTime.utc(2026),
);

void main() {
  late FakeAuthRepository authRepository;
  late FakeBranchRepository branchRepository;
  late ResolveSessionUseCase useCase;

  setUp(() {
    authRepository = FakeAuthRepository();
    branchRepository = FakeBranchRepository();
    useCase = ResolveSessionUseCase(authRepository, branchRepository);
  });

  tearDown(() => authRepository.dispose());

  test(
    'resolves SessionState.needsOrganization when the ID token carries no '
    'orgAccess claim at all — the fail-closed default, never a granted '
    'access',
    () async {
      final result = await useCase(_user);

      expect(result, isA<ResultSuccess<SessionState>>());
      final state = (result as ResultSuccess<SessionState>).value;
      expect(state, const SessionState.needsOrganization(_user));
    },
  );

  test(
    'resolves SessionState.needsBranch when an Owner claim exists but the '
    'Organization has zero Branches',
    () async {
      authRepository.seededOrgAccess = const OrgAccess(
        organizationId: _organizationId,
        role: UserRole.owner,
      );

      final result = await useCase(_user);

      final state = (result as ResultSuccess<SessionState>).value;
      expect(state, isA<SessionNeedsBranch>());
      final needsBranch = state as SessionNeedsBranch;
      expect(needsBranch.orgAccess.role, UserRole.owner);
      expect(needsBranch.orgAccess.organizationId, _organizationId);
    },
  );

  test(
    'resolves SessionState.ready with org-wide access (no branchId '
    'restriction) for an Owner claim once a Branch exists',
    () async {
      authRepository.seededOrgAccess = const OrgAccess(
        organizationId: _organizationId,
        role: UserRole.owner,
      );
      branchRepository.branchesByOrgId[_organizationId.value] = [
        _branch(id: _branchId),
      ];

      final result = await useCase(_user);

      final state = (result as ResultSuccess<SessionState>).value;
      expect(state, isA<SessionReady>());
      final ready = state as SessionReady;
      expect(ready.orgAccess.role, UserRole.owner);
      expect(
        ready.orgAccess.branchId,
        isNull,
        reason:
            "An Owner's claim carries no branchId — access to every "
            'Branch follows from role == owner alone (docs/07 §7.4).',
      );
    },
  );

  test(
    'resolves SessionState.ready for a Receptionist claim scoped to exactly '
    'the one Branch it names, never org-wide — the client-side analogue of '
    'Branch isolation (docs/06 §6.6, FR-7.4) — without any Branch-existence '
    'lookup, since the claim is already authoritative for a Receptionist',
    () async {
      authRepository.seededOrgAccess = const OrgAccess(
        organizationId: _organizationId,
        role: UserRole.receptionist,
        branchId: _branchId,
      );
      // Deliberately configured to fail if the use case were to consult
      // BranchRepository for a Receptionist's path at all.
      branchRepository.shouldFail = true;

      final result = await useCase(_user);

      final state = (result as ResultSuccess<SessionState>).value;
      expect(state, isA<SessionReady>());
      final ready = state as SessionReady;
      expect(ready.orgAccess.role, UserRole.receptionist);
      expect(ready.orgAccess.branchId, _branchId);
    },
  );

  test(
    'propagates an AuthRepository failure as Result.failure rather than '
    'throwing',
    () async {
      authRepository.shouldFailOrgAccess = true;

      final result = await useCase(_user);

      expect(result, isA<ResultFailure<SessionState>>());
    },
  );

  test(
    'propagates a BranchRepository failure as Result.failure rather than '
    'throwing, for an Owner claim',
    () async {
      authRepository.seededOrgAccess = const OrgAccess(
        organizationId: _organizationId,
        role: UserRole.owner,
      );
      branchRepository.shouldFail = true;

      final result = await useCase(_user);

      expect(result, isA<ResultFailure<SessionState>>());
    },
  );
}
