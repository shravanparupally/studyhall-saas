import 'package:app/core/domain/ids.dart';
import 'package:app/core/domain/phone_number.dart';
import 'package:app/core/result/failure.dart';
import 'package:app/core/result/result.dart';
import 'package:app/features/receptionist/domain/receptionist.dart';
import 'package:app/features/receptionist/domain/receptionist_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

/// The only place this feature imports `cloud_firestore`/`cloud_functions`,
/// per docs/15_Technical_Architecture.md §15.7/§15.15.
///
/// [invite] calls the `inviteReceptionist` Cloud Function
/// (`backend/src/features/receptionist/`) rather than writing Firestore
/// directly: per docs/07_Firestore_Schema.md §7.2, the
/// `receptionists/{userId}` document ID *is* the invited person's Firebase
/// Auth uid, and resolving-or-creating that uid from a phone number that
/// may never have signed in is an Admin-SDK-only capability the client
/// cannot perform itself — this is also why `firestore.rules` does not
/// grant the client a direct-write path for this collection's initial
/// creation.
class FirestoreReceptionistRepository implements ReceptionistRepository {
  /// Creates the repository from a Firestore instance and a Cloud
  /// Functions instance.
  FirestoreReceptionistRepository(this._firestore, this._functions);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<Result<Receptionist>> invite({
    required OrganizationId organizationId,
    required BranchId branchId,
    required String name,
    required PhoneNumber phoneNumber,
    required String invitedBy,
  }) async {
    try {
      final callable = _functions.httpsCallable('inviteReceptionist');
      final response = await callable.call<Map<String, Object?>>({
        'organizationId': organizationId.value,
        'branchId': branchId.value,
        'name': name,
        'phoneNumber': phoneNumber.value,
      });
      final data = response.data;
      return Result.success(
        Receptionist(
          userId: data['userId']! as String,
          organizationId: organizationId,
          branchId: branchId,
          name: name,
          phoneNumber: phoneNumber,
          status: ReceptionistGrantStatus.active,
          invitedAt: DateTime.parse(data['invitedAt']! as String),
          invitedBy: invitedBy,
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      return Result.failure(_mapCallableException(error));
    }
  }

  @override
  Future<Result<Receptionist>> reassign({
    required OrganizationId organizationId,
    required String name,
    required PhoneNumber phoneNumber,
    required BranchId toBranchId,
    required String reassignedBy,
  }) async {
    try {
      final callable = _functions.httpsCallable('reassignReceptionist');
      final response = await callable.call<Map<String, Object?>>({
        'organizationId': organizationId.value,
        'phoneNumber': phoneNumber.value,
        'toBranchId': toBranchId.value,
      });
      final data = response.data;
      return Result.success(
        Receptionist(
          userId: data['userId']! as String,
          organizationId: organizationId,
          branchId: BranchId(data['branchId']! as String),
          name: name,
          phoneNumber: phoneNumber,
          status: ReceptionistGrantStatus.active,
          invitedAt: DateTime.parse(data['reassignedAt']! as String),
          invitedBy: reassignedBy,
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      return Result.failure(_mapCallableException(error));
    }
  }

  @override
  Future<Result<List<Receptionist>>> listByBranch({
    required OrganizationId organizationId,
    required BranchId branchId,
  }) async {
    try {
      final snapshot = await _branchRef(
        organizationId,
        branchId,
      ).collection('receptionists').get();
      return Result.success(
        snapshot.docs
            .map((doc) => _receptionistFromDoc(organizationId, branchId, doc))
            .toList(),
      );
    } on FirebaseException catch (error) {
      return Result.failure(_mapFirestoreException(error));
    }
  }

  DocumentReference<Map<String, Object?>> _branchRef(
    OrganizationId organizationId,
    BranchId branchId,
  ) => _firestore
      .collection('organizations')
      .doc(organizationId.value)
      .collection('branches')
      .doc(branchId.value);

  Receptionist _receptionistFromDoc(
    OrganizationId organizationId,
    BranchId branchId,
    QueryDocumentSnapshot<Map<String, Object?>> doc,
  ) {
    final data = doc.data();
    return Receptionist(
      userId: doc.id,
      organizationId: organizationId,
      branchId: branchId,
      name: data['name']! as String,
      phoneNumber: PhoneNumber(data['phoneNumber']! as String),
      status: (data['status']! as String) == 'active'
          ? ReceptionistGrantStatus.active
          : ReceptionistGrantStatus.revoked,
      invitedAt: (data['invitedAt']! as Timestamp).toDate(),
      invitedBy: data['invitedBy']! as String,
    );
  }

  Failure _mapCallableException(FirebaseFunctionsException error) =>
      switch (error.code) {
        'permission-denied' || 'unauthenticated' => Failure.permission(
          error.message,
        ),
        'invalid-argument' => Failure.validation(error.message),
        'not-found' => Failure.notFound(error.message),
        'already-exists' => Failure.conflict(error.message),
        _ => Failure.network(error.message),
      };

  Failure _mapFirestoreException(FirebaseException error) =>
      switch (error.code) {
        'permission-denied' => Failure.permission(error.message),
        'not-found' => Failure.notFound(error.message),
        'already-exists' => Failure.conflict(error.message),
        _ => Failure.network(error.message),
      };
}
