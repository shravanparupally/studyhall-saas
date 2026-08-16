import 'package:app/core/domain/ids.dart';
import 'package:app/core/domain/phone_number.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'owner.freezed.dart';

/// `active`/`revoked`, per docs/14_Domain_Model.md §Owner and §Receptionist
/// — shared shape, both grant kinds are one-way `active → revoked`.
enum GrantStatus {
  /// The grant is currently in effect.
  active,

  /// The grant has been revoked and no longer confers access.
  revoked,
}

/// One person's org-wide authority over an Organization, per
/// docs/14_Domain_Model.md §Owner. `email` is a Sprint 1 addition — a
/// business contact address, never used for sign-in (phone OTP remains
/// the only auth method per §15.6).
@freezed
sealed class Owner with _$Owner {
  const factory Owner({
    required String id,
    required OrganizationId organizationId,
    required String userId,
    required String name,
    required PhoneNumber phoneNumber,
    required GrantStatus status,
    required DateTime addedAt,
    String? email,
    String? addedBy,
  }) = _Owner;
}
