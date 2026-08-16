import 'package:app/core/session/presentation/session_providers.dart';
import 'package:app/features/auth/application/send_otp_use_case.dart';
import 'package:app/features/auth/application/sign_out_use_case.dart';
import 'package:app/features/auth/application/verify_otp_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_providers.g.dart';

/// The composition-root binding for [SendOtpUseCase].
@riverpod
SendOtpUseCase sendOtpUseCase(Ref ref) =>
    SendOtpUseCase(ref.watch(authRepositoryProvider));

/// The composition-root binding for [VerifyOtpUseCase].
@riverpod
VerifyOtpUseCase verifyOtpUseCase(Ref ref) =>
    VerifyOtpUseCase(ref.watch(authRepositoryProvider));

/// The composition-root binding for [SignOutUseCase].
@riverpod
SignOutUseCase signOutUseCase(Ref ref) =>
    SignOutUseCase(ref.watch(authRepositoryProvider));
