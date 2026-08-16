import 'package:app/core/domain/ids.dart';
import 'package:app/core/domain/phone_number.dart';
import 'package:app/core/result/failure.dart';
import 'package:app/core/result/result.dart';
import 'package:app/features/organization/domain/organization.dart';
import 'package:app/features/organization/domain/organization_repository.dart';
import 'package:app/features/organization/domain/owner.dart';
import 'package:uuid/uuid.dart';

/// Creates an Organization and its founding Owner together, per
/// docs/14_Domain_Model.md §Organization ("an Organization is never
/// created without at least one Owner"). Validates input at the
/// Application layer per docs/15_Technical_Architecture.md §15.7 —
/// malformed input is rejected here, before it ever reaches Firestore,
/// not left to a security rule to catch.
class CreateOrganizationUseCase {
  /// Creates the use case from its [OrganizationRepository]. [uuid] is
  /// injectable for tests; defaults to a real [Uuid] generator.
  CreateOrganizationUseCase(this._organizationRepository, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final OrganizationRepository _organizationRepository;
  final Uuid _uuid;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Validates the given fields and creates the Organization and its
  /// founding Owner together.
  Future<Result<Organization>> call({
    required String organizationName,
    required String address,
    required String timezone,
    required Currency currency,
    required String ownerName,
    required String userId,
    required PhoneNumber ownerPhoneNumber,
    String? gstNumber,
    String? ownerEmail,
  }) async {
    final trimmedOrgName = organizationName.trim();
    if (trimmedOrgName.isEmpty) {
      return const Result.failure(
        Failure.validation('Enter an organization name.'),
      );
    }
    final trimmedOwnerName = ownerName.trim();
    if (trimmedOwnerName.isEmpty) {
      return const Result.failure(Failure.validation('Enter the owner name.'));
    }
    final trimmedAddress = address.trim();
    if (trimmedAddress.isEmpty) {
      return const Result.failure(Failure.validation('Enter an address.'));
    }
    final email = ownerEmail?.trim();
    if (email != null && email.isNotEmpty && !_emailPattern.hasMatch(email)) {
      return const Result.failure(
        Failure.validation('Enter a valid email address.'),
      );
    }

    final now = DateTime.now().toUtc();
    final organization = Organization(
      id: OrganizationId(_uuid.v4()),
      name: trimmedOrgName,
      gstNumber: (gstNumber?.trim().isEmpty ?? true) ? null : gstNumber!.trim(),
      address: trimmedAddress,
      timezone: timezone,
      currency: currency,
      status: OrganizationStatus.setupIncomplete,
      createdAt: now,
    );
    final owner = Owner(
      id: userId,
      organizationId: organization.id,
      userId: userId,
      name: trimmedOwnerName,
      phoneNumber: ownerPhoneNumber,
      email: (email?.isEmpty ?? true) ? null : email,
      status: GrantStatus.active,
      addedAt: now,
    );

    return _organizationRepository.createOrganization(
      organization: organization,
      owner: owner,
    );
  }
}
