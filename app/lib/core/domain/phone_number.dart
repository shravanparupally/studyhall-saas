import 'package:app/core/result/failure.dart';
import 'package:app/core/result/result.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'phone_number.freezed.dart';

/// An E.164-formatted phone number — the identity anchor for every
/// human-associated entity (Owner, Receptionist, Student), per
/// docs/14_Domain_Model.md §14.4.
///
/// Only [PhoneNumber.parse] validates untrusted input (e.g. a login
/// form). The bare `PhoneNumber(value)` constructor is for call sites
/// that already hold a trusted, pre-validated value — for example a
/// phone number Firebase Auth itself issued — and must never be used on
/// raw user input.
@freezed
sealed class PhoneNumber with _$PhoneNumber {
  const factory PhoneNumber(String value) = _PhoneNumber;

  /// Matches E.164: a leading `+`, then 8-15 digits, first digit 1-9.
  static final _e164 = RegExp(r'^\+[1-9]\d{7,14}$');

  /// Validates [raw] as E.164 and constructs a [PhoneNumber], or returns
  /// a [ValidationFailure] describing what's wrong.
  static Result<PhoneNumber> parse(String raw) {
    final trimmed = raw.trim();
    if (!_e164.hasMatch(trimmed)) {
      return const Result.failure(
        Failure.validation(
          'Enter a valid phone number, including country code.',
        ),
      );
    }
    return Result.success(PhoneNumber(trimmed));
  }
}
