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
/// **This is derived from Firestore reads, not from a Firebase Auth
/// custom claim** — no Cloud Function exists yet to issue that claim
/// (out of Sprint 1 scope). It is therefore a UX convenience only, per
/// docs/15_Technical_Architecture.md §15.5: it drives route guards and
/// screen content, but is **not** a security boundary. Firestore
/// security rules keyed off a real custom claim, issued server-side,
/// must land before this is safe to treat as enforcement.
@freezed
sealed class OrgAccess with _$OrgAccess {
  const factory OrgAccess({
    required OrganizationId organizationId,
    required UserRole role,
    BranchId? branchId,
  }) = _OrgAccess;
}
