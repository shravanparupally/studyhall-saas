import 'package:app/core/result/result.dart';
import 'package:app/core/session/application/resolve_session_use_case.dart';
import 'package:app/core/session/domain/session_state.dart';
import 'package:app/core/session/presentation/session_providers.dart';
import 'package:app/features/branch/presentation/branch_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_notifier.g.dart';

/// The Tier 3 shared session state every Branch-scoped screen and the
/// GoRouter redirect guard read from, per
/// docs/15_Technical_Architecture.md §15.29 ("deliberately small and
/// stable" — hence `keepAlive`, unlike the screen-scoped notifiers
/// elsewhere in this sprint). Re-resolves whenever Firebase Auth's own
/// state changes; never duplicated into a separately maintained local
/// copy.
@Riverpod(keepAlive: true)
class SessionNotifier extends _$SessionNotifier {
  @override
  Stream<SessionState> build() {
    final authRepository = ref.watch(authRepositoryProvider);
    final resolveSession = ResolveSessionUseCase(
      authRepository,
      ref.watch(branchRepositoryProvider),
    );

    return authRepository.authStateChanges().asyncMap((user) async {
      if (user == null) return const SessionState.unauthenticated();

      final result = await resolveSession(user);
      return result.when(
        success: (state) => state,
        // A transient failure resolving access must not silently route
        // an already-authenticated user through onboarding again — see
        // the router guard's `error` handling, which keeps them on the
        // splash screen with a retry affordance instead.
        failure: (failure) => throw StateError(failure.toString()),
      );
    });
  }
}
