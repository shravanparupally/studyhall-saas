import 'package:app/core/domain/ids.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'branch.freezed.dart';

/// `active ⇄ inactive`, per docs/14_Domain_Model.md §Branch.
enum BranchStatus {
  /// The Branch is operating normally.
  active,

  /// The Branch is not currently operating.
  inactive,
}

/// A physical Study Hall location, per docs/14_Domain_Model.md §Branch.
///
/// `city` and `googleMapsUrl` are Sprint 1 additions beyond the original
/// entity table. `operatingHours` from the documented schema is
/// deliberately omitted here — Sprint 1's onboarding form doesn't
/// collect it, and inventing a default schedule would be exactly the
/// kind of placeholder data the project rules forbid; it lands as a
/// nullable field once a real UI collects it. `timezone` is not
/// collected on the Branch form either — it defaults to the owning
/// Organization's timezone at creation time (see
/// `CreateBranchUseCase`), consistent with `operatingHours: map<dayOfWeek,
/// ...>` in docs/07_Firestore_Schema.md §7.2 still requiring a value.
@freezed
sealed class Branch with _$Branch {
  const factory Branch({
    required BranchId id,
    required OrganizationId organizationId,
    required String name,
    required String city,
    required String address,
    required String contactPhone,
    required String timezone,
    required BranchStatus status,
    required DateTime createdAt,
    String? googleMapsUrl,
  }) = _Branch;
}
