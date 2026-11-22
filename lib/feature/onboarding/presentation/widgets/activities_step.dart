import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../activities/data/activity_repository.dart';
import '../../../activities/presentation/widgets/activity_edit_sheet.dart';

class OnboardingPreset {
  const OnboardingPreset(this.name, this.color);

  final String name;
  final int color;
}

/// Step 1 presets, each with its own swatch from the activity palette.
final List<OnboardingPreset> onboardingPresets = [
  OnboardingPreset('Client work', activitySwatches[0]),
  OnboardingPreset('Meetings', activitySwatches[1]),
  OnboardingPreset('Admin', activitySwatches[2]),
  OnboardingPreset('Deep focus', activitySwatches[3]),
  OnboardingPreset('Learning', activitySwatches[4]),
];

/// Step 1: tick presets and/or add your own; Continue creates the ticked
/// presets through [ActivityRepository].
class ActivitiesStep extends StatefulWidget {
  const ActivitiesStep({super.key, required this.onNext, required this.onSkip});

  final VoidCallback onNext;

  /// "Skip setup": leaves the whole flow without creating anything.
  final VoidCallback onSkip;

  @override
  State<ActivitiesStep> createState() => _ActivitiesStepState();
}

class _ActivitiesStepState extends State<ActivitiesStep> {
  late final ActivityRepository _repo;
  late final Stream<List<Activity>> _added;
  final Set<String> _selected = {
    onboardingPresets[0].name,
    onboardingPresets[1].name,
  };
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repo = context.read<ActivityRepository>();
    // Held in state so ticking a checkbox does not resubscribe.
    _added = _repo.watchActive();
  }

  Future<void> _continue() async {
    setState(() => _busy = true);
    try {
      // Skip a preset the user already added by hand under the same name.
      final existing =
          (await _repo.activeActivities()).map((a) => a.name).toSet();
      for (final preset in onboardingPresets) {
        if (_selected.contains(preset.name) &&
            !existing.contains(preset.name)) {
          await _repo.create(name: preset.name, color: preset.color);
        }
      }
    } finally {
      // Also after a failed write, so Continue and Skip work again.
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) widget.onNext();
  }

  void _toggle(String name, bool? checked) {
    setState(() {
      if (checked == true) {
        _selected.add(name);
      } else {
        _selected.remove(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return StreamBuilder<List<Activity>>(
      stream: _added,
      builder: (context, snapshot) {
        final added = snapshot.data ?? const <Activity>[];
        final count = _selected.length +
            added.where((a) => !_selected.contains(a.name)).length;
        final canContinue = !_busy && count > 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('What do you track?', style: textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Pick a few. Each one becomes a big start button.',
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Expanded(child: _list(added)),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('onboarding-continue'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: canContinue ? _continue : null,
              child: Text('Continue · $count selected'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: _busy ? null : widget.onSkip,
              child: const Text('Skip setup'),
            ),
          ],
        );
      },
    );
  }

  Widget _list(List<Activity> added) {
    return ListView(
      children: [
        for (final preset in onboardingPresets)
          CheckboxListTile(
            value: _selected.contains(preset.name),
            onChanged: (checked) => _toggle(preset.name, checked),
            title: Text(preset.name),
            secondary: CircleAvatar(
              backgroundColor: Color(preset.color),
              radius: 10,
            ),
          ),
        for (final activity in added)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: activity.color != null
                  ? Color(activity.color!)
                  : AppColors.hairline,
              radius: 10,
            ),
            title: Text(activity.name),
            trailing: const Icon(Icons.check, color: AppColors.accent),
          ),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Add your own'),
          onTap: () => ActivityEditSheet.show(context, repo: _repo),
        ),
      ],
    );
  }
}
