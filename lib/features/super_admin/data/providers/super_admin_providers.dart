import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../models/super_admin_models.dart';
import '../repositories/super_admin_repository.dart';

/// Super Admin Repository Provider
final superAdminRepositoryProvider = Provider.autoDispose<SuperAdminRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SuperAdminRepository(client);
});

/// Platform Metrics Provider
final platformMetricsProvider = FutureProvider.autoDispose<PlatformMetrics>((ref) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  final result = await repository.getPlatformMetrics();
  debugPrint('🔵 platformMetricsProvider: $result');
  return result;
});

/// All Organizations Provider
/// NOTE: family arg is a record (structural value equality). A plain Map would
/// create a new cache key on every build → infinite rebuild loop on the page.
final allOrganizationsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, OrgsQuery>(
        (ref, q) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  return repository.getAllOrganizations(
    limit: q.limit,
    offset: q.offset,
    search: q.search,
    status: q.status,
  );
});

/// Value-equal query record for [allOrganizationsProvider].
class OrgsQuery {
  final int limit;
  final int offset;
  final String? search;
  final String? status;
  const OrgsQuery({
    this.limit = 50,
    this.offset = 0,
    this.search,
    this.status,
  });

  @override
  bool operator ==(Object other) =>
      other is OrgsQuery &&
      other.limit == limit &&
      other.offset == offset &&
      other.search == search &&
      other.status == status;

  @override
  int get hashCode =>
      Object.hash(limit, offset, search, status);
}

/// Organization Details Provider
final organizationDetailsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, orgId) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  return repository.getOrganizationById(orgId);
});

/// Organization Full Detail Provider
/// 6 parallel queries → OrgDetailData typed model.
final orgDetailFullProvider =
    FutureProvider.autoDispose.family<OrgDetailData?, String>((ref, orgId) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  debugPrint('🔵 orgDetailFullProvider called for orgId: $orgId');
  final result = await repository.getOrganizationFullDetail(orgId);
  debugPrint('🔵 orgDetailFullProvider result: ${result != null ? "OrgDetailData(${result.memberCount} members, ${result.branches.length} branches)" : "NULL"}');
  return result;
});

/// Organization Health Provider
final organizationHealthProvider =
    FutureProvider.autoDispose.family<OrganizationHealthScore?, String>((ref, orgId) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  return repository.getOrganizationHealth(orgId);
});

/// All Users Provider
final allUsersProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Map<String, dynamic>>(
        (ref, params) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  return repository.getAllUsers(
    limit: params['limit'] ?? 50,
    offset: params['offset'] ?? 0,
    search: params['search'],
    role: params['role'],
  );
});

/// User Activity Log Provider
final userActivityLogProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, userId) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  return repository.getUserActivityLog(userId);
});

/// Feature Flags Provider
final featureFlagsProvider = FutureProvider.autoDispose<List<FeatureFlag>>((ref) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  return repository.getFeatureFlags();
});

/// Platform Announcements Provider
final platformAnnouncementsProvider =
    FutureProvider.autoDispose<List<PlatformAnnouncement>>((ref) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  return repository.getAnnouncements();
});

/// Audit Logs Provider
final auditLogsProvider =
    FutureProvider.autoDispose.family<List<SystemAuditLog>, Map<String, dynamic>>(
        (ref, params) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  return repository.getAuditLogs(
    limit: params['limit'] ?? 100,
    action: params['action'],
    entityType: params['entityType'],
    orgId: params['orgId'],
  );
});

/// Support Tickets Provider
final supportTicketsProvider =
    FutureProvider.autoDispose.family<List<SupportTicket>, Map<String, dynamic>>(
        (ref, params) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  return repository.getSupportTickets(
    status: params['status'],
    priority: params['priority'],
    limit: params['limit'] ?? 50,
  );
});

/// Maintenance Windows Provider
final maintenanceWindowsProvider =
    FutureProvider.autoDispose<List<MaintenanceWindow>>((ref) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  return repository.getMaintenanceWindows();
});

/// Platform Revenue Provider
final platformRevenueProvider =
    FutureProvider.autoDispose<List<PlatformRevenue>>((ref) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  return repository.getRevenue();
});

/// Revenue Summary Provider
final revenueSummaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  final result = await repository.getRevenueSummary();
      debugPrint('🔵 revenueSummaryProvider: $result');
      return result;
});

/// Platform Settings Provider
final platformSettingsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  return repository.getPlatformSettings();
});

/// API Usage Stats Provider
final apiUsageStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  return repository.getApiUsageStats();
});

/// Error Logs Provider
final errorLogsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  return repository.getErrorLogs();
});

/// Activity Feed Provider
final activityFeedProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  final result = await repository.getActivityFeed();
      debugPrint('🔵 activityFeedProvider: ${result.length} items');
      return result;
});

