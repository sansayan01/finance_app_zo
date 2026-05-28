import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Service for compressing images before upload.
///
/// Resizes to a max dimension and compresses JPEG quality to minimize
/// storage usage on Supabase free tier.
class ImageCompressService {
  /// Default max dimension for profile pictures (width or height).
  static const int defaultMaxDimension = 256;

  /// Default JPEG quality (0-100). 35% is visually fine for avatars.
  static const int defaultQuality = 35;

  /// Compresses an image file and returns the compressed bytes.
  ///
  /// - [file]: The source image file.
  /// - [maxDimension]: Max width/height in pixels (default 256).
  /// - [quality]: JPEG quality 0-100 (default 35).
  ///
  /// Returns compressed image bytes as Uint8List, or null if compression fails.
  static Future<Uint8List?> compressFile(
    File file, {
    int maxDimension = defaultMaxDimension,
    int quality = defaultQuality,
  }) async {
    try {
      final filePath = file.absolute.path;
      final originalSize = await file.length();

      final result = await FlutterImageCompress.compressWithFile(
        filePath,
        minWidth: maxDimension,
        minHeight: maxDimension,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        final compressedSize = result.length;
        final savings =
            ((1 - compressedSize / originalSize) * 100).toStringAsFixed(1);
        debugPrint(
          'ImageCompress: ${_formatBytes(originalSize)} → '
          '${_formatBytes(compressedSize)} ($savings% saved)',
        );
      }

      return result;
    } catch (e) {
      debugPrint('ImageCompressService.compressFile error: $e');
      return null;
    }
  }

  /// Compresses image bytes directly (useful for web or when you already
  /// have bytes in memory).
  static Future<Uint8List?> compressBytes(
    Uint8List bytes, {
    int maxDimension = defaultMaxDimension,
    int quality = defaultQuality,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxDimension,
        minHeight: maxDimension,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      debugPrint(
        'ImageCompress: ${_formatBytes(bytes.length)} → '
        '${_formatBytes(result.length)} '
        '(${((1 - result.length / bytes.length) * 100).toStringAsFixed(1)}% saved)',
      );

      return result;
    } catch (e) {
      debugPrint('ImageCompressService.compressBytes error: $e');
      return null;
    }
  }

  /// Compresses and saves to a temporary file. Returns the temp file path.
  /// Useful when you need a File reference for upload APIs.
  static Future<File?> compressToTempFile(
    File file, {
    int maxDimension = defaultMaxDimension,
    int quality = defaultQuality,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        minWidth: maxDimension,
        minHeight: maxDimension,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      debugPrint('ImageCompressService.compressToTempFile error: $e');
      return null;
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
