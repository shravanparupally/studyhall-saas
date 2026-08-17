import 'package:app/core/domain/ids.dart';
import 'package:app/core/result/failure.dart';
import 'package:app/core/result/result.dart';
import 'package:app/core/session/domain/org_access.dart';
import 'package:app/core/session/domain/session_state.dart';
import 'package:app/core/session/presentation/session_notifier.dart';
import 'package:app/features/receptionist/presentation/reassign_receptionist_state.dart';
import 'package:app/features/receptionist/presentation/receptionist_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reassign_receptionist_notifier.g.dart';

/// Drives the "reassign Receptionist" screen.
@riverpod
class ReassignReceptionistNotifier extends _$ReassignReceptionistNotifier {
  @override
  ReassignReceptionistState build() => const ReassignReceptionistState();

  /// Validates the form fields and reassigns the Receptionist identified
  /// by [name]/[phoneNumber] to [toBranchId]. Returns `true` on success.
  Future<bool> submit({
    required String name,
    required String phoneNumber,
    required BranchId toBranchId,
  }) async {
    final session = ref.read(sessionProvider).value;
    if (session is! SessionReady || session.orgAccess.role != UserRole.owner) {
      state = state.copyWith(
        error: const Failure.permission(
          'Only an Owner can reassign a Receptionist.',
        ),
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, error: null);
    final result = await ref.read(reassignReceptionistUseCaseProvider)(
      organizationId: session.orgAccess.organizationId,
      name: name,
      rawPhoneNumber: phoneNumber,
      toBranchId: toBranchId,
      reassignedBy: session.user.uid,
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
