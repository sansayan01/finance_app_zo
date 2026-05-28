import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:microflow_pro/core/constants/enums.dart';
import '../models/collection_model.dart';

class CollectionRepository {
  final SupabaseClient _client;
  final String _orgId;

  CollectionRepository(this._client, this._orgId);

  /// Get today's due EMIs for a staff member
  Future<List<Map<String, dynamic>>> getTodayDueEmis(String staffId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final response = await _client
        .from('loans')
        .select('''
           id,
          member_id,
          member_name,
          outstanding_balance,
          loan_number,
          members(
            id,
            full_name,
            phone,
            area,
            gps_lat,
            gps_lng,
            gps_address
          ),
          emi_schedule(
            id,
            period,
            due_date,
            emi_amount,
            principal,
            interest,
            balance_after,
            is_paid,
            is_overdue,
            penalty_amount
          )
        ''')
        .eq('agent_id', staffId)
        .eq('org_id', _orgId)
        .eq('status', 'active');

    // Filter schedules for today
    final result = <Map<String, dynamic>>[];
    for (final loan in response) {
      final schedules = loan['emi_schedule'] as List?;
      if (schedules != null) {
        for (final schedule in schedules) {
          if (schedule['due_date']?.toString().startsWith(today) == true &&
              schedule['is_paid'] == false) {
            result.add({
              ...loan,
              'current_schedule': schedule,
            });
          }
        }
      }
    }
    return result;
  }

