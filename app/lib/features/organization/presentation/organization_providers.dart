import 'package:app/core/firebase/firebase_providers.dart';
import 'package:app/features/organization/application/create_organization_use_case.dart';
import 'package:app/features/organization/domain/organization_repository.dart';
import 'package:app/features/organization/infrastructure/firestore_organization_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'organization_providers.g.dart';

/// The composition-root binding for [OrganizationRepository] — the one
/// place its Firestore implementation is provided, per
/// docs/15_Technical_Architecture.md §15.16.
@Riverpod(keepAlive: true)
OrganizationRepository organizationRepository(Ref ref) =>
    FirestoreOrganizationRepository(ref.watch(firestoreProvider));

/// The composition-root binding for [CreateOrganizationUseCase].
@riverpod
CreateOrganizationUseCase createOrganizationUseCase(Ref ref) =>
    CreateOrganizationUseCase(ref.watch(organizationRepositoryProvider));
