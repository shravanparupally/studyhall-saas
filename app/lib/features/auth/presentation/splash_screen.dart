import 'package:app/core/session/presentation/session_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shown while [SessionNotifier] resolves whether anyone is signed in
/// and, if so, where they stand — the "Splash Authentication Check".
/// Navigation itself happens via the GoRouter redirect guard watching
/// the same provider; this screen only renders the loading/error state.
class SplashScreen extends ConsumerWidget {
  /// Creates the Splash screen.
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: Center(
        child: session.when(
          data: (_) => const CircularProgressIndicator(),
          loading: () => const CircularProgressIndicator(),
          error: (error, stackTrace) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Couldn't check your sign-in status."),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(sessionProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
