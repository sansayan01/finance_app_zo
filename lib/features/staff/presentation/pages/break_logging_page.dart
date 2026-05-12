import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/staff_providers.dart';
import '../../../../providers/supabase_provider.dart';

enum BreakType {
  lunch,
  tea,
  rest,
  personal,
  other,
}

class BreakLoggingPage extends ConsumerStatefulWidget {
  const BreakLoggingPage({super.key});

  @override
  ConsumerState<BreakLoggingPage> createState() => _BreakLoggingPageState();
}

class _BreakLoggingPageState extends ConsumerState<BreakLoggingPage> {
  bool _isOnBreak = false;
  BreakType _selectedBreakType = BreakType.lunch;
  DateTime? _breakStartTime;
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentBreakStatus();
  }

  Future<void> _checkCurrentBreakStatus() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      final currentBreak = await ref.read(staffRepositoryProvider).getCurrentBreak(user.id);
      if (currentBreak != null) {
        setState(() {
          _isOnBreak = true;
          _breakStartTime = DateTime.parse(currentBreak['start_time']);
          _selectedBreakType = BreakType.values.firstWhere(
            (t) => t.name == currentBreak['break_type'],
            orElse: () => BreakType.other,
          );
        });
      }
    } catch (e) {
      // No active break
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isOnBreak ? 'On Break' : 'Start Break'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isOnBreak) _buildActiveBreakCard(theme),
            if (!_isOnBreak) ...[
              _buildBreakTypeSelector(theme),
              const SizedBox(height: 24),
              _buildNotesSection(theme),
              const SizedBox(height: 32),
              _buildStartBreakButton(theme),
            ],
            const SizedBox(height: 24),
            _buildBreakHistory(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveBreakCard(ThemeData theme) {
    final elapsed = _breakStartTime != null
        ? DateTime.now().difference(_breakStartTime!)
        : Duration.zero;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.coffee,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'On Break',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Take your time',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),
          _buildElapsedTimeCard(elapsed, theme),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isLoading ? null : _endBreak,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.stop),
            label: const Text('End Break'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: theme.colorScheme.primary,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElapsedTimeCard(Duration elapsed, ThemeData theme) {
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    final seconds = elapsed.inSeconds.remainder(60);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTimeUnit(hours.toString().padLeft(2, '0'), 'HRS'),
          const SizedBox(width: 16),
          _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'MIN'),
          const SizedBox(width: 16),
          _buildTimeUnit(seconds.toString().padLeft(2, '0'), 'SEC'),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakTypeSelector(ThemeData theme) {
    final breakTypes = [
      BreakType.lunch,
      BreakType.tea,
      BreakType.rest,
      BreakType.personal,
      BreakType.other,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Break Type',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: breakTypes.map((type) {
            return _buildBreakTypeCard(type, theme);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBreakTypeCard(BreakType type, ThemeData theme) {
    final isSelected = _selectedBreakType == type;
    final icon = _getBreakIcon(type);
    final label = _getBreakLabel(type);

    return InkWell(
      onTap: () {
        setState(() => _selectedBreakType = type);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: (MediaQuery.of(context).size.width - 56) / 3,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? theme.colorScheme.primary : null,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getBreakIcon(BreakType type) {
    switch (type) {
      case BreakType.lunch:
        return Icons.restaurant;
      case BreakType.tea:
        return Icons.coffee;
      case BreakType.rest:
        return Icons.bed;
      case BreakType.personal:
        return Icons.person;
      case BreakType.other:
        return Icons.more_horiz;
    }
  }

  String _getBreakLabel(BreakType type) {
    switch (type) {
      case BreakType.lunch:
        return 'Lunch';
      case BreakType.tea:
        return 'Tea Break';
      case BreakType.rest:
        return 'Rest';
      case BreakType.personal:
        return 'Personal';
      case BreakType.other:
        return 'Other';
    }
  }

  Widget _buildNotesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (Optional)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Add any notes...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartBreakButton(ThemeData theme) {
    return FilledButton.icon(
      onPressed: _isLoading ? null : _startBreak,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.play_arrow),
      label: Text(_isLoading ? 'Starting...' : 'Start Break'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildBreakHistory(ThemeData theme) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const SizedBox.shrink();

    final breaksAsync = ref.watch(todayBreaksProvider(user.id));

    return breaksAsync.when(
      data: (breaks) {
        if (breaks.isEmpty) return const SizedBox.shrink();

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s Breaks',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...breaks.map((b) => _buildBreakHistoryItem(b, theme)),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error: $err'),
    );
  }

  Widget _buildBreakHistoryItem(Map<String, dynamic> breakItem, ThemeData theme) {
    final startTime = DateTime.parse(breakItem['start_time']);
    final endTime = breakItem['end_time'] != null
        ? DateTime.parse(breakItem['end_time'])
        : null;
    final duration = endTime != null
        ? endTime.difference(startTime)
        : Duration.zero;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getBreakIcon(BreakType.values.firstWhere(
            (t) => t.name == breakItem['break_type'],
            orElse: () => BreakType.other,
          )),
          color: theme.colorScheme.primary,
        ),
      ),
      title: Text(_getBreakLabel(BreakType.values.firstWhere(
        (t) => t.name == breakItem['break_type'],
        orElse: () => BreakType.other,
      ))),
      subtitle: Text(
        '${DateFormat.jm().format(startTime)} - ${endTime != null ? DateFormat.jm().format(endTime) : 'Ongoing'}',
      ),
      trailing: Text(
        '${duration.inMinutes} min',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _startBreak() async {
    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not authenticated');

      await ref.read(staffRepositoryProvider).startBreak(
        staffId: user.id,
        breakType: _selectedBreakType.name,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      setState(() {
        _isOnBreak = true;
        _breakStartTime = DateTime.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Break started!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start break: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _endBreak() async {
    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not authenticated');

      await ref.read(staffRepositoryProvider).endBreak(user.id);

      setState(() {
        _isOnBreak = false;
        _breakStartTime = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Break ended!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end break: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
