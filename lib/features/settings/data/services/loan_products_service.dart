import 'package:supabase_flutter/supabase_flutter.dart';

class LoanProductsService {
  final SupabaseClient _client;
  final String _orgId;

  LoanProductsService(this._client, this._orgId);

  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final data = await _client
          .from('loan_products')
          .select()
          .eq('org_id', _orgId)
          .order('name');
      return (data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getProduct(String id) async {
    try {
      final data = await _client
          .from('loan_products')
          .select()
          .eq('id', id)
          .maybeSingle();
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<String> createProduct({
    required String name,
    String? description,
    required double interestRate,
    String interestMode = 'reducing',
    String interestBasis = 'onPrincipal',
    double? minAmount,
    double? maxAmount,
    int tenureMonths = 12,
    String tenureUnit = 'months',
    String frequency = 'monthly',
    double processingFee = 0,
    double latePenaltyPct = 0,
    int gracePeriodDays = 0,
    String interestLogic = 'reducingBalance',
    double? defaultPrincipal,
  }) async {
    final data = await _client
        .from('loan_products')
        .insert({
          'org_id': _orgId,
          'name': name,
          'description': description,
          'interest_rate': interestRate,
          'interest_mode': interestMode,
          'interest_basis': interestBasis,
          'interest_logic': interestLogic,
          'default_principal': defaultPrincipal,
          'min_amount': minAmount,
          'max_amount': maxAmount,
          'tenure_months': tenureMonths,
          'tenure_unit': tenureUnit,
          'frequency': frequency,
          'processing_fee': processingFee,
          'late_penalty_pct': latePenaltyPct,
          'grace_period_days': gracePeriodDays,
        })
        .select('id')
        .maybeSingle();

    if (data == null) throw Exception('Failed to create loan product');
    return data['id'] as String;
  }

  Future<void> updateProduct(String id, {
    String? name,
    String? description,
    double? interestRate,
    String? interestMode,
    String? interestBasis,
    String? interestLogic,
    double? defaultPrincipal,
    double? minAmount,
    double? maxAmount,
    int? tenureMonths,
    String? tenureUnit,
    String? frequency,
    double? processingFee,
    double? latePenaltyPct,
    int? gracePeriodDays,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (interestRate != null) updates['interest_rate'] = interestRate;
    if (interestMode != null) updates['interest_mode'] = interestMode;
    if (interestBasis != null) updates['interest_basis'] = interestBasis;
    if (interestLogic != null) updates['interest_logic'] = interestLogic;
    if (defaultPrincipal != null) updates['default_principal'] = defaultPrincipal;
    if (minAmount != null) updates['min_amount'] = minAmount;
    if (maxAmount != null) updates['max_amount'] = maxAmount;
    if (tenureMonths != null) updates['tenure_months'] = tenureMonths;
    if (tenureUnit != null) updates['tenure_unit'] = tenureUnit;
    if (frequency != null) updates['frequency'] = frequency;
    if (processingFee != null) updates['processing_fee'] = processingFee;
    if (latePenaltyPct != null) updates['late_penalty_pct'] = latePenaltyPct;
    if (gracePeriodDays != null) updates['grace_period_days'] = gracePeriodDays;
    if (isActive != null) updates['is_active'] = isActive;

    await _client.from('loan_products').update(updates).eq('id', id);
  }

  Future<void> deleteProduct(String id) async {
    await _client.from('loan_products').delete().eq('id', id);
  }

  Future<void> toggleActive(String id, bool isActive) async {
    await _client.from('loan_products').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }
}
