import 'package:app/core/domain/ids.dart';
import 'package:app/core/result/failure.dart';
import 'package:app/core/result/result.dart';
import 'package:app/features/branch/domain/branch.dart';
import 'package:app/features/branch/domain/branch_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// The only place this feature imports `cloud_firestore`, per
/// docs/15_Technical_Architecture.md §15.7. Collection layout matches
/// docs/07_Firestore_Schema.md §7.2:
/// `/organizations/{organizationId}/branches/{branchId}`.
class FirestoreBranchRepository implements BranchRepository {
  /// Creates the repository from a Firestore instance.
  FirestoreBranchRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, Object?>> _orgRef(
    OrganizationId organizationId,
  ) => _firestore.collection('organizations').doc(organizationId.value);

  @override
  Future<Result<Branch>> createBranch({
    required OrganizationId organizationId,
    required Branch branch,
  }) async {
    try {
      final orgRef = _orgRef(organizationId);
      final branchRef = orgRef.collection('branches').doc(branch.id.value);

      // Creating a Branch is also, per docs/14_Domain_Model.md §14.10's
      // Ownership Guard, how an Organization leaves `setup_incomplete`
      // (its founding Owner already exists by construction — see
      // OrganizationRepository.createOrganization — so the first Branch
      // is the only remaining activation condition). Both writes happen
      // in one transaction so the two can never disagree.
      await _firestore.runTransaction((transaction) async {
        final orgSnapshot = await transaction.get(orgRef);
        transaction.set(branchRef, _branchToDoc(branch));
        if (orgSnapshot.data()?['status'] == 'setup_incomplete') {
          transaction.update(orgRef, {'status': 'active'});
        }
      });

      return Result.success(branch);
    } on FirebaseException catch (error) {
      return Result.failure(_mapException(error));
    }
  }

  @override
  Future<Result<List<Branch>>> listBranches(
    OrganizationId organizationId,
  ) async {
    try {
      final snapshot = await _orgRef(
        organizationId,
      ).collection('branches').get();
      return Result.success(
        snapshot.docs
            .map((doc) => _branchFromDoc(organizationId, doc))
            .toList(),
      );
    } on FirebaseException catch (error) {
      return Result.failure(_mapException(error));
    }
  }

  Map<String, Object?> _branchToDoc(Branch branch) => {
    'organizationId': branch.organizationId.value,
    'name': branch.name,
    'city': branch.city,
    'address': branch.address,
    'googleMapsUrl': branch.googleMapsUrl,
    'contactPhone': branch.contactPhone,
    'timezone': branch.timezone,
    'status': branch.status.name,
    'createdAt': Timestamp.fromDate(branch.createdAt),
  };

  Branch _branchFromDoc(
    OrganizationId organizationId,
    QueryDocumentSnapshot<Map<String, Object?>> doc,
  ) {
    final data = doc.data();
    return Branch(
      id: BranchId(doc.id),
      organizationId: organizationId,
      name: data['name']! as String,
      city: data['city']! as String,
      address: data['address']! as String,
      googleMapsUrl: data['googleMapsUrl'] as String?,
      contactPhone: data['contactPhone']! as String,
      timezone: data['timezone']! as String,
      status: (data['status']! as String) == 'active'
          ? BranchStatus.active
          : BranchStatus.inactive,
      createdAt: (data['createdAt']! as Timestamp).toDate(),
    );
  }

  Failure _mapException(FirebaseException error) => switch (error.code) {
    'permission-denied' => Failure.permission(error.message),
    'not-found' => Failure.notFound(error.message),
    'already-exists' => Failure.conflict(error.message),
    _ => Failure.network(error.message),
  };
}
