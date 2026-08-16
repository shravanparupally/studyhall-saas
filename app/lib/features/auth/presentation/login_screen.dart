import 'dart:async';

import 'package:app/core/result/failure.dart';
import 'package:app/features/auth/presentation/login_notifier.dart';
import 'package:app/features/auth/presentation/login_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phone-OTP sign-in, per docs/04_User_Flows.md §4.1's first step and
/// docs/15_Technical_Architecture.md §15.6.
class LoginScreen extends ConsumerStatefulWidget {
  /// Creates the Login screen.
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginProvider);
    final notifier = ref.read(loginProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: switch (state) {
          LoginEnteringPhone() => _PhoneForm(
            controller: _phoneController,
            state: state,
            onSubmit: () => notifier.sendOtp(_phoneController.text),
          ),
          LoginOtpSent() => _OtpForm(
            controller: _otpController,
            state: state,
            onVerify: () => notifier.verifyOtp(_otpController.text),
            onResend: notifier.resendOtp,
          ),
        },
      ),
    );
  }
}

class _PhoneForm extends StatelessWidget {
  const _PhoneForm({
    required this.controller,
    required this.state,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final LoginEnteringPhone state;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          enabled: !state.isSubmitting,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '+91XXXXXXXXXX',
          ),
        ),
        if (state.error != null) ...[
          const SizedBox(height: 8),
          Text(
            state.error!.when(
              network: (message) =>
                  message ?? 'Something went wrong. Try again.',
              validation: (message) => message ?? 'Enter a valid phone number.',
              permission: (message) =>
                  message ?? "You don't have access to do that.",
              conflict: (message) => message ?? 'That already exists.',
              notFound: (message) => message ?? "That wasn't found.",
            ),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: state.isSubmitting ? null : onSubmit,
          child: state.isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send OTP'),
        ),
      ],
    );
  }
}

class _OtpForm extends StatelessWidget {
  const _OtpForm({
    required this.controller,
    required this.state,
    required this.onVerify,
    required this.onResend,
  });

  final TextEditingController controller;
  final LoginOtpSent state;
  final VoidCallback onVerify;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enter the code sent to ${state.phoneNumber.value}'),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          enabled: !state.isSubmitting,
          decoration: const InputDecoration(labelText: 'OTP code'),
        ),
        if (state.error != null) ...[
          const SizedBox(height: 8),
          Text(
            state.error!.when(
              network: (message) =>
                  message ?? 'Something went wrong. Try again.',
              validation: (message) =>
                  message ?? "That code doesn't look right.",
              permission: (message) =>
                  message ?? "You don't have access to do that.",
              conflict: (message) => message ?? 'That already exists.',
              notFound: (message) => message ?? "That wasn't found.",
            ),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: state.isSubmitting ? null : onVerify,
          child: state.isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verify'),
        ),
        const SizedBox(height: 8),
        _ResendButton(
          resendAvailableAt: state.resendAvailableAt,
          enabled: !state.isSubmitting,
          onResend: onResend,
        ),
      ],
    );
  }
}

/// The OTP resend cooldown countdown — Tier 1 ephemeral UI state per
/// docs/15_Technical_Architecture.md §15.29: purely local, never
/// promoted to a provider, since nothing outside this widget needs to
/// know "how many seconds are left."
class _ResendButton extends StatefulWidget {
  const _ResendButton({
    required this.resendAvailableAt,
    required this.enabled,
    required this.onResend,
  });

  final DateTime resendAvailableAt;
  final bool enabled;
  final VoidCallback onResend;

  @override
  State<_ResendButton> createState() => _ResendButtonState();
}

class _ResendButtonState extends State<_ResendButton> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.resendAvailableAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return TextButton(
        onPressed: widget.enabled ? widget.onResend : null,
        child: const Text('Resend code'),
      );
    }
    return Text(
      'Resend code in ${remaining.inSeconds + 1}s',
      textAlign: TextAlign.center,
    );
  }
}
