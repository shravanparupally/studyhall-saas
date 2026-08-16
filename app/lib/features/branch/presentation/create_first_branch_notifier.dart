import 'package:app/core/result/failure.dart';
import 'package:app/core/result/result.dart';
import 'package:app/core/session/domain/session_state.dart';
import 'package:app/core/session/presentation/session_notifier.dart';
import 'package:app/features/branch/presentation/branch_providers.dart';
import 'package:app/features/branch/presentation/create_first_branch_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_first_branch_notifier.g.dart';

/// Drives the "create first Branch" onboarding step.
@riverpod
class CreateFirstBranchNotifier extends _$CreateFirstBranchNotifier {
  @override
  CreateFirstBranchState build() => const CreateFirstBranchState();

  /// Validates the form fields and creates the Branch.
  Future<bool> submit({
    required String name,
    required String city,
    required String address,
    required String contactPhone,
    String? googleMapsUrl,
  }) async {
    final session = ref.read(sessionProvider).value;
    if (session is! SessionNeedsBranch) {
      state = state.copyWith(
        error: const Failure.permission(
          'You must create an organization first.',
        ),
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, error: null);
    final result = await ref.read(createBranchUseCaseProvider)(
      organizationId: session.orgAccess.organizationId,
      name: name,
      city: city,
      address: address,
      googleMapsUrl: googleMapsUrl,
      contactPhone: contactPhone,
    );

    return result.when(
      success: (_) {
        state = state.copyWith(isSubmitting: false);
        ref.invalidate(sessionProvider);
        return true;
      },
      failure: (failure) {
        state = state.copyWith(isSubmitting: false, error: failure);
        return false;
      },
    );
  }
}
