import 'dart:async';

import 'package:app/core/domain/auth_user.dart';
import 'package:app/core/domain/ids.dart';
import 'package:app/core/domain/phone_number.dart';
import 'package:app/core/domain/phone_otp_session.dart';
import 'package:app/core/result/failure.dart';
import 'package:app/core/result/result.dart';
import 'package:app/core/session/domain/auth_repository.dart';
import 'package:app/core/session/domain/org_access.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// The only place `package:firebase_auth` is imported, per
/// docs/15_Technical_Architecture.md §15.15 — every other layer talks to
/// [AuthRepository], never this class directly.
class FirebaseAuthRepository implements AuthRepository {
  /// Creates the repository from a Firebase Auth instance.
  FirebaseAuthRepository(this._auth);

  final fb.FirebaseAuth _auth;

  @override
  Stream<AuthUser?> authStateChanges() =>
      _auth.authStateChanges().map(_toDomain);

  @override
  AuthUser? get currentUser => _toDomain(_auth.currentUser);

  AuthUser? _toDomain(fb.User? user) {
    final phone = user?.phoneNumber;
    if (user == null || phone == null) return null;
    // Firebase Auth itself issued this number, so it's already valid
    // E.164 — the raw constructor is safe here (see PhoneNumber's doc
    // comment on when that's true).
    return AuthUser(uid: user.uid, phoneNumber: PhoneNumber(phone));
  }

  @override
  Future<Result<PhoneOtpSession>> sendOtp(
    PhoneNumber phoneNumber, {
    int? forceResendingToken,
  }) {
    final completer = Completer<Result<PhoneOtpSession>>();

    unawaited(
      _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber.value,
        forceResendingToken: forceResendingToken,
        verificationCompleted: (credential) async {
          // Android SMS auto-retrieval: sign-in completes before the
          // user types anything.
          try {
            await _auth.signInWithCredential(credential);
            if (!completer.isCompleted) {
              completer.complete(
                const Result.success(PhoneOtpSession.autoVerified()),
              );
            }
          } on fb.FirebaseAuthException catch (error) {
            if (!completer.isCompleted) {
              completer.complete(Result.failure(_mapException(error)));
            }
          }
        },
        verificationFailed: (error) {
          if (!completer.isCompleted) {
            completer.complete(Result.failure(_mapException(error)));
          }
        },
        codeSent: (verificationId, resendToken) {
          if (!completer.isCompleted) {
            completer.complete(
              Result.success(
                PhoneOtpSession.codeSent(
                  verificationId: verificationId,
                  resendToken: resendToken,
                ),
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (_) {
          // Expected to fire after codeSent in the normal case; not a
          // failure on its own.
        },
      ),
    );

    return completer.future;
  }

  @override
  Future<Result<AuthUser>> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = _toDomain(userCredential.user);
      if (user == null) {
        return const Result.failure(
          Failure.notFound('Sign-in did not return a user.'),
        );
      }
      return Result.success(user);
    } on fb.FirebaseAuthException catch (error) {
      return Result.failure(_mapException(error));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _auth.signOut();
      return const Result.success(null);
    } on Object catch (error) {
      return Result.failure(Failure.network(error.toString()));
    }
  }

  @override
  Future<Result<OrgAccess?>> currentOrgAccess({
    bool forceRefresh = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return const Result.success(null);
    try {
      final tokenResult = await user.getIdTokenResult(forceRefresh);
      return Result.success(_parseOrgAccess(tokenResult.claims?['orgAccess']));
    } on fb.FirebaseAuthException catch (error) {
      return Result.failure(_mapException(error));
    }
  }

  /// Parses the `orgAccess` claim map, ignoring any entry that isn't a
  /// well-formed `{role, branchId?}` shape rather than trusting it blindly
  /// — the same defensive parsing `shared/auth-context.ts`'s
  /// `isOrgAccessClaim` applies server-side. A signed-in user is assumed
  /// to operate within at most one Organization's context at a time (no
  /// org-switcher UI exists yet); when the claim carries more than one
  /// entry, an Owner grant takes precedence, matching the same
  /// owner-before-receptionist precedence the Firestore-derived resolution
  /// this replaces used to apply.
  OrgAccess? _parseOrgAccess(Object? rawClaim) {
    if (rawClaim is! Map) return null;

    OrgAccess? receptionistAccess;
    for (final entry in rawClaim.entries) {
      final organizationId = entry.key;
      final value = entry.value;
      if (organizationId is! String || value is! Map) continue;

      final role = value['role'];
      if (role == 'owner') {
        return OrgAccess(
          organizationId: OrganizationId(organizationId),
          role: UserRole.owner,
        );
      }
      if (role == 'receptionist' && value['branchId'] is String) {
        receptionistAccess ??= OrgAccess(
          organizationId: OrganizationId(organizationId),
          role: UserRole.receptionist,
          branchId: BranchId(value['branchId'] as String),
        );
      }
    }
    return receptionistAccess;
  }

  /// Maps a Firebase Auth error code onto the closed [Failure] hierarchy
  /// (docs/15_Technical_Architecture.md §15.17) — a `FirebaseAuthException`
  /// must never escape this class as itself.
  Failure _mapException(fb.FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-verification-code' ||
      'invalid-verification-id' ||
      'invalid-phone-number' ||
      'session-expired' => Failure.validation(error.message),
      'user-disabled' => Failure.permission(error.message),
      'too-many-requests' ||
      'network-request-failed' ||
      'quota-exceeded' => Failure.network(error.message),
      _ => Failure.network(error.message),
    };
  }
}
