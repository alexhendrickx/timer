import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../data/activity_repository.dart';
import 'widgets/activity_edit_sheet.dart';

/// Mac's dedicated activity management surface: a list with add/edit/archive
/// actions, reachable from the window and the tray menu. Deleting an
/// activity with sessions is not offered here — [ActivityEditSheet] blocks
/// it and explains archiving instead (spec D7).
class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ActivityRepository>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Activities'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            ActivityEditSheet.show(context, repo: repo, existing: null),
        tooltip: 'Add activity',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Activity>>(
        stream: repo.watchActive(),
        builder: (context, snapshot) {
          final activities = snapshot.data ?? const [];
          if (activities.isEmpty) {
            return Center(
              child: Text(
                'No activities yet.\nTap + to add your first one.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            );
          }
          return ListView.separated(
            itemCount: activities.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final a = activities[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: a.color != null
                      ? Color(a.color!)
                      : AppColors.hairline,
                  radius: 10,
                ),
                title: Text(a.name),
                subtitle: a.hourlyRate != null
                    ? Text(
                        '${a.hourlyRate!.toStringAsFixed(2)}'
                        '${a.currencyLabel != null ? ' ${a.currencyLabel}' : ''}/h',
                      )
                    : null,
                onTap: () =>
                    ActivityEditSheet.show(context, repo: repo, existing: a),
                trailing: const Icon(Icons.chevron_right),
              );
            },
          );
        },
      ),
    );
  }
}
