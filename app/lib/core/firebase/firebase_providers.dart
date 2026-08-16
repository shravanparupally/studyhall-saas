import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'firebase_providers.g.dart';

// The composition-root providers for the Firebase SDK singletons, per
// docs/15_Technical_Architecture.md §15.16 — every repository
// implementation depends on these rather than reading
// `FirebaseAuth.instance`/`FirebaseFirestore.instance`/
// `FirebaseFunctions.instance` directly, so tests can override them with
// fakes.

/// The [FirebaseAuth] singleton for the current platform.
@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;

/// The [FirebaseFirestore] singleton for the current platform.
@Riverpod(keepAlive: true)
FirebaseFirestore firestore(Ref ref) => FirebaseFirestore.instance;

/// The [FirebaseFunctions] singleton for the current platform.
@Riverpod(keepAlive: true)
FirebaseFunctions firebaseFunctions(Ref ref) => FirebaseFunctions.instance;
