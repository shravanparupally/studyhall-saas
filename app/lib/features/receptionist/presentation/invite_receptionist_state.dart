import 'package:app/core/result/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'invite_receptionist_state.freezed.dart';

/// The "invite Receptionist" screen's flow state.
@freezed
sealed class InviteReceptionistState with _$InviteReceptionistState {
  const factory InviteReceptionistState({
    @Default(false) bool isSubmitting,
    Failure? error,
  }) = _InviteReceptionistState;
}
