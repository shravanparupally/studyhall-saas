import 'package:app/core/domain/phone_number.dart';
import 'package:app/core/result/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_state.freezed.dart';

/// The Login screen's flow state — a Tier 2 screen-scoped state per
/// docs/15_Technical_Architecture.md §15.29, not shared session state
/// (that's `SessionState`, resolved separately once sign-in succeeds).
/// `error`/`isSubmitting` live inside each phase (rather than wrapping
/// the whole notifier in `AsyncValue`) specifically so a failed
/// verify/resend attempt never loses the in-flight `verificationId` —
/// losing it would force the user back to square one over a transient
/// network error.
@freezed
sealed class LoginState with _$LoginState {
  const factory LoginState.enteringPhone({
    @Default(false) bool isSubmitting,
    Failure? error,
  }) = LoginEnteringPhone;

  const factory LoginState.otpSent({
    required PhoneNumber phoneNumber,
    required String verificationId,
    required DateTime resendAvailableAt,
    int? resendToken,
    @Default(false) bool isSubmitting,
    Failure? error,
  }) = LoginOtpSent;
}
