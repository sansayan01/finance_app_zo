import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../enterprise/models/enterprise_models.dart';
import '../../../analytics/models/analytics_models.dart';
import '../../../operations/models/operations_models.dart';
import '../../../growth/models/growth_models.dart';

// ============================================
// ENTERPRISE PROVIDERS
// ============================================

/// Audit logs provider
final auditLogsProvider = FutureProvider.family<List<AuditLogModel>, String>((ref, orgId) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('audit_logs')
      .select()
      .eq('org_id', orgId)
      .order('created_at', ascending: false)
      .limit(100);
  
  return response.map<AuditLogModel>((json) => AuditLogModel.fromJson(json)).toList();
});

/// Organization settings provider
final orgSettingsProvider = FutureProvider.family<OrgSettingsModel?, String>((ref, orgId) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('org_settings')
      .select()
      .eq('org_id', orgId)
      .maybeSingle();
  
  if (response == null) return null;
  return OrgSettingsModel.fromJson(response);
});

// ============================================
// ANALYTICS PROVIDERS
// ============================================

/// Organization metrics provider
final orgMetricsProvider = FutureProvider.family<OrgMetricsModel?, String>((ref, orgId) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('org_metrics')
      .select()
      .eq('org_id', orgId)
      .maybeSingle();
  
  if (response == null) return null;
  return OrgMetricsModel.fromJson(response);
});

/// Custom reports provider
final customReportsProvider = FutureProvider.family<List<CustomReportModel>, String>((ref, orgId) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('custom_reports')
      .select()
      .eq('org_id', orgId)
      .order('created_at', ascending: false);
  
  return response.map<CustomReportModel>((json) => CustomReportModel.fromJson(json)).toList();
});

// ============================================
// OPERATIONS PROVIDERS
// ============================================

/// System status provider
final systemStatusProvider = FutureProvider<List<SystemStatusModel>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('system_status')
      .select()
      .inFilter('status', ['investigating', 'identified', 'monitoring'])
      .order('created_at', ascending: false);
  
  return response.map<SystemStatusModel>((json) => SystemStatusModel.fromJson(json)).toList();
});

/// Help articles provider
final helpArticlesProvider = FutureProvider.family<List<HelpArticleModel>, String?>((ref, category) async {
  final client = ref.watch(supabaseClientProvider);
  var query = client
      .from('help_articles')
      .select()
      .eq('status', 'published');
  
  if (category != null) {
    query = query.eq('category', category);
  }
  
  final response = await query.order('view_count', ascending: false);
  return response.map<HelpArticleModel>((json) => HelpArticleModel.fromJson(json)).toList();
});

/// Video tutorials provider
final videoTutorialsProvider = FutureProvider.family<List<VideoTutorialModel>, String?>((ref, category) async {
  final client = ref.watch(supabaseClientProvider);
  var query = client
      .from('video_tutorials')
      .select()
      .eq('status', 'published');
  
  if (category != null) {
    query = query.eq('category', category);
  }
  
  final response = await query.order('view_count', ascending: false);
  return response.map<VideoTutorialModel>((json) => VideoTutorialModel.fromJson(json)).toList();
});

// ============================================
// GROWTH PROVIDERS
// ============================================

/// Referrals provider
final referralsProvider = FutureProvider.family<List<ReferralModel>, String>((ref, orgId) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('referrals')
      .select()
      .eq('org_id', orgId)
      .order('created_at', ascending: false);
  
  return response.map<ReferralModel>((json) => ReferralModel.fromJson(json)).toList();
});

/// Feature requests provider
final featureRequestsProvider = FutureProvider<List<FeatureRequestModel>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('feature_requests')
      .select()
      .order('votes', ascending: false);
  
  return response.map<FeatureRequestModel>((json) => FeatureRequestModel.fromJson(json)).toList();
});

/// Announcements provider
final announcementsProvider = FutureProvider<List<AnnouncementModel>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('announcements')
      .select()
      .eq('status', 'published')
      .order('published_at', ascending: false)
      .limit(10);
  
  return response.map<AnnouncementModel>((json) => AnnouncementModel.fromJson(json)).toList();
});

