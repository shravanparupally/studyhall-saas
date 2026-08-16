import 'package:app/core/domain/ids.dart';
import 'package:app/core/result/failure.dart';
import 'package:app/core/result/result.dart';
import 'package:app/core/session/domain/session_state.dart';
import 'package:app/core/session/presentation/session_notifier.dart';
import 'package:app/core/session/presentation/session_providers.dart';
import 'package:app/features/organization/domain/organization.dart';
import 'package:app/features/organization/presentation/create_organization_state.dart';
import 'package:app/features/organization/presentation/organization_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_organization_notifier.g.dart';

/// Bounded best-effort wait for the `orgAccess` custom claim to propagate
/// after Organization creation, per docs/15_Technical_Architecture.md
/// §15.6. The claim is issued asynchronously by a Cloud Function trigger,
/// so it may not be visible yet on the very next write (the first Branch
/// creation) — this narrows that race without blocking onboarding
/// indefinitely if the trigger is slow, not yet deployed, or the device is
/// offline: if the wait times out, submission still succeeds, and a
/// subsequent write that still lacks the claim surfaces a clear
/// [Failure.permission] the user can retry, rather than the UI hanging.
const _claimPropagationAttempts = 5;
const _claimPropagationDelay = Duration(milliseconds: 400);

/// Drives the "create Organization" onboarding step.
@riverpod
class CreateOrganizationNotifier extends _$CreateOrganizationNotifier {
  @override
  CreateOrganizationState build() => const CreateOrganizationState();

  /// Validates the form fields and creates the Organization and its
  /// founding Owner.
  Future<bool> submit({
    required String organizationName,
    required String address,
    required String timezone,
    required Currency currency,
    required String ownerName,
    String? gstNumber,
    String? ownerEmail,
  }) async {
    final session = ref.read(sessionProvider).value;
    if (session is! SessionNeedsOrganization) {
      state = state.copyWith(
        error: const Failure.permission(
          'You must be signed in to create an organization.',
        ),
      );
      return false;
    }
    final user = session.user;

    state = state.copyWith(isSubmitting: true, error: null);
    final result = await ref.read(createOrganizationUseCaseProvider)(
      organizationName: organizationName,
      gstNumber: gstNumber,
      address: address,
      timezone: timezone,
      currency: currency,
      ownerName: ownerName,
      userId: user.uid,
      ownerPhoneNumber: user.phoneNumber,
      ownerEmail: ownerEmail,
    );

    return result.when(
      success: (organization) async {
        await _waitForOrgAccessClaim(organization.id);
        state = state.copyWith(isSubmitting: false);
        // SessionNotifier re-resolves lazily; force it now so the router
        // guard advances immediately instead of waiting for the next
        // unrelated auth-state event.
        ref.invalidate(sessionProvider);
        return true;
      },
      failure: (failure) async {
        state = state.copyWith(isSubmitting: false, error: failure);
        return false;
      },
    );
  }

  Future<void> _waitForOrgAccessClaim(OrganizationId organizationId) async {
    final authRepository = ref.read(authRepositoryProvider);
    for (var attempt = 0; attempt < _claimPropagationAttempts; attempt++) {
      final result = await authRepository.hasOrgAccessAfterRefresh(
        organizationId,
      );
      final hasClaim = result.when(
        success: (value) => value,
        failure: (_) => false,
      );
      if (hasClaim) return;
      await Future<void>.delayed(_claimPropagationDelay);
    }
  }
}
