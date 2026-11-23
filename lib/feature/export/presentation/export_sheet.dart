import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../service/export_service.dart';

/// Format + scope picker for the active History/Reports filter, shown as a
/// bottom sheet; "Share" hands the built files to the system share sheet.
/// Export scope always follows the filter the caller is already showing
/// (the active activity + date range) — this sheet adds no filter of its
/// own (spec: Export scope = the active History filter).
class ExportSheet extends StatefulWidget {
  const ExportSheet({
    super.key,
    required this.exportService,
    this.range,
    this.activityId,
  });

  final ExportService exportService;
  final DateTimeRange? range;
  final int? activityId;

  /// Opens the sheet modally.
  static Future<void> show(
    BuildContext context, {
    required ExportService exportService,
    DateTimeRange? range,
    int? activityId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExportSheet(
        exportService: exportService,
        range: range,
        activityId: activityId,
      ),
    );
  }

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  final Set<ExportFormat> _formats = {ExportFormat.csv};
  ExportScope _scope = ExportScope.combined;
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final files = await widget.exportService.buildFiles(
        formats: _formats,
        scope: _scope,
        range: widget.range,
        activityId: widget.activityId,
      );
      await widget.exportService.share(files);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Formats', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: [
                for (final format in ExportFormat.values)
                  FilterChip(
                    label: Text(format.name.toUpperCase()),
                    selected: _formats.contains(format),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _formats.add(format);
                      } else {
                        _formats.remove(format);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Scope', style: Theme.of(context).textTheme.titleSmall),
            SegmentedButton<ExportScope>(
              segments: const [
                ButtonSegment(
                    value: ExportScope.combined, label: Text('Combined')),
                ButtonSegment(
                    value: ExportScope.perActivity,
                    label: Text('One file per activity')),
              ],
              selected: {_scope},
              onSelectionChanged: (s) => setState(() => _scope = s.first),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _formats.isEmpty || _sharing ? null : _share,
                icon: const Icon(Icons.ios_share),
                label: Text(_sharing ? 'Preparing…' : 'Share'),
              ),
            ),
            if (_formats.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Choose at least one format.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
