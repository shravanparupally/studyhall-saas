import 'package:app/core/domain/ids.dart';
import 'package:app/core/domain/phone_number.dart';
import 'package:app/core/result/failure.dart';
import 'package:app/core/result/result.dart';
import 'package:app/features/receptionist/domain/receptionist.dart';
import 'package:app/features/receptionist/domain/receptionist_repository.dart';

/// Validates input and moves an existing Receptionist to a different
/// Branch (BR-23's revoke-old/create-new model). Validates at the
/// Application layer per docs/15_Technical_Architecture.md §15.7, matching
/// `InviteReceptionistUseCase`'s own-input-validation convention — the
/// person is identified by name/phone number, the same fields Invite
/// collects, since there is no roster screen yet to pick an existing
/// Receptionist from directly.
class ReassignReceptionistUseCase {
  /// Creates the use case from its [ReceptionistRepository].
  const ReassignReceptionistUseCase(this._receptionistRepository);

  final ReceptionistRepository _receptionistRepository;

  /// Validates [name]/[rawPhoneNumber] and reassigns the Receptionist to
  /// [toBranchId].
  Future<Result<Receptionist>> call({
    required OrganizationId organizationId,
    required String name,
    required String rawPhoneNumber,
    required BranchId toBranchId,
    required String reassignedBy,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return Future.value(
        const Result.failure(
          Failure.validation("Enter the receptionist's name."),
        ),
      );
    }

    final phoneResult = PhoneNumber.parse(rawPhoneNumber);
    return phoneResult.when(
      failure: (failure) => Future.value(Result.failure(failure)),
      success: (phoneNumber) => _receptionistRepository.reassign(
        organizationId: organizationId,
        name: trimmedName,
        phoneNumber: phoneNumber,
        toBranchId: toBranchId,
        reassignedBy: reassignedBy,
      ),
    );
  }
}
