import 'package:supabase_flutter/supabase_flutter.dart';

/// Conflict resolution strategy
enum ConflictStrategy {
  serverWins, // Server data takes priority
  localWins, // Local data takes priority
  merge, // Attempt to merge both
  manual, // Require manual resolution
}

/// Conflict types
enum ConflictType {
  updateUpdate, // Both local and server updated same record
  deleteUpdate, // Local deleted, server updated
  updateDelete, // Local updated, server deleted
  duplicate, // Duplicate records detected
}

/// Conflict record
class ConflictRecord {
  final String id;
  final String table;
  final ConflictType type;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> serverData;
  final DateTime detectedAt;
  ConflictStrategy? resolution;
  Map<String, dynamic>? resolvedData;

  ConflictRecord({
    required this.id,
    required this.table,
    required this.type,
    required this.localData,
    required this.serverData,
    DateTime? detectedAt,
    this.resolution,
    this.resolvedData,
  }) : detectedAt = detectedAt ?? DateTime.now();

  bool get isResolved => resolution != null && resolvedData != null;
}

/// Conflict Resolution Service
/// Handles data conflicts between local and server data
class ConflictResolutionService {
  final SupabaseClient _client;

  // Default resolution strategies per table
  final Map<String, ConflictStrategy> _defaultStrategies = {
    'collections': ConflictStrategy.serverWins,
    'staff_wallet': ConflictStrategy.serverWins,
    'staff_profiles': ConflictStrategy.serverWins,
    'loans': ConflictStrategy.serverWins,
    'members': ConflictStrategy.merge,
  };

  ConflictResolutionService(this._client);

  /// Detect conflicts between local and server data
  Future<List<ConflictRecord>> detectConflicts({
    required String table,
    required List<Map<String, dynamic>> localRecords,
    required List<Map<String, dynamic>> serverRecords,
  }) async {
    final conflicts = <ConflictRecord>[];

    // Create lookup maps
    final serverMap = {for (var r in serverRecords) r['id']: r};

    // Check for update-update conflicts
    for (final local in localRecords) {
      final id = local['id'];
      final server = serverMap[id];

      if (server != null) {
        // Check if both have been modified
        final localUpdatedAt = DateTime.tryParse(local['updated_at'] ?? '');
        final serverUpdatedAt = DateTime.tryParse(server['updated_at'] ?? '');

        if (localUpdatedAt != null &&
            serverUpdatedAt != null &&
            localUpdatedAt != serverUpdatedAt) {
          // Both have been updated - potential conflict
          if (_hasDataDifferences(local, server)) {
            conflicts.add(ConflictRecord(
              id: id.toString(),
              table: table,
              type: ConflictType.updateUpdate,
              localData: local,
              serverData: server,
            ));
          }
        }
      }
    }

    // Check for delete-update conflicts (local deleted, server updated)
    // This would require tracking deleted IDs

    return conflicts;
  }

  /// Check if two records have different data
  bool _hasDataDifferences(
    Map<String, dynamic> local,
    Map<String, dynamic> server,
  ) {
    final keysToCheck = local.keys.where((k) =>
        !k.startsWith('_') &&
        k != 'updated_at' &&
        k != 'synced_at' &&
        k != 'sync_status');

    for (final key in keysToCheck) {
      if (local[key] != server[key]) {
        return true;
      }
    }
    return false;
  }

  /// Resolve a conflict using specified strategy
  Future<Map<String, dynamic>> resolveConflict(
    ConflictRecord conflict, {
    ConflictStrategy? strategy,
  }) async {
    final resolution = strategy ??
        _defaultStrategies[conflict.table] ??
        ConflictStrategy.serverWins;

    Map<String, dynamic> resolvedData;

    switch (resolution) {
      case ConflictStrategy.serverWins:
        resolvedData = conflict.serverData;
        break;

      case ConflictStrategy.localWins:
        resolvedData = conflict.localData;
        break;

      case ConflictStrategy.merge:
        resolvedData = await _mergeData(
          conflict.localData,
          conflict.serverData,
          conflict.table,
        );
        break;

      case ConflictStrategy.manual:
        throw Exception('Manual resolution required');
    }

    // Apply resolution to server
    await _applyResolution(conflict.table, resolvedData);

    return resolvedData;
  }

  /// Merge local and server data
  Future<Map<String, dynamic>> _mergeData(
    Map<String, dynamic> local,
    Map<String, dynamic> server,
    String table,
  ) async {
    // Merge logic: local wins for specific fields, server wins for others
    final merged = Map<String, dynamic>.from(server);

    // Table-specific merge logic
    switch (table) {
      case 'collections':
        // For collections, prefer server amounts but keep local remarks
        if (local['remarks'] != null &&
            local['remarks'].toString().isNotEmpty) {
          merged['remarks'] = local['remarks'];
        }
        break;

      case 'members':
        // For members, merge contact info updates
        if (local['phone'] != server['phone']) {
          // Prefer more recent phone number
          merged['phone'] = local['phone'];
        }
        break;

      default:
        // Default: use server data for conflicting fields
        // but preserve any local-only fields
        for (final key in local.keys) {
          if (!server.containsKey(key) && local[key] != null) {
            merged[key] = local[key];
          }
        }
    }

    merged['updated_at'] = DateTime.now().toIso8601String();
    merged['sync_status'] = 'synced';

    return merged;
  }

  /// Apply resolution to server
  Future<void> _applyResolution(
    String table,
    Map<String, dynamic> data,
  ) async {
    await _client.from(table).update(data).eq('id', data['id']);
  }

  /// Get pending conflicts for a table
  Future<List<ConflictRecord>> getPendingConflicts(String table) async {
    final conflicts = await _client
        .from('sync_conflicts')
        .select()
        .eq('table_name', table)
        .isFilter('resolved_at', null);

    return conflicts
        .map((c) => ConflictRecord(
              id: c['id'].toString(),
              table: c['table_name'],
              type: ConflictType.updateUpdate,
              localData: c['local_data'],
              serverData: c['server_data'],
              detectedAt: DateTime.parse(c['created_at']),
            ))
        .toList();
  }

  /// Set default resolution strategy for a table
  void setDefaultStrategy(String table, ConflictStrategy strategy) {
    _defaultStrategies[table] = strategy;
  }

  /// Get default resolution strategy for a table
  ConflictStrategy getDefaultStrategy(String table) {
    return _defaultStrategies[table] ?? ConflictStrategy.serverWins;
  }
}
