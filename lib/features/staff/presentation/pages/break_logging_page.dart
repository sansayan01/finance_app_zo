import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/staff_providers.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/smokey_background.dart';
import '../widgets/premium_helpers.dart';

enum BreakType { lunch, tea, rest, personal, other;

  String get displayName {
    switch (this) {
      case BreakType.lunch: return 'Lunch';
      case BreakType.tea: return 'Tea';
      case BreakType.rest: return 'Rest';
      case BreakType.personal: return 'Personal';
      case BreakType.other: return 'Other';
    }
  }
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
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _checkCurrentBreakStatus();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkCurrentBreakStatus() async {
    final profile = await ref.read(staffProfileProvider.future);
    if (profile == null) return;
    try {
      final currentBreak =
          await ref.read(staffRepositoryProvider).getCurrentBreak(profile.id);
      if (currentBreak != null && mounted) {
        setState(() {
          _isOnBreak = true;
          _breakStartTime = DateTime.parse(currentBreak['break_start']);
          _selectedBreakType = BreakType.values.firstWhere(
              (t) => t.toString().split('.').last == currentBreak['break_type'],
              orElse: () => BreakType.other);
        });
        _startTimer();
      }
    } catch (_) {}
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_breakStartTime != null && mounted) {
        setState(() => _elapsedSeconds =
            DateTime.now().difference(_breakStartTime!).inSeconds);
      }
    });
  }

  Future<void> _handleBreakAction() async {
    HapticFeedback.mediumImpact();
    final profile = await ref.read(staffProfileProvider.future);
    if (profile == null) return;
    final repo = ref.read(staffRepositoryProvider);
    setState(() => _isLoading = true);
    try {
      if (_isOnBreak) {
        await repo.endBreak(profile.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Break ended'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating));
        }
        _timer?.cancel();
        setState(() {
          _isOnBreak = false;
          _breakStartTime = null;
          _elapsedSeconds = 0;
        });
      } else {
        await repo.startBreak(
            staffId: profile.id,
            breakType: _selectedBreakType.toString().split('.').last,
            notes: _notesController.text.isNotEmpty
                ? _notesController.text
                : null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Break started'),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating));
        }
        setState(() {
          _isOnBreak = true;
          _breakStartTime = DateTime.now();
        });
        _startTimer();
      }
      ref.invalidate(currentActivityProvider(profile.id));
      ref.invalidate(recentActivitiesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white70 : Colors.black87),
        ),
        title: Text(_isOnBreak ? 'On Break' : 'Take a Break',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
      ),
      body: SmokeyBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            await _checkCurrentBreakStatus();
            ref.invalidate(recentActivitiesProvider);
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                if (_isOnBreak)
                  _buildActiveBreakCard(theme, isDark)
                else
                  _buildBreakSetup(theme, isDark),
              ].animate(interval: 60.ms).fadeIn().slideY(begin: 0.04, end: 0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveBreakCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.orange.shade600, Colors.deepOrange.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.orange.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle),
            child: const Icon(Icons.free_breakfast_rounded,
                color: Colors.white, size: 48),
          ),
          const SizedBox(height: 20),
          Text('Break in Progress',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          const SizedBox(height: 4),
          Text(
            '${_elapsedSeconds ~/ 60}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w900,
                letterSpacing: 2),
          ),
          const SizedBox(height: 4),
          Text(_selectedBreakType.displayName.toUpperCase(),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleBreakAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 22),
                        SizedBox(width: 8),
                        Text('Resume Work',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700))
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakSetup(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderCard(theme, isDark),
        const SizedBox(height: 20),
        _buildBreakTypeSelector(theme, isDark),
        const SizedBox(height: 20),
        _buildNotesSection(theme, isDark),
        const SizedBox(height: 28),
        _buildStartButton(theme),
      ],
    );
  }

  Widget _buildHeaderCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 10))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.coffee_outlined,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Take a Break',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                Text('Select your break type below',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakTypeSelector(ThemeData theme, bool isDark) {
    final breakTypes = [
      {
        'type': BreakType.lunch,
        'icon': Icons.restaurant_rounded,
        'label': 'Lunch',
        'color': Colors.orangeAccent
      },
      {
        'type': BreakType.tea,
        'icon': Icons.coffee_rounded,
        'label': 'Tea Break',
        'color': AppColors.primary
      },
      {
        'type': BreakType.rest,
        'icon': Icons.nights_stay_rounded,
        'label': 'Rest',
        'color': AppColors.info
      },
      {
        'type': BreakType.personal,
        'icon': Icons.person_rounded,
        'label': 'Personal',
        'color': AppColors.indigo
      },
      {
        'type': BreakType.other,
        'icon': Icons.more_horiz_rounded,
        'label': 'Other',
        'color': Colors.grey
      },
    ];

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumHelpers.sectionHeader(theme, 'Break Type',
              icon: Icons.category_outlined),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: breakTypes.map((b) {
              final type = b['type'] as BreakType;
              final isSelected = _selectedBreakType == type;
              final color = b['color'] as Color;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedBreakType = type);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withValues(alpha: 0.18),
                              color.withValues(alpha: 0.08),
                            ],
                          )
                        : null,
                    color: isSelected
                        ? null
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : theme.colorScheme.surface),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isSelected
                            ? color.withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(b['icon'] as IconData,
                          size: 18,
                          color: isSelected
                              ? color
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4)),
                      const SizedBox(width: 8),
                      Text(b['label'] as String,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSelected ? color : null)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(ThemeData theme, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumHelpers.sectionHeader(theme, 'Notes',
              icon: Icons.notes_rounded),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Optional notes...',
              hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : theme.colorScheme.surface,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleBreakAction,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.free_breakfast_rounded, size: 22),
                  SizedBox(width: 10),
                  Text('Start Break',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700))
                ],
              ),
      ),
    );
  }
}
