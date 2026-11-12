import 'package:flutter/material.dart';

import '../../../../core/services/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_utils.dart';
import '../../data/history_repository.dart';

/// One session row in the day list: start–end clock times, the exact
/// duration (never rounded — spec D4/Anti-goals), and an editable note.
class SessionTile extends StatelessWidget {
  const SessionTile({super.key, required this.session, required this.repo});

  final Session session;
  final HistoryRepository repo;

  String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _editNote(BuildContext context) async {
    final controller = TextEditingController(text: session.note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Add a note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await repo.setNote(session.id, result.isEmpty ? null : result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final end = session.endTime;
    return ListTile(
      title: Text(
        end == null
            ? '${_clock(session.startTime)} – running'
            : '${_clock(session.startTime)} – ${_clock(end)}',
      ),
      subtitle: Text(
        session.note?.isNotEmpty == true ? session.note! : 'Add a note',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontStyle:
                  session.note?.isNotEmpty == true ? null : FontStyle.italic,
            ),
      ),
      trailing: Text(
        formatHms(session.durationSeconds),
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.textSecondary),
      ),
      onTap: () => _editNote(context),
    );
  }
}
