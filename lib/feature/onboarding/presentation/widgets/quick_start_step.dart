import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

const String _hotkey = '⌘ ⇧ Space';

/// Step 3: how to start without opening the app first. Static guidance
/// only; nothing here calls a system API.
class QuickStartStep extends StatelessWidget {
  const QuickStartStep({
    super.key,
    required this.hasMenuBar,
    required this.onDone,
  });

  /// True on Mac (hotkey + menu bar), false on iPhone.
  final bool hasMenuBar;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          hasMenuBar ? 'Start with one shortcut' : 'Start in one tap',
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: hasMenuBar ? _mac(textTheme) : _iphone(textTheme),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
          onPressed: onDone,
          child: const Text('Done'),
        ),
      ],
    );
  }

  List<Widget> _mac(TextTheme textTheme) {
    return [
      const SizedBox(height: 24),
      Text(
        _hotkey,
        textAlign: TextAlign.center,
        style: textTheme.displaySmall,
      ),
      const SizedBox(height: 16),
      Text(
        'Press it anywhere to pick an activity and start. '
        'Timer also lives in the menu bar.',
        textAlign: TextAlign.center,
        style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    ];
  }

  List<Widget> _iphone(TextTheme textTheme) {
    return [
      Text(
        'Add the ones you want. You can do it later too.',
        style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      const _MethodCard(
        icon: Icons.smart_button,
        title: 'Action button',
        subtitle: 'Settings > Action Button > Shortcut > Start Tracking.',
      ),
      const SizedBox(height: 10),
      const _MethodCard(
        icon: Icons.widgets_outlined,
        title: 'Lock Screen widget',
        subtitle: 'Touch and hold the Lock Screen, tap Customize, '
            'then add Timer Quick Start.',
      ),
      const SizedBox(height: 10),
      const _MethodCard(
        icon: Icons.mic_none,
        title: 'Siri',
        subtitle: 'Say "Start tracking in Timer".',
      ),
      const SizedBox(height: 10),
      const _MacHint(),
    ];
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The iPhone page also names the Mac hotkey, for users who have both.
class _MacHint extends StatelessWidget {
  const _MacHint();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'On your Mac',
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Text(_hotkey, style: textTheme.titleSmall),
        ],
      ),
    );
  }
}
