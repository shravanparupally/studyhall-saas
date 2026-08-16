import 'package:app/core/result/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'result.freezed.dart';

/// Every Application-layer use case and repository returns `Result<T>`
/// instead of throwing, per docs/15_Technical_Architecture.md §15.17 —
/// the failure branch always carries the closed [Failure] hierarchy, never
/// a per-call-site error type, so callers can exhaustively `switch` on it.
@freezed
sealed class Result<T> with _$Result<T> {
  const factory Result.success(T value) = ResultSuccess<T>;
  const factory Result.failure(Failure failure) = ResultFailure<T>;
}
