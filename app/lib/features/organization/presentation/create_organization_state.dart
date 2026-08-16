import 'package:app/core/result/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'create_organization_state.freezed.dart';

/// The "create Organization" screen's flow state.
@freezed
sealed class CreateOrganizationState with _$CreateOrganizationState {
  const factory CreateOrganizationState({
    @Default(false) bool isSubmitting,
    Failure? error,
  }) = _CreateOrganizationState;
}
