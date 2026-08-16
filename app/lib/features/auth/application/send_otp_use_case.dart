import 'package:app/core/domain/phone_number.dart';
import 'package:app/core/domain/phone_otp_session.dart';
import 'package:app/core/result/result.dart';
import 'package:app/core/session/domain/auth_repository.dart';

/// Requests a phone OTP. Thin by design — per
/// docs/08_System_Architecture.md §8.4, one class per use case, even
/// when it's a direct pass-through, keeps every use case's shape
/// consistent as the codebase grows.
class SendOtpUseCase {
  /// Creates the use case from its [AuthRepository].
  const SendOtpUseCase(this._authRepository);

  final AuthRepository _authRepository;

  /// Requests an OTP for [phoneNumber].
  Future<Result<PhoneOtpSession>> call(
    PhoneNumber phoneNumber, {
    int? forceResendingToken,
  }) => _authRepository.sendOtp(
    phoneNumber,
    forceResendingToken: forceResendingToken,
  );
}
