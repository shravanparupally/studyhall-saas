import 'package:app/core/routing/route_not_found_screen.dart';
import 'package:app/core/session/domain/session_state.dart';
import 'package:app/core/session/presentation/session_notifier.dart';
import 'package:app/features/auth/presentation/login_screen.dart';
import 'package:app/features/auth/presentation/splash_screen.dart';
import 'package:app/features/branch/presentation/create_first_branch_screen.dart';
import 'package:app/features/home/presentation/home_screen.dart';
import 'package:app/features/organization/presentation/create_organization_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

const _splashPath = '/splash';
const _loginPath = '/login';
const _createOrganizationPath = '/onboarding/organization';
const _createBranchPath = '/onboarding/branch';
const _homePath = '/';

/// The single, centralized route configuration for this app, per
/// docs/15_Technical_Architecture.md §15.5 — no `Navigator.push` calls
/// scattered through feature code.
///
/// The `redirect` below is exactly what §15.5 calls "a UX convenience
/// only, never the actual security boundary" — it's driven by
/// [SessionState], which is itself derived from client-side Firestore
/// reads (see `OrgAccess`'s doc comment), not a server-issued custom
/// claim. Real enforcement is Firestore security rules + a Cloud
/// Function issuing `orgAccess` claims — both still pending (Sprint 1
/// scope is client-only).
@riverpod
GoRouter appRouter(Ref ref) {
  final session = ref.watch(sessionProvider);
  return GoRouter(
    initialLocation: _splashPath,
    redirect: (context, state) => _redirect(session, state.matchedLocation),
    routes: [
      GoRoute(
        path: _splashPath,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: _loginPath,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: _createOrganizationPath,
        name: 'createOrganization',
        builder: (context, state) => const CreateOrganizationScreen(),
      ),
      GoRoute(
        path: _createBranchPath,
        name: 'createBranch',
        builder: (context, state) => const CreateFirstBranchScreen(),
      ),
      GoRoute(
        path: _homePath,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
    errorBuilder: (context, state) => const RouteNotFoundScreen(),
  );
}

String? _redirect(AsyncValue<SessionState> session, String location) {
  return session.when(
    loading: () => location == _splashPath ? null : _splashPath,
    // Kept on splash (not bounced to /login) so an already-authenticated
    // user isn't wrongly sent through sign-in again over a transient
    // failure resolving their org access — see SessionNotifier's doc
    // comment. The splash screen itself offers a retry.
    error: (error, stackTrace) => location == _splashPath ? null : _splashPath,
    data: (state) => switch (state) {
      SessionUnauthenticated() => location == _loginPath ? null : _loginPath,
      SessionNeedsOrganization() =>
        location == _createOrganizationPath ? null : _createOrganizationPath,
      SessionNeedsBranch() =>
        location == _createBranchPath ? null : _createBranchPath,
      SessionReady() => _authScreens.contains(location) ? _homePath : null,
    },
  );
}

const Set<String> _authScreens = {
  _splashPath,
  _loginPath,
  _createOrganizationPath,
  _createBranchPath,
};
