import 'package:app/core/domain/ids.dart';
import 'package:app/core/result/result.dart';
import 'package:app/features/branch/domain/branch.dart';

/// One repository interface for the Branch Aggregate Root, per
/// docs/15_Technical_Architecture.md §15.15. Every method is
/// Organization-scoped, leading parameter, never optional — per
/// docs/08_System_Architecture.md §8.4, this is what makes a
/// cross-Organization query impossible to construct by accident.
abstract class BranchRepository {
  /// Creates [branch] under [organizationId].
  Future<Result<Branch>> createBranch({
    required OrganizationId organizationId,
    required Branch branch,
  });

  /// Lists every Branch under [organizationId]. Used by session
  /// resolution to decide whether onboarding still needs a first Branch
  /// — Sprint 1 has no roster screen yet to justify pagination.
  Future<Result<List<Branch>>> listBranches(OrganizationId organizationId);
}
