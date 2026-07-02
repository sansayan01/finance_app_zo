import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';

/// Search result types
enum SearchResultType { member, staff, loan, transaction, savings }

/// Unified search result item
class SearchResult {
  final String id;
  final SearchResultType type;
  final String title;
  final String subtitle;
  final String? trailing;
  final Map<String, dynamic>? rawData;
  final String? route;

  const SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.rawData,
    this.route,
  });
}

/// Search state
class SearchState {
  final String query;
  final List<SearchResult> results;
  final bool isLoading;
  final String? error;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.error,
  });

  SearchState copyWith({
    String? query,
    List<SearchResult>? results,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Search notifier
class SearchNotifier extends StateNotifier<SearchState> {
  final SupabaseClient _client;
  final String _orgId;

  SearchNotifier(this._client, this._orgId) : super(const SearchState());

  void setQuery(String query) {
    state = state.copyWith(query: query);
    if (query.trim().length >= 2) {
      _performSearch(query.trim());
    } else {
      state = state.copyWith(results: []);
    }
  }

  void clear() {
    state = const SearchState();
  }

  Future<void> _performSearch(String query) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final results = <SearchResult>[];

      // Search in parallel
      await Future.wait([
        _searchMembers(query, results),
        _searchStaff(query, results),
        _searchLoans(query, results),
      ]);

      state = state.copyWith(
        results: results,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _searchMembers(String query, List<SearchResult> results) async {
    try {
      final response = await _client
          .from('members')
          .select('id, full_name, phone, member_id, branch_id')
          .eq('org_id', _orgId)
          .or('full_name.ilike.%$query%,phone.ilike.%$query%,member_id.ilike.%$query%')
          .limit(10);

      for (final row in response as List) {
        results.add(SearchResult(
          id: row['id'] as String,
          type: SearchResultType.member,
          title: row['full_name'] as String? ?? 'Unknown',
          subtitle: row['phone'] as String? ?? '',
          trailing: row['member_id'] as String?,
          rawData: row as Map<String, dynamic>,
          route: '/users/${row['id']}',
        ));
      }
    } catch (e) {
      debugPrint('Search members error: $e');
    }
  }

  Future<void> _searchStaff(String query, List<SearchResult> results) async {
    try {
      final response = await _client
          .from('profiles')
          .select('id, full_name, email, phone, role, staff_code')
          .eq('org_id', _orgId)
          .or('full_name.ilike.%$query%,email.ilike.%$query%,phone.ilike.%$query%,staff_code.ilike.%$query%')
          .limit(10);

      for (final row in response as List) {
        final role = row['role'] as String? ?? '';
        final roleLabel = role == 'collectionAgent'
            ? 'Collection Agent'
            : role == 'manager'
                ? 'Branch Manager'
                : role == 'executiveAdmin'
                    ? 'Executive Admin'
                    : role.toUpperCase();

        results.add(SearchResult(
          id: row['id'] as String,
          type: SearchResultType.staff,
          title: row['full_name'] as String? ?? 'Unknown',
          subtitle: row['email'] as String? ?? row['phone'] as String? ?? '',
          trailing: roleLabel,
          rawData: row as Map<String, dynamic>,
          route: '/users/${row['id']}',
        ));
      }
    } catch (e) {
      debugPrint('Search staff error: $e');
    }
  }

  Future<void> _searchLoans(String query, List<SearchResult> results) async {
    try {
      final response = await _client
          .from('loans')
          .select('id, loan_number, amount, status, outstanding_amount, member_name')
          .eq('org_id', _orgId)
          .or('loan_number.ilike.%$query%,member_name.ilike.%$query%')
          .limit(10);

      for (final row in response as List) {
        final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;

        results.add(SearchResult(
          id: row['id'] as String,
          type: SearchResultType.loan,
          title: row['loan_number'] as String? ?? 'Unknown Loan',
          subtitle: row['member_name'] as String? ?? 'Unknown Member',
          trailing: '₹${amount.toStringAsFixed(0)}',
          rawData: row as Map<String, dynamic>,
          route: '/loans/${row['id']}',
        ));
      }
    } catch (e) {
      debugPrint('Search loans error: $e');
    }
  }
}

/// Search provider
final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdProvider);
  return SearchNotifier(client, orgId ?? '');
});
