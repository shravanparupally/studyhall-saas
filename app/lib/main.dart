import 'package:app/app.dart';
import 'package:app/core/firebase/firebase_bootstrap.dart';
import 'package:app/core/logging/app_logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A ProviderContainer is created explicitly (rather than letting
  // ProviderScope create one implicitly) so bootstrap steps that need a
  // dependency — here, the logger — resolve it through the same DI
  // mechanism the rest of the app uses, per
  // docs/15_Technical_Architecture.md §15.16. UncontrolledProviderScope
  // hands this exact container to the widget tree below instead of
  // creating a second one.
  final container = ProviderContainer();
  await initializeFirebase(container.read(appLoggerProvider));

  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
