import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/avatar_upload_service.dart';
import '../providers/user_list_provider.dart';

/// Provider for the avatar upload service.
final avatarUploadServiceProvider = Provider<AvatarUploadService>((ref) {
  return AvatarUploadService(Supabase.instance.client);
});

/// Notifier that manages avatar upload state for a specific user.
class AvatarUploadNotifier extends StateNotifier<AsyncValue<String?>> {
  final AvatarUploadService _service;
  final Ref _ref;

  AvatarUploadNotifier(this._service, this._ref)
      : super(const AsyncValue.data(null));

  /// Pick, compress, upload, and update the profile avatar.
  Future<String?> uploadAvatar({
    required String profileId,
    required String userId,
    ImageSource source = ImageSource.gallery,
  }) async {
    state = const AsyncValue.loading();

    try {
      // Upload to storage
      final url = await _service.pickAndUploadAvatar(
        userId: userId,
        source: source,
      );

      if (url == null) {
        state = const AsyncValue.data(null);
        return null;
      }

      // Update profile record
      final success = await _service.updateProfileAvatarUrl(profileId, url);

      if (success) {
        // Invalidate user list to refresh avatars everywhere
        _ref.invalidate(userListProvider);
        _ref.invalidate(userDetailsProvider(profileId));
        state = AsyncValue.data(url);
        return url;
      } else {
        state = AsyncValue.error(
            'Failed to update profile', StackTrace.current);
        return null;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Remove the avatar.
  Future<void> removeAvatar({
    required String profileId,
    required String userId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.deleteAvatar(userId);
      await _service.updateProfileAvatarUrl(profileId, '');
      _ref.invalidate(userListProvider);
      _ref.invalidate(userDetailsProvider(profileId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for avatar upload state.
final avatarUploadNotifierProvider =
    StateNotifierProvider<AvatarUploadNotifier, AsyncValue<String?>>((ref) {
  final service = ref.watch(avatarUploadServiceProvider);
  return AvatarUploadNotifier(service, ref);
});
