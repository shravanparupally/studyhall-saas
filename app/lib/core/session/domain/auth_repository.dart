import 'package:app/core/domain/auth_user.dart';
import 'package:app/core/domain/phone_number.dart';
import 'package:app/core/domain/phone_otp_session.dart';
import 'package:app/core/result/result.dart';
import 'package:app/core/session/domain/org_access.dart';

/// The authentication contract every other layer depends on, per
/// docs/15_Technical_Architecture.md §15.15 — no widget or Notifier ever
/// talks to `firebase_auth` directly (§15.7's Firestore rule, applied
/// identically to Auth).
///
/// This interface is phone-OTP-shaped today because phone OTP is the
/// only approved sign-in method (docs/15_Technical_Architecture.md
/// §15.6). Adding a future provider (email, Google, Apple) means adding
/// new methods here — e.g. `signInWithGoogle()` — never changing or
/// removing what already exists, so nothing above this interface needs
/// to change shape when that happens.
abstract class AuthRepository {
  /// Emits the signed-in [AuthUser], or `null` when signed out —
  /// including the current value on subscription. Firebase Auth persists
  /// this across app restarts natively; no separate token storage is
  /// implemented here.
  Stream<AuthUser?> authStateChanges();

  /// The signed-in user, if any, without waiting for a stream event.
  AuthUser? get currentUser;

  /// Requests an OTP be sent to [phoneNumber]. See [PhoneOtpSession] for
  /// the two possible real outcomes.
  ///
  /// Pass [forceResendingToken] (from a prior [PhoneOtpCodeSent]) when
  /// this is a user-initiated resend, so Firebase treats it as a resend
  /// of the same request rather than an unrelated new one.
  Future<Result<PhoneOtpSession>> sendOtp(
    PhoneNumber phoneNumber, {
    int? forceResendingToken,
  });

  /// Completes sign-in using the code the user received for
  /// [verificationId].
  Future<Result<AuthUser>> verifyOtp({
    required String verificationId,
    required String smsCode,
  });

  /// Signs the current user out.
  Future<Result<void>> signOut();

  /// The signed-in user's `orgAccess` custom claim, resolved from the
  /// verified Firebase ID token — the **authoritative** source for
  /// [OrgAccess], per docs/07_Firestore_Schema.md §7.4: an Owner claim
  /// carries no `branchId` (org-wide access to every Branch); a
  /// Receptionist claim carries exactly the one Branch they're assigned
  /// to. Returns `Result.success(null)` (never a thrown error, and never a
  /// granted default) when no user is signed in, the token carries no
  /// `orgAccess` entry, or the entry is malformed — every one of those
  /// cases fails closed to "no access" exactly like a missing grant does.
  ///
  /// Custom claims are issued asynchronously by a Cloud Function trigger
  /// (`backend/src/features/org-access/`) reacting to an
  /// Owner/Receptionist grant write — they are never visible on the
  /// client until the ID token is refreshed, and forgetting this step is a
  /// named common mistake in docs/15_Technical_Architecture.md §15.6. Pass
  /// [forceRefresh] to force that refresh (e.g. right after this user's
  /// own grant was just created) rather than reading the token's current,
  /// possibly stale, cached claims.
  Future<Result<OrgAccess?>> currentOrgAccess({bool forceRefresh = false});
}