  /// Get overdue EMIs for a staff member
  Future<List<Map<String, dynamic>>> getOverdueEmis(String staffId) async {
    final response = await _client
        .from('overdue_loans_view')
        .select()
        .eq('agent_id', staffId)
        .order('due_date', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Record a new collection
  Future<CollectionModel> recordCollection({
    required String staffId,
    String? loanId,
    String? loanScheduleId,
    String? memberId,
    required String memberName,
    String? memberPhone,
    String? loanNumber,
    required double amountExpected,
    required double amountCollected,
    bool isPartial = false,
    bool isAdvance = false,
    required PaymentMode paymentMode,
    String? referenceNumber,
    required double gpsLat,
    required double gpsLng,
    double? gpsAccuracy,
    String? gpsAddress,
    String? remarks,
  }) async {
    final now = DateTime.now();

    final payload = {
      'loan_id': loanId,
      'loan_schedule_id': loanScheduleId,
      'member_id': memberId,
      'staff_id': staffId,
      'member_name': memberName,
      'member_phone': memberPhone,
      'loan_number': loanNumber,
      'amount_expected': amountExpected,
      'amount_collected': amountCollected,
      'is_partial': isPartial,
      'is_advance': isAdvance,
      'payment_mode': paymentMode.name,
      'reference_number': referenceNumber,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'gps_accuracy': gpsAccuracy,
      'gps_address': gpsAddress,
      'collection_date': now.toIso8601String().split('T').first,
      'collection_time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
      'sync_status': 'synced',
      'remarks': remarks,
      'org_id': _orgId,
    };

    final response =
        await _client.from('collections').insert(payload).select().single();

    return CollectionModel.fromJson(response);
  }

  /// Get today's collections
  Future<List<CollectionModel>> getTodayCollections(String staffId) async {
    final today = DateTime.now().toIso8601String().split('T').first;

    final response = await _client
        .from('collections')
        .select()
        .eq('staff_id', staffId)
        .eq('collection_date', today)
        .order('collection_time', ascending: false);

    return response
        .map<CollectionModel>((json) => CollectionModel.fromJson(json))
        .toList();
  }

  /// Get collection history with parameters
  Future<List<Map<String, dynamic>>> getCollectionHistory(
    String staffId, {
    String? customerId,
    int? year,
    int? month,
    String? type,
    String? paymentMode,
    int limit = 100,
  }) async {
    var query = _client.from('collections').select('''
          id,
          member_id,
          member_name,
          member_phone,
          loan_number,
          loan_id,
          amount_collected,
          amount_expected,
          payment_mode,
          collection_date,
          collection_time,
          receipt_number,
          collection_type,
          is_partial,
          is_offline,
          sync_status,
          profiles!fk_collections_staff(full_name)
        ''').eq('staff_id', staffId);

    if (customerId != null) {
      query = query.eq('member_id', customerId);
    }

    if (year != null && month != null) {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0);
      query = query
          .filter('collection_date', 'gte',
              startDate.toIso8601String().split('T').first)
          .filter('collection_date', 'lte',
              endDate.toIso8601String().split('T').first);
    }

    if (type != null && type != 'all') {
      query = query.eq('collection_type', type);
    }

    if (paymentMode != null && paymentMode != 'all') {
      query = query.eq('payment_mode', paymentMode);
    }

    final response =
        await query.order('collection_time', ascending: false).limit(limit);

    // Flatten staff name
    return response.map((item) {
      final staff = item['profiles'] as Map<String, dynamic>?;
      return {
        ...Map<String, dynamic>.from(item),
        'staff_name': staff?['full_name'],
        'type': item['collection_type'],
        'amount': item['amount_collected'],
      };
    }).toList();
  }

  /// Get today's stats
  Future<Map<String, dynamic>> getTodayStats(String staffId) async {
    final today = DateTime.now().toIso8601String().split('T').first;

    final response = await _client
        .from('collections')
        .select('amount_collected, payment_mode')
        .eq('staff_id', staffId)
        .eq('collection_date', today);

    double totalCollected = 0;
    double cashCollected = 0;
    double digitalCollected = 0;
    int count = response.length;

    for (final item in response) {
      final amount = (item['amount_collected'] as num?)?.toDouble() ?? 0;
      totalCollected += amount;

      if (item['payment_mode'] == 'cash') {
        cashCollected += amount;
      } else {
        digitalCollected += amount;
      }
    }

    return {
      'total_collected': totalCollected,
      'cash_collected': cashCollected,
      'digital_collected': digitalCollected,
      'collection_count': count,
    };
  }

  /// Search customers by name, phone, or loan number
  Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    if (query.isEmpty) return [];

    final searchTerm = query.toLowerCase();

    final response = await _client
        .from('members')
        .select('''
          id,
          full_name,
          phone,
          area,
          gps_address,
          member_id,
          kyc_status,
          active_loans,
          total_savings,
          loans(
            id,
            loan_number,
            principal,
            outstanding_balance,
            status
          )
        ''')
        .or('full_name.ilike.%$searchTerm%,phone.ilike.%$searchTerm%,member_id.ilike.%$searchTerm%')
        .limit(20);

    // Calculate outstanding for each member
    final result = <Map<String, dynamic>>[];
    for (final member in response) {
      final loans = member['loans'] as List? ?? [];
      double outstanding = 0;
      String? loanNumber;

      for (final loan in loans) {
        if (loan['status'] == 'active') {
          outstanding += (loan['outstanding_balance'] as num?)?.toDouble() ?? 0;
          loanNumber ??= loan['loan_number'];
        }
      }

      result.add({
        ...member,
        'outstanding_balance': outstanding,
        'loan_number': loanNumber,
      });
    }

    return result;
  }

