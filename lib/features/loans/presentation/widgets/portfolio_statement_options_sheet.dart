import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Options for portfolio-level statement generation.
class PortfolioStatementOptions {
  final DateTime periodStart;
  final DateTime periodEnd;

  const PortfolioStatementOptions({
    required this.periodStart,
    required this.periodEnd,
  });
}

enum _RangePreset { thisMonth, last3M, last6M, thisFY }

/// Simplified options sheet for portfolio-level statement generation.
class PortfolioStatementOptionsSheet extends StatefulWidget {
  const PortfolioStatementOptionsSheet({super.key});

  @override
  State<PortfolioStatementOptionsSheet> createState() =>
      _PortfolioStatementOptionsSheetState();
}

class _PortfolioStatementOptionsSheetState
    extends State<PortfolioStatementOptionsSheet> {
  _RangePreset _preset = _RangePreset.thisFY;

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
        final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
        return (DateTime(fyStartYear, 4, 1), now);
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
            Text('Portfolio Statement',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Generate a summary of your entire loan portfolio.',
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
                  onTap: () => setState(() => _preset = p),
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
                        color: selected
                            ? Colors.white
                            : theme.colorScheme.primary,
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
                  color:
                      theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                )),
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
                    PortfolioStatementOptions(
                      periodStart: start,
                      periodEnd: end,
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
          color: Theme.of(context)
              .textTheme
              .bodySmall
              ?.color
              ?.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
