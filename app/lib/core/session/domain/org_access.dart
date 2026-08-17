import 'package:app/core/domain/ids.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'org_access.freezed.dart';

/// The two default roles, per docs/02_Product_Requirements_Document.md
/// FR-7.1. Custom roles (finer-grained, still Branch-scoped) are a later
/// phase (FR-7.3) and are not modeled here yet.
enum UserRole {
  /// Org-wide access to every Branch, per FR-7.4.
  owner,

  /// Access to exactly one assigned Branch, per FR-7.4.
  receptionist,
}

/// A resolved user's access within one Organization — the client-side
/// analogue of the `orgAccess` custom claim in
/// docs/07_Firestore_Schema.md §7.4.
///
/// Sourced directly from the signed-in user's verified Firebase ID token
/// (`AuthRepository.currentOrgAccess`), the same claim a Cloud Function
/// trigger issues and `firestore.rules` reads — not re-derived from a
/// separate Firestore query. It drives route guards and screen content
/// exactly as before, but per docs/15_Technical_Architecture.md §15.5 the
/// actual enforcement is still, and only ever, Firestore security rules
/// plus each Cloud Function's own independent `orgAccess` check — this
/// value being authoritative doesn't change that Firestore rules and
/// Cloud Functions are the layers that actually enforce it.
@freezed
sealed class OrgAccess with _$OrgAccess {
  const factory OrgAccess({
    required OrganizationId organizationId,
    required UserRole role,
    BranchId? branchId,
  }) = _OrgAccess;
}
