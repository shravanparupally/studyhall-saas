import 'package:app/core/domain/ids.dart';
import 'package:app/core/result/failure.dart';
import 'package:app/core/result/result.dart';
import 'package:app/features/branch/domain/branch.dart';
import 'package:app/features/branch/domain/branch_repository.dart';
import 'package:app/features/organization/domain/organization_repository.dart';
import 'package:uuid/uuid.dart';

/// Creates a Branch under an Organization. Validates input at the
/// Application layer, per docs/15_Technical_Architecture.md §15.7 — see
/// `CreateOrganizationUseCase` for the same reasoning.
///
/// Depends on [OrganizationRepository] as well as [BranchRepository] —
/// purely to read the owning Organization's `timezone` so a new Branch
/// defaults to it (docs/14_Domain_Model.md §Branch requires a value, and
/// Sprint 1's form doesn't collect one). Reading another feature's
/// public repository interface for exactly this kind of cross-aggregate
/// need is the sanctioned pattern per
/// docs/15_Technical_Architecture.md §15.20.
class CreateBranchUseCase {
  /// Creates the use case from its collaborating repositories. [uuid]
  /// is injectable for tests; defaults to a real [Uuid] generator.
  CreateBranchUseCase(
    this._branchRepository,
    this._organizationRepository, {
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final BranchRepository _branchRepository;
  final OrganizationRepository _organizationRepository;
  final Uuid _uuid;

  /// Validates the given fields and creates a Branch under
  /// [organizationId].
  Future<Result<Branch>> call({
    required OrganizationId organizationId,
    required String name,
    required String city,
    required String address,
    required String contactPhone,
    String? googleMapsUrl,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return const Result.failure(Failure.validation('Enter a branch name.'));
    }
    final trimmedCity = city.trim();
    if (trimmedCity.isEmpty) {
      return const Result.failure(Failure.validation('Enter a city.'));
    }
    final trimmedAddress = address.trim();
    if (trimmedAddress.isEmpty) {
      return const Result.failure(Failure.validation('Enter an address.'));
    }
    final trimmedContactPhone = contactPhone.trim();
    if (trimmedContactPhone.isEmpty) {
      return const Result.failure(
        Failure.validation('Enter a contact number.'),
      );
    }

    final organizationResult = await _organizationRepository.getOrganization(
      organizationId,
    );
    return organizationResult.when(
      failure: (failure) async => Result.failure(failure),
      success: (organization) {
        final mapsUrl = googleMapsUrl?.trim();
        final branch = Branch(
          id: BranchId(_uuid.v4()),
          organizationId: organizationId,
          name: trimmedName,
          city: trimmedCity,
          address: trimmedAddress,
          googleMapsUrl: (mapsUrl?.isEmpty ?? true) ? null : mapsUrl,
          contactPhone: trimmedContactPhone,
          timezone: organization.timezone,
          status: BranchStatus.active,
          createdAt: DateTime.now().toUtc(),
        );
        return _branchRepository.createBranch(
          organizationId: organizationId,
          branch: branch,
        );
      },
    );
  }
}
