import 'package:app/core/result/result.dart';
import 'package:app/features/auth/presentation/auth_providers.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The signed-in landing screen. No business logic yet — every real
/// feature screen (seat map, dues, etc.) lands under its own
/// `features/<name>/` module per docs/15_Technical_Architecture.md
/// §15.20, not here. Sign-out lives here because Sprint 1 has no other
/// screen to host it on yet.
class HomeScreen extends ConsumerWidget {
  /// Creates the Home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _signOut(context, ref),
          ),
        ],
      ),
      body: Center(child: Text(l10n.homeWelcomeMessage)),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(signOutUseCaseProvider)();
    if (!context.mounted) return;
    result.when(
      success: (_) {},
      failure: (_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(content: Text("Couldn't sign out. Try again.")),
        );
      },
    );
  }
}
