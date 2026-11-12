import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../activities/data/activity_repository.dart';
import '../service/start_coordinator.dart';

/// Case-insensitive substring filter for the type-to-filter list. Empty
/// [query] returns [names] unchanged.
List<String> filterActivityNames(List<String> names, String query) {
  if (query.isEmpty) return names;
  final q = query.toLowerCase();
  return names.where((name) => name.toLowerCase().contains(q)).toList();
}

/// The Spotlight-style quick-start overlay opened by the global hotkey: a
/// light, centered, type-to-filter list of active activities. Picking one
/// starts it via [StartCoordinator] (the D1 switch confirm is honored, same
/// as everywhere else) and dismisses — it never shows the main window.
class QuickStartPicker extends StatefulWidget {
  const QuickStartPicker({super.key, required this.onDismiss});

  /// Called once a pick has started (or the user cancels) so the shell can
  /// hide this overlay's window.
  final VoidCallback onDismiss;

  @override
  State<QuickStartPicker> createState() => _QuickStartPickerState();
}

class _QuickStartPickerState extends State<QuickStartPicker> {
  final _queryController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _onPick(Activity activity) async {
    final coordinator = context.read<StartCoordinator>();
    final repo = context.read<ActivityRepository>();
    final outcome = await coordinator.requestStart(activity.id);
    if (outcome.kind == StartKind.needsSwitchConfirm) {
      final activities = await repo.activeActivities();
      final runningName = activities
          .where((a) => a.id == outcome.runningActivityId)
          .map((a) => a.name)
          .firstOrNull;
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${runningName ?? 'A timer'} is running'),
          content: Text('Stop it and start ${activity.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Stop and start'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await coordinator.confirmSwitch(activity.id);
    }
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ActivityRepository>();
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _queryController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Start tracking…',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (text) => setState(() => _query = text),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: StreamBuilder<List<Activity>>(
                stream: repo.watchActive(),
                builder: (context, snapshot) {
                  final activities = snapshot.data ?? const [];
                  final matching =
                      filterActivityNames(
                    activities.map((a) => a.name).toList(),
                    _query,
                  ).toSet();
                  final visible =
                      activities.where((a) => matching.contains(a.name)).toList();
                  if (visible.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No matching activity'),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final activity = visible[index];
                      return ListTile(
                        dense: true,
                        title: Text(activity.name),
                        onTap: () => _onPick(activity),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
