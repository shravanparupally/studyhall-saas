import 'package:app/core/domain/auth_user.dart';
import 'package:app/core/result/result.dart';
import 'package:app/core/session/domain/auth_repository.dart';
import 'package:app/core/session/domain/org_access.dart';
import 'package:app/core/session/domain/session_state.dart';
import 'package:app/features/branch/domain/branch_repository.dart';

/// Resolves where a signed-in user currently stands — orchestrates
/// [AuthRepository] (the authoritative source of [OrgAccess], read from
/// the verified ID token) and [BranchRepository], which is exactly why
/// this lives in `core/session` rather than inside either feature: it's
/// a cross-aggregate concern, the Application-layer analogue of a Domain
/// Service (docs/14_Domain_Model.md §14.10), consuming each feature's
/// public repository interface only — never an implementation, never a
/// private feature type.
class ResolveSessionUseCase {
  /// Creates the use case from its two collaborating repositories.
  const ResolveSessionUseCase(this._authRepository, this._branchRepository);

  final AuthRepository _authRepository;
  final BranchRepository _branchRepository;

  /// Resolves where [user] currently stands.
  Future<Result<SessionState>> call(AuthUser user) async {
    final accessResult = await _authRepository.currentOrgAccess();
    return accessResult.when(
      failure: (failure) async => Result.failure(failure),
      success: (orgAccess) async {
        if (orgAccess == null) {
          return Result.success(SessionState.needsOrganization(user));
        }
        // A Receptionist's claim already names the one Branch they're
        // assigned to, authoritatively — no Firestore existence check is
        // needed for their path. An Owner's claim is org-wide by
        // construction, so a Branch-existence read is still the only way
        // to tell "onboarding still needs a first Branch" apart from
        // "ready" (docs §14.10's Ownership Guard is real Firestore state,
        // not an authorization decision).
        if (orgAccess.role == UserRole.receptionist) {
          return Result.success(SessionState.ready(user, orgAccess));
        }
        final branchesResult = await _branchRepository.listBranches(
          orgAccess.organizationId,
        );
        return branchesResult.when(
          failure: (failure) async => Result.failure(failure),
          success: (branches) async => Result.success(
            branches.isEmpty
                ? SessionState.needsBranch(user, orgAccess)
                : SessionState.ready(user, orgAccess),
          ),
        );
      },
    );
  }
}
