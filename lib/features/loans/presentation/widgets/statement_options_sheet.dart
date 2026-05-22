import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/services/loan_statement_pdf_service.dart';

enum StatementFormat { pdf, excel, csv }

class StatementOptions {
  final DateTime periodStart;
  final DateTime periodEnd;
  final StatementVariant variant;
  final StatementFormat format;

  const StatementOptions({
    required this.periodStart,
    required this.periodEnd,
    required this.variant,
    required this.format,
  });
}

enum _RangePreset { thisMonth, last3M, last6M, thisFY, custom }

class StatementOptionsSheet extends StatefulWidget {
  final DateTime loanStart;
  const StatementOptionsSheet({super.key, required this.loanStart});

  @override
  State<StatementOptionsSheet> createState() => _StatementOptionsSheetState();
}

class _StatementOptionsSheetState extends State<StatementOptionsSheet> {
  _RangePreset _preset = _RangePreset.thisFY;
  StatementVariant _variant = StatementVariant.fullSchedule;
  StatementFormat _format = StatementFormat.pdf;
  late DateTime _customStart;
  late DateTime _customEnd;

  @override
  void initState() {
    super.initState();
    _customStart = widget.loanStart;
    _customEnd = DateTime.now();
  }

  (DateTime, DateTime) _resolveRange() {
    final now = DateTime.now();
    switch (_preset) {
      case _RangePreset.thisMonth:
        return (DateTime(now.year, now.month, 1), now);
      case _RangePreset.last3M:
        return (DateTime(now.year, now.month - 3, now.day), now);
      case _RangePreset.last6M:
        return (DateTime(now.year, now.month - 6, now.day), now);
      case _RangePreset.thisFY:
        // India FY: April 1 – March 31
        final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
        return (DateTime(fyStartYear, 4, 1), now);
      case _RangePreset.custom:
        return (_customStart, _customEnd);
    }
  }

  String _presetLabel(_RangePreset p) {
    switch (p) {
      case _RangePreset.thisMonth:
        return 'This Month';
      case _RangePreset.last3M:
        return 'Last 3 Months';
      case _RangePreset.last6M:
        return 'Last 6 Months';
      case _RangePreset.thisFY:
        return 'This FY';
      case _RangePreset.custom:
        return 'Custom';
    }
  }

  String _variantLabel(StatementVariant v) {
    switch (v) {
      case StatementVariant.fullSchedule:
        return 'Full Schedule';
      case StatementVariant.activityOnly:
        return 'Activity Only';
      case StatementVariant.taxStatement:
        return 'Tax Statement';
    }
  }

  String _formatLabel(StatementFormat f) {
    switch (f) {
      case StatementFormat.pdf:
        return 'PDF';
      case StatementFormat.excel:
        return 'Excel';
      case StatementFormat.csv:
        return 'CSV';
    }
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _customStart, end: _customEnd),
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
        _preset = _RangePreset.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (start, end) = _resolveRange();
    final fmt = DateFormat('dd MMM yyyy');

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Generate Statement',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Choose the period, type, and format.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 20),

            // ── Period ──
            _SectionLabel(label: 'PERIOD'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _RangePreset.values.map((p) {
                final selected = _preset == p;
                return GestureDetector(
                  onTap: () async {
                    if (p == _RangePreset.custom) {
                      await _pickCustomRange();
                    } else {
                      setState(() => _preset = p);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _presetLabel(p),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: selected ? Colors.white : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Text('${fmt.format(start)}  →  ${fmt.format(end)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                )),
            const SizedBox(height: 20),

            // ── Variant ──
            _SectionLabel(label: 'STATEMENT TYPE'),
            ...StatementVariant.values.map((v) {
              return RadioListTile<StatementVariant>(
                value: v,
                groupValue: _variant,
                onChanged: (val) => setState(() => _variant = val!),
                title: Text(_variantLabel(v),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(_variantSubtitle(v),
                    style: theme.textTheme.bodySmall),
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),
            const SizedBox(height: 16),

            // ── Format ──
            _SectionLabel(label: 'FORMAT'),
            SegmentedButton<StatementFormat>(
              segments: StatementFormat.values
                  .map((f) => ButtonSegment(
                        value: f,
                        label: Text(_formatLabel(f)),
                        icon: Icon(_formatIcon(f)),
                      ))
                  .toList(),
              selected: {_format},
              onSelectionChanged: (s) => setState(() => _format = s.first),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(
                    context,
                    StatementOptions(
                      periodStart: start,
                      periodEnd: end,
                      variant: _variant,
                      format: _format,
                    ),
                  );
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Generate',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _variantSubtitle(StatementVariant v) {
    switch (v) {
      case StatementVariant.fullSchedule:
        return 'All EMIs (scheduled + paid) with full ledger.';
      case StatementVariant.activityOnly:
        return 'Only actual transactions — paid, late, and disbursements.';
      case StatementVariant.taxStatement:
        return 'Interest and principal paid in the period for tax filing.';
    }
  }

  IconData _formatIcon(StatementFormat f) {
    switch (f) {
      case StatementFormat.pdf:
        return Icons.picture_as_pdf_rounded;
      case StatementFormat.excel:
        return Icons.grid_on_rounded;
      case StatementFormat.csv:
        return Icons.table_chart_rounded;
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w900,
          color: Theme.of(context).textTheme.bodySmall?.color
              ?.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
