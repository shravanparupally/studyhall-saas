import 'package:app/core/domain/ids.dart';
import 'package:app/core/result/failure.dart';
import 'package:app/core/result/result.dart';
import 'package:app/features/branch/domain/branch.dart';
import 'package:app/features/branch/domain/branch_repository.dart';

/// A controllable in-memory [BranchRepository] for tests, per
/// docs/15_Technical_Architecture.md §15.15/§15.23.
class FakeBranchRepository implements BranchRepository {
  /// Seed/inspect Branches by their owning Organization's id.
  final Map<String, List<Branch>> branchesByOrgId = {};

  /// When true, every method returns a [Failure.network].
  bool shouldFail = false;

  @override
  Future<Result<Branch>> createBranch({
    required OrganizationId organizationId,
    required Branch branch,
  }) async {
    if (shouldFail) {
      return const Result.failure(Failure.network('simulated failure'));
    }
    (branchesByOrgId[organizationId.value] ??= []).add(branch);
    return Result.success(branch);
  }

  @override
  Future<Result<List<Branch>>> listBranches(
    OrganizationId organizationId,
  ) async {
    if (shouldFail) {
      return const Result.failure(Failure.network('simulated failure'));
    }
    return Result.success(branchesByOrgId[organizationId.value] ?? const []);
  }
}
