import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_compress_service.dart';

/// Handles profile avatar picking, compression, and upload to Supabase Storage.
class AvatarUploadService {
  static const String _bucketName = 'avatars';

  /// Maximum file size allowed after compression (200 KB).
  static const int _maxFileSizeBytes = 200 * 1024;

  final SupabaseClient _client;

  AvatarUploadService(this._client);

  /// Pick an image from gallery or camera, compress it, and upload to Supabase.
  ///
  /// Returns the public URL of the uploaded avatar, or null if cancelled/failed.
  Future<String?> pickAndUploadAvatar({
    required String userId,
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      // 1. Pick image
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024, // Pre-limit before compression
        maxHeight: 1024,
      );

      if (picked == null) return null;

      // 2. Compress
      final file = File(picked.path);
      final compressed = await ImageCompressService.compressFile(
        file,
        maxDimension: 256,
        quality: 35,
      );

      if (compressed == null) {
        debugPrint('AvatarUpload: compression failed, using original');
        // Fallback: try with bytes directly
        final bytes = await file.readAsBytes();
        return await _uploadBytes(bytes, userId);
      }

      // 3. Check size cap
      if (compressed.length > _maxFileSizeBytes) {
        debugPrint(
            'AvatarUpload: still too large (${compressed.length} bytes), '
            're-compressing at lower quality');
        final recompressed = await ImageCompressService.compressBytes(
          compressed,
          maxDimension: 200,
          quality: 20,
        );
        return await _uploadBytes(recompressed ?? compressed, userId);
      }

      return await _uploadBytes(compressed, userId);
    } catch (e) {
      debugPrint('AvatarUploadService.pickAndUploadAvatar error: $e');
      return null;
    }
  }

  /// Upload raw bytes to Supabase Storage and return the public URL.
  Future<String?> _uploadBytes(Uint8List bytes, String userId) async {
    try {
      final filePath = 'profiles/$userId.jpg';

      // Upload (upsert to overwrite existing avatar)
      await _client.storage.from(_bucketName).uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Get public URL
      final publicUrl =
          _client.storage.from(_bucketName).getPublicUrl(filePath);

      debugPrint('AvatarUpload: uploaded successfully → $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('AvatarUploadService._uploadBytes error: $e');
      return null;
    }
  }

  /// Update the avatar_url in the profiles table.
  Future<bool> updateProfileAvatarUrl(
      String profileId, String avatarUrl) async {
    try {
      await _client.from('profiles').update({
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', profileId);
      return true;
    } catch (e) {
      debugPrint('AvatarUploadService.updateProfileAvatarUrl error: $e');
      return false;
    }
  }

  /// Delete the avatar from storage.
  Future<bool> deleteAvatar(String userId) async {
    try {
      final filePath = 'profiles/$userId.jpg';
      await _client.storage.from(_bucketName).remove([filePath]);
      return true;
    } catch (e) {
      debugPrint('AvatarUploadService.deleteAvatar error: $e');
      return false;
    }
  }
}
