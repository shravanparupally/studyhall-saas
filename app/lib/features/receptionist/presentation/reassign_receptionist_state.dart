import 'package:app/core/result/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reassign_receptionist_state.freezed.dart';

/// The "reassign Receptionist" screen's flow state.
@freezed
sealed class ReassignReceptionistState with _$ReassignReceptionistState {
  const factory ReassignReceptionistState({
    @Default(false) bool isSubmitting,
    Failure? error,
  }) = _ReassignReceptionistState;
}