/// Open Tickets Count Provider
final openTicketsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  return repository.getOpenTicketsCount();
});

/// At Risk Orgs Count Provider
final atRiskOrgsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repository = ref.watch(superAdminRepositoryProvider);
  return repository.getAtRiskOrgsCount();
});

/// Super Admin Actions Notifier
class SuperAdminActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final SuperAdminRepository _repository;
  final Ref _ref;

  SuperAdminActionsNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  /// Update organization status
  Future<bool> updateOrganizationStatus(String orgId, String status) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repository.updateOrganizationStatus(orgId, status);
      if (success) {
        _ref.invalidate(allOrganizationsProvider);
        _ref.invalidate(orgDetailFullProvider(orgId));
        await _repository.logAuditEvent(
          action: 'update_status',
          entityType: 'organization',
          entityId: orgId,
          newValues: {'status': status},
        );
      }
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Create organization
  Future<bool> createOrganization({
    required String name,
    required String slug,
    String plan = 'free',
    String status = 'active',
  }) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repository.createOrganization(
        name: name,
        slug: slug,
        plan: plan,
        status: status,
      );
      if (success) {
        _ref.invalidate(allOrganizationsProvider);
      }
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Update user status
  Future<bool> updateUserStatus(String userId, bool isActive) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repository.updateUserStatus(userId, isActive);
      if (success) {
        _ref.invalidate(allUsersProvider);
        await _repository.logAuditEvent(
          action: isActive ? 'activate_user' : 'deactivate_user',
          entityType: 'user',
          entityId: userId,
        );
      }
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Toggle feature flag
  Future<bool> toggleFeatureFlag(String flagId, bool isEnabled) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repository.toggleFeatureFlag(flagId, isEnabled);
      if (success) {
        _ref.invalidate(featureFlagsProvider);
      }
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Create announcement
  Future<bool> createAnnouncement({
    required String title,
    required String message,
    String type = 'info',
    String targetAudience = 'all',
    List<String>? targetOrgs,
    DateTime? showFrom,
    DateTime? showUntil,
  }) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repository.createAnnouncement(
        title: title,
        message: message,
        type: type,
        targetAudience: targetAudience,
        targetOrgs: targetOrgs,
        showFrom: showFrom,
        showUntil: showUntil,
      );
      if (success) {
        _ref.invalidate(platformAnnouncementsProvider);
      }
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Update announcement
  Future<bool> updateAnnouncement({
    required String id,
    String? title,
    String? message,
    String? type,
    String? targetAudience,
    List<String>? targetOrgs,
    DateTime? showFrom,
    DateTime? showUntil,
    bool? isActive,
  }) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repository.updateAnnouncement(
        id: id,
        title: title,
        message: message,
        type: type,
        targetAudience: targetAudience,
        targetOrgs: targetOrgs,
        showFrom: showFrom,
        showUntil: showUntil,
        isActive: isActive,
      );
      if (success) {
        _ref.invalidate(platformAnnouncementsProvider);
      }
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Delete announcement
  Future<bool> deleteAnnouncement(String id) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repository.deleteAnnouncement(id);
      if (success) {
        _ref.invalidate(platformAnnouncementsProvider);
      }
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Update ticket status
  Future<bool> updateTicketStatus(String ticketId, String status,
      {String? assignedTo}) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repository.updateTicketStatus(ticketId, status,
          assignedTo: assignedTo);
      if (success) {
        _ref.invalidate(supportTicketsProvider);
      }
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Create maintenance window
  Future<bool> createMaintenanceWindow({
    required String title,
    String? description,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    List<String>? affectedServices,
  }) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repository.createMaintenanceWindow(
        title: title,
        description: description,
        scheduledStart: scheduledStart,
        scheduledEnd: scheduledEnd,
        affectedServices: affectedServices,
      );
      if (success) {
        _ref.invalidate(maintenanceWindowsProvider);
      }
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Update platform setting
  Future<bool> updatePlatformSetting(String key, dynamic value) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repository.updatePlatformSetting(key, value);
      if (success) {
        _ref.invalidate(platformSettingsProvider);
      }
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Resolve error
  Future<bool> resolveError(String errorId) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repository.resolveError(errorId);
      if (success) {
        _ref.invalidate(errorLogsProvider);
      }
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Super Admin Actions Provider
final superAdminActionsProvider =
    StateNotifierProvider.autoDispose<SuperAdminActionsNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(superAdminRepositoryProvider);
  return SuperAdminActionsNotifier(repository, ref);
});

/// Branch Locations Provider (for platform map)
final branchLocationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    return await client
        .from('branches')
        .select('id, name, location_lat, location_lng')
        .not('location_lat', 'is', null)
        .not('location_lng', 'is', null);
  } catch (e) {
    return [];
  }
});
