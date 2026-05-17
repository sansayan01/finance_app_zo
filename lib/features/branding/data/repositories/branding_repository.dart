import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/org_branding_model.dart';

class BrandingRepository {
  final SupabaseClient _client;

  BrandingRepository(this._client);

  /// Get branding for an organization
  Future<OrgBrandingModel?> getBranding(String orgId) async {
    try {
      final response = await _client
          .from('org_branding')
          .select()
          .eq('org_id', orgId)
          .maybeSingle();

      if (response == null) return null;
      return OrgBrandingModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Update branding
  Future<OrgBrandingModel> updateBranding(
    String orgId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();

      final response = await _client
          .from('org_branding')
          .update(updates)
          .eq('org_id', orgId)
          .select()
          .single();

      return OrgBrandingModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Upload logo
  Future<String> uploadLogo(
    String orgId,
    String filePath,
    List<int> bytes, {
    bool isDark = false,
  }) async {
    final fileName = isDark ? 'logo_dark.png' : 'logo.png';
    final storagePath = 'branding/$orgId/$fileName';

    await _client.storage.from('organization-assets').uploadBinary(
        storagePath, Uint8List.fromList(bytes),
        fileOptions: const FileOptions(upsert: true));

    final publicUrl =
        _client.storage.from('organization-assets').getPublicUrl(storagePath);

    // Update branding record
    await updateBranding(orgId, {
      isDark ? 'logo_dark_url' : 'logo_url': publicUrl,
    });

    return publicUrl;
  }

  /// Set custom domain
  Future<void> setCustomDomain(String orgId, String domain) async {
    try {
      // Generate verification token
      final response =
          await _client.rpc('generate_verification_token').single();
      final token = response as String;

      // Update branding
      await updateBranding(orgId, {
        'custom_domain': domain,
        'domain_verified': false,
        'domain_verification_token': token,
      });

      // Create custom domain record
      await _client.from('custom_domains').upsert({
        'org_id': orgId,
        'domain': domain,
        'verification_token': token,
        'verification_method': 'dns',
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Verify custom domain
  Future<bool> verifyCustomDomain(String orgId) async {
    try {
      // This would typically involve checking DNS records
      // For now, we'll simulate verification
      final branding = await getBranding(orgId);
      if (branding == null || branding.customDomain == null) return false;

      // In production, you'd check DNS TXT record
      // For demo, we'll mark as verified
      await updateBranding(orgId, {
        'domain_verified': true,
      });

      await _client.from('custom_domains').update({
        'verified': true,
        'status': 'active',
        'verified_at': DateTime.now().toIso8601String(),
      }).eq('org_id', orgId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update feature flags
  Future<void> updateFeatures(
    String orgId,
    Map<String, dynamic> features,
  ) async {
    try {
      final branding = await getBranding(orgId);
      if (branding == null) return;

      final updatedFeatures = {
        ...branding.features,
        ...features,
      };

      await updateBranding(orgId, {'features': updatedFeatures});
    } catch (e) {
      rethrow;
    }
  }

  /// Get email template
  Future<Map<String, dynamic>?> getEmailTemplate(
    String templateType, {
    String? orgId,
  }) async {
    try {
      // First try to get org-specific template
      if (orgId != null) {
        final orgTemplate = await _client
            .from('email_templates')
            .select()
            .eq('org_id', orgId)
            .eq('template_type', templateType)
            .maybeSingle();

        if (orgTemplate != null) return orgTemplate;
      }

      // Fall back to default template
      final defaultTemplate = await _client
          .from('email_templates')
          .select()
          .filter('org_id', 'is', null)
          .eq('template_type', templateType)
          .maybeSingle();

      return defaultTemplate;
    } catch (e) {
      return null;
    }
  }

  /// Update email template
  Future<void> updateEmailTemplate(
    String orgId,
    String templateType, {
    String? subject,
    String? htmlBody,
    String? textBody,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (subject != null) updates['subject'] = subject;
      if (htmlBody != null) updates['html_body'] = htmlBody;
      if (textBody != null) updates['text_body'] = textBody;
      updates['updated_at'] = DateTime.now().toIso8601String();

      await _client.from('email_templates').upsert({
        'org_id': orgId,
        'template_type': templateType,
        ...updates,
      });
    } catch (e) {
      rethrow;
    }
  }
}
