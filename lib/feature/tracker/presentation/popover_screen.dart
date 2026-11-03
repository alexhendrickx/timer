import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/database/app_database.dart';
import '../../../core/services/window_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/duration_utils.dart';
import '../../activities/data/activity_repository.dart';
import '../data/session_repository.dart';
import '../service/timer_engine.dart';
import 'widgets/activity_picker.dart';

/// The frameless menu-bar popover: pick an activity and Start, or Stop a
/// running timer, jot a quick note on the running (or just-stopped) session,
/// and open the full window. Shares providers with the main window, so state
/// stays in sync between the two.
class PopoverScreen extends StatefulWidget {
  const PopoverScreen({super.key});

  @override
  State<PopoverScreen> createState() => _PopoverScreenState();
}

class _PopoverScreenState extends State<PopoverScreen> {
  int? _selectedActivityId;
  final _noteController = TextEditingController();
  int? _noteSeededFor;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // Seed the note field from the session's stored note the first time we see a
  // given session, so switching sessions doesn't carry a stale note over.
  void _seedNote(TimerEngine engine) {
    final id = engine.currentSessionId;
    if (id == _noteSeededFor) return;
    _noteSeededFor = id;
    _noteController.text = engine.running?.note ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<TimerEngine>();
    final activities = context.read<ActivityRepository>();
    final sessions = context.read<SessionRepository>();
    final window = context.read<WindowController>();
    final running = engine.running;
    _seedNote(engine);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (running != null)
                _RunningBlock(
                  engine: engine,
                  repo: activities,
                  onStop: () => engine.stop(),
                )
              else
                _IdleBlock(
                  repo: activities,
                  selectedId: _selectedActivityId,
                  onChanged: (id) =>
                      setState(() => _selectedActivityId = id),
                  onStart: () {
                    final id = _selectedActivityId;
                    if (id != null) engine.start(id);
                  },
                ),
              if (engine.currentSessionId != null) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    hintText: 'Add a quick note…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (text) =>
                      sessions.setNote(engine.currentSessionId!, text),
                ),
              ],
              const Spacer(),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: window.showMainWindow,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open window'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Idle: compact activity picker + Start.
class _IdleBlock extends StatelessWidget {
  const _IdleBlock({
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ActivityPicker(
              activities: activities,
              selectedId: selectedId,
              onChanged: onChanged,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: selectedId == null ? null : onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
            ),
          ],
        );
      },
    );
  }
}

/// Running: current activity + live elapsed + Stop.
class _RunningBlock extends StatelessWidget {
  const _RunningBlock({
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          formatHms(engine.elapsed.inSeconds),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.accent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
        const SizedBox(height: 12),
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
