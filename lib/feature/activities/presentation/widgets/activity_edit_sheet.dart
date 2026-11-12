import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../../../core/services/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/activity_repository.dart';

/// A subset of colors offered as optional activity swatches.
const List<int> activitySwatches = [
  0xFF4FB8A8, // accent teal
  0xFFE0A458, // amber
  0xFFC45B6E, // rose
  0xFF6E8FC4, // blue
  0xFF8FB36E, // green
  0xFFB08FC4, // violet
];

/// Add/edit an activity: name, color, optional hourly rate + currency,
/// archive. Shared by both platforms — a long-press-opened sheet on
/// iPhone, and the Mac Activities screen's add/edit action. Delete is only
/// offered when the activity has no sessions (spec D7); otherwise this
/// explains that archiving is the only option.
class ActivityEditSheet extends StatefulWidget {
  const ActivityEditSheet({super.key, required this.repo, this.existing});

  final ActivityRepository repo;
  final Activity? existing;

  /// Opens this sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required ActivityRepository repo,
    Activity? existing,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ActivityEditSheet(repo: repo, existing: existing),
    );
  }

  @override
  State<ActivityEditSheet> createState() => _ActivityEditSheetState();
}

class _ActivityEditSheetState extends State<ActivityEditSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _rate = TextEditingController(
      text: widget.existing?.hourlyRate?.toStringAsFixed(2) ?? '');
  late final TextEditingController _currency =
      TextEditingController(text: widget.existing?.currencyLabel ?? '');
  late int? _color = widget.existing?.color;
  Future<bool>? _canDelete;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _canDelete = widget.repo.canDelete(existing.id);
    }
  }

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

  Future<void> _archive() async {
    final existing = widget.existing;
    if (existing == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive "${existing.name}"?'),
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
    if (ok == true) {
      await widget.repo.archive(existing.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${existing.name}"?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.repo.delete(existing.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'Add activity' : 'Edit activity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
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
                  for (final c in activitySwatches)
                    _ColorDot(
                      color: Color(c),
                      selected: _color == c,
                      onTap: () => setState(() => _color = c),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (existing != null)
                FutureBuilder<bool>(
                  future: _canDelete,
                  builder: (context, snapshot) {
                    final canDelete = snapshot.data ?? false;
                    return Row(
                      children: [
                        TextButton(
                          onPressed: _archive,
                          child: const Text('Archive'),
                        ),
                        const SizedBox(width: 8),
                        if (canDelete)
                          TextButton(
                            onPressed: _delete,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger,
                            ),
                            child: const Text('Delete'),
                          )
                        else
                          Expanded(
                            child: Text(
                              'Has sessions — archive instead of delete.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _valid ? _save : null,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
