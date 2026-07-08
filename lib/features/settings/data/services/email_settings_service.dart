import 'package:supabase_flutter/supabase_flutter.dart';

class EmailSettingsService {
  final SupabaseClient _client;
  final String _orgId;

  EmailSettingsService(this._client, this._orgId);

  Future<Map<String, dynamic>> getCommunications() async {
    try {
      final data = await _client
          .from('organizations')
          .select('settings')
          .eq('id', _orgId)
          .maybeSingle();
      if (data == null) return <String, dynamic>{};
      final settings = data['settings'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return (settings['communications'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> saveCommunications({
    required String provider,
    String? smtpHost,
    int? smtpPort,
    String? smtpUsername,
    String? smtpPassword,
    String? apiKey,
    String? fromEmail,
    String? fromName,
  }) async {
    final data = await _client
        .from('organizations')
        .select('settings')
        .eq('id', _orgId)
        .maybeSingle();
    final settings = Map<String, dynamic>.from(data?['settings'] as Map? ?? {});
    final comms = Map<String, dynamic>.from(settings['communications'] as Map? ?? {});

    comms['provider'] = provider;

    if (provider == 'smtp') {
      comms['smtp_host'] = smtpHost;
      comms['smtp_port'] = smtpPort;
      comms['smtp_username'] = smtpUsername;
      comms['smtp_password'] = smtpPassword;
      comms.remove('api_key');
    } else if (provider == 'resend') {
      comms['api_key'] = apiKey;
      comms.remove('smtp_host');
      comms.remove('smtp_port');
      comms.remove('smtp_username');
      comms.remove('smtp_password');
    } else {
      comms.remove('api_key');
      comms.remove('smtp_host');
      comms.remove('smtp_port');
      comms.remove('smtp_username');
      comms.remove('smtp_password');
    }

    if (fromEmail != null) comms['from_email'] = fromEmail;
    if (fromName != null) comms['from_name'] = fromName;

    settings['communications'] = comms;
    await _client.from('organizations').update({'settings': settings}).eq('id', _orgId);
  }

  Future<bool> sendTestEmail(String toEmail) async {
    try {
      final data = await _client
          .from('organizations')
          .select('settings')
          .eq('id', _orgId)
          .maybeSingle();
      final settings = (data?['settings'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final comms = (settings['communications'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final provider = comms['provider'] as String?;

      if (provider == null || provider.isEmpty || provider == 'none') return false;

      final fromEmail = (comms['from_email'] as String?) ?? 'noreply@microflowpro.com';

      final res = await _client.functions.invoke(
        'send-email',
        body: {
          'to': toEmail,
          'subject': 'Test Email from MicroFlow Pro',
          'html': '<h2>Test Email</h2><p>Your email configuration is working correctly.</p>',
          'orgId': _orgId,
          'replyTo': fromEmail,
        },
      );

      return res.data != null && (res.data as Map<String, dynamic>)['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
