import 'dart:async';

import 'package:app/core/domain/auth_user.dart';
import 'package:app/core/domain/phone_number.dart';
import 'package:app/core/domain/phone_otp_session.dart';
import 'package:app/core/result/failure.dart';
import 'package:app/core/result/result.dart';
import 'package:app/core/session/domain/auth_repository.dart';
import 'package:app/core/session/domain/org_access.dart';

/// A controllable in-memory [AuthRepository] for tests, per
/// docs/15_Technical_Architecture.md §15.15/§15.23 — every use case/
/// Notifier test runs against a fake repository, never a real or emulated
/// Firebase Auth.
class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  /// Controls what [currentOrgAccess] reports — the claims-trigger result a
  /// real ID token would carry. `null` (the default) simulates "no claim
  /// yet" — e.g. the Cloud Function trigger hasn't caught up.
  OrgAccess? seededOrgAccess;

  /// When true, [currentOrgAccess] returns a [Failure.network] instead.
  bool shouldFailOrgAccess = false;

  // Mirrors real Firebase Auth's `authStateChanges()` contract: a *new*
  // subscriber immediately receives the current value, then subsequent
  // changes — not just future events off a bare broadcast stream. This
  // matters because SessionNotifier re-subscribes on every
  // `ref.invalidate(sessionProvider)` (§15.6's forced-refresh pattern), and
  // a fake that didn't replay the current value here would silently hang
  // instead of re-resolving, unlike the real SDK.
  //
  // `Stream.multi` (rather than an `async*` generator) is deliberate: its
  // `onListen` callback runs synchronously as part of `.listen()`, so
  // "emit the current value" and "attach the forwarding subscription" for
  // a given listener happen back-to-back with nothing able to run in
  // between — an `async*` generator defers its first `yield` to a
  // microtask, which can race with `emit()` calls made immediately after
  // `.listen()` and silently drop an event on the underlying broadcast
  // controller.
  @override
  Stream<AuthUser?> authStateChanges() {
    return Stream<AuthUser?>.multi((controller) {
      controller.add(_currentUser);
      final subscription = _controller.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  AuthUser? get currentUser => _currentUser;

  /// Test helper: simulates Firebase Auth emitting a new signed-in/out
  /// state, exactly as `authStateChanges()` would.
  void emit(AuthUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  @override
  Future<Result<PhoneOtpSession>> sendOtp(
    PhoneNumber phoneNumber, {
    int? forceResendingToken,
  }) async => throw UnimplementedError('not exercised by these tests');

  @override
  Future<Result<AuthUser>> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async => throw UnimplementedError('not exercised by these tests');

  @override
  Future<Result<void>> signOut() async {
    emit(null);
    return const Result.success(null);
  }

  @override
  Future<Result<OrgAccess?>> currentOrgAccess({
    bool forceRefresh = false,
  }) async {
    if (shouldFailOrgAccess) {
      return const Result.failure(Failure.network('simulated failure'));
    }
    return Result.success(seededOrgAccess);
  }

  /// Closes the underlying stream controller — call from `addTearDown`.
  void dispose() => _controller.close();
}
