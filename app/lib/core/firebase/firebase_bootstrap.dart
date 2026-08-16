import 'package:app/core/logging/app_logger.dart';
import 'package:app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

/// Initializes Firebase for the current platform.
///
/// Per docs/08_System_Architecture.md §8.12, environment (dev/staging/prod)
/// is selected entirely by which Firebase project `firebase_options.dart`
/// was generated against — this function never branches on environment
/// itself. Until that file is generated (see its header), initialization
/// fails predictably; that failure is logged, not thrown, so a
/// not-yet-configured environment never crashes the app before any
/// Firebase-dependent feature exists to need it (per
/// docs/15_Technical_Architecture.md §15.11 — a caught failure must
/// still be visible, never silent).
Future<void> initializeFirebase(AppLogger logger) async {
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    await Firebase.initializeApp(options: options);
    logger.info('firebase.initialized');
  } on Object catch (error, stackTrace) {
    logger.error(
      'firebase.initialize_failed',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
