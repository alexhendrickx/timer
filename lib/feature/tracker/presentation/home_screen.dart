import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/duration_utils.dart';
import '../../activities/data/activity_repository.dart';
import '../service/timer_engine.dart';
import 'widgets/activity_picker.dart';

/// The main tracker screen: pick an activity and Start/Stop a live timer.
/// On first launch it resolves any session left open by a quit/crash (D2).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _selectedActivityId;
  bool _resumeHandled = false;

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
    if (decision == null || !mounted) return;

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

  Future<void> _onStart(TimerEngine engine) async {
    final id = _selectedActivityId;
    if (id == null) return;

    if (engine.running != null) {
      final repo = context.read<ActivityRepository>();
      final activities = await repo.activeActivities();
      final runningName = activities
          .where((a) => a.id == engine.running!.activityId)
          .map((a) => a.name)
          .firstOrNull;
      final nextName =
          activities.where((a) => a.id == id).map((a) => a.name).firstOrNull;
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('A timer is already running'),
          content: Text(
            '${runningName ?? 'A timer'} is running. '
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
      if (confirmed != true) return;
      await engine.stop();
    }

    await engine.start(id);
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<TimerEngine>();
    final repo = context.read<ActivityRepository>();
    final running = engine.running;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Activities',
            onPressed: () => context.go('/activities'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Center(
        child: running != null
            ? _RunningView(
                engine: engine,
                repo: repo,
                onStop: () => engine.stop(),
              )
            : _IdleView(
                repo: repo,
                selectedId: _selectedActivityId,
                onChanged: (id) => setState(() => _selectedActivityId = id),
                onStart: () => _onStart(engine),
              ),
      ),
    );
  }
}

String _formatClock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Idle state: activity picker + Start (disabled until an activity is picked).
class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.repo,
    required this.selectedId,
    required this.onChanged,
    required this.onStart,
  });

  final ActivityRepository repo;
  final int? selectedId;
  final ValueChanged<int?> onChanged;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Activity>>(
      stream: repo.watchActive(),
      builder: (context, snapshot) {
        final activities = snapshot.data ?? const [];
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ActivityPicker(
                  activities: activities,
                  selectedId: selectedId,
                  onChanged: onChanged,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: selectedId == null ? null : onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Running state: live elapsed + current activity name + Stop.
class _RunningView extends StatelessWidget {
  const _RunningView({
    required this.engine,
    required this.repo,
    required this.onStop,
  });

  final TimerEngine engine;
  final ActivityRepository repo;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final running = engine.running!;
    return Column(
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
              style: Theme.of(context).textTheme.titleMedium,
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          formatHms(engine.elapsed.inSeconds),
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppColors.accent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: onStop,
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
        ),
      ],
    );
  }
}
