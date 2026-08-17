import 'package:app/core/domain/ids.dart';
import 'package:app/core/result/result.dart';
import 'package:app/features/organization/domain/organization.dart';
import 'package:app/features/organization/domain/owner.dart';

/// One repository interface per Aggregate Root, per
/// docs/15_Technical_Architecture.md §15.15 — Owner has no repository of
/// its own (Sprint 1 scope lists exactly three: Auth, Organization,
/// Branch), so its lifecycle is managed here, through the aggregate it's
/// created alongside.
abstract class OrganizationRepository {
  /// Creates [organization] and its founding [owner] atomically — per
  /// docs/14_Domain_Model.md §Organization, "an Organization is never
  /// created without at least one Owner."
  Future<Result<Organization>> createOrganization({
    required Organization organization,
    required Owner owner,
  });

  /// Reads one Organization by ID.
  Future<Result<Organization>> getOrganization(OrganizationId id);
}
