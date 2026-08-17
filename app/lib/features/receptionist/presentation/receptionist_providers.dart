import 'package:app/core/firebase/firebase_providers.dart';
import 'package:app/features/receptionist/application/invite_receptionist_use_case.dart';
import 'package:app/features/receptionist/application/reassign_receptionist_use_case.dart';
import 'package:app/features/receptionist/domain/receptionist_repository.dart';
import 'package:app/features/receptionist/infrastructure/firestore_receptionist_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'receptionist_providers.g.dart';

/// The composition-root binding for [ReceptionistRepository] — the one
/// place its Firestore/Cloud-Functions implementation is provided, per
/// docs/15_Technical_Architecture.md §15.16.
@Riverpod(keepAlive: true)
ReceptionistRepository receptionistRepository(Ref ref) =>
    FirestoreReceptionistRepository(
      ref.watch(firestoreProvider),
      ref.watch(firebaseFunctionsProvider),
    );

/// The composition-root binding for [InviteReceptionistUseCase].
@riverpod
InviteReceptionistUseCase inviteReceptionistUseCase(Ref ref) =>
    InviteReceptionistUseCase(ref.watch(receptionistRepositoryProvider));

/// The composition-root binding for [ReassignReceptionistUseCase].
@riverpod
ReassignReceptionistUseCase reassignReceptionistUseCase(Ref ref) =>
    ReassignReceptionistUseCase(ref.watch(receptionistRepositoryProvider));
