import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shown for any unmatched route. Per docs/15_Technical_Architecture.md
/// §15.5, a bad deep link or guard failure must always resolve to a
/// dedicated, consistently-styled screen — never a blank page or a crash.
class RouteNotFoundScreen extends StatelessWidget {
  /// Creates the not-found fallback screen.
  const RouteNotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Page not found'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    );
  }
}
