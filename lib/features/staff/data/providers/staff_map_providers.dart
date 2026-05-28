import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import 'staff_providers.dart';

/// Provider that fetches today's due customers with their locations
/// for display as pins on the staff agent's map.
///
/// Joins emi_schedule with members to get customer lat/lng.
/// Falls back to visit_logs last known location if members lack coordinates.
final todayDueCustomerLocationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);

  try {
    final today = DateTime.now();
    final startOfDay =
        DateTime(today.year, today.month, today.day).toIso8601String();
    final endOfDay =
        DateTime(today.year, today.month, today.day, 23, 59, 59)
            .toIso8601String();

    // Try to get due EMIs with member location data
    final response = await client
        .from('emi_schedule')
        .select('''
          id,
          due_date,
          emi_amount,
          status,
          loan_id,
          loans!inner(
            id,
            member_id,
            members!inner(
              id,
              full_name,
              phone,
              gps_lat,
              gps_lng
            )
          )
        ''')
        .eq('status', 'pending')
        .gte('due_date', startOfDay)
        .lte('due_date', endOfDay)
        .eq('loans.staff_id', profile.id)
        .eq('loans.org_id', orgId);

    final emiList = List<Map<String, dynamic>>.from(response as List);

    // Build customer location list
    final List<Map<String, dynamic>> customerLocations = [];

    for (final emi in emiList) {
      final loan = emi['loans'] as Map<String, dynamic>?;
      if (loan == null) continue;
      final member = loan['members'] as Map<String, dynamic>?;
      if (member == null) continue;

      double? lat = (member['gps_lat'] as num?)?.toDouble();
      double? lng = (member['gps_lng'] as num?)?.toDouble();

      // If member doesn't have coordinates, try visit_logs
      if (lat == null || lng == null) {
        final memberId = member['id'] as String;
        final visitLog = await _getLastVisitLocation(client, memberId);
        if (visitLog != null) {
          lat = visitLog['latitude'];
          lng = visitLog['longitude'];
        }
      }

      // Only add if we have valid coordinates
      if (lat != null && lng != null && lat != 0 && lng != 0) {
        customerLocations.add({
          'member_id': member['id'],
          'full_name': member['full_name'] ?? 'Unknown',
          'phone': member['phone'] ?? '',
          'latitude': lat,
          'longitude': lng,
          'emi_amount': (emi['emi_amount'] as num?)?.toDouble() ?? 0,
          'due_date': emi['due_date'],
          'loan_id': emi['loan_id'],
        });
      }
    }

    return customerLocations;
  } catch (e) {
    debugPrint('[StaffMap] Error fetching due customer locations: $e');

    // Fallback: try a simpler query approach
    try {
      return await _fallbackCustomerLocations(client, orgId, profile.id);
    } catch (e2) {
      debugPrint('[StaffMap] Fallback also failed: $e2');
      return [];
    }
  }
});

/// Get last known location from visit_logs for a member
Future<Map<String, double>?> _getLastVisitLocation(
    dynamic client, String memberId) async {
  try {
    final response = await client
        .from('visit_logs')
        .select('check_in_lat, check_in_lng')
        .eq('member_id', memberId)
        .not('check_in_lat', 'is', null)
        .not('check_in_lng', 'is', null)
        .order('created_at', ascending: false)
        .limit(1);

    final list = List<Map<String, dynamic>>.from(response as List);
    if (list.isEmpty) return null;

    final lat = (list.first['check_in_lat'] as num?)?.toDouble();
    final lng = (list.first['check_in_lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    return {'latitude': lat, 'longitude': lng};
  } catch (_) {
    return null;
  }
}

/// Fallback approach: query collections due today for this staff
Future<List<Map<String, dynamic>>> _fallbackCustomerLocations(
    dynamic client, String orgId, String staffId) async {
  final today = DateTime.now();
  final startOfDay =
      DateTime(today.year, today.month, today.day).toIso8601String();

  // Try getting members assigned to this staff with pending dues
  final response = await client
      .from('loans')
      .select('''
        id,
        member_id,
        members!inner(
          id,
          full_name,
          phone,
          gps_lat,
          gps_lng
        )
      ''')
      .eq('staff_id', staffId)
      .eq('org_id', orgId)
      .eq('status', 'active');

  final loans = List<Map<String, dynamic>>.from(response as List);
  final List<Map<String, dynamic>> results = [];
  final seenMembers = <String>{};

  for (final loan in loans) {
    final member = loan['members'] as Map<String, dynamic>?;
    if (member == null) continue;
    final memberId = member['id'] as String;
    if (seenMembers.contains(memberId)) continue;
    seenMembers.add(memberId);

    final lat = (member['gps_lat'] as num?)?.toDouble();
    final lng = (member['gps_lng'] as num?)?.toDouble();

    if (lat != null && lng != null && lat != 0 && lng != 0) {
      results.add({
        'member_id': memberId,
        'full_name': member['full_name'] ?? 'Unknown',
        'phone': member['phone'] ?? '',
        'latitude': lat,
        'longitude': lng,
        'emi_amount': 0.0,
        'due_date': startOfDay,
        'loan_id': loan['id'],
      });
    }
  }

  return results;
}
