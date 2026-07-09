import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:microflow_pro/core/constants/app_colors.dart';
import 'package:microflow_pro/features/staff/data/providers/live_tracking_providers.dart';

/// Bottom sheet for viewing historical location data with playback.
class LocationHistorySheet extends ConsumerStatefulWidget {
  final String staffId;
  final String staffName;

  const LocationHistorySheet({
    super.key,
    required this.staffId,
    required this.staffName,
  });

  @override
  ConsumerState<LocationHistorySheet> createState() => _LocationHistorySheetState();
}

class _LocationHistorySheetState extends ConsumerState<LocationHistorySheet>
    with SingleTickerProviderStateMixin {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _breadcrumbs = [];
  bool _isLoading = false;
  bool _isPlaying = false;
  int _currentIndex = 0;
  Timer? _playbackTimer;
  double _playbackSpeed = 1.0;

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _breadcrumbs = [];
      _currentIndex = 0;
      _isPlaying = false;
    });
    _playbackTimer?.cancel();

    try {
      final repo = ref.read(liveTrackingRepositoryProvider);
      final data = await repo.getBreadcrumbsForDateRange(
        widget.staffId,
        _startDate,
        _endDate.add(const Duration(hours: 23, minutes: 59)),
      );
      setState(() {
        _breadcrumbs = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _togglePlayback() {
    if (_breadcrumbs.isEmpty) return;

    setState(() => _isPlaying = !_isPlaying);

    if (_isPlaying) {
      _playbackTimer = Timer.periodic(
        Duration(milliseconds: (200 / _playbackSpeed).round()),
        (_) {
          if (_currentIndex < _breadcrumbs.length - 1) {
            setState(() => _currentIndex++);
          } else {
            setState(() {
              _isPlaying = false;
              _currentIndex = 0;
            });
            _playbackTimer?.cancel();
          }
        },
      );
    } else {
      _playbackTimer?.cancel();
    }
  }

  void _setSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    if (_isPlaying) {
      _playbackTimer?.cancel();
      _playbackTimer = Timer.periodic(
        Duration(milliseconds: (200 / speed).round()),
        (_) {
          if (_currentIndex < _breadcrumbs.length - 1) {
            setState(() => _currentIndex++);
          } else {
            setState(() {
              _isPlaying = false;
              _currentIndex = 0;
            });
            _playbackTimer?.cancel();
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.history, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Location History — ${widget.staffName}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Date range selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _dateButton('From', _startDate, (date) {
                  if (date != null) setState(() => _startDate = date);
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 16),
                ),
                _dateButton('To', _endDate, (date) {
                  if (date != null) setState(() => _endDate = date);
                }),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadData,
                  icon: _isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search, size: 18),
                  label: const Text('Load'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Playback controls
          if (_breadcrumbs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _togglePlayback,
                    icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle),
                    iconSize: 36,
                    color: AppColors.primary,
                  ),
                  Expanded(
                    child: Slider(
                      value: _currentIndex.toDouble(),
                      min: 0,
                      max: (_breadcrumbs.length - 1).toDouble().clamp(1, double.infinity),
                      onChanged: (v) => setState(() => _currentIndex = v.round()),
                    ),
                  ),
                  Text(
                    '${_currentIndex + 1}/${_breadcrumbs.length}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          // Speed selector
          if (_breadcrumbs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [1.0, 2.0, 4.0].map((speed) {
                  final isSelected = _playbackSpeed == speed;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text('${speed.toInt()}x'),
                      selected: isSelected,
                      onSelected: (_) => _setSpeed(speed),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
          // Current point info
          if (_breadcrumbs.isNotEmpty && _currentIndex < _breadcrumbs.length)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.red),
                  title: Text(
                    _breadcrumbs[_currentIndex]['activity_type']?.toString() ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    DateFormat('MMM d, yyyy — HH:mm:ss').format(
                      DateTime.parse(_breadcrumbs[_currentIndex]['recorded_at']),
                    ),
                  ),
                  trailing: Text(
                    '${(_breadcrumbs[_currentIndex]['speed'] as num?)?.toStringAsFixed(1) ?? '0'} m/s',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          // Empty state
          if (!_isLoading && _breadcrumbs.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_off, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No location data for this date range', style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 16),
                    Text('Select dates and tap Load', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dateButton(String label, DateTime date, ValueChanged<DateTime?> onTap) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now().subtract(const Duration(days: 90)),
          lastDate: DateTime.now(),
        );
        onTap(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            Text(DateFormat('MMM d, yyyy').format(date), style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
