import 'package:supabase_flutter/supabase_flutter.dart';

class SavingsProductsService {
  final SupabaseClient _client;
  final String _orgId;

  SavingsProductsService(this._client, this._orgId);

  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final data = await _client
          .from('savings_products')
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
          .from('savings_products')
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
    double interestRate = 0,
    String collectionType = 'monthly',
    double? minDeposit,
    double? maxDeposit,
    int tenure = 12,
    String tenureUnit = 'months',
    double prematurePenalty = 0,
    double? defaultInstallment,
    double? defaultMaturityAmount,
  }) async {
    final data = await _client
        .from('savings_products')
        .insert({
          'org_id': _orgId,
          'name': name,
          'description': description,
          'interest_rate': interestRate,
          'collection_type': collectionType,
          'min_deposit': minDeposit,
          'max_deposit': maxDeposit,
          'tenure': tenure,
          'tenure_unit': tenureUnit,
          'premature_penalty': prematurePenalty,
          'default_installment': defaultInstallment,
          'default_maturity_amount': defaultMaturityAmount,
        })
        .select('id')
        .maybeSingle();

    if (data == null) throw Exception('Failed to create savings product');
    return data['id'] as String;
  }

  Future<void> updateProduct(String id, {
    String? name,
    String? description,
    double? interestRate,
    String? collectionType,
    double? minDeposit,
    double? maxDeposit,
    int? tenure,
    String? tenureUnit,
    double? prematurePenalty,
    double? defaultInstallment,
    double? defaultMaturityAmount,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (interestRate != null) updates['interest_rate'] = interestRate;
    if (collectionType != null) updates['collection_type'] = collectionType;
    if (minDeposit != null) updates['min_deposit'] = minDeposit;
    if (maxDeposit != null) updates['max_deposit'] = maxDeposit;
    if (tenure != null) updates['tenure'] = tenure;
    if (tenureUnit != null) updates['tenure_unit'] = tenureUnit;
    if (prematurePenalty != null) updates['premature_penalty'] = prematurePenalty;
    if (defaultInstallment != null) updates['default_installment'] = defaultInstallment;
    if (defaultMaturityAmount != null) updates['default_maturity_amount'] = defaultMaturityAmount;
    if (isActive != null) updates['is_active'] = isActive;

    await _client.from('savings_products').update(updates).eq('id', id);
  }

  Future<void> deleteProduct(String id) async {
    await _client.from('savings_products').delete().eq('id', id);
  }

  Future<void> toggleActive(String id, bool isActive) async {
    await _client.from('savings_products').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }
}
