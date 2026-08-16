import 'package:app/core/domain/ids.dart';
import 'package:app/core/domain/phone_number.dart';
import 'package:app/core/result/failure.dart';
import 'package:app/core/result/result.dart';
import 'package:app/features/receptionist/domain/receptionist.dart';
import 'package:app/features/receptionist/domain/receptionist_repository.dart';

/// Validates input and invites a Receptionist for exactly one Branch
/// (FR-7.1). Validates at the Application layer per
/// docs/15_Technical_Architecture.md §15.7, matching every other use
/// case's own-input-validation convention in this codebase.
class InviteReceptionistUseCase {
  /// Creates the use case from its [ReceptionistRepository].
  const InviteReceptionistUseCase(this._receptionistRepository);

  final ReceptionistRepository _receptionistRepository;

  /// Validates [name]/[rawPhoneNumber] and invites the Receptionist.
  Future<Result<Receptionist>> call({
    required OrganizationId organizationId,
    required BranchId branchId,
    required String name,
    required String rawPhoneNumber,
    required String invitedBy,
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
      success: (phoneNumber) => _receptionistRepository.invite(
        organizationId: organizationId,
        branchId: branchId,
        name: trimmedName,
        phoneNumber: phoneNumber,
        invitedBy: invitedBy,
      ),
    );
  }
}
