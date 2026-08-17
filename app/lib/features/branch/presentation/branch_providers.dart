import 'package:app/core/domain/ids.dart';
import 'package:app/core/firebase/firebase_providers.dart';
import 'package:app/core/result/result.dart';
import 'package:app/features/branch/application/create_branch_use_case.dart';
import 'package:app/features/branch/domain/branch.dart';
import 'package:app/features/branch/domain/branch_repository.dart';
import 'package:app/features/branch/infrastructure/firestore_branch_repository.dart';
import 'package:app/features/organization/presentation/organization_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'branch_providers.g.dart';

/// The composition-root binding for [BranchRepository] — the one place
/// its Firestore implementation is provided, per
/// docs/15_Technical_Architecture.md §15.16.
@Riverpod(keepAlive: true)
BranchRepository branchRepository(Ref ref) =>
    FirestoreBranchRepository(ref.watch(firestoreProvider));

/// The composition-root binding for [CreateBranchUseCase].
@riverpod
CreateBranchUseCase createBranchUseCase(Ref ref) => CreateBranchUseCase(
  ref.watch(branchRepositoryProvider),
  ref.watch(organizationRepositoryProvider),
);

/// Every Branch under [organizationId] — backs the Branch picker on the
/// Invite/Reassign Receptionist screens. `autoDispose` (the `@riverpod`
/// default): this list is a screen-scoped read, not shared session state,
/// per docs/15_Technical_Architecture.md §15.29.
@riverpod
Future<List<Branch>> branchesForOrganization(
  Ref ref,
  OrganizationId organizationId,
) async {
  final result = await ref
      .watch(branchRepositoryProvider)
      .listBranches(organizationId);
  return result.when(
    success: (branches) => branches,
    // Mirrors SessionNotifier's same throw-to-propagate-as-AsyncError
    // pattern for turning a Result failure into this FutureProvider's
    // AsyncValue.error, since Failure itself deliberately doesn't extend
    // Exception/Error (it's a Result-only, never-thrown type elsewhere).
    failure: (failure) => throw StateError(failure.toString()),
  );
}
