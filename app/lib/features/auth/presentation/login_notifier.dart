import 'package:app/core/domain/phone_number.dart';
import 'package:app/core/domain/phone_otp_session.dart';
import 'package:app/core/result/result.dart';
import 'package:app/features/auth/presentation/auth_providers.dart';
import 'package:app/features/auth/presentation/login_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'login_notifier.g.dart';

/// The OTP resend cooldown mandated by
/// docs/15_Technical_Architecture.md §15.6 ("no less than 30 seconds
/// client-side"). This is a UX rule, not infrastructure, so it lives
/// here rather than in the repository.
const _resendCooldown = Duration(seconds: 30);

/// Drives the Login screen's phone-entry and OTP-verification flow.
@riverpod
class LoginNotifier extends _$LoginNotifier {
  @override
  LoginState build() => const LoginState.enteringPhone();

  /// Requests an OTP for [rawPhone], parsing/validating it first.
  Future<void> sendOtp(String rawPhone) async {
    final parseResult = PhoneNumber.parse(rawPhone);
    final PhoneNumber phone;
    switch (parseResult) {
      case ResultFailure(:final failure):
        state = LoginState.enteringPhone(error: failure);
        return;
      case ResultSuccess(:final value):
        phone = value;
    }

    state = const LoginState.enteringPhone(isSubmitting: true);
    final result = await ref.read(sendOtpUseCaseProvider)(phone);
    _applySendResult(result, phone: phone);
  }

  /// Re-requests an OTP for the phone number already entered, subject to
  /// the resend cooldown.
  Future<void> resendOtp() async {
    final current = state;
    if (current is! LoginOtpSent || current.isSubmitting) return;
    if (DateTime.now().isBefore(current.resendAvailableAt)) return;

    state = current.copyWith(isSubmitting: true, error: null);
    final result = await ref.read(
      sendOtpUseCaseProvider,
    )(current.phoneNumber, forceResendingToken: current.resendToken);
    _applySendResult(result, phone: current.phoneNumber);
  }

  void _applySendResult(
    Result<PhoneOtpSession> result, {
    required PhoneNumber phone,
  }) {
    state = switch (result) {
      ResultFailure(:final failure) => LoginState.enteringPhone(error: failure),
      ResultSuccess(:final value) => switch (value) {
        PhoneOtpCodeSent(:final verificationId, :final resendToken) =>
          LoginState.otpSent(
            phoneNumber: phone,
            verificationId: verificationId,
            resendToken: resendToken,
            resendAvailableAt: DateTime.now().add(_resendCooldown),
          ),
        // Android auto-retrieval already completed sign-in; SessionNotifier
        // will route away from Login on its own once it observes the new
        // Firebase Auth user, so there's nothing further to do here.
        PhoneOtpAutoVerified() => const LoginState.enteringPhone(),
      },
    };
  }

  /// Completes sign-in with [smsCode].
  Future<void> verifyOtp(String smsCode) async {
    final current = state;
    if (current is! LoginOtpSent || current.isSubmitting) return;

    state = current.copyWith(isSubmitting: true, error: null);
    final result = await ref.read(
      verifyOtpUseCaseProvider,
    )(verificationId: current.verificationId, smsCode: smsCode);
    state = result.when(
      // Sign-in succeeded; SessionNotifier picks up the new Firebase Auth
      // user and the router redirects away from Login.
      success: (_) => current.copyWith(isSubmitting: false),
      failure: (failure) =>
          current.copyWith(isSubmitting: false, error: failure),
    );
  }
}
