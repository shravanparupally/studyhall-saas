import 'package:freezed_annotation/freezed_annotation.dart';

part 'phone_otp_session.freezed.dart';

/// The outcome of requesting a phone OTP, per Firebase Auth's
/// `verifyPhoneNumber` API. Two real outcomes exist:
///
/// - [PhoneOtpCodeSent]: a code was texted; the caller must collect it
///   and call `AuthRepository.verifyOtp`.
/// - [PhoneOtpAutoVerified]: Android's SMS auto-retrieval verified the
///   device before the user typed anything — sign-in already completed,
///   there is nothing left to collect.
@freezed
sealed class PhoneOtpSession with _$PhoneOtpSession {
  const factory PhoneOtpSession.codeSent({
    required String verificationId,
    int? resendToken,
  }) = PhoneOtpCodeSent;
  const factory PhoneOtpSession.autoVerified() = PhoneOtpAutoVerified;
}
