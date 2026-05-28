import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/providers/staff_providers.dart';
import '../../../../core/widgets/smokey_background.dart';
import '../widgets/premium_helpers.dart';

class VisitCheckInPage extends ConsumerStatefulWidget {
  final String? customerId;
  const VisitCheckInPage({super.key, this.customerId});

  @override
  ConsumerState<VisitCheckInPage> createState() => _VisitCheckInPageState();
}

class _VisitCheckInPageState extends ConsumerState<VisitCheckInPage> {
  bool _isLoading = false;
  Position? _currentPosition;
  String? _currentActivity;
  String? _visitPurpose;
  final _notesController = TextEditingController();
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _getCurrentVisitStatus();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentLocation();
      if (mounted) setState(() => _currentPosition = position);
    } catch (_) {}
  }

  Future<void> _getCurrentVisitStatus() async {
    final profile = await ref.read(staffProfileProvider.future);
    if (profile == null) return;
    try {
      final repository = ref.read(staffRepositoryProvider);
      final status = await repository.getCurrentActivity(profile.id);
      if (mounted) setState(() => _currentActivity = status);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActive = _currentActivity == 'collecting';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white70 : Colors.black87),
        ),
        title: Text(isActive ? 'Active Visit' : 'Check In',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
      ),
      body: SmokeyBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(activeVisitProvider);
            ref.invalidate(recentActivitiesProvider);
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isActive) _buildCheckInView(theme, isDark),
                  if (isActive) _buildActiveVisitView(theme, isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckInView(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderCard(theme, isDark, false),
        const SizedBox(height: 20),
        _buildLocationStatus(theme, isDark),
        const SizedBox(height: 20),
        _buildPurposeSelector(theme, isDark),
        const SizedBox(height: 20),
        _buildNotesField(theme, isDark),
        const SizedBox(height: 28),
        _buildActionButton(theme, false),
      ].animate(interval: 60.ms).fadeIn().slideY(begin: 0.04, end: 0),
    );
  }

  Widget _buildActiveVisitView(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderCard(theme, isDark, true),
        const SizedBox(height: 20),
        _buildActiveVisitCard(theme, isDark),
        const SizedBox(height: 20),
        _buildLocationStatus(theme, isDark),
        const SizedBox(height: 20),
        _buildNotesField(theme, isDark),
        const SizedBox(height: 28),
        _buildActionButton(theme, true),
      ].animate(interval: 60.ms).fadeIn().slideY(begin: 0.04, end: 0),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, bool isDark, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [Colors.green.shade600, Colors.teal.shade700]
              : [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (isActive ? Colors.green : AppColors.primary)
                .withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16)),
                child: Icon(
                  isActive ? Icons.check_circle_rounded : Icons.login_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isActive ? 'Visit in Progress' : 'Ready to Start',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    Text(
                        isActive
                            ? 'You are currently on a visit'
                            : 'Check in to begin your visit',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('Elapsed: ${_formatElapsed()}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationStatus(ThemeData theme, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_currentPosition != null
                      ? Colors.greenAccent
                      : Colors.orangeAccent)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _currentPosition != null
                  ? Icons.gps_fixed_rounded
                  : Icons.gps_not_fixed_rounded,
              color: _currentPosition != null
                  ? Colors.greenAccent
                  : Colors.orangeAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Location Status',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  _currentPosition != null
                      ? 'Lat ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng ${_currentPosition!.longitude.toStringAsFixed(4)}'
                      : 'Acquiring GPS signal...',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_currentPosition != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${_currentPosition!.accuracy.toStringAsFixed(0)}m',
                  style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            )
          else
            IconButton(
              onPressed: _getCurrentLocation,
              icon: Icon(Icons.refresh_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
        ],
      ),
    );
  }

  Widget _buildPurposeSelector(ThemeData theme, bool isDark) {
    final purposes = [
      {
        'id': 'collection',
        'icon': Icons.payments_rounded,
        'label': 'Collection',
        'color': AppColors.primary
      },
      {
        'id': 'verification',
        'icon': Icons.verified_user_rounded,
        'label': 'Verification',
        'color': Colors.greenAccent
      },
      {
        'id': 'follow_up',
        'icon': Icons.follow_the_signs_rounded,
        'label': 'Follow Up',
        'color': Colors.orangeAccent
      },
      {
        'id': 'document',
        'icon': Icons.description_rounded,
        'label': 'Document',
        'color': AppColors.indigo
      },
      {
        'id': 'other',
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
          PremiumHelpers.sectionHeader(theme, 'Visit Purpose',
              icon: Icons.flag_outlined),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: purposes.map((p) {
              final isSelected = _visitPurpose == p['id'];
              final color = p['color'] as Color;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() =>
                      _visitPurpose = isSelected ? null : p['id'] as String);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isSelected
                            ? color.withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(p['icon'] as IconData,
                          size: 18,
                          color: isSelected
                              ? color
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5)),
                      const SizedBox(width: 8),
                      Text(p['label'] as String,
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

  Widget _buildNotesField(ThemeData theme, bool isDark) {
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
            maxLines: 3,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Add any relevant notes...',
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

  Widget _buildActionButton(ThemeData theme, bool isActive) {
    final canCheckIn = _currentPosition != null && _visitPurpose != null;

    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: (_isLoading || (!isActive && !canCheckIn))
            ? null
            : (isActive ? _checkOut : _checkIn),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? Colors.redAccent : AppColors.primary,
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
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isActive ? Icons.logout_rounded : Icons.login_rounded,
                      size: 22),
                  const SizedBox(width: 10),
                  Text(
                    _isLoading
                        ? 'Processing...'
                        : (isActive
                            ? 'Complete Visit & Check Out'
                            : 'Check In Now'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _checkIn() async {
    if (_currentPosition == null || _visitPurpose == null) return;
    setState(() => _isLoading = true);
    try {
      final profile = await ref.read(staffProfileProvider.future);
      if (profile == null) {
        throw Exception(
            'Staff profile not found. Please contact your manager.');
      }
      final repo = ref.read(staffRepositoryProvider);
      await repo.logVisit(
        staffId: profile.id,
        orgId: profile.orgId ?? '',
        customerId: widget.customerId,
        purpose: _visitPurpose!,
        checkInLat: _currentPosition!.latitude,
        checkInLng: _currentPosition!.longitude,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );
      if (mounted) {
        setState(() {
          _currentActivity = 'collecting';
          _elapsedSeconds = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Checked in successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating));
      }
      ref.invalidate(activeVisitProvider);
      ref.invalidate(recentActivitiesProvider);
    } catch (e) {
      debugPrint('[CheckIn] Error: $e');
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkOut() async {
    if (_currentPosition == null) return;
    setState(() => _isLoading = true);
    try {
      final profile = await ref.read(staffProfileProvider.future);
      if (profile == null) throw Exception('No profile');
      final repo = ref.read(staffRepositoryProvider);
      await repo.completeVisit(
        staffId: profile.id,
        checkOutLat: _currentPosition!.latitude,
        checkOutLng: _currentPosition!.longitude,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Checked out successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating));
        context.pop();
      }
      ref.invalidate(activeVisitProvider);
      ref.invalidate(recentActivitiesProvider);
    } catch (e) {
      final msg = e.toString().contains('No active visit')
          ? 'No active visit found to check out from.'
          : 'Failed to check out. Please try again.';
      if (mounted) _showError(msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildActiveVisitCard(ThemeData theme, bool isDark) {
    final activeVisitAsync = ref.watch(activeVisitProvider);

    return activeVisitAsync.when(
      data: (visit) {
        if (visit == null) return const SizedBox.shrink();
        final member = visit['members'] as Map? ?? {};
        final name = member['full_name'] ?? 'Unknown Customer';
        final purpose = visit['purpose']?.toString().toUpperCase() ?? 'VISIT';

        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.person_pin_circle_rounded,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(purpose,
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildVisitStat(
                      theme, 'Started At', _formatTime(visit['check_in_time'])),
                  _buildVisitStat(theme, 'Duration', _formatElapsed()),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildVisitStat(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
        const SizedBox(height: 4),
        Text(value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  String _formatTime(dynamic time) {
    if (time == null) return '--:--';
    try {
      final dt = AppFormatters.convertToIST(DateTime.parse(time.toString()));
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }

  String _formatElapsed() {
    final h = _elapsedSeconds ~/ 3600;
    final m = (_elapsedSeconds % 3600) ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating));
  }
}
