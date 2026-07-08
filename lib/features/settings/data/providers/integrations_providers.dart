import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../services/email_settings_service.dart';
import '../services/whatsapp_service.dart';

// ─── Email ──────────────────────────────────────────────────────

final emailSettingsServiceProvider = Provider<EmailSettingsService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId  = ref.watch(currentOrgIdOrThrowProvider);
  return EmailSettingsService(client, orgId);
});

final emailCommunicationsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final svc = ref.watch(emailSettingsServiceProvider);
  return svc.getCommunications();
});

// ─── WhatsApp ───────────────────────────────────────────────────

final whatsAppServiceProvider = Provider<WhatsAppService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId  = ref.watch(currentOrgIdOrThrowProvider);
  return WhatsAppService(client, orgId);
});

final whatsAppConfigProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final svc = ref.watch(whatsAppServiceProvider);
  return svc.getWhatsAppConfig();
});

final whatsAppTemplatesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final svc = ref.watch(whatsAppServiceProvider);
  return svc.getTemplates();
});
