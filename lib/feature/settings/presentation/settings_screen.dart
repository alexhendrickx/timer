import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/storage_location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../tracker/service/reminder_scheduler.dart';
import '../data/reminder_settings.dart';
import '../data/rounding_settings.dart';

/// Common break-interval choices offered in Settings.
const List<Duration> _reminderIntervalChoices = [
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(minutes: 45),
  Duration(minutes: 60),
  Duration(minutes: 90),
  Duration(minutes: 120),
];

/// Rounding-step choices (seconds) offered in Settings — the step totals,
/// reports, and exports round to (view only; spec D4).
const List<int> _roundingStepChoices = [900, 1800, 3600];

/// Settings: data folder + the break-reminder interval.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _justChangedTo;

  @override
  Widget build(BuildContext context) {
    final storage = context.read<StorageLocationService>();
    final folder = _justChangedTo ?? storage.currentFolder ?? 'Resolving…';
    final fallback = storage.lastFallbackReason;
    final reminderSettings = context.read<ReminderSettings>();
    final reminderScheduler = context.read<ReminderScheduler>();
    final roundingSettings = context.read<RoundingSettings>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Data folder',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            folder,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          if (fallback != null) ...[
            const SizedBox(height: 8),
            Text(
              fallback,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _changeFolder(storage),
            icon: const Icon(Icons.folder_open),
            label: const Text('Change data folder…'),
          ),
          if (_justChangedTo != null) ...[
            const SizedBox(height: 12),
            Text(
              'Takes effect on next launch.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 32),
          Text('Break reminders',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'A gentle full-screen nudge while a timer is running.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          DropdownButton<Duration>(
            value: reminderSettings.interval,
            items: [
              for (final choice in _reminderIntervalChoices)
                DropdownMenuItem(
                  value: choice,
                  child: Text('Every ${choice.inMinutes} min'),
                ),
            ],
            onChanged: (value) =>
                _changeReminderInterval(reminderSettings, reminderScheduler, value),
          ),
          const SizedBox(height: 32),
          Text('Rounding', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Totals, reports, and exports round sums to this step. '
            'The exact recorded time is never changed.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          DropdownButton<int>(
            value: roundingSettings.stepSeconds,
            items: [
              for (final choice in _roundingStepChoices)
                DropdownMenuItem(
                  value: choice,
                  child: Text('Nearest ${choice ~/ 60} min'),
                ),
            ],
            onChanged: (value) => _changeRoundingStep(roundingSettings, value),
          ),
        ],
      ),
    );
  }

  Future<void> _changeReminderInterval(
    ReminderSettings settings,
    ReminderScheduler scheduler,
    Duration? value,
  ) async {
    if (value == null) return;
    settings.interval = value;
    await settings.save();
    scheduler.onSettingsChanged();
    if (mounted) setState(() {});
  }

  Future<void> _changeRoundingStep(RoundingSettings settings, int? value) async {
    if (value == null) return;
    settings.stepSeconds = value;
    await settings.save();
    if (mounted) setState(() {});
  }

  Future<void> _changeFolder(StorageLocationService storage) async {
    final picked = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose a folder for your Timer data',
    );
    if (picked == null) return;
    await storage.setDataFolder(picked);
    if (!mounted) return;
    setState(() => _justChangedTo = picked);
  }
}
