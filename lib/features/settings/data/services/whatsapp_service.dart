import 'package:supabase_flutter/supabase_flutter.dart';

class WhatsAppService {
  final SupabaseClient _client;
  final String _orgId;

  WhatsAppService(this._client, this._orgId);

  // ── Config CRUD ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getWhatsAppConfig() async {
    try {
      final data = await _client
          .from('organizations')
          .select('settings')
          .eq('id', _orgId)
          .maybeSingle();
      if (data == null) return <String, dynamic>{};
      final settings = data['settings'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return (settings['whatsapp'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> saveWhatsAppConfig({
    required String phoneNumberId,
    required String businessAccountId,
    required String accessToken,
  }) async {
    final data = await _client
        .from('organizations')
        .select('settings')
        .eq('id', _orgId)
        .maybeSingle();
    final settings = Map<String, dynamic>.from(data?['settings'] as Map? ?? {});
    settings['whatsapp'] = {
      'phone_number_id': phoneNumberId,
      'business_account_id': businessAccountId,
      'access_token': accessToken,
    };
    await _client.from('organizations').update({'settings': settings}).eq('id', _orgId);
  }

  Future<void> deleteWhatsAppConfig() async {
    final data = await _client
        .from('organizations')
        .select('settings')
        .eq('id', _orgId)
        .maybeSingle();
    final settings = Map<String, dynamic>.from(data?['settings'] as Map? ?? {});
    settings.remove('whatsapp');
    await _client.from('organizations').update({'settings': settings}).eq('id', _orgId);
  }

  // ── Template CRUD ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTemplates() async {
    final data = await _client
        .from('whatsapp_templates')
        .select()
        .eq('org_id', _orgId)
        .order('name');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<Map<String, dynamic>?> getTemplate(String templateKey) async {
    final data = await _client
        .from('whatsapp_templates')
        .select()
        .eq('org_id', _orgId)
        .eq('key', templateKey)
        .maybeSingle();
    return data;
  }

  Future<Map<String, dynamic>> createTemplate({
    required String name,
    required String language,
    required String category,
    required String body,
    List<String> variables = const [],
  }) async {
    final result = await _client
        .from('whatsapp_templates')
        .insert({
          'org_id': _orgId,
          'name': name,
          'language': language,
          'category': category,
          'body': body,
          'variables': variables,
        })
        .select()
        .single();
    return result;
  }

  Future<void> deleteTemplate(String templateId) async {
    await _client
        .from('whatsapp_templates')
        .delete()
        .eq('id', templateId)
        .eq('org_id', _orgId);
  }

  // ── Send Test ─────────────────────────────────────────────────

  Future<bool> sendTestMessage(String toPhone) async {
    try {
      final res = await _client.functions.invoke(
        'send-whatsapp',
        body: {
          'to': toPhone,
          'templateName': 'hello_world',
          'templateLanguage': 'en_US',
          'orgId': _orgId,
        },
      );
      return res.data != null && (res.data as Map<String, dynamic>)['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
