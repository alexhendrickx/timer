import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/storage_location_service.dart';
import '../../../core/theme/app_colors.dart';

/// Settings for v0.1.0: shows the current data folder and lets the user change
/// it. Reminder intervals and the rest arrive in later versions.
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
        ],
      ),
    );
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
