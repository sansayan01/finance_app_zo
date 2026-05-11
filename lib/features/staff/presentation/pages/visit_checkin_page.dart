import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../data/models/staff_location_model.dart';
import '../../data/providers/staff_providers.dart';

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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _getCurrentVisitStatus();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await LocationService.getCurrentPosition();
      setState(() => _currentPosition = position);
    } catch (e) {
      _showError('Failed to get location: $e');
    }
  }

  Future<void> _getCurrentVisitStatus() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      final status = await ref.read(staffRepositoryProvider).getCurrentActivity(user.id);
      setState(() => _currentActivity = status);
    } catch (e) {
      // No active visit
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = _currentActivity == 'collecting';

    return Scaffold(
      appBar: AppBar(
        title: Text(isActive ? 'Check Out' : 'Check In'),
        actions: [
          if (isActive)
            TextButton.icon(
              onPressed: _isLoading ? null : _checkOut,
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Check Out', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLocationCard(theme),
            const SizedBox(height: 16),
            if (isActive) _buildActiveVisitCard(theme),
            if (!isActive) ...[
              _buildPurposeSelector(theme),
              const SizedBox(height: 16),
              _buildNotesField(theme),
              const SizedBox(height: 24),
              _buildCheckInButton(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _currentPosition != null ? Icons.gps_fixed : Icons.gps_not_fixed,
                  color: _currentPosition != null ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Location',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_currentPosition != null) ...[
              _buildLocationRow('Lat', '${_currentPosition!.latitude.toStringAsFixed(6)}'),
              _buildLocationRow('Long', '${_currentPosition!.longitude.toStringAsFixed(6)}'),
              _buildLocationRow('Accuracy', '${_currentPosition!.accuracy.toStringAsFixed(1)}m'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.verified,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'GPS Active',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                'Acquiring GPS signal...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Location'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveVisitCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Visit in Progress',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Purpose', _visitPurpose ?? 'Collection'),
            const SizedBox(height: 8),
            _buildInfoRow('Customer', widget.customerId ?? 'N/A'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isLoading ? null : _checkOut,
              icon: const Icon(Icons.stop),
              label: const Text('Complete Visit'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPurposeSelector(ThemeData theme) {
    final purposes = [
      {'id': 'collection', 'icon': Icons.payments, 'label': 'Collection'},
      {'id': 'verification', 'icon': Icons.verified_user, 'label': 'Verification'},
      {'id': 'follow_up', 'icon': Icons.follow_the_signs, 'label': 'Follow Up'},
      {'id': 'document', 'icon': Icons.description, 'label': 'Document Collection'},
      {'id': 'other', 'icon': Icons.more_horiz, 'label': 'Other'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visit Purpose',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: purposes.map((p) {
            final isSelected = _visitPurpose == p['id'];
            return ChoiceChip(
              avatar: Icon(
                p['icon'] as IconData,
                size: 18,
                color: isSelected ? Colors.white : null,
              ),
              label: Text(p['label'] as String),
              selected: isSelected,
              selectedColor: theme.colorScheme.primary,
              onSelected: (selected) {
                setState(() => _visitPurpose = selected ? p['id'] as String : null);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNotesField(ThemeData theme) {
    return TextField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Notes (Optional)',
        hintText: 'Add any relevant notes for this visit...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildCheckInButton(ThemeData theme) {
    final canCheckIn = _currentPosition != null && _visitPurpose != null;

    return Column(
      children: [
        FilledButton.icon(
          onPressed: (_isLoading || !canCheckIn) ? null : _checkIn,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.login),
          label: Text(_isLoading ? 'Checking In...' : 'Check In'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (!canCheckIn) ...[
          const SizedBox(height: 8),
          Text(
            _currentPosition == null ? 'Waiting for GPS...' : 'Select a visit purpose',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _checkIn() async {
    if (_currentPosition == null || _visitPurpose == null) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not authenticated');

      await ref.read(staffRepositoryProvider).logVisit(
        staffId: user.id,
        customerId: widget.customerId,
        purpose: _visitPurpose!,
        checkInLat: _currentPosition!.latitude,
        checkInLng: _currentPosition!.longitude,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      setState(() => _currentActivity = 'collecting');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checked in successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to check in: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkOut() async {
    if (_currentPosition == null) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not authenticated');

      await ref.read(staffRepositoryProvider).completeVisit(
        staffId: user.id,
        checkOutLat: _currentPosition!.latitude,
        checkOutLng: _currentPosition!.longitude,
      );

      setState(() => _currentActivity = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checked out successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      _showError('Failed to check out: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
