import 'package:flutter/material.dart';

/// GPS Accuracy Indicator
/// 
/// Shows the current GPS accuracy with a color-coded indicator.
/// Green = High accuracy (< 10m)
/// Yellow = Medium accuracy (10-50m)
/// Red = Low accuracy (> 50m)
class GpsAccuracyIndicator extends StatelessWidget {
  final double? accuracy; // in meters
  final bool isLocating;
  final double size;

  const GpsAccuracyIndicator({
    super.key,
    this.accuracy,
    this.isLocating = false,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (isLocating) {
      return SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (accuracy == null) {
      return Icon(
        Icons.location_off,
        size: size,
        color: Colors.grey,
      );
    }

    final (color, label) = _getAccuracyColorAndLabel(accuracy!);

    return Tooltip(
      message: 'GPS Accuracy: ${accuracy!.toStringAsFixed(0)}m ($label)',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.gps_fixed,
            size: size,
            color: color,
          ),
          if (size > 14) ...[
            const SizedBox(width: 4),
            Text(
              '${accuracy!.toStringAsFixed(0)}m',
              style: TextStyle(
                fontSize: size * 0.75,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  (Color, String) _getAccuracyColorAndLabel(double accuracyMeters) {
    if (accuracyMeters < 10) {
      return (Colors.green, 'High');
    } else if (accuracyMeters < 50) {
      return (Colors.orange, 'Medium');
    } else {
      return (Colors.red, 'Low');
    }
  }
}

/// GPS Status Card - Shows full GPS details
class GpsStatusCard extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? address;
  final bool isLocating;
  final VoidCallback? onRefresh;

  const GpsStatusCard({
    super.key,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.address,
    this.isLocating = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (accuracyColor, accuracyLabel) = accuracy != null
        ? _getAccuracyColorAndLabel(accuracy!)
        : (Colors.grey, 'Unknown');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2A) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLocating ? Icons.gps_not_fixed : Icons.gps_fixed,
                size: 20,
                color: accuracyColor,
              ),
              const SizedBox(width: 8),
              Text(
                'GPS Location',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              if (onRefresh != null)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: onRefresh,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLocating)
            const Center(child: CircularProgressIndicator())
          else if (latitude != null && longitude != null) ...[
            _buildDetailRow(
              'Coordinates',
              '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}',
            ),
            const SizedBox(height: 4),
            _buildDetailRow(
              'Accuracy',
              '${accuracy?.toStringAsFixed(0) ?? '?'}m ($accuracyLabel)',
              color: accuracyColor,
            ),
            if (address != null) ...[
              const SizedBox(height: 4),
              _buildDetailRow('Address', address!, maxLines: 2),
            ],
          ] else
            Text(
              'Location not available',
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color, int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
        style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  (Color, String) _getAccuracyColorAndLabel(double accuracyMeters) {
    if (accuracyMeters < 10) {
      return (Colors.green, 'High');
    } else if (accuracyMeters < 50) {
      return (Colors.orange, 'Medium');
    } else {
      return (Colors.red, 'Low');
    }
  }
}
