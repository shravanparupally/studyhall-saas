import 'package:app/core/firebase/firebase_providers.dart';
import 'package:app/core/session/domain/auth_repository.dart';
import 'package:app/core/session/infrastructure/firebase_auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_providers.g.dart';

/// The composition-root binding for [AuthRepository] — the one place its
/// Firebase implementation is provided, per
/// docs/15_Technical_Architecture.md §15.16.
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    FirebaseAuthRepository(ref.watch(firebaseAuthProvider));
