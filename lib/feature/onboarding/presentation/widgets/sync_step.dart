import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../sync/presentation/widgets/sign_in_buttons.dart';
import '../../../sync/service/auth_service.dart';

/// Step 2: optional sign-in. Shown only when sync is configured.
class SyncStep extends StatelessWidget {
  const SyncStep({super.key, required this.auth, required this.onNext});

  final AuthService auth;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Scrolls, so the short Mac window never overflows.
        Expanded(
          child: ListView(
            children: [
              Text(
                'Same timer on all your devices',
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Start on your iPhone, stop on your Mac. '
                'Sign in with the same account on both.',
                style: textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              const _Reassurance(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SignInButtons(auth: auth, onSignedIn: onNext),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: onNext,
          child: const Text('Not now, keep it on this device'),
        ),
      ],
    );
  }
}

class _Reassurance extends StatelessWidget {
  const _Reassurance();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          _Point(
            icon: Icons.lock_outline,
            text: 'Your data stays on this device first. '
                'Sync only copies it to your own account.',
          ),
          SizedBox(height: 16),
          _Point(
            icon: Icons.cloud_off_outlined,
            text: 'Works offline. '
                'Changes catch up when you are back online.',
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
