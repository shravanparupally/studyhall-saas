import 'package:app/core/domain/auth_user.dart';
import 'package:app/core/result/result.dart';
import 'package:app/core/session/domain/auth_repository.dart';

/// Completes phone sign-in with the code the user received.
class VerifyOtpUseCase {
  /// Creates the use case from its [AuthRepository].
  const VerifyOtpUseCase(this._authRepository);

  final AuthRepository _authRepository;

  /// Completes sign-in for the code received for [verificationId].
  Future<Result<AuthUser>> call({
    required String verificationId,
    required String smsCode,
  }) => _authRepository.verifyOtp(
    verificationId: verificationId,
    smsCode: smsCode,
  );
}
