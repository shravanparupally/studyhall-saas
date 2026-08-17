import 'package:app/core/domain/ids.dart';
import 'package:app/core/result/failure.dart';
import 'package:app/core/result/result.dart';
import 'package:app/core/session/domain/org_access.dart';
import 'package:app/core/session/domain/session_state.dart';
import 'package:app/core/session/presentation/session_notifier.dart';
import 'package:app/features/receptionist/presentation/invite_receptionist_state.dart';
import 'package:app/features/receptionist/presentation/receptionist_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'invite_receptionist_notifier.g.dart';

/// Drives the "invite Receptionist" screen.
@riverpod
class InviteReceptionistNotifier extends _$InviteReceptionistNotifier {
  @override
  InviteReceptionistState build() => const InviteReceptionistState();

  /// Validates the form fields and invites the Receptionist to [branchId].
  /// Returns `true` on success.
  Future<bool> submit({
    required BranchId branchId,
    required String name,
    required String phoneNumber,
  }) async {
    final session = ref.read(sessionProvider).value;
    if (session is! SessionReady || session.orgAccess.role != UserRole.owner) {
      state = state.copyWith(
        error: const Failure.permission(
          'Only an Owner can invite a Receptionist.',
        ),
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, error: null);
    final result = await ref.read(inviteReceptionistUseCaseProvider)(
      organizationId: session.orgAccess.organizationId,
      branchId: branchId,
      name: name,
      rawPhoneNumber: phoneNumber,
      invitedBy: session.user.uid,
    );

    return result.when(
      success: (_) {
        state = state.copyWith(isSubmitting: false);
        return true;
      },
      failure: (failure) {
        state = state.copyWith(isSubmitting: false, error: failure);
        return false;
      },
    );
  }
}
