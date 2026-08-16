import 'package:app/core/result/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'create_first_branch_state.freezed.dart';

/// The "create first Branch" screen's flow state.
@freezed
sealed class CreateFirstBranchState with _$CreateFirstBranchState {
  const factory CreateFirstBranchState({
    @Default(false) bool isSubmitting,
    Failure? error,
  }) = _CreateFirstBranchState;
}
