import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_feedback_model.dart';

/// Repository for managing customer feedback in the `customer_feedback` table.
class CustomerFeedbackRepository {
  final SupabaseClient _client;
  final String _orgId;

  CustomerFeedbackRepository(this._client, this._orgId);

  /// Fetches all feedback for a given customer, ordered by newest first.
  Future<List<CustomerFeedbackModel>> getFeedbacks(String customerId) async {
    try {
      final data = await _client
          .from('customer_feedback')
          .select()
          .eq('customer_id', customerId)
          .eq('org_id', _orgId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => CustomerFeedbackModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Submits a new feedback entry.
  Future<void> submitFeedback({
    required String customerId,
    required String type,
    String? subject,
    required String message,
    int? rating,
  }) async {
    await _client.from('customer_feedback').insert({
      'customer_id': customerId,
      'type': type,
      'subject': subject,
      'message': message,
      'rating': rating,
      'status': 'new',
      'org_id': _orgId,
    });
  }
}
