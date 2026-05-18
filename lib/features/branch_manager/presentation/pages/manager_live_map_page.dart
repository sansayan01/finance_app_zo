import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:microflow_pro/core/constants/app_colors.dart';
import 'package:microflow_pro/features/staff/data/providers/live_tracking_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerLiveMapPage extends ConsumerStatefulWidget {
  const ManagerLiveMapPage({super.key});

  @override
  ConsumerState<ManagerLiveMapPage> createState() => _ManagerLiveMapPageState();
}

class _ManagerLiveMapPageState extends ConsumerState<ManagerLiveMapPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _radarCtrl;
  late MapController _mapController;
  RealtimeChannel? _channel;
  Timer? _refreshTimer;
  String? _selectedStaffId;
  bool _showList = true;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _radarCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
    _initRealtime();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _refreshSnapshot());
  }

  Future<void> _initRealtime() async {
    final snapshot = await ref
        .read(liveTrackingRepositoryProvider)
        .getLatestAgentLocations();
    if (!mounted) return;
    ref.read(liveAgentLocationsProvider.notifier).seedFromSnapshot(snapshot);

    // Auto-fit map to agents after loading
    if (snapshot.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToAgents());
    }

    final channel =
        ref.read(liveTrackingRepositoryProvider).subscribeToAgentLocations(
      onUpdate: (payload) {
        if (!mounted) return;
        ref
            .read(liveAgentLocationsProvider.notifier)
            .applyRealtimeUpdate(payload);
      },
    );
    ref.read(liveAgentLocationsProvider.notifier).setChannel(channel);
    _channel = channel;
  }

  Future<void> _refreshSnapshot() async {
    final snapshot = await ref
        .read(liveTrackingRepositoryProvider)
        .getLatestAgentLocations();
    if (!mounted) return;
    ref.read(liveAgentLocationsProvider.notifier).seedFromSnapshot(snapshot);
  }

  void _fitMapToAgents() {
    if (!_isMapReady) return;
    final agents = ref.read(liveAgentLocationsProvider);
    final active = agents.values
        .where((a) => a['latitude'] != null && a['longitude'] != null)
        .toList();

    if (active.isEmpty) return;

    if (active.length == 1) {
      final a = active.first;
      _mapController.move(
        LatLng((a['latitude'] as num).toDouble(),
            (a['longitude'] as num).toDouble()),
        14,
      );
      return;
    }

    // Calculate bounding box
    final lats = active.map((a) => (a['latitude'] as num).toDouble()).toList();
    final lngs = active.map((a) => (a['longitude'] as num).toDouble()).toList();
    final bounds = LatLngBounds(
      LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
      LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
    );
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  void _focusAgent(Map<String, dynamic> agent) {
    if (!_isMapReady) return;
    final lat = (agent['latitude'] as num?)?.toDouble();
    final lng = (agent['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    _mapController.move(LatLng(lat, lng), 15);
    setState(() => _selectedStaffId = agent['staff_id'] as String?);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _radarCtrl.dispose();
    _mapController.dispose();
    _refreshTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final agents = ref.watch(liveAgentLocationsProvider);
    final agentList = agents.values.toList();
    final activeCount = agentList.where((a) => a['is_active'] == true).length;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF0F4FF),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // ── Full-screen map ────────────────────────────────
            _buildMap(isDark, agentList),

            // ── Header overlay ─────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildHeader(theme, isDark, activeCount, agentList.length),
            ),

            // ── Stats strip overlay ────────────────────────────
            Positioned(
              top: 74,
              left: 16,
              right: 16,
              child: _buildStatsBar(theme, isDark, agentList),
            ),

            // ── Bottom sheet: agent list ───────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomSheet(theme, isDark, agentList),
            ),

            // ── Fit-to-agents FAB ──────────────────────────────
            Positioned(
              bottom: _showList ? 320 : 24,
              right: 16,
              child: _buildFABs(agentList),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Full-screen Map ──────────────────────────────────────────────────────

  Widget _buildMap(bool isDark, List<Map<String, dynamic>> agentList) {
    final markers = agentList
        .where((a) => a['latitude'] != null && a['longitude'] != null)
        .map((agent) => _buildMarker(agent))
        .toList();

    // Build polyline for selected agent's breadcrumb
    final breadcrumbsAsync = _selectedStaffId != null
        ? ref.watch(agentBreadcrumbsProvider(_selectedStaffId!))
        : null;

    final breadcrumbPoints = breadcrumbsAsync?.valueOrNull
            ?.map((p) => LatLng(
                  (p['latitude'] as num).toDouble(),
                  (p['longitude'] as num).toDouble(),
                ))
            .toList() ??
        [];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(20.5937, 78.9629), // India center
        initialZoom: 5,
        onMapReady: () => setState(() {
          _isMapReady = true;
          _fitMapToAgents();
        }),
      ),
      children: [
        // Base tile layer (OpenStreetMap)
        TileLayer(
          urlTemplate: isDark
              ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
              : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.microflow.pro',
        ),

        // Breadcrumb trail for selected agent
        if (breadcrumbPoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: breadcrumbPoints,
                strokeWidth: 3,
                color: AppColors.primary.withValues(alpha: 0.7),
                borderColor: AppColors.primary.withValues(alpha: 0.2),
                borderStrokeWidth: 5,
              ),
            ],
          ),

        // Agent markers
        MarkerLayer(markers: markers),
      ],
    );
  }

  Marker _buildMarker(Map<String, dynamic> agent) {
    final lat = (agent['latitude'] as num).toDouble();
    final lng = (agent['longitude'] as num).toDouble();
    final name = agent['full_name'] as String? ?? 'A';
    final activityType = agent['activity_type'] as String? ?? 'idle';
    final isActive = agent['is_active'] == true;
    final isSelected = _selectedStaffId == agent['staff_id'];
    final color = _activityColor(activityType);

    return Marker(
      point: LatLng(lat, lng),
      width: isSelected ? 70 : 52,
      height: isSelected ? 80 : 60,
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: () => _focusAgent(agent),
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isActive)
                Container(
                  width: isSelected ? 14 : 10,
                  height: isSelected ? 14 : 10,
                  decoration: BoxDecoration(
                    color: color
                        .withValues(alpha: 0.2 + _pulseCtrl.value * 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: color.withValues(alpha: 0.1), width: 2),
                  ),
                ),
              Container(
                width: isSelected ? 48 : 36,
                height: isSelected ? 48 : 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.9), color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(
                          alpha: isActive
                              ? 0.3 + _pulseCtrl.value * 0.3
                              : 0.2),
                      blurRadius: isSelected ? 16 : 8,
                      spreadRadius: isSelected ? 2 : 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    name[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSelected ? 20 : 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              // Pin tail
              Container(
                width: 2,
                height: 8,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(
      ThemeData theme, bool isDark, int active, int total) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF181C24).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back_rounded,
                  color: isDark ? Colors.white70 : Colors.black87, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Field Agent Tracker',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3)),
                Text('$active active · $total agents',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.45),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.success
                    .withValues(alpha: 0.08 + _pulseCtrl.value * 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.success.withValues(
                              alpha: 0.5 + _pulseCtrl.value * 0.5),
                          blurRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                const Text('LIVE',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.success,
                        letterSpacing: 0.5)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _refreshSnapshot();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: AppColors.primary, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats Bar ────────────────────────────────────────────────────────────

  Widget _buildStatsBar(
      ThemeData theme, bool isDark, List<Map<String, dynamic>> agents) {
    final active = agents.where((a) => a['is_active'] == true).length;
    final traveling = agents
        .where((a) =>
            a['is_active'] == true && a['activity_type'] == 'traveling')
        .length;
    final collecting = agents
        .where((a) =>
            a['is_active'] == true && a['activity_type'] == 'collecting')
        .length;
    final idle = agents
        .where(
            (a) => a['is_active'] == true && a['activity_type'] == 'idle')
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF181C24).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statChip(active.toString(), 'ACTIVE', AppColors.success),
          _divider(),
          _statChip(traveling.toString(), 'MOVING', AppColors.primary),
          _divider(),
          _statChip(collecting.toString(), 'COLLECT', AppColors.accent),
          _divider(),
          _statChip(idle.toString(), 'IDLE', Colors.orange),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _statChip(String val, String label, Color color) => Column(
        children: [
          Text(val,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1)),
          const SizedBox(height: 1),
          Text(label,
              style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                  color: color.withValues(alpha: 0.7),
                  letterSpacing: 0.3)),
        ],
      );

  Widget _divider() => Container(
      width: 1, height: 24, color: AppColors.primary.withValues(alpha: 0.1));

  // ─── FABs ────────────────────────────────────────────────────────────────

  Widget _buildFABs(List<Map<String, dynamic>> agentList) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fit all agents
        FloatingActionButton.small(
          heroTag: 'fit',
          backgroundColor: AppColors.primary,
          onPressed: () {
            HapticFeedback.lightImpact();
            _fitMapToAgents();
          },
          child: const Icon(Icons.fit_screen_rounded,
              color: Colors.white, size: 18),
        ),
        const SizedBox(height: 8),
        // Toggle list
        FloatingActionButton.small(
          heroTag: 'list',
          backgroundColor: Colors.white,
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() => _showList = !_showList);
          },
          child: Icon(
              _showList
                  ? Icons.expand_more_rounded
                  : Icons.people_rounded,
              color: AppColors.primary,
              size: 18),
        ),
      ],
    );
  }

  // ─── Bottom Sheet: Agent List ─────────────────────────────────────────────

  Widget _buildBottomSheet(
      ThemeData theme, bool isDark, List<Map<String, dynamic>> agentList) {
    return AnimatedContainer(
      duration: 300.ms,
      height: _showList ? 300 : 0,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1117) : Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
              blurRadius: 24,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Field Agents',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text('${agentList.length} total',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: agentList.isEmpty
                ? Center(
                    child: Text('No agents reporting location',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.3),
                            fontSize: 13,
                            fontWeight: FontWeight.w500)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: agentList.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (ctx, i) =>
                        _buildAgentChip(theme, isDark, agentList[i], i),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentChip(ThemeData theme, bool isDark,
      Map<String, dynamic> agent, int index) {
    final name = agent['full_name'] as String? ?? 'Unknown';
    final staffCode = agent['staff_code'] as String? ?? '';
    final activityType = agent['activity_type'] as String? ?? 'idle';
    final isActive = agent['is_active'] == true;
    final battery = (agent['battery_level'] as num?)?.toInt();
    final recordedAt = agent['recorded_at'] != null
        ? DateTime.tryParse(agent['recorded_at'] as String)
        : null;
    final branchName = agent['branch_name'] as String? ?? '';
    final color = _activityColor(activityType);
    final isSelected = _selectedStaffId == agent['staff_id'];

    return GestureDetector(
      onTap: () => _focusAgent(agent),
      child: AnimatedContainer(
        duration: 250.ms,
        width: 160,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.4)
                : theme.colorScheme.onSurface.withValues(alpha: 0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.8), color],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    if (isActive)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, __) => Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF0F1117)
                                      : Colors.white,
                                  width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withValues(
                                      alpha: 0.4 + _pulseCtrl.value * 0.4),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                if (battery != null)
                  Icon(
                    battery > 50
                        ? Icons.battery_full_rounded
                        : battery > 20
                            ? Icons.battery_4_bar_rounded
                            : Icons.battery_alert_rounded,
                    size: 13,
                    color: battery < 20
                        ? Colors.red
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name.split(' ').first,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (staffCode.isNotEmpty)
              Text(staffCode,
                  style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700)),
            if (branchName.isNotEmpty)
              Text(branchName,
                  style: TextStyle(
                      fontSize: 9,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.35),
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(
                _activityLabel(activityType),
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: color),
              ),
            ),
            if (recordedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _timeAgo(recordedAt),
                  style: TextStyle(
                      fontSize: 9,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.35),
                      fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 400.ms, delay: (index * 40).ms)
          .slideY(begin: 0.1, end: 0),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Color _activityColor(String type) {
    switch (type) {
      case 'traveling':
        return AppColors.primary;
      case 'collecting':
        return AppColors.accent;
      case 'resting':
        return Colors.orange;
      case 'idle':
      default:
        return Colors.grey;
    }
  }

  String _activityLabel(String type) {
    switch (type) {
      case 'traveling':
        return '🚗 Moving';
      case 'collecting':
        return '💰 Collecting';
      case 'resting':
        return '☕ Break';
      case 'idle':
      default:
        return '⏸ Idle';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return DateFormat('HH:mm').format(dt);
  }
}
