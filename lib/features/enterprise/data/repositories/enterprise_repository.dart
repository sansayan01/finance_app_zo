import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/audit_log_model.dart';

class EnterpriseRepository {
  final SupabaseClient _client;

  EnterpriseRepository(this._client);

  /// Get audit logs
  Future<List<AuditLogModel>> getAuditLogs(
    String orgId, {
    int limit = 100,
    int offset = 0,
    String? action,
    String? entityType,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client.from('audit_logs').select().eq('org_id', orgId);

      if (action != null) query = query.eq('action', action);
      if (entityType != null) query = query.eq('entity_type', entityType);
      if (userId != null) query = query.eq('user_id', userId);
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return response.map((e) => AuditLogModel.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Log an audit event
  Future<void> logAuditEvent({
    required String orgId,
    String? userId,
    required String action,
    required String entityType,
    String? entityId,
    String? description,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String severity = 'info',
    String? category,
  }) async {
    try {
      await _client.rpc('log_audit_event', params: {
        'p_org_id': orgId,
        'p_user_id': userId,
        'p_action': action,
        'p_entity_type': entityType,
        'p_entity_id': entityId,
        'p_description': description,
        'p_old_values': oldValues,
        'p_new_values': newValues,
        'p_severity': severity,
        'p_category': category,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Get audit log stats
  Future<Map<String, dynamic>> getAuditStats(String orgId) async {
    try {
      final response = await _client
          .from('audit_logs')
          .select('action, severity, created_at')
          .eq('org_id', orgId);

      final now = DateTime.now();
      final today = response.where((e) {
        final createdAt = DateTime.parse(e['created_at'] as String);
        return createdAt.year == now.year &&
            createdAt.month == now.month &&
            createdAt.day == now.day;
      }).length;

      final byAction = <String, int>{};
      final bySeverity = <String, int>{};

      for (final e in response) {
        final action = e['action'] as String;
        final severity = e['severity'] as String;
        byAction[action] = (byAction[action] ?? 0) + 1;
        bySeverity[severity] = (bySeverity[severity] ?? 0) + 1;
      }

      return {
        'total': response.length,
        'today': today,
        'by_action': byAction,
        'by_severity': bySeverity,
      };
    } catch (e) {
      return {'total': 0, 'today': 0, 'by_action': {}, 'by_severity': {}};
    }
  }

  /// Export audit logs
  Future<String> exportAuditLogs(
    String orgId, {
    String format = 'csv',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final logs = await getAuditLogs(
        orgId,
        limit: 10000,
        startDate: startDate,
        endDate: endDate,
      );

      if (format == 'csv') {
        final buffer = StringBuffer();
        buffer.writeln('ID,Date,User,Action,Entity,Description,Severity');
        for (final log in logs) {
          buffer.writeln([
            log.id,
            log.createdAt.toIso8601String(),
            log.userEmail ?? 'System',
            log.action,
            log.entityType,
            log.description ?? '',
            log.severity,
          ].join(','));
        }
        return buffer.toString();
      }

      // JSON format
      return logs.map((e) => e.toJson()).toList().toString();
    } catch (e) {
      rethrow;
    }
  }
}
