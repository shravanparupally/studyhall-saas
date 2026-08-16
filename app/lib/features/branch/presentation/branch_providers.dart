import 'package:app/core/firebase/firebase_providers.dart';
import 'package:app/features/branch/application/create_branch_use_case.dart';
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
