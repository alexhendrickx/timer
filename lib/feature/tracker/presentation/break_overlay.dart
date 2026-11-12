import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

/// A full-screen, gentle "Time to stand" nudge shown while a timer is
/// running. Easily dismissed by a tap or a swipe in any direction — it never
/// blocks the app, it just reminds.
class BreakOverlay extends StatelessWidget {
  const BreakOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: GestureDetector(
        onTap: () => context.pop(),
        onVerticalDragEnd: (_) => context.pop(),
        onHorizontalDragEnd: (_) => context.pop(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.self_improvement,
                  size: 72,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 24),
                Text(
                  'Time to stand',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'You have been tracking for a while — take a short break.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                Text(
                  'Tap or swipe to dismiss',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
