import 'package:app/core/domain/auth_user.dart';
import 'package:app/core/domain/ids.dart';
import 'package:app/core/domain/phone_number.dart';
import 'package:app/core/session/domain/org_access.dart';
import 'package:app/core/session/domain/session_state.dart';
import 'package:app/core/session/presentation/session_notifier.dart';
import 'package:app/core/session/presentation/session_providers.dart';
import 'package:app/features/branch/domain/branch.dart';
import 'package:app/features/branch/presentation/branch_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_branch_repository.dart';

const _organizationId = OrganizationId('org-1');
const _user = AuthUser(
  uid: 'user-1',
  phoneNumber: PhoneNumber('+911234567890'),
);

Branch _branch() => Branch(
  id: const BranchId('branch-1'),
  organizationId: _organizationId,
  name: 'Test Branch',
  city: 'Kota',
  address: '123 Main Street',
  contactPhone: '+911234567891',
  timezone: 'Asia/Kolkata',
  status: BranchStatus.active,
  createdAt: DateTime.utc(2026),
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeAuthRepository authRepository;
  late FakeBranchRepository branchRepository;
  late ProviderContainer container;

  setUp(() {
    authRepository = FakeAuthRepository();
    branchRepository = FakeBranchRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        branchRepositoryProvider.overrideWithValue(branchRepository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(authRepository.dispose);
  });

  test(
    'SessionState follows Firebase Auth sign-in/out — unauthenticated when signed out, '
    'needsOrganization the moment a user with no orgAccess claim signs in',
    () async {
      final states = <SessionState>[];
      final subscription = container.listen(sessionProvider, (
        previous,
        next,
      ) {
        next.whenData(states.add);
      }, fireImmediately: true);
      addTearDown(subscription.close);

      authRepository.emit(null);
      await _settle();
      expect(states.last, const SessionState.unauthenticated());

      authRepository.emit(_user);
      await _settle();
      expect(states.last, isA<SessionNeedsOrganization>());
    },
  );

  test(
    'SessionState re-resolves to needsBranch once an Owner orgAccess claim '
    'is seeded for the signed-in user, and to ready once that Organization '
    'also has a Branch',
    () async {
      final states = <SessionState>[];
      final subscription = container.listen(sessionProvider, (
        previous,
        next,
      ) {
        next.whenData(states.add);
      }, fireImmediately: true);
      addTearDown(subscription.close);

      authRepository.emit(_user);
      await _settle();
      expect(states.last, isA<SessionNeedsOrganization>());

      authRepository.seededOrgAccess = const OrgAccess(
        organizationId: _organizationId,
        role: UserRole.owner,
      );
      // SessionNotifier only re-resolves on an auth-state event or an
      // explicit invalidation — matching production's use of
      // `ref.invalidate(sessionProvider)` after a claims-affecting write
      // (see CreateOrganizationNotifier/CreateFirstBranchNotifier).
      container.invalidate(sessionProvider);
      await _settle();
      expect(states.last, isA<SessionNeedsBranch>());

      branchRepository.branchesByOrgId[_organizationId.value] = [_branch()];
      container.invalidate(sessionProvider);
      await _settle();
      expect(states.last, isA<SessionReady>());
    },
  );

  test(
    'a Receptionist orgAccess claim resolves straight to ready, scoped to '
    'exactly the Branch the claim names',
    () async {
      authRepository.seededOrgAccess = const OrgAccess(
        organizationId: _organizationId,
        role: UserRole.receptionist,
        branchId: BranchId('branch-1'),
      );

      final states = <SessionState>[];
      final subscription = container.listen(sessionProvider, (
        previous,
        next,
      ) {
        next.whenData(states.add);
      }, fireImmediately: true);
      addTearDown(subscription.close);

      authRepository.emit(_user);
      await _settle();

      expect(states.last, isA<SessionReady>());
      final ready = states.last as SessionReady;
      expect(ready.orgAccess.role, UserRole.receptionist);
      expect(ready.orgAccess.branchId, const BranchId('branch-1'));
    },
  );

  test(
    'signing out resets SessionState to unauthenticated even after '
    'reaching ready',
    () async {
      authRepository.seededOrgAccess = const OrgAccess(
        organizationId: _organizationId,
        role: UserRole.owner,
      );
      branchRepository.branchesByOrgId[_organizationId.value] = [_branch()];

      final states = <SessionState>[];
      final subscription = container.listen(sessionProvider, (
        previous,
        next,
      ) {
        next.whenData(states.add);
      }, fireImmediately: true);
      addTearDown(subscription.close);

      authRepository.emit(_user);
      await _settle();
      expect(states.last, isA<SessionReady>());

      authRepository.emit(null);
      await _settle();
      expect(states.last, const SessionState.unauthenticated());
    },
  );
}
