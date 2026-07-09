import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/utils/location_permission_helper.dart';

enum GpsStatus {
  active,
  inactive,
  noPermission,
  disabled,
  lowAccuracy,
}

class GpsStatusChip extends StatelessWidget {
  final GpsStatus status;
  final double? accuracy;
  final VoidCallback? onTap;

  const GpsStatusChip({
    super.key,
    required this.status,
    this.accuracy,
    this.onTap,
  });

  factory GpsStatusChip.fromPosition(Position? position,
      {VoidCallback? onTap}) {
    if (position == null) {
      return GpsStatusChip(status: GpsStatus.inactive, onTap: onTap);
    }

    final accuracy = position.accuracy;
    if (accuracy > 100) {
      return GpsStatusChip(
        status: GpsStatus.lowAccuracy,
        accuracy: accuracy,
        onTap: onTap,
      );
    }

    return GpsStatusChip(
      status: GpsStatus.active,
      accuracy: accuracy,
      onTap: onTap,
    );
  }

  static Future<GpsStatus> checkStatus() async {
    final status = await LocationPermissionHelper.checkStatus();
    switch (status) {
      case LocationPermissionStatus.granted:
        return GpsStatus.active;
      case LocationPermissionStatus.serviceDisabled:
        return GpsStatus.disabled;
      case LocationPermissionStatus.denied:
      case LocationPermissionStatus.permanentlyDenied:
        return GpsStatus.noPermission;
      default:
        return GpsStatus.inactive;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getBackgroundColor(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getColor().withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing dot
            if (status == GpsStatus.active) _buildPulsingDot(),

            // Icon
            Icon(
              _getIcon(),
              color: _getColor(),
              size: 16,
            ),
            const SizedBox(width: 6),

            // Text
            Text(
              _getText(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: _getColor(),
                fontWeight: FontWeight.w700,
              ),
            ),

            // Accuracy
            if (accuracy != null && status == GpsStatus.active) ...[
              const SizedBox(width: 4),
              Text(
                '±${accuracy!.toStringAsFixed(0)}m',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _getColor().withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingDot() {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.5, end: 1.0),
        duration: const Duration(milliseconds: 1000),
        builder: (context, value, child) {
          return Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withValues(alpha: 0.5 * value),
                  blurRadius: 4 * value,
                  spreadRadius: 2 * value,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getBackgroundColor(bool isDark) {
    final color = _getColor();
    if (isDark) return color.withValues(alpha: 0.1);
    return color.withValues(alpha: 0.08);
  }

  Color _getColor() {
    switch (status) {
      case GpsStatus.active:
        return Colors.greenAccent;
      case GpsStatus.lowAccuracy:
        return Colors.orangeAccent;
      case GpsStatus.inactive:
      case GpsStatus.noPermission:
      case GpsStatus.disabled:
        return Colors.redAccent;
    }
  }

  IconData _getIcon() {
    switch (status) {
      case GpsStatus.active:
        return Icons.gps_fixed_rounded;
      case GpsStatus.lowAccuracy:
        return Icons.gps_not_fixed_rounded;
      case GpsStatus.inactive:
      case GpsStatus.noPermission:
        return Icons.gps_off_rounded;
      case GpsStatus.disabled:
        return Icons.location_off_rounded;
    }
  }

  String _getText() {
    switch (status) {
      case GpsStatus.active:
        return 'GPS Active';
      case GpsStatus.lowAccuracy:
        return 'Low Accuracy';
      case GpsStatus.inactive:
        return 'GPS Inactive';
      case GpsStatus.noPermission:
        return 'No Permission';
      case GpsStatus.disabled:
        return 'GPS Disabled';
    }
  }
}
