import 'package:app/app.dart';
import 'package:app/core/domain/auth_user.dart';
import 'package:app/core/domain/ids.dart';
import 'package:app/core/domain/phone_number.dart';
import 'package:app/core/session/domain/org_access.dart';
import 'package:app/core/session/presentation/session_providers.dart';
import 'package:app/features/branch/domain/branch.dart';
import 'package:app/features/branch/presentation/branch_providers.dart';
import 'package:app/features/organization/presentation/organization_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_branch_repository.dart';
import 'fakes/fake_organization_repository.dart';

// This app talks to Firebase Auth/Firestore for everything past the splash
// screen, and no Firebase project is configured in this environment (see
// lib/firebase_options.dart's doc comment). Rather than weakening the
// assertion or skipping the test, both scenarios below override the three
// repository providers with fakes — the sanctioned Riverpod testing
// pattern per docs/15_Technical_Architecture.md §15.4/§15.16/§15.23 ("tests
// override these same providers with fakes via ProviderContainer... no
// Notifier ships without a test exercising its state transitions"). The
// app still exercises its real Splash -> SessionNotifier -> GoRouter
// redirect -> screen routing end to end; only the data source is fake.

const _organizationId = OrganizationId('org-1');
const _user = AuthUser(
  uid: 'owner-1',
  phoneNumber: PhoneNumber('+911234567890'),
);

Branch _branch() => Branch(
  id: const BranchId('branch-1'),
  organizationId: _organizationId,
  name: 'Main Branch',
  city: 'Kota',
  address: '123 Main Street',
  contactPhone: '+911234567891',
  timezone: 'Asia/Kolkata',
  status: BranchStatus.active,
  createdAt: DateTime.utc(2026),
);

void main() {
  testWidgets(
    'A signed-in Owner with an Organization and Branch lands on the Home '
    'screen',
    (tester) async {
      final authRepository = FakeAuthRepository()
        ..seededOrgAccess = const OrgAccess(
          organizationId: _organizationId,
          role: UserRole.owner,
        );
      addTearDown(authRepository.dispose);
      final organizationRepository = FakeOrganizationRepository();
      final branchRepository = FakeBranchRepository()
        ..branchesByOrgId[_organizationId.value] = [_branch()];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepository),
            organizationRepositoryProvider.overrideWithValue(
              organizationRepository,
            ),
            branchRepositoryProvider.overrideWithValue(branchRepository),
          ],
          child: const App(),
        ),
      );

      authRepository.emit(_user);
      await tester.pumpAndSettle();

      expect(find.text('StudyHall OS'), findsWidgets);
      expect(find.text('Welcome to StudyHall OS'), findsOneWidget);
    },
  );

  testWidgets('An unauthenticated user is routed to the Login screen', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository();
    addTearDown(authRepository.dispose);
    final organizationRepository = FakeOrganizationRepository();
    final branchRepository = FakeBranchRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          organizationRepositoryProvider.overrideWithValue(
            organizationRepository,
          ),
          branchRepositoryProvider.overrideWithValue(branchRepository),
        ],
        child: const App(),
      ),
    );

    authRepository.emit(null);
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
  });
}
