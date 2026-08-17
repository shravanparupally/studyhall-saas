import 'package:app/core/domain/ids.dart';
import 'package:app/core/result/failure.dart';
import 'package:app/core/result/result.dart';
import 'package:app/features/organization/domain/organization.dart';
import 'package:app/features/organization/domain/organization_repository.dart';
import 'package:app/features/organization/domain/owner.dart';

/// A controllable in-memory [OrganizationRepository] for tests, per
/// docs/15_Technical_Architecture.md §15.15/§15.23.
class FakeOrganizationRepository implements OrganizationRepository {
  /// Seed/inspect Organizations by their id.
  final Map<String, Organization> organizationsById = {};

  /// When true, every method returns a [Failure.network] — simulates an
  /// infrastructure failure independent of the seeded data above.
  bool shouldFail = false;

  @override
  Future<Result<Organization>> createOrganization({
    required Organization organization,
    required Owner owner,
  }) async {
    if (shouldFail) {
      return const Result.failure(Failure.network('simulated failure'));
    }
    organizationsById[organization.id.value] = organization;
    return Result.success(organization);
  }

  @override
  Future<Result<Organization>> getOrganization(OrganizationId id) async {
    if (shouldFail) {
      return const Result.failure(Failure.network('simulated failure'));
    }
    final organization = organizationsById[id.value];
    if (organization == null) {
      return const Result.failure(Failure.notFound('Organization not found.'));
    }
    return Result.success(organization);
  }
}
