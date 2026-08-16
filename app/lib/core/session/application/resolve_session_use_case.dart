import 'package:app/core/domain/auth_user.dart';
import 'package:app/core/result/result.dart';
import 'package:app/core/session/domain/session_state.dart';
import 'package:app/features/branch/domain/branch_repository.dart';
import 'package:app/features/organization/domain/organization_repository.dart';

/// Resolves where a signed-in user currently stands — orchestrates
/// [OrganizationRepository] and [BranchRepository], which is exactly why
/// this lives in `core/session` rather than inside either feature: it's
/// a cross-aggregate concern, the Application-layer analogue of a Domain
/// Service (docs/14_Domain_Model.md §14.10), consuming each feature's
/// public repository interface only — never an implementation, never a
/// private feature type.
class ResolveSessionUseCase {
  /// Creates the use case from its two collaborating repositories.
  const ResolveSessionUseCase(
    this._organizationRepository,
    this._branchRepository,
  );

  final OrganizationRepository _organizationRepository;
  final BranchRepository _branchRepository;

  /// Resolves where [user] currently stands.
  Future<Result<SessionState>> call(AuthUser user) async {
    final accessResult = await _organizationRepository.resolveAccessForUser(
      user.uid,
    );
    return accessResult.when(
      failure: (failure) async => Result.failure(failure),
      success: (orgAccess) async {
        if (orgAccess == null) {
          return Result.success(SessionState.needsOrganization(user));
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
