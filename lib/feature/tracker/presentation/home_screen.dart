import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/platform/platform_shell.dart';
import '../../../core/services/database/app_database.dart';
import '../../../core/services/storage_location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../activities/data/activity_repository.dart';
import '../../activities/presentation/widgets/activity_edit_sheet.dart';
import '../data/session_repository.dart';
import '../service/start_coordinator.dart';
import '../service/timer_engine.dart';
import 'widgets/focus_card.dart';

/// Home: a 2-column grid of focus cards. One tap on a card starts that
/// activity immediately — this screen *is* the start control. On first
/// launch it resolves any session left open by a quit/crash (D2), and if a
/// timer ends up running it hands off to the Running screen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _resumeHandled = false;
  bool _fallbackDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleResume());
  }

  Future<void> _handleResume() async {
    if (_resumeHandled) return;
    _resumeHandled = true;
    final engine = context.read<TimerEngine>();
    final decision = await engine.detectOrphan();
    if (decision != null && mounted) {
      final repo = context.read<ActivityRepository>();
      final activities = await repo.activeActivities();
      final name = activities
          .where((a) => a.id == decision.activityId)
          .map((a) => a.name)
          .firstOrNull;
      if (!mounted) return;

      final keep = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Timer was still running'),
          content: Text(
            'Timer for ${name ?? 'an activity'} has run since '
            '${_formatClock(decision.start)}.\n\n'
            'Keep it going, or stop it at ${_formatClock(decision.lastSeenAt)} '
            '(when the app was last active)?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Stop at ${_formatClock(decision.lastSeenAt)}'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Keep going'),
            ),
          ],
        ),
      );

      if (keep == true) {
        await engine.resumeKeepRunning();
      } else {
        await engine.resumeStopAtLastSeen();
      }
    }

    // A resumed (or already-running) session always lands on Running (Step 4).
    if (mounted && engine.running != null) {
      context.go('/running');
    }
  }

  Future<void> _onTapCard(
    StartCoordinator coordinator,
    ActivityRepository repo,
    int activityId,
  ) async {
    final outcome = await coordinator.requestStart(activityId);
    switch (outcome.kind) {
      case StartKind.started:
      case StartKind.alreadyRunning:
        if (mounted) context.go('/running');
        return;
      case StartKind.needsSwitchConfirm:
        final activities = await repo.activeActivities();
        final runningName = activities
            .where((a) => a.id == outcome.runningActivityId)
            .map((a) => a.name)
            .firstOrNull;
        final nextName = activities
            .where((a) => a.id == activityId)
            .map((a) => a.name)
            .firstOrNull;
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${runningName ?? 'A timer'} is running'),
            content: Text(
              'Stop it and start ${nextName ?? 'the new activity'}?',
            ),
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
        if (confirmed == true) {
          await coordinator.confirmSwitch(activityId);
          if (mounted) context.go('/running');
        }
        return;
    }
  }

  /// First-run (and "+") entry point: on iPhone this opens the add-activity
  /// sheet in place; on Mac it routes to the dedicated Activities screen.
  void _addFirstActivity(bool hasMenuBar, ActivityRepository activityRepo) {
    if (hasMenuBar) {
      context.go('/activities');
    } else {
      ActivityEditSheet.show(context, repo: activityRepo, existing: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<TimerEngine>();
    final coordinator = context.read<StartCoordinator>();
    final activityRepo = context.read<ActivityRepository>();
    final sessionRepo = context.read<SessionRepository>();
    // Mac has a dedicated Activities screen (reachable here + the tray
    // menu); iPhone manages activities in place via long-press + "+" on the
    // cards below, so it skips the list view entirely.
    final hasMenuBar = context.read<PlatformShell>().hasMenuBar;
    // Surfaced only on Mac: the chosen data folder was missing at launch and
    // the app fell back to the default (v0.1 behavior). Dismissible.
    final fallbackReason = context
        .read<StorageLocationService>()
        .lastFallbackReason;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timer'),
        actions: [
          if (hasMenuBar)
            IconButton(
              icon: const Icon(Icons.list_alt),
              tooltip: 'Activities',
              onPressed: () => context.go('/activities'),
            )
          else
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add activity',
              onPressed: () => ActivityEditSheet.show(
                context,
                repo: activityRepo,
                existing: null,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () => context.push('/history'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (hasMenuBar && fallbackReason != null && !_fallbackDismissed)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppColors.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      fallbackReason,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Dismiss',
                    onPressed: () => setState(() => _fallbackDismissed = true),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<Activity>>(
              stream: activityRepo.watchActive(),
              builder: (context, activitySnapshot) {
                final activities = activitySnapshot.data ?? const [];
                if (activities.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No activities yet',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () =>
                              _addFirstActivity(hasMenuBar, activityRepo),
                          icon: const Icon(Icons.add),
                          label: const Text('Add your first activity'),
                        ),
                      ],
                    ),
                  );
                }
                return StreamBuilder<Map<int, int>>(
                  stream: sessionRepo.watchTodayTotals(DateTime.now()),
                  builder: (context, totalsSnapshot) {
                    final closedTotals = totalsSnapshot.data ?? const {};
                    final runningId = engine.running?.activityId;
                    final liveSeconds = runningId == null
                        ? 0
                        : engine.elapsed.inSeconds;
                    final totalToday =
                        closedTotals.values.fold<int>(0, (a, b) => a + b) +
                        liveSeconds;

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        final activity = activities[index];
                        final isRunning = activity.id == runningId;
                        final seconds =
                            (closedTotals[activity.id] ?? 0) +
                            (isRunning ? liveSeconds : 0);
                        return FocusCard(
                          activity: activity,
                          todaySeconds: seconds,
                          fraction: ringFraction(seconds, totalToday),
                          onTap: () => _onTapCard(
                            coordinator,
                            activityRepo,
                            activity.id,
                          ),
                          onLongPress: hasMenuBar
                              ? null
                              : () => ActivityEditSheet.show(
                                  context,
                                  repo: activityRepo,
                                  existing: activity,
                                ),
                          onViewHistory: () =>
                              context.push('/history', extra: activity.id),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _formatClock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
