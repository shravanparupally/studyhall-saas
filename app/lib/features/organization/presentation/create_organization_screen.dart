import 'package:app/core/result/failure.dart';
import 'package:app/core/session/domain/session_state.dart';
import 'package:app/core/session/presentation/session_notifier.dart';
import 'package:app/features/organization/domain/organization.dart';
import 'package:app/features/organization/presentation/create_organization_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sprint 1's onboarding step 1: create the Organization and its
/// founding Owner, per docs/04_User_Flows.md §4.1.
///
/// `timezone`/`currency` are offered as selectable fields (not a
/// hardcoded constant) so the mechanism supports more values later, but
/// India-only launch (docs/02_Product_Requirements_Document.md §2.7)
/// means exactly one option exists in each today.
class CreateOrganizationScreen extends ConsumerStatefulWidget {
  /// Creates the "create Organization" screen.
  const CreateOrganizationScreen({super.key});

  @override
  ConsumerState<CreateOrganizationScreen> createState() =>
      _CreateOrganizationScreenState();
}

class _CreateOrganizationScreenState
    extends ConsumerState<CreateOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _organizationNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstController = TextEditingController();
  final _addressController = TextEditingController();
  String _timezone = 'Asia/Kolkata';
  Currency _currency = Currency.inr;

  @override
  void dispose() {
    _organizationNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _gstController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(createOrganizationProvider.notifier)
        .submit(
          organizationName: _organizationNameController.text,
          gstNumber: _gstController.text,
          address: _addressController.text,
          timezone: _timezone,
          currency: _currency,
          ownerName: _ownerNameController.text,
          ownerEmail: _emailController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final formState = ref.watch(createOrganizationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create your organization')),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text("Couldn't load your session.")),
        data: (state) {
          if (state is! SessionNeedsOrganization) {
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
                    controller: _organizationNameController,
                    decoration: const InputDecoration(
                      labelText: 'Organization name',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ownerNameController,
                    decoration: const InputDecoration(labelText: 'Owner name'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: state.user.phoneNumber.value,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                    ),
                    enabled: false,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _gstController,
                    decoration: const InputDecoration(
                      labelText: 'GST number (optional)',
                    ),
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
                  DropdownButtonFormField<String>(
                    initialValue: _timezone,
                    decoration: const InputDecoration(labelText: 'Timezone'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Asia/Kolkata',
                        child: Text('Asia/Kolkata'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _timezone = value ?? _timezone),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Currency>(
                    initialValue: _currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: const [
                      DropdownMenuItem(
                        value: Currency.inr,
                        child: Text('INR (₹)'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _currency = value ?? _currency),
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
                        : const Text('Create organization'),
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
