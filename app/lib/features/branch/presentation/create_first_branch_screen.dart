import 'package:app/core/result/failure.dart';
import 'package:app/core/session/domain/session_state.dart';
import 'package:app/core/session/presentation/session_notifier.dart';
import 'package:app/features/branch/presentation/create_first_branch_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sprint 1's onboarding step 2: create the first Branch, per
/// docs/04_User_Flows.md §4.1.
class CreateFirstBranchScreen extends ConsumerStatefulWidget {
  /// Creates the "create first Branch" screen.
  const CreateFirstBranchScreen({super.key});

  @override
  ConsumerState<CreateFirstBranchScreen> createState() =>
      _CreateFirstBranchScreenState();
}

class _CreateFirstBranchScreenState
    extends ConsumerState<CreateFirstBranchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _mapsUrlController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _mapsUrlController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(createFirstBranchProvider.notifier)
        .submit(
          name: _nameController.text,
          city: _cityController.text,
          address: _addressController.text,
          googleMapsUrl: _mapsUrlController.text,
          contactPhone: _contactPhoneController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final formState = ref.watch(createFirstBranchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create your first branch')),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text("Couldn't load your session.")),
        data: (state) {
          if (state is! SessionNeedsBranch) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Branch name'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'City'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                    maxLines: 2,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _mapsUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Google Maps link (optional)',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Contact number',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Required'
                        : null,
                  ),
                  if (formState.error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      formState.error!.when(
                        network: (message) =>
                            message ?? 'Something went wrong. Try again.',
                        validation: (message) =>
                            message ?? 'Check the form and try again.',
                        permission: (message) =>
                            message ?? "You don't have access to do that.",
                        conflict: (message) =>
                            message ?? 'That already exists.',
                        notFound: (message) => message ?? "That wasn't found.",
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: formState.isSubmitting ? null : _submit,
                    child: formState.isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create branch'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
