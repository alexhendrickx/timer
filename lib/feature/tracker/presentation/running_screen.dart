import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/duration_utils.dart';
import '../../activities/data/activity_repository.dart';
import '../service/timer_engine.dart';

/// The Running screen: a large live-ticking timer, the current activity
/// name, and a single red Stop button. Nothing else — the running state
/// should not compete for attention (spec: Running).
class RunningScreen extends StatelessWidget {
  const RunningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<TimerEngine>();
    final repo = context.read<ActivityRepository>();
    final running = engine.running;

    if (running == null) {
      // The timer was stopped elsewhere (e.g. a resume dialog); nothing to
      // show here — return to Home instead of a blank screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/');
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<List<Activity>>(
              future: repo.activeActivities(),
              builder: (context, snapshot) {
                final name = (snapshot.data ?? const [])
                    .where((a) => a.id == running.activityId)
                    .map((a) => a.name)
                    .firstOrNull;
                return Text(
                  name ?? 'Running',
                  style: Theme.of(context).textTheme.titleLarge,
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              formatHms(engine.elapsed.inSeconds),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: AppColors.accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size(160, 56),
              ),
              onPressed: () async {
                await engine.stop();
                if (context.mounted) context.go('/');
              },
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
            ),
          ],
        ),
      ),
    );
  }
}
