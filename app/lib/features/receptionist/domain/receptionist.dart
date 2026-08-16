import 'package:app/core/domain/ids.dart';
import 'package:app/core/domain/phone_number.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'receptionist.freezed.dart';

/// `active ⇄ revoked`, per docs/14_Domain_Model.md §Receptionist. Modeled
/// as its own enum, distinct from Owner's `GrantStatus`, since this
/// feature must not depend on the organization feature's internals
/// (docs/15_Technical_Architecture.md §15.20 — features depend on `core`,
/// never on another feature's internals directly).
enum ReceptionistGrantStatus {
  /// The grant is currently in effect.
  active,

  /// The grant has been revoked and no longer confers access.
  revoked,
}

/// A Receptionist's single-Branch grant, per
/// docs/07_Firestore_Schema.md §7.2's
/// `branches/{branchId}/receptionists/{userId}` and
/// docs/06_Database_Design.md §6.3's `BranchReceptionist` form — modeled
/// as its own concrete shape, not a `StaffMembership` with an optional
/// `branchId`, per that section's reasoning.
@freezed
sealed class Receptionist with _$Receptionist {
  const factory Receptionist({
    required String userId,
    required OrganizationId organizationId,
    required BranchId branchId,
    required String name,
    required PhoneNumber phoneNumber,
    required ReceptionistGrantStatus status,
    required DateTime invitedAt,
    required String invitedBy,
  }) = _Receptionist;
}
