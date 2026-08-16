import 'package:app/core/domain/ids.dart';
import 'package:app/core/result/result.dart';
import 'package:app/core/session/domain/org_access.dart';
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

  /// Resolves [userId]'s access, if any — an Owner grant on some
  /// Organization, or a Receptionist grant on some Branch. Returns
  /// `Result.success(null)` when the user has neither yet (a brand-new
  /// sign-in that hasn't completed onboarding).
  ///
  /// See [OrgAccess]'s doc comment: this is a UX-routing convenience,
  /// not a security check.
  Future<Result<OrgAccess?>> resolveAccessForUser(String userId);

  /// Reads one Organization by ID.
  Future<Result<Organization>> getOrganization(OrganizationId id);
}
