import 'dart:io';
import 'package:flutter/services.dart';

/// Represents a preset app icon theme that can be applied at runtime.
class IconPreset {
  final String id;
  final String label;
  final String description;
  final int colorValue; // Preview color for the UI grid
  final String assetPreview; // Asset path for preview in the picker

  const IconPreset({
    required this.id,
    required this.label,
    required this.description,
    required this.colorValue,
    required this.assetPreview,
  });
}

/// All available icon presets bundled in the app.
/// These map 1:1 to activity-alias entries (Android) and alternate icons (iOS).
class IconPresets {
  IconPresets._();

  static const List<IconPreset> all = [
    IconPreset(
      id: 'default',
      label: 'MicroFlow Pro',
      description: 'Default platform branding',
      colorValue: 0xFF4F46E5,
      assetPreview: 'assets/icons/preset_default.png',
    ),
    IconPreset(
      id: 'bank_blue',
      label: 'Bank Blue',
      description: 'Professional banking aesthetic',
      colorValue: 0xFF1E40AF,
      assetPreview: 'assets/icons/preset_bank_blue.png',
    ),
    IconPreset(
      id: 'savings_green',
      label: 'Savings Green',
      description: 'Growth and savings focused',
      colorValue: 0xFF059669,
      assetPreview: 'assets/icons/preset_savings_green.png',
    ),
    IconPreset(
      id: 'micro_orange',
      label: 'Micro Orange',
      description: 'Warm and approachable',
      colorValue: 0xFFEA580C,
      assetPreview: 'assets/icons/preset_micro_orange.png',
    ),
    IconPreset(
      id: 'trust_purple',
      label: 'Trust Purple',
      description: 'Premium and trustworthy',
      colorValue: 0xFF7C3AED,
      assetPreview: 'assets/icons/preset_trust_purple.png',
    ),
    IconPreset(
      id: 'field_teal',
      label: 'Field Teal',
      description: 'Field operations and mobility',
      colorValue: 0xFF0D9488,
      assetPreview: 'assets/icons/preset_field_teal.png',
    ),
    IconPreset(
      id: 'future_swarupnagar',
      label: 'Future Swarupnagar',
      description: 'Future Swarupnagar branding',
      colorValue: 0xFF2563EB,
      assetPreview: 'assets/icons/preset_future_swarupnagar.png',
    ),
  ];

  static IconPreset getById(String id) {
    return all.firstWhere(
      (p) => p.id == id,
      orElse: () => all.first,
    );
  }
}

/// Service that communicates with native platform to switch the launcher icon.
class AppIconService {
  static const _channel = MethodChannel('com.microflow.app_icon');

  /// Check if the platform supports dynamic icon switching.
  static Future<bool> isSupported() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod<bool>('isSupported');
        return result ?? false;
      } else if (Platform.isIOS) {
        final result = await _channel.invokeMethod<bool>('isSupported');
        return result ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get the currently active icon preset ID.
  static Future<String> getCurrentIcon() async {
    try {
      final result = await _channel.invokeMethod<String>('getCurrentIcon');
      return result ?? 'default';
    } catch (e) {
      return 'default';
    }
  }

  /// Switch to a different icon preset.
  /// Returns true if the switch was successful.
  static Future<bool> setIcon(String presetId) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setIcon',
        {'iconName': presetId},
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}
