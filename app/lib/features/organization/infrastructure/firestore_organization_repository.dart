import 'package:app/core/domain/ids.dart';
import 'package:app/core/result/failure.dart';
import 'package:app/core/result/result.dart';
import 'package:app/features/organization/domain/organization.dart';
import 'package:app/features/organization/domain/organization_repository.dart';
import 'package:app/features/organization/domain/owner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// The only place this feature imports `cloud_firestore`, per
/// docs/15_Technical_Architecture.md §15.7 — conversion between domain
/// entities and Firestore document shapes happens exclusively here.
///
/// Collection layout matches docs/07_Firestore_Schema.md §7.2:
/// `/organizations/{organizationId}` and
/// `/organizations/{organizationId}/owners/{userId}`. The owner
/// document's `userId` field is a Sprint 1 addition to that schema —
/// redundant with the document ID, kept for the same
/// denormalize-for-query-convenience pattern §7.1 uses elsewhere (a
/// `collectionGroup('owners')` lookup by uid, should one be needed again;
/// session resolution itself now reads the `orgAccess` custom claim off
/// the ID token instead — see `AuthRepository.currentOrgAccess`).
class FirestoreOrganizationRepository implements OrganizationRepository {
  /// Creates the repository from a Firestore instance.
  FirestoreOrganizationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, Object?>> get _organizations =>
      _firestore.collection('organizations');

  @override
  Future<Result<Organization>> createOrganization({
    required Organization organization,
    required Owner owner,
  }) async {
    try {
      final orgRef = _organizations.doc(organization.id.value);
      final ownerRef = orgRef.collection('owners').doc(owner.userId);

      final batch = _firestore.batch()
        ..set(orgRef, _organizationToDoc(organization))
        ..set(ownerRef, _ownerToDoc(owner));
      await batch.commit();

      return Result.success(organization);
    } on FirebaseException catch (error) {
      return Result.failure(_mapException(error));
    }
  }

  @override
  Future<Result<Organization>> getOrganization(OrganizationId id) async {
    try {
      final snapshot = await _organizations.doc(id.value).get();
      final data = snapshot.data();
      if (data == null) {
        return const Result.failure(
          Failure.notFound('Organization not found.'),
        );
      }
      return Result.success(_organizationFromDoc(id, data));
    } on FirebaseException catch (error) {
      return Result.failure(_mapException(error));
    }
  }

  Organization _organizationFromDoc(
    OrganizationId id,
    Map<String, Object?> data,
  ) => Organization(
    id: id,
    name: data['name']! as String,
    gstNumber: data['gstNumber'] as String?,
    address: data['address']! as String,
    timezone: data['timezone']! as String,
    // Currency is a single-member enum today (docs/14_Domain_Model.md
    // §14.4 fixes Money to INR at MVP) — this becomes real parsing once
    // a second currency exists.
    currency: Currency.inr,
    status: _statusFromDoc(data['status']! as String),
    createdAt: (data['createdAt']! as Timestamp).toDate(),
  );

  OrganizationStatus _statusFromDoc(String status) => switch (status) {
    'active' => OrganizationStatus.active,
    'suspended' => OrganizationStatus.suspended,
    _ => OrganizationStatus.setupIncomplete,
  };

  Map<String, Object?> _organizationToDoc(Organization organization) => {
    'name': organization.name,
    'gstNumber': organization.gstNumber,
    'address': organization.address,
    'timezone': organization.timezone,
    'currency': organization.currency.name,
    'status': _statusToDoc(organization.status),
    'createdAt': Timestamp.fromDate(organization.createdAt),
  };

  Map<String, Object?> _ownerToDoc(Owner owner) => {
    'userId': owner.userId,
    'name': owner.name,
    'phoneNumber': owner.phoneNumber.value,
    'email': owner.email,
    'status': owner.status.name,
    'addedAt': Timestamp.fromDate(owner.addedAt),
    'addedBy': owner.addedBy,
  };

  String _statusToDoc(OrganizationStatus status) => switch (status) {
    OrganizationStatus.setupIncomplete => 'setup_incomplete',
    OrganizationStatus.active => 'active',
    OrganizationStatus.suspended => 'suspended',
  };

  Failure _mapException(FirebaseException error) => switch (error.code) {
    'permission-denied' => Failure.permission(error.message),
    'not-found' => Failure.notFound(error.message),
    'already-exists' => Failure.conflict(error.message),
    _ => Failure.network(error.message),
  };
}
