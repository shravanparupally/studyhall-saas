import 'package:app/core/domain/ids.dart';
import 'package:app/core/domain/phone_number.dart';
import 'package:app/core/result/failure.dart';
import 'package:app/core/result/result.dart';
import 'package:app/features/receptionist/domain/receptionist.dart';
import 'package:app/features/receptionist/domain/receptionist_repository.dart';

/// A controllable in-memory [ReceptionistRepository] for tests, per
/// docs/15_Technical_Architecture.md §15.15/§15.23.
class FakeReceptionistRepository implements ReceptionistRepository {
  /// Every `invite()` call this fake has recorded.
  final List<Receptionist> invited = [];

  /// Every `reassign()` call this fake has recorded.
  final List<Receptionist> reassigned = [];

  /// When true, every method returns a [Failure.network].
  bool shouldFail = false;

  @override
  Future<Result<Receptionist>> invite({
    required OrganizationId organizationId,
    required BranchId branchId,
    required String name,
    required PhoneNumber phoneNumber,
    required String invitedBy,
  }) async {
    if (shouldFail) {
      return const Result.failure(Failure.network('simulated failure'));
    }
    final receptionist = Receptionist(
      userId: 'user-42',
      organizationId: organizationId,
      branchId: branchId,
      name: name,
      phoneNumber: phoneNumber,
      status: ReceptionistGrantStatus.active,
      invitedAt: DateTime.utc(2026),
      invitedBy: invitedBy,
    );
    invited.add(receptionist);
    return Result.success(receptionist);
  }

  @override
  Future<Result<List<Receptionist>>> listByBranch({
    required OrganizationId organizationId,
    required BranchId branchId,
  }) async {
    if (shouldFail) {
      return const Result.failure(Failure.network('simulated failure'));
    }
    return Result.success(
      invited.where((r) => r.branchId == branchId).toList(),
    );
  }

  @override
  Future<Result<Receptionist>> reassign({
    required OrganizationId organizationId,
    required String name,
    required PhoneNumber phoneNumber,
    required BranchId toBranchId,
    required String reassignedBy,
  }) async {
    if (shouldFail) {
      return const Result.failure(Failure.network('simulated failure'));
    }
    final receptionist = Receptionist(
      userId: 'user-42',
      organizationId: organizationId,
      branchId: toBranchId,
      name: name,
      phoneNumber: phoneNumber,
      status: ReceptionistGrantStatus.active,
      invitedAt: DateTime.utc(2026),
      invitedBy: reassignedBy,
    );
    reassigned.add(receptionist);
    return Result.success(receptionist);
  }
}
