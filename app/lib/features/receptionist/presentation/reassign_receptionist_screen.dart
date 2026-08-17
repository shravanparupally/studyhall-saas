import 'package:app/core/domain/ids.dart';
import 'package:app/core/result/failure.dart';
import 'package:app/core/session/domain/session_state.dart';
import 'package:app/core/session/presentation/session_notifier.dart';
import 'package:app/features/branch/domain/branch.dart';
import 'package:app/features/branch/presentation/branch_providers.dart';
import 'package:app/features/receptionist/presentation/reassign_receptionist_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owner-only: move an existing Receptionist to a different Branch within
/// the same Organization (BR-23's revoke-old/create-new model). The
/// person is identified by name/phone — the same fields Invite collects —
/// since there is no roster screen yet to pick an existing Receptionist
/// from directly.
class ReassignReceptionistScreen extends ConsumerStatefulWidget {
  /// Creates the "reassign Receptionist" screen.
  const ReassignReceptionistScreen({super.key});

  @override
  ConsumerState<ReassignReceptionistScreen> createState() =>
      _ReassignReceptionistScreenState();
}

class _ReassignReceptionistScreenState
    extends ConsumerState<ReassignReceptionistScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  BranchId? _selectedBranchId;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final branchId = _selectedBranchId;
    if (!(_formKey.currentState?.validate() ?? false) || branchId == null) {
      return;
    }
    final succeeded = await ref
        .read(reassignReceptionistProvider.notifier)
        .submit(
          name: _nameController.text,
          phoneNumber: _phoneController.text,
          toBranchId: branchId,
        );
    if (succeeded && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final formState = ref.watch(reassignReceptionistProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reassign receptionist')),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text("Couldn't load your session.")),
        data: (state) {
          if (state is! SessionReady) {
            return const Center(child: CircularProgressIndicator());
          }
          final branches = ref.watch(
            branchesForOrganizationProvider(state.orgAccess.organizationId),
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Receptionist's name",
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  branches.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) =>
                        const Text("Couldn't load branches."),
                    data: (branchList) => DropdownButtonFormField<BranchId>(
                      initialValue: _selectedBranchId,
                      decoration: const InputDecoration(
                        labelText: 'Move to Branch',
                      ),
                      items: [
                        for (final Branch branch in branchList)
                          DropdownMenuItem(
                            value: branch.id,
                            child: Text(branch.name),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedBranchId = value),
                      validator: (value) => value == null ? 'Required' : null,
                    ),
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
                        : const Text('Reassign'),
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
