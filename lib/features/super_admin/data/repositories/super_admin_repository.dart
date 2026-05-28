import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/super_admin_models.dart';

/// Super Admin Repository
/// Handles all platform-wide management operations
class SuperAdminRepository {
  final SupabaseClient _client;

  SuperAdminRepository(this._client);

  // =====================================================
  // PLATFORM METRICS
  // =====================================================

  /// Get current platform metrics
  Future<PlatformMetrics> getPlatformMetrics() async {
    try {
      final response = await _client.rpc('get_platform_metrics');
      return PlatformMetrics.fromJson(response);
    } catch (e) {
      // Return empty metrics on error
      return const PlatformMetrics();
    }
  }

  /// Get platform daily metrics for date range
  Future<List<Map<String, dynamic>>> getPlatformDailyMetrics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _client
          .from('platform_daily_metrics')
          .select()
          .gte('metric_date', startDate.toIso8601String().split('T')[0])
          .lte('metric_date', endDate.toIso8601String().split('T')[0])
          .order('metric_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // =====================================================
  // ORGANIZATIONS
  // =====================================================

  /// Get all organizations with pagination
  Future<List<Map<String, dynamic>>> getAllOrganizations({
    int limit = 50,
    int offset = 0,
    String? search,
    String? status,
  }) async {
    try {
      var query = _client.from('organizations').select('''
            id,
            name,
            slug,
            status,
            plan,
            created_at,
            profiles:profiles(count),
            branches:branches(count),
            members:members(count)
          ''');

      if (search != null && search.isNotEmpty) {
        query = query.ilike('name', '%$search%');
      }

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Get organization by ID with full details
  Future<Map<String, dynamic>?> getOrganizationById(String orgId) async {
    try {
      final response = await _client.from('organizations').select('''
            *,
            profiles:profiles(id, full_name, email, role, created_at),
            branches:branches(*),
            subscriptions:subscriptions(*)
          ''').eq('id', orgId).single();

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Update organization status
  Future<bool> updateOrganizationStatus(String orgId, String status) async {
    try {
      await _client.from('organizations').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', orgId);
      return true;
    } catch (e) {
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
    try {
      await _client.from('organizations').insert({
        'name': name,
        'slug': slug,
        'plan': plan,
        'status': status,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get organization health score
  Future<OrganizationHealthScore?> getOrganizationHealth(String orgId) async {
    try {
      final response = await _client
          .from('organization_health_scores')
          .select()
          .eq('org_id', orgId)
          .order('score_date', ascending: false)
          .limit(1)
          .single();

      return OrganizationHealthScore.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // =====================================================
  // USERS
  // =====================================================

  /// Get all users across platform
  Future<List<Map<String, dynamic>>> getAllUsers({
    int limit = 50,
    int offset = 0,
    String? search,
    String? role,
  }) async {
    try {
      var query = _client.from('profiles').select('''
            id,
            full_name,
            email,
            phone,
            role,
            is_active,
            created_at,
            last_login,
            organizations:org_id(id, name)
          ''');

      if (search != null && search.isNotEmpty) {
        query = query.or('full_name.ilike.%$search%,email.ilike.%$search%');
      }

      if (role != null && role.isNotEmpty) {
        query = query.eq('role', role);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Get user activity log
  Future<List<Map<String, dynamic>>> getUserActivityLog(
    String userId, {
    int limit = 100,
  }) async {
    try {
      final response = await _client
          .from('platform_activity_feed')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Update user status
  Future<bool> updateUserStatus(String userId, bool isActive) async {
    try {
      await _client.from('profiles').update({
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // =====================================================
  // FEATURE FLAGS
  // =====================================================

  /// Get all feature flags
  Future<List<FeatureFlag>> getFeatureFlags() async {
    try {
      final response = await _client
          .from('feature_flags')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      return response
          .map<FeatureFlag>((json) => FeatureFlag.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Create or update feature flag
  Future<bool> upsertFeatureFlag(FeatureFlag flag) async {
    try {
      await _client.from('feature_flags').upsert({
        ...flag.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Toggle feature flag
  Future<bool> toggleFeatureFlag(String flagId, bool isEnabled) async {
    try {
      await _client.from('feature_flags').update({
        'is_enabled': isEnabled,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', flagId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // =====================================================
  // PLATFORM ANNOUNCEMENTS
  // =====================================================

  /// Get all announcements
  Future<List<PlatformAnnouncement>> getAnnouncements(
      {bool activeOnly = false}) async {
    try {
      var query = _client.from('platform_announcements').select();

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response =
          await query.order('created_at', ascending: false).limit(100);
      return response
          .map<PlatformAnnouncement>(
              (json) => PlatformAnnouncement.fromJson(json))
          .toList();
    } catch (e) {
      return [];
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
    try {
      await _client.from('platform_announcements').insert({
        'title': title,
        'message': message,
        'type': type,
        'target_audience': targetAudience,
        'target_orgs': targetOrgs ?? [],
        'show_from': showFrom?.toIso8601String(),
        'show_until': showUntil?.toIso8601String(),
      });
      return true;
    } catch (e) {
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
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (title != null) updates['title'] = title;
      if (message != null) updates['message'] = message;
      if (type != null) updates['type'] = type;
      if (targetAudience != null) updates['target_audience'] = targetAudience;
      if (targetOrgs != null) updates['target_orgs'] = targetOrgs;
      if (showFrom != null) updates['show_from'] = showFrom.toIso8601String();
      if (showUntil != null) {
        updates['show_until'] = showUntil.toIso8601String();
      }
      if (isActive != null) updates['is_active'] = isActive;

      await _client.from('platform_announcements').update(updates).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete announcement
  Future<bool> deleteAnnouncement(String id) async {
    try {
      await _client.from('platform_announcements').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update announcement status
  Future<bool> updateAnnouncementStatus(
      String announcementId, bool isActive) async {
    try {
      await _client.from('platform_announcements').update({
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', announcementId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // =====================================================
  // AUDIT LOGS
  // =====================================================

  /// Get system audit logs
  Future<List<SystemAuditLog>> getAuditLogs({
    int limit = 100,
    String? action,
    String? entityType,
    String? orgId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client.from('audit_logs').select();

      if (action != null) {
        query = query.eq('action', action);
      }
      if (entityType != null) {
        query = query.eq('entity_type', entityType);
      }
      if (orgId != null) {
        query = query.eq('org_id', orgId);
      }
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);
      return response
          .map<SystemAuditLog>((json) => SystemAuditLog.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Log audit event
  Future<void> logAuditEvent({
    required String action,
    required String entityType,
    String? entityId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? orgId,
  }) async {
    try {
      await _client.from('audit_logs').insert({
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'old_values': oldValues,
        'new_values': newValues,
        'org_id': orgId,
        'user_id': _client.auth.currentUser?.id,
      });
    } catch (e) {
      // Silently fail audit logging
    }
  }

  // =====================================================
  // SUPPORT TICKETS
  // =====================================================

  /// Get all support tickets
  Future<List<SupportTicket>> getSupportTickets({
    String? status,
    String? priority,
    int limit = 50,
  }) async {
    try {
      var query = _client.from('support_tickets').select();

      if (status != null) {
        query = query.eq('status', status);
      }
      if (priority != null) {
        query = query.eq('priority', priority);
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);
      return response
          .map<SupportTicket>((json) => SupportTicket.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Update ticket status
  Future<bool> updateTicketStatus(String ticketId, String status,
      {String? assignedTo}) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (assignedTo != null) {
        updates['assigned_to'] = assignedTo;
      }

      if (status == 'resolved') {
        updates['resolved_at'] = DateTime.now().toIso8601String();
      }

      await _client.from('support_tickets').update(updates).eq('id', ticketId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Add message to ticket
  Future<bool> addTicketMessage(
      String ticketId, String message, bool isInternal) async {
    try {
      // Get current messages
      final ticket = await _client
          .from('support_tickets')
          .select('messages')
          .eq('id', ticketId)
          .single();

      final messages =
          List<Map<String, dynamic>>.from(ticket['messages'] ?? []);
      messages.add({
        'content': message,
        'is_internal': isInternal,
        'created_at': DateTime.now().toIso8601String(),
        'created_by': _client.auth.currentUser?.id,
      });

      await _client.from('support_tickets').update({
        'messages': messages,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', ticketId);

      return true;
    } catch (e) {
      return false;
    }
  }

  // =====================================================
  // MAINTENANCE
  // =====================================================

  /// Get maintenance windows
  Future<List<MaintenanceWindow>> getMaintenanceWindows(
      {bool activeOnly = false}) async {
    try {
      var query = _client.from('maintenance_windows').select();

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query
          .order('scheduled_start', ascending: false)
          .limit(50);
      return response
          .map<MaintenanceWindow>((json) => MaintenanceWindow.fromJson(json))
          .toList();
    } catch (e) {
      return [];
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
    try {
      await _client.from('maintenance_windows').insert({
        'title': title,
        'description': description,
        'scheduled_start': scheduledStart.toIso8601String(),
        'scheduled_end': scheduledEnd.toIso8601String(),
        'affected_services': affectedServices ?? [],
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Toggle maintenance mode
  Future<bool> toggleMaintenanceMode(String windowId, bool isActive) async {
    try {
      await _client
          .from('maintenance_windows')
          .update({'is_active': isActive}).eq('id', windowId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // =====================================================
  // REVENUE
  // =====================================================

  /// Get platform revenue
  Future<List<PlatformRevenue>> getRevenue({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int limit = 100,
  }) async {
    try {
      var query = _client.from('platform_revenue').select();

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }
      if (status != null) {
        query = query.eq('status', status);
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);
      return response
          .map<PlatformRevenue>((json) => PlatformRevenue.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get revenue summary
  Future<Map<String, dynamic>> getRevenueSummary({int months = 12}) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: months * 30));

      final response = await _client
          .from('platform_revenue')
          .select('amount, status, created_at')
          .gte('created_at', startDate.toIso8601String())
          .eq('status', 'completed');

      final revenues = List<Map<String, dynamic>>.from(response);

      final totalRevenue =
          revenues.fold<double>(0, (sum, r) => sum + (r['amount'] ?? 0));
      final avgMonthly = totalRevenue / months;

      return {
        'total_revenue': totalRevenue,
        'avg_monthly_revenue': avgMonthly,
        'transaction_count': revenues.length,
      };
    } catch (e) {
      return {
        'total_revenue': 0,
        'avg_monthly_revenue': 0,
        'transaction_count': 0,
      };
    }
  }

  // =====================================================
  // PLATFORM SETTINGS
  // =====================================================

  /// Get platform settings
  Future<Map<String, dynamic>> getPlatformSettings() async {
    try {
      final response = await _client
          .from('platform_settings')
          .select()
          .limit(50);

      final settings = <String, dynamic>{};
      for (final item in response) {
        settings[item['key']] = item['value'];
      }
      return settings;
    } catch (e) {
      return {};
    }
  }

  /// Update platform setting
  Future<bool> updatePlatformSetting(String key, dynamic value) async {
    try {
      await _client.from('platform_settings').upsert({
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'key');
      return true;
    } catch (e) {
      return false;
    }
  }

  // =====================================================
  // ERROR LOGS
  // =====================================================

  /// Get system error logs
  Future<List<Map<String, dynamic>>> getErrorLogs({
    bool? resolved,
    int limit = 100,
  }) async {
    try {
      var query = _client.from('system_error_logs').select();

      if (resolved != null) {
        query = query.eq('resolved', resolved);
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Mark error as resolved
  Future<bool> resolveError(String errorId) async {
    try {
      await _client.from('system_error_logs').update({
        'resolved': true,
        'resolved_by': _client.auth.currentUser?.id,
        'resolved_at': DateTime.now().toIso8601String(),
      }).eq('id', errorId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // =====================================================
  // API USAGE
  // =====================================================

  /// Get API usage statistics
  Future<Map<String, dynamic>> getApiUsageStats({int days = 7}) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));

      final response = await _client
          .from('api_usage_logs')
          .select('endpoint, method, status_code, response_time_ms, created_at')
          .gte('created_at', startDate.toIso8601String());

      final logs = List<Map<String, dynamic>>.from(response);

      // Calculate stats
      final endpointCounts = <String, int>{};
      final statusCounts = <int, int>{};
      var totalResponseTime = 0;

      for (final log in logs) {
        final endpoint = log['endpoint'] as String;
        final status = log['status_code'] as int;
        final responseTime = log['response_time_ms'] as int? ?? 0;

        endpointCounts[endpoint] = (endpointCounts[endpoint] ?? 0) + 1;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        totalResponseTime += responseTime;
      }

      return {
        'total_requests': logs.length,
        'unique_endpoints': endpointCounts.length,
        'endpoint_counts': endpointCounts,
        'status_counts': statusCounts,
        'avg_response_time':
            logs.isNotEmpty ? totalResponseTime / logs.length : 0,
      };
    } catch (e) {
      return {
        'total_requests': 0,
        'unique_endpoints': 0,
        'endpoint_counts': {},
        'status_counts': {},
        'avg_response_time': 0,
      };
    }
  }

  // =====================================================
  // DASHBOARD COUNTS
  // =====================================================

  /// Get count of open support tickets
  Future<int> getOpenTicketsCount() async {
    try {
      final response = await _client
          .from('support_tickets')
          .select('id')
          .inFilter('status', ['open', 'in_progress']);
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Get count of at-risk organizations (trial ending soon or suspended)
  Future<int> getAtRiskOrgsCount() async {
    try {
      final now = DateTime.now();
      final soon = now.add(const Duration(days: 7));
      final response = await _client
          .from('organizations')
          .select('id')
          .or('status.eq.suspended,trial_ends_at.lte.${soon.toIso8601String()}');
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  // =====================================================
  // REAL-TIME ACTIVITY
  // =====================================================

  /// Get real-time activity feed
  Future<List<Map<String, dynamic>>> getActivityFeed({int limit = 50}) async {
    try {
      final response = await _client.from('platform_activity_feed').select('''
            *,
            profiles:user_id(full_name, email),
            organizations:org_id(name)
          ''').order('created_at', ascending: false).limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Log activity
  Future<void> logActivity({
    required String activityType,
    Map<String, dynamic>? activityData,
    String? orgId,
    String? branchId,
  }) async {
    try {
      await _client.from('platform_activity_feed').insert({
        'activity_type': activityType,
        'activity_data': activityData ?? {},
        'org_id': orgId,
        'branch_id': branchId,
        'user_id': _client.auth.currentUser?.id,
      });
    } catch (e) {
      // Silently fail activity logging
    }
  }
}
