import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../data/activity_repository.dart';

/// Manage the activity list: add, edit, archive. Deleting is not offered —
/// activities with sessions are archived to preserve history (spec D7).
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
        onPressed: () => _openEditor(context, repo, null),
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit',
                      onPressed: () => _openEditor(context, repo, a),
                    ),
                    IconButton(
                      icon: const Icon(Icons.archive_outlined),
                      tooltip: 'Archive',
                      onPressed: () => _confirmArchive(context, repo, a),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmArchive(
    BuildContext context,
    ActivityRepository repo,
    Activity a,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive "${a.name}"?'),
        content: const Text(
          'It will be hidden from the picker. Its past sessions are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (ok == true) await repo.archive(a.id);
  }

  Future<void> _openEditor(
    BuildContext context,
    ActivityRepository repo,
    Activity? existing,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ActivityEditor(repo: repo, existing: existing),
    );
  }
}

/// A subset of colors offered as optional activity swatches.
const List<int> _swatches = [
  0xFF4FB8A8, // accent teal
  0xFFE0A458, // amber
  0xFFC45B6E, // rose
  0xFF6E8FC4, // blue
  0xFF8FB36E, // green
  0xFFB08FC4, // violet
];

class _ActivityEditor extends StatefulWidget {
  const _ActivityEditor({required this.repo, required this.existing});

  final ActivityRepository repo;
  final Activity? existing;

  @override
  State<_ActivityEditor> createState() => _ActivityEditorState();
}

class _ActivityEditorState extends State<_ActivityEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _rate = TextEditingController(
      text: widget.existing?.hourlyRate?.toStringAsFixed(2) ?? '');
  late final TextEditingController _currency =
      TextEditingController(text: widget.existing?.currencyLabel ?? '');
  late int? _color = widget.existing?.color;

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    _currency.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final rate = double.tryParse(_rate.text.trim().replaceAll(',', '.'));
    final currency =
        _currency.text.trim().isEmpty ? null : _currency.text.trim();

    final existing = widget.existing;
    if (existing == null) {
      await widget.repo.create(
        name: name,
        color: _color,
        hourlyRate: rate,
        currencyLabel: currency,
      );
    } else {
      await widget.repo.update(
        existing.copyWith(
          name: name,
          color: Value(_color),
          hourlyRate: Value(rate),
          currencyLabel: Value(currency),
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add activity' : 'Edit activity'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rate,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Hourly rate (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _currency,
              decoration: const InputDecoration(
                labelText: 'Currency label (optional, e.g. EUR)',
              ),
            ),
            const SizedBox(height: 16),
            Text('Color (optional)',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                _ColorDot(
                  color: null,
                  selected: _color == null,
                  onTap: () => setState(() => _color = null),
                ),
                for (final c in _swatches)
                  _ColorDot(
                    color: Color(c),
                    selected: _color == c,
                    onTap: () => setState(() => _color = c),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid ? _save : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color ?? AppColors.hairline,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.textPrimary : Colors.transparent,
            width: 2,
          ),
        ),
        child: color == null
            ? const Icon(Icons.block, size: 16, color: AppColors.textSecondary)
            : null,
      ),
    );
  }
}
