import 'package:app/core/result/result.dart';
import 'package:app/core/session/domain/auth_repository.dart';

/// Signs the current user out.
class SignOutUseCase {
  /// Creates the use case from its [AuthRepository].
  const SignOutUseCase(this._authRepository);

  final AuthRepository _authRepository;

  /// Signs the current user out.
  Future<Result<void>> call() => _authRepository.signOut();
}
