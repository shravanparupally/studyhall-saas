import 'package:app/core/domain/auth_user.dart';
import 'package:app/core/session/domain/org_access.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_state.freezed.dart';

/// Where the signed-in user currently stands, per
/// docs/15_Technical_Architecture.md §15.29 Tier 3 (shared session
/// state) — every Branch-scoped screen resolves its access from here,
/// never by re-deriving it independently. Drives the GoRouter redirect
/// guard in `core/routing/app_router.dart` via an exhaustive `switch`,
/// per §15.2's mandate for sealed domain unions.
@freezed
sealed class SessionState with _$SessionState {
  /// No one is signed in.
  const factory SessionState.unauthenticated() = SessionUnauthenticated;

  /// Signed in, but this user owns no Organization yet — onboarding
  /// must create one (docs/04_User_Flows.md §4.1).
  const factory SessionState.needsOrganization(AuthUser user) =
      SessionNeedsOrganization;

  /// Signed in with an Organization, but it has no Branch yet.
  const factory SessionState.needsBranch(AuthUser user, OrgAccess orgAccess) =
      SessionNeedsBranch;

  /// Signed in, with an Organization and at least one Branch — normal
  /// operating state.
  const factory SessionState.ready(AuthUser user, OrgAccess orgAccess) =
      SessionReady;
}
