import 'package:app/core/domain/ids.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'organization.freezed.dart';

/// The Organization lifecycle, per docs/14_Domain_Model.md §Organization.
/// `suspended` is driven by a Platform Subscription event — not modeled
/// yet (Sprint 1 has no billing) — and is included here only so the
/// closed enum doesn't need to change shape when that lands.
enum OrganizationStatus {
  /// Signed up, but has not yet created its first Branch.
  setupIncomplete,

  /// Fully onboarded and operating normally.
  active,

  /// Access revoked, driven by a Platform Subscription event.
  suspended,
}

/// Currency the Organization's Money values are denominated in. A
/// closed enum with one member today — per docs/14_Domain_Model.md
/// §14.4, `Money` is fixed to INR at MVP; multi-currency is a named P3
/// extension (§14.11), so this is ready to grow without a shape change
/// rather than a hardcoded constant.
enum Currency {
  /// Indian Rupee — the only supported currency at MVP.
  inr,
}

/// The tenancy root — one Study Hall business, per
/// docs/14_Domain_Model.md §Organization. `gstNumber` and the
/// address/timezone/currency fields below are a Sprint 1 addition beyond
/// the original entity table (business-registration detail collected at
/// signup); `address`/`timezone` here describe the Organization's
/// registered business record, distinct from a Branch's own operating
/// address/timezone.
@freezed
sealed class Organization with _$Organization {
  const factory Organization({
    required OrganizationId id,
    required String name,
    required String address,
    required String timezone,
    required Currency currency,
    required OrganizationStatus status,
    required DateTime createdAt,
    String? gstNumber,
  }) = _Organization;
}
