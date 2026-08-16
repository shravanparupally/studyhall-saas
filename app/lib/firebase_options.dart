import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// A placeholder for the output of the FlutterFire CLI.
///
/// Run `flutterfire configure` against a real Firebase project (dev,
/// staging, or prod — see docs/08_System_Architecture.md §8.12) to
/// replace this file with the generated `DefaultFirebaseOptions`. The
/// CLI always writes to this exact path, so nothing else in the app
/// needs to change when that happens — see
/// `core/firebase/firebase_bootstrap.dart`, the only place this is
/// imported.
///
/// This stub intentionally defines no platform options and no API keys —
/// per docs/15_Technical_Architecture.md §15.3/§15.26, Firebase
/// configuration is never hardcoded in source.
final class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  /// Throws until `flutterfire configure` replaces this file.
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'DefaultFirebaseOptions.currentPlatform has not been configured yet. '
      'Run `flutterfire configure` to generate real per-platform Firebase '
      'options for this environment.',
    );
  }
}
