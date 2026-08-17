import 'package:app/core/domain/ids.dart';
import 'package:app/core/domain/phone_number.dart';
import 'package:app/core/result/result.dart';
import 'package:app/features/receptionist/domain/receptionist.dart';

/// One repository interface for the Receptionist Aggregate Root, per
/// docs/15_Technical_Architecture.md §15.15's aggregate map. Every method
/// is Organization- and Branch-scoped, required leading parameters, never
/// optional filters — the same compile-time isolation guarantee as every
/// other Branch-scoped repository (docs/08_System_Architecture.md §8.4).
abstract class ReceptionistRepository {
  /// Invites a new Receptionist for [phoneNumber], assigning them to
  /// exactly one [branchId] (FR-7.1). This write is server-mediated — see
  /// `FirestoreReceptionistRepository`'s doc comment for why the client
  /// cannot perform it directly.
  Future<Result<Receptionist>> invite({
    required OrganizationId organizationId,
    required BranchId branchId,
    required String name,
    required PhoneNumber phoneNumber,
    required String invitedBy,
  });

  /// Lists every Receptionist assigned to [branchId].
  Future<Result<List<Receptionist>>> listByBranch({
    required OrganizationId organizationId,
    required BranchId branchId,
  });

  /// Moves an existing Receptionist, identified by [phoneNumber] (there is
  /// no roster lookup for this to resolve a userId against client-side —
  /// see `FirestoreReceptionistRepository`'s doc comment), to [toBranchId]
  /// within [organizationId] — the revoke-old/create-new model (BR-23).
  /// This write is server-mediated for the same reason [invite] is.
  Future<Result<Receptionist>> reassign({
    required OrganizationId organizationId,
    required String name,
    required PhoneNumber phoneNumber,
    required BranchId toBranchId,
    required String reassignedBy,
  });
}
