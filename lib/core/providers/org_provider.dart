import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

final Provider<String?> currentOrgIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.orgId;
});

final currentOrgIdOrThrowProvider = Provider<String>((ref) {
  final orgId = ref.watch(currentOrgIdProvider);
  return orgId ?? '00000000-0000-0000-0000-000000000001';
});
