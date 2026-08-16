import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

/// The exhaustive, closed set of failure kinds a use case may return,
/// per docs/15_Technical_Architecture.md §15.17. A new kind is a
/// deliberate addition here, never an ad hoc subclass added in a feature
/// branch. Raw infrastructure exceptions (`FirebaseException` and the
/// like) must be mapped to one of these at the repository boundary and
/// must never escape the Infrastructure layer as themselves.
@freezed
sealed class Failure with _$Failure {
  const factory Failure.network([String? message]) = NetworkFailure;
  const factory Failure.validation([String? message]) = ValidationFailure;
  const factory Failure.permission([String? message]) = PermissionFailure;
  const factory Failure.conflict([String? message]) = ConflictFailure;
  const factory Failure.notFound([String? message]) = NotFoundFailure;
}
