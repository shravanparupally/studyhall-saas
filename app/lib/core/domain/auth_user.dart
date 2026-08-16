import 'package:app/core/domain/phone_number.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';

/// The signed-in identity, as Firebase Auth knows it. Deliberately thin —
/// per docs/14_Domain_Model.md §14.4, the domain treats the underlying
/// `UserId` as an opaque reference and never models authentication
/// mechanics itself; this is just enough shape for the rest of the app
/// to know *who* is signed in.
@freezed
sealed class AuthUser with _$AuthUser {
  const factory AuthUser({
    required String uid,
    required PhoneNumber phoneNumber,
  }) = _AuthUser;
}
