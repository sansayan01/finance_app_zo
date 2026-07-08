import 'package:supabase_flutter/supabase_flutter.dart';

class SecurityPoliciesService {
  final SupabaseClient _client;
  final String _orgId;

  SecurityPoliciesService(this._client, this._orgId);

  Future<Map<String, dynamic>> _readSettings() async {
    try {
      final data = await _client
          .from('organizations')
          .select('settings')
          .eq('id', _orgId)
          .maybeSingle();
      if (data == null) return <String, dynamic>{};
      return (data['settings'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeSettings(Map<String, dynamic> settings) async {
    await _client
        .from('organizations')
        .update({'settings': settings}).eq('id', _orgId);
  }

  Future<Map<String, dynamic>> getSecurityPolicies() async {
    final settings = await _readSettings();
    return (settings['security_policies'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  }

  Future<void> savePasswordRules({
    required int minLength,
    required bool requireUppercase,
    required bool requireLowercase,
    required bool requireNumbers,
    required bool requireSpecial,
    required int maxAgeDays,
    required int recycleBuffer,
    required int maxLoginRetries,
  }) async {
    final settings = await _readSettings();
    final policies = Map<String, dynamic>.from(
        (settings['security_policies'] as Map?)?.cast<String, dynamic>() ?? {});

    policies['password'] = {
      'min_length': minLength,
      'require_uppercase': requireUppercase,
      'require_lowercase': requireLowercase,
      'require_numbers': requireNumbers,
      'require_special': requireSpecial,
      'max_age_days': maxAgeDays,
      'recycle_buffer': recycleBuffer,
      'max_login_retries': maxLoginRetries,
    };

    settings['security_policies'] = policies;
    await _writeSettings(settings);
  }

  Future<void> saveSessionConfig({
    required int autoLogoutMinutes,
    required int maxLoginRetries,
    required int lockoutDurationMinutes,
  }) async {
    final settings = await _readSettings();
    final policies = Map<String, dynamic>.from(
        (settings['security_policies'] as Map?)?.cast<String, dynamic>() ?? {});

    policies['session'] = {
      'auto_logout_minutes': autoLogoutMinutes,
      'max_login_retries': maxLoginRetries,
      'lockout_duration_minutes': lockoutDurationMinutes,
    };

    settings['security_policies'] = policies;
    await _writeSettings(settings);
  }

  Future<void> saveTwoFactorConfig({
    required bool enabled,
    required String method,
    required List<String> enforcedRoles,
  }) async {
    final settings = await _readSettings();
    final policies = Map<String, dynamic>.from(
        (settings['security_policies'] as Map?)?.cast<String, dynamic>() ?? {});

    policies['two_factor'] = {
      'enabled': enabled,
      'method': method,
      'enforced_roles': enforcedRoles,
    };

    settings['security_policies'] = policies;
    await _writeSettings(settings);
  }

  Future<void> saveAuditRetention({
    required int retentionDays,
    required bool autoArchive,
  }) async {
    final settings = await _readSettings();
    final policies = Map<String, dynamic>.from(
        (settings['security_policies'] as Map?)?.cast<String, dynamic>() ?? {});

    policies['audit_retention'] = {
      'retention_days': retentionDays,
      'auto_archive': autoArchive,
    };

    settings['security_policies'] = policies;
    await _writeSettings(settings);
  }
}
