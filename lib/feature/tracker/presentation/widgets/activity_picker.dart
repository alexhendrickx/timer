import 'package:flutter/material.dart';

import '../../../../core/services/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';

/// Dropdown to pick the activity a new timer will be tagged with. Bound to the
/// active (non-archived) activities; the selection enables the Start button.
class ActivityPicker extends StatelessWidget {
  const ActivityPicker({
    super.key,
    required this.activities,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Activity> activities;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Text(
        'No activities yet — add one to start tracking.',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.textSecondary),
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: selectedId,
      decoration: const InputDecoration(
        labelText: 'Activity',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final a in activities)
          DropdownMenuItem(value: a.id, child: Text(a.name)),
      ],
      onChanged: onChanged,
    );
  }
}
