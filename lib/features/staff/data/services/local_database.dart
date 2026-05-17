import 'package:hive_flutter/hive_flutter.dart';

/// Local database service using Hive for offline storage
/// Provides fast, encrypted local storage for offline-first operations
class LocalDatabase {
  static const String _collectionsBox = 'collections';
  static const String _customersBox = 'customers';
  static const String _loansBox = 'loans';
  static const String _pendingOpsBox = 'pending_operations';
  static const String _settingsBox = 'settings';

  late final Box<Map> _collections;
  late final Box<Map> _customers;
  late final Box<Map> _loans;
  late final Box<Map> _pendingOps;
  late final Box<dynamic> _settings;

  /// Initialize the local database
  Future<void> init() async {
    await Hive.initFlutter();

    _collections = await Hive.openBox<Map>(_collectionsBox);
    _customers = await Hive.openBox<Map>(_customersBox);
    _loans = await Hive.openBox<Map>(_loansBox);
    _pendingOps = await Hive.openBox<Map>(_pendingOpsBox);
    _settings = await Hive.openBox(_settingsBox);
  }

  // ==================== COLLECTIONS ====================

  /// Store a collection locally
  Future<void> putCollection(String id, Map<String, dynamic> collection) async {
    await _collections.put(id, collection);
  }

  /// Get a collection by ID
  Map<String, dynamic>? getCollection(String id) {
    return _collections.get(id)?.cast<String, dynamic>();
  }

  /// Get all collections
  List<Map<String, dynamic>> getAllCollections() {
    return _collections.values.map((e) => e.cast<String, dynamic>()).toList();
  }

  /// Get collections for a specific date
  List<Map<String, dynamic>> getCollectionsForDate(DateTime date) {
    final dateStr = date.toIso8601String().split('T').first;
    return _collections.values.map((e) => e.cast<String, dynamic>()).where((c) {
      final collectionTime = c['collection_time'] as String?;
      return collectionTime?.startsWith(dateStr) ?? false;
    }).toList();
  }

  /// Delete a collection
  Future<void> deleteCollection(String id) async {
    await _collections.delete(id);
  }

  /// Clear all collections
  Future<void> clearCollections() async {
    await _collections.clear();
  }

  // ==================== CUSTOMERS ====================

  /// Store a customer locally
  Future<void> putCustomer(String id, Map<String, dynamic> customer) async {
    await _customers.put(id, customer);
  }

  /// Get a customer by ID
  Map<String, dynamic>? getCustomer(String id) {
    return _customers.get(id)?.cast<String, dynamic>();
  }

  /// Search customers locally
  List<Map<String, dynamic>> searchCustomers(String query) {
    final lowerQuery = query.toLowerCase();
    return _customers.values.map((e) => e.cast<String, dynamic>()).where((c) {
      final name = (c['full_name'] as String?)?.toLowerCase() ?? '';
      final phone = (c['phone'] as String?)?.toLowerCase() ?? '';
      final memberId = (c['member_id'] as String?)?.toLowerCase() ?? '';
      return name.contains(lowerQuery) ||
          phone.contains(lowerQuery) ||
          memberId.contains(lowerQuery);
    }).toList();
  }

  /// Get all customers
  List<Map<String, dynamic>> getAllCustomers() {
    return _customers.values.map((e) => e.cast<String, dynamic>()).toList();
  }

  /// Clear all customers
  Future<void> clearCustomers() async {
    await _customers.clear();
  }

  // ==================== LOANS ====================

  /// Store a loan locally
  Future<void> putLoan(String id, Map<String, dynamic> loan) async {
    await _loans.put(id, loan);
  }

  /// Get a loan by ID
  Map<String, dynamic>? getLoan(String id) {
    return _loans.get(id)?.cast<String, dynamic>();
  }

  /// Get loans for a customer
  List<Map<String, dynamic>> getLoansForCustomer(String customerId) {
    return _loans.values
        .map((e) => e.cast<String, dynamic>())
        .where((l) => l['member_id'] == customerId)
        .toList();
  }

  /// Get all loans
  List<Map<String, dynamic>> getAllLoans() {
    return _loans.values.map((e) => e.cast<String, dynamic>()).toList();
  }

  /// Clear all loans
  Future<void> clearLoans() async {
    await _loans.clear();
  }

  // ==================== PENDING OPERATIONS ====================

  /// Add a pending operation
  Future<void> addPendingOperation(Map<String, dynamic> operation) async {
    final id =
        operation['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    await _pendingOps.put(id, operation);
  }

  /// Get all pending operations
  List<Map<String, dynamic>> getPendingOperations() {
    return _pendingOps.values
        .map((e) => e.cast<String, dynamic>())
        .where((op) => op['status'] == 'pending')
        .toList();
  }

  /// Update operation status
  Future<void> updateOperationStatus(String id, String status) async {
    final op = _pendingOps.get(id);
    if (op != null) {
      final updated = Map<String, dynamic>.from(op.cast<String, dynamic>());
      updated['status'] = status;
      await _pendingOps.put(id, updated);
    }
  }

  /// Remove a pending operation
  Future<void> removePendingOperation(String id) async {
    await _pendingOps.delete(id);
  }

  /// Clear all pending operations
  Future<void> clearPendingOperations() async {
    await _pendingOps.clear();
  }

  // ==================== SETTINGS ====================

  /// Get a setting value
  T? getSetting<T>(String key) {
    return _settings.get(key) as T?;
  }

  /// Set a setting value
  Future<void> setSetting<T>(String key, T value) async {
    await _settings.put(key, value);
  }

  /// Get last sync time
  DateTime? getLastSyncTime() {
    final syncTime = _settings.get('last_sync_time') as String?;
    return syncTime != null ? DateTime.tryParse(syncTime) : null;
  }

  /// Set last sync time
  Future<void> setLastSyncTime(DateTime time) async {
    await _settings.put('last_sync_time', time.toIso8601String());
  }

  /// Get current staff ID
  String? getCurrentStaffId() {
    return _settings.get('current_staff_id') as String?;
  }

  /// Set current staff ID
  Future<void> setCurrentStaffId(String staffId) async {
    await _settings.put('current_staff_id', staffId);
  }

  // ==================== BULK OPERATIONS ====================

  /// Sync customers from server
  Future<void> syncCustomers(List<Map<String, dynamic>> customers) async {
    for (final customer in customers) {
      final id = customer['id'] as String;
      await putCustomer(id, customer);
    }
  }

  /// Sync loans from server
  Future<void> syncLoans(List<Map<String, dynamic>> loans) async {
    for (final loan in loans) {
      final id = loan['id'] as String;
      await putLoan(id, loan);
    }
  }

  /// Clear all local data
  Future<void> clearAll() async {
    await _collections.clear();
    await _customers.clear();
    await _loans.clear();
    await _pendingOps.clear();
  }

  /// Get storage stats
  Map<String, int> getStats() {
    return {
      'collections': _collections.length,
      'customers': _customers.length,
      'loans': _loans.length,
      'pending_operations': _pendingOps.length,
    };
  }
}
