import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

/// Placeholder home for v0.1.0 — the live timer and activity picker arrive in
/// v0.2.0. For now it shows an empty state and a way into Settings.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined,
                size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No timer yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Activities and start/stop arrive in v0.2.0.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.settings),
              label: const Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