  /// Get customer detail with all info
  Future<Map<String, dynamic>?> getCustomerDetail(String customerId) async {
    final response = await _client.from('members').select('''
          *,
          loans(
            id,
            loan_number,
            principal,
            interest_rate,
            tenure_months,
            emi,
            outstanding_balance,
            status,
            start_date,
            paid_emis,
            total_emis,
            emi_schedule(
              id,
              period,
              due_date,
              emi_amount,
              is_paid,
              is_overdue
            )
          ),
          savings_plans(
            id,
            plan_name,
            current_amount,
            target_amount,
            monthly_deposit,
            status,
            collection_type
          )
        ''').eq('id', customerId).maybeSingle();

    if (response == null) return null;

    // Calculate stats
    double outstandingAmount = 0;
    double overdueAmount = 0;
    double nextDueAmount = 0;
    DateTime? nextDueDate;
    double collectionRate = 100;
    int paidEmis = 0;
    int totalEmis = 0;

    final loans = response['loans'] as List? ?? [];
    for (final loan in loans) {
      if (loan['status'] == 'active') {
        outstandingAmount +=
            (loan['outstanding_balance'] as num?)?.toDouble() ?? 0;
        paidEmis += (loan['paid_emis'] as num?)?.toInt() ?? 0;
        totalEmis += (loan['total_emis'] as num?)?.toInt() ??
            (loan['tenure'] as num?)?.toInt() ??
            0;

        final schedules = loan['emi_schedule'] as List? ?? [];
        for (final schedule in schedules) {
          if (schedule['is_overdue'] == true) {
            overdueAmount += (schedule['emi'] as num?)?.toDouble() ?? 0;
          }
          if (schedule['is_paid'] == false && nextDueDate == null) {
            final dueDate = DateTime.tryParse(schedule['due_date'] ?? '');
            if (dueDate != null) {
              nextDueDate = dueDate;
              nextDueAmount = (schedule['emi'] as num?)?.toDouble() ?? 0;
            }
          }
        }
      }
    }

    if (totalEmis > 0) {
      collectionRate = (paidEmis / totalEmis) * 100;
    }

    return {
      ...response,
      'outstanding_balance': outstandingAmount,
      'overdue_amount': overdueAmount,
      'next_due_amount': nextDueAmount,
      'next_due_date': nextDueDate?.toIso8601String(),
      'collection_rate': collectionRate,
    };
  }

  /// Get customer loans
  Future<List<Map<String, dynamic>>> getCustomerLoans(String customerId) async {
    final response = await _client.from('loans').select('''
          id,
          loan_number,
          principal,
          interest_rate,
          tenure_months,
          emi,
          outstanding_balance,
          status,
           start_date,
          paid_emis,
          total_emis,
          emi_schedule(
            id,
            period,
            due_date,
            emi_amount,
            principal,
            interest,
            balance_after,
            is_paid,
            is_overdue,
            paid_on,
            penalty_amount
          )
        ''').eq('member_id', customerId).order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get customer savings
  Future<List<Map<String, dynamic>>> getCustomerSavings(
      String customerId) async {
    final response = await _client.from('savings_plans').select('''
          id,
          plan_name,
          current_amount,
          target_amount,
          monthly_deposit,
          status,
          created_at,
          maturity_date,
          collection_type
        ''').eq('member_id', customerId).order('created_at', ascending: false);

    // Map current_amount → balance for backward compatibility
    return response.map((item) {
      return {
        ...Map<String, dynamic>.from(item),
        'balance': item['current_amount'],
      };
    }).toList();
  }

  /// Get customer collection history
  Future<List<Map<String, dynamic>>> getCustomerCollectionHistory(
    String customerId, {
    int limit = 50,
  }) async {
    final response = await _client
        .from('collections')
        .select('''
          id,
          amount_collected,
          amount_expected,
          payment_mode,
          collection_date,
          collection_time,
          receipt_number,
          loan_number,
          loan_id,
          collection_type,
          is_partial,
          is_offline,
          sync_status,
          profiles!fk_collections_staff(full_name)
        ''')
        .eq('member_id', customerId)
        .order('collection_time', ascending: false)
        .limit(limit);

    // Flatten staff name
    return response.map((item) {
      final staff = item['profiles'] as Map<String, dynamic>?;
      return {
        ...Map<String, dynamic>.from(item),
        'staff_name': staff?['full_name'],
        'type': item['collection_type'],
      };
    }).toList();
  }

  /// Get recent collections (for dashboard)
  Future<List<Map<String, dynamic>>> getRecentCollections(
    String staffId, {
    int limit = 20,
  }) async {
    final response = await _client
        .from('collections')
        .select('''
          id,
          member_id,
          member_name,
          member_phone,
          loan_number,
          amount_collected,
          payment_mode,
          collection_date,
          collection_time,
          receipt_number,
          is_offline,
          sync_status
        ''')
        .eq('staff_id', staffId)
        .order('collection_time', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get frequent customers (top by collection count)
  Future<List<Map<String, dynamic>>> getFrequentCustomers(
    String staffId, {
    int limit = 10,
  }) async {
    final response = await _client.rpc('get_frequent_customers', params: {
      'p_staff_id': staffId,
      'p_limit': limit,
    });

    return List<Map<String, dynamic>>.from(response);
  }
}
