import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/statement_formatters.dart';

// ---------------------------------------------------------------------------
// CATEGORY DEFINITIONS (no Flutter UI types — icons/colors live in the page)
// ---------------------------------------------------------------------------

class BackupCategoryDef {
  final String key;
  final String tableName;
  final String label;

  const BackupCategoryDef({
    required this.key,
    required this.tableName,
    required this.label,
  });
}

class BackupCategory {
  static const members = 'members';
  static const loans = 'loans';
  static const emiSchedule = 'loan_schedules';
  static const savings = 'savings';
  static const savingsPlans = 'savings_plans';
  static const transactions = 'transactions';
  static const collections = 'collections';
  static const savingsCollections = 'savings_collections';
  static const branches = 'branches';
  static const staffProfiles = 'staff_profiles';
  static const activityLogs = 'activity_logs';
  static const visitLogs = 'visit_logs';
  static const cashDeposits = 'cash_deposits';
  static const walletTransactions = 'wallet_transactions';
  static const staffStreaks = 'staff_streaks';
  static const achievements = 'achievements';
  static const offlineQueue = 'offline_sync_queue';
  static const syncConflicts = 'sync_conflicts';
}

const List<BackupCategoryDef> kBackupCategories = [
  BackupCategoryDef(key: 'members', tableName: 'members', label: 'Members'),
  BackupCategoryDef(key: 'loans', tableName: 'loans', label: 'Loans'),
  BackupCategoryDef(key: 'emi_schedule', tableName: 'loan_schedules', label: 'EMI Schedule'),
  BackupCategoryDef(key: 'savings', tableName: 'savings', label: 'Savings'),
  BackupCategoryDef(key: 'savings_plans', tableName: 'savings_plans', label: 'Savings Plans'),
  BackupCategoryDef(key: 'transactions', tableName: 'transactions', label: 'Transactions'),
  BackupCategoryDef(key: 'collections', tableName: 'collections', label: 'Collections'),
  BackupCategoryDef(key: 'savings_collections', tableName: 'savings_collections', label: 'Savings Coll.'),
  BackupCategoryDef(key: 'branches', tableName: 'branches', label: 'Branches'),
  BackupCategoryDef(key: 'staff_profiles', tableName: 'staff_profiles', label: 'Staff'),
  BackupCategoryDef(key: 'activity_logs', tableName: 'activity_logs', label: 'Activity Logs'),
  BackupCategoryDef(key: 'visit_logs', tableName: 'visit_logs', label: 'Visit Logs'),
  BackupCategoryDef(key: 'cash_deposits', tableName: 'cash_deposits', label: 'Cash Deposits'),
  BackupCategoryDef(key: 'wallet_transactions', tableName: 'wallet_transactions', label: 'Wallet Txns'),
  BackupCategoryDef(key: 'staff_streaks', tableName: 'staff_streaks', label: 'Streaks'),
  BackupCategoryDef(key: 'achievements', tableName: 'achievements', label: 'Achievements'),
  BackupCategoryDef(key: 'offline_queue', tableName: 'offline_sync_queue', label: 'Offline Queue'),
  BackupCategoryDef(key: 'sync_conflicts', tableName: 'sync_conflicts', label: 'Sync Issues'),
];

// ---------------------------------------------------------------------------
// SERVICE
// ---------------------------------------------------------------------------

class BackupExportService {
  final SupabaseClient _client;

  BackupExportService(this._client);

  // ── CATEGORY COUNTS ───────────────────────────────────────────────────

  Future<Map<String, int>> getCategoryCounts(String orgId) async {
    final results = await Future.wait(
      kBackupCategories.map((cat) async {
        try {
          final count = await _client
              .from(cat.tableName)
              .select('id')
              .eq('org_id', orgId)
              .count();
          return MapEntry(cat.key, count.count);
        } catch (_) {
          return MapEntry(cat.key, 0);
        }
      }),
    );
    return Map.fromEntries(results);
  }

  // ── SINGLE CATEGORY EXPORT ───────────────────────────────────────────

  Future<String> exportSingleCategory({
    required String orgId,
    required String orgName,
    required String categoryKey,
    required String format,
    DateTime? start,
    DateTime? end,
  }) async {
    final cat = kBackupCategories.firstWhere((c) => c.key == categoryKey);
    final data = await fetchTableData(orgId, cat.tableName, start: start, end: end);
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = '${cat.key}_$timestamp';

    final categoryData = {cat.key: data};

    switch (format.toLowerCase()) {
      case 'excel':
        return _generateExcel(tempDir.path, fileName, orgName, categoryData);
      case 'pdf':
        return _generatePdf(tempDir.path, fileName, orgName, categoryData);
      default:
        return _generateCsv(tempDir.path, fileName, orgName, categoryData);
    }
  }

  // ── TABLE DATA FETCH ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchTableData(
    String orgId,
    String tableName, {
    DateTime? start,
    DateTime? end,
    int limit = 10000,
  }) async {
    try {
      var query = _client.from(tableName).select().eq('org_id', orgId);
      if (start != null) query = query.gte('created_at', start.toIso8601String());
      if (end != null) query = query.lte('created_at', end.toIso8601String());
      final result = await query.limit(limit);
      return List<Map<String, dynamic>>.from(result as List? ?? const []);
    } catch (e) {
      debugPrint('fetchTableData($tableName) error: $e');
      return const [];
    }
  }

  // ── FULL BACKUP ──────────────────────────────────────────────────────

  Future<String> generateFullBackup({
    required String orgId,
    required String orgName,
    required Set<String> selectedCategories,
    required String format,
    DateTime? startDate,
    DateTime? endDate,
    String? filenamePrefix,
    void Function(String step, double progress)? onProgress,
  }) async {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final prefix = filenamePrefix?.isNotEmpty == true ? filenamePrefix! : 'backup';
    final fileName =
        '${prefix}_${orgName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_$timestamp';

    // Fetch data for each category with progress
    final categoryData = <String, List<Map<String, dynamic>>>{};
    final categoryList = selectedCategories.toList();
    final total = categoryList.length;

    for (var i = 0; i < total; i++) {
      final key = categoryList[i];
      final cat = kBackupCategories.firstWhere((c) => c.key == key);
      onProgress?.call('Fetching ${cat.label}...', (i + 1) / total);
      final data = await fetchTableData(orgId, cat.tableName, start: startDate, end: endDate);
      categoryData[key] = data;
    }

    onProgress?.call('Generating file...', 1.0);
    final tempDir = await getTemporaryDirectory();

    switch (format.toLowerCase()) {
      case 'excel':
        return _generateExcel(tempDir.path, fileName, orgName, categoryData);
      case 'pdf':
        return _generatePdf(tempDir.path, fileName, orgName, categoryData);
      default:
        return _generateCsv(tempDir.path, fileName, orgName, categoryData);
    }
  }

  // ── SHARE FILE ───────────────────────────────────────────────────────

  Future<void> shareFile(String filePath, String format) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('Export file not found');

    final mimeType = switch (format.toLowerCase()) {
      'csv' => 'text/csv',
      'excel' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };

    await SharePlus.instance.share(
      ShareParams(files: [XFile(filePath, mimeType: mimeType)]),
    );
  }

  /// Get file size in human-readable format.
  Future<String> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.length();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return 'Unknown';
    }
  }

  // ── CSV ──────────────────────────────────────────────────────────────

  Future<String> _generateCsv(
    String dirPath,
    String fileName,
    String orgName,
    Map<String, List<Map<String, dynamic>>> categoryData,
  ) async {
    final buffer = StringBuffer();
    buffer.write('\uFEFF'); // UTF-8 BOM
    buffer.writeln('MICROFLOW PRO — ORGANIZATION DATA BACKUP');
    buffer.writeln('Organization,$orgName');
    buffer.writeln('Generated,${StatementFormatters.timestamp(DateTime.now())}');
    buffer.writeln('Categories,${categoryData.length}');
    buffer.writeln('');

    for (final entry in categoryData.entries) {
      final cat = kBackupCategories.firstWhere((c) => c.key == entry.key);
      final rows = entry.value;

      buffer.writeln('');
      buffer.writeln('══════════════════════════════════════════════');
      buffer.writeln('  ${cat.label.toUpperCase()} — ${rows.length} records');
      buffer.writeln('══════════════════════════════════════════════');

      if (rows.isEmpty) {
        buffer.writeln('No records found.');
        continue;
      }

      final headers = rows.first.keys.toList();
      buffer.writeln(headers.join(','));

      for (final row in rows) {
        final values = headers.map((h) {
          final val = row[h];
          if (val == null) return '';
          final str = val.toString();
          if (str.contains(',') || str.contains('"') || str.contains('\n')) {
            return '"${str.replaceAll('"', '""')}"';
          }
          return str;
        });
        buffer.writeln(values.join(','));
      }
    }

    // Footer
    buffer.writeln('');
    buffer.writeln('══════════════════════════════════════════════');
    buffer.writeln('END OF BACKUP — Generated by MicroFlow Pro');
    buffer.writeln('══════════════════════════════════════════════');

    final filePath = '$dirPath/$fileName.csv';
    await File(filePath).writeAsString(
      StatementFormatters.sanitizeForEncoding(buffer.toString()),
    );
    return filePath;
  }

  // ── EXCEL ────────────────────────────────────────────────────────────

  Future<String> _generateExcel(
    String dirPath,
    String fileName,
    String orgName,
    Map<String, List<Map<String, dynamic>>> categoryData,
  ) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    // Summary sheet
    final summary = excel['Summary'];
    summary.cell(CellIndex.indexByString('A1')).value =
        TextCellValue('MicroFlow Pro — Organization Backup');
    summary.cell(CellIndex.indexByString('A2')).value =
        TextCellValue('Organization: $orgName');
    summary.cell(CellIndex.indexByString('A3')).value =
        TextCellValue('Generated: ${StatementFormatters.timestamp(DateTime.now())}');
    summary.cell(CellIndex.indexByString('A5')).value = TextCellValue('Category');
    summary.cell(CellIndex.indexByString('B5')).value = TextCellValue('Records');

    var row = 6;
    for (final entry in categoryData.entries) {
      final cat = kBackupCategories.firstWhere((c) => c.key == entry.key);
      summary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(cat.label);
      summary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          IntCellValue(entry.value.length);
      row++;
    }

    // One sheet per category
    for (final entry in categoryData.entries) {
      final cat = kBackupCategories.firstWhere((c) => c.key == entry.key);
      final sheetName =
          cat.label.length > 31 ? cat.label.substring(0, 31) : cat.label;
      final sheet = excel[sheetName];
      final rows = entry.value;

      if (rows.isEmpty) {
        sheet.cell(CellIndex.indexByString('A1')).value =
            TextCellValue('No records found');
        continue;
      }

      final headers = rows.first.keys.toList();
      for (var i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = TextCellValue(headers[i]);
      }

      for (var r = 0; r < rows.length; r++) {
        for (var c = 0; c < headers.length; c++) {
          final val = rows[r][headers[c]];
          final cell = CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1);
          if (val == null) {
            sheet.cell(cell).value = TextCellValue('');
          } else if (val is num) {
            sheet.cell(cell).value = DoubleCellValue(val.toDouble());
          } else if (val is bool) {
            sheet.cell(cell).value = BoolCellValue(val);
          } else {
            sheet.cell(cell).value = TextCellValue(val.toString());
          }
        }
      }
    }

    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('Failed to generate Excel file');

    final filePath = '$dirPath/$fileName.xlsx';
    await File(filePath).writeAsBytes(fileBytes);
    return filePath;
  }

  // ── PDF ──────────────────────────────────────────────────────────────

  Future<String> _generatePdf(
    String dirPath,
    String fileName,
    String orgName,
    Map<String, List<Map<String, dynamic>>> categoryData,
  ) async {
    final pdf = pw.Document();

    // Cover page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 60),
            pw.Text(
              'MICROFLOW PRO',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Organization Data Backup',
              style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 40),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfInfoRow('Organization', orgName),
                  _pdfInfoRow('Generated', StatementFormatters.timestamp(DateTime.now())),
                  _pdfInfoRow('Categories', '${categoryData.length}'),
                  _pdfInfoRow(
                    'Total Records',
                    '${categoryData.values.fold<int>(0, (a, b) => a + b.length)}',
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Text(
              'Contents',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            for (final entry in categoryData.entries) ...[
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(kBackupCategories.firstWhere((c) => c.key == entry.key).label),
                  pw.Text('${entry.value.length} records',
                      style: const pw.TextStyle(color: PdfColors.grey600)),
                ],
              ),
              pw.SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );

    // One page per category with data
    for (final entry in categoryData.entries) {
      final cat = kBackupCategories.firstWhere((c) => c.key == entry.key);
      final rows = entry.value;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (context) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(cat.label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('${rows.length} records',
                    style: const pw.TextStyle(color: PdfColors.grey600)),
              ],
            ),
          ),
          build: (context) {
            if (rows.isEmpty) {
              return [pw.Center(child: pw.Text('No records found'))];
            }

            final headers = rows.first.keys.toList();
            final tableHeaders = headers.take(8).toList(); // Limit columns for PDF
            final tableData = rows.take(200).toList(); // Limit rows for PDF

            return [
              pw.TableHelper.fromTextArray(
                headers: tableHeaders,
                data: tableData
                    .map((row) => tableHeaders
                        .map((h) => row[h]?.toString() ?? '')
                        .toList())
                    .toList(),
                headerStyle: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor(0.18, 0.31, 0.52),
                ),
                cellStyle: const pw.TextStyle(fontSize: 7),
                cellHeight: 18,
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColor(0.97, 0.97, 0.97),
                ),
              ),
              if (rows.length > 200)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Text(
                    '... and ${rows.length - 200} more records (truncated for PDF)',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
            ];
          },
        ),
      );
    }

    final fileBytes = await pdf.save();
    final filePath = '$dirPath/$fileName.pdf';
    await File(filePath).writeAsBytes(fileBytes);
    return filePath;
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey600)),
          ),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  // ── EXPORT HISTORY ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getExportHistory(String orgId) async {
    try {
      final result = await _client
          .from('data_exports')
          .select()
          .eq('org_id', orgId)
          .order('created_at', ascending: false)
          .limit(30);
      return List<Map<String, dynamic>>.from(result as List? ?? const []);
    } catch (e) {
      debugPrint('getExportHistory error: $e');
      return const [];
    }
  }

  Future<Map<String, dynamic>?> createExportRecord({
    required String orgId,
    required String type,
    required String format,
    Map<String, dynamic>? filters,
    String? createdBy,
  }) async {
    try {
      final response = await _client
          .from('data_exports')
          .insert({
            'org_id': orgId,
            'type': type,
            'format': format,
            'filters': filters ?? {},
            if (createdBy != null) 'created_by': createdBy,
            'status': 'completed',
          })
          .select()
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('createExportRecord error: $e');
      return null;
    }
  }

  // ── SCHEDULE SETTINGS ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getScheduleSettings(String orgId) async {
    try {
      final result = await _client
          .from('organizations')
          .select('settings')
          .eq('id', orgId)
          .maybeSingle();

      final settings = result?['settings'] as Map<String, dynamic>? ?? {};
      return (settings['backup_schedule'] as Map<String, dynamic>?) ??
          _defaultSchedule();
    } catch (e) {
      debugPrint('getScheduleSettings error: $e');
      return _defaultSchedule();
    }
  }

  Map<String, dynamic> _defaultSchedule() => {
        'enabled': false,
        'frequency': 'weekly',
        'day_of_week': 1,
        'time_hour': 2,
        'time_minute': 0,
        'format': 'csv',
        'categories': kBackupCategories.map((c) => c.key).toList(),
        'notify_on_complete': true,
      };

  Future<bool> updateScheduleSettings(
      String orgId, Map<String, dynamic> schedule) async {
    try {
      final result = await _client
          .from('organizations')
          .select('settings')
          .eq('id', orgId)
          .maybeSingle();

      final currentSettings = Map<String, dynamic>.from(
        (result?['settings'] as Map<String, dynamic>?) ?? {},
      );
      currentSettings['backup_schedule'] = schedule;

      await _client
          .from('organizations')
          .update({
            'settings': currentSettings,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orgId);

      return true;
    } catch (e) {
      debugPrint('updateScheduleSettings error: $e');
      return false;
    }
  }

  // ── ESTIMATED SIZE ───────────────────────────────────────────────────

  /// Rough estimate of export size based on record counts.
  String estimateFileSize(Map<String, int> counts, Set<String> selected, String format) {
    var totalRows = 0;
    for (final key in selected) {
      totalRows += counts[key] ?? 0;
    }

    // Rough estimates: ~200 bytes per row for CSV, ~250 for Excel, ~150 for PDF
    final bytesPerRow = switch (format) {
      'excel' => 250,
      'pdf' => 150,
      _ => 200,
    };

    final estimatedBytes = totalRows * bytesPerRow + 5000; // 5KB overhead
    if (estimatedBytes < 1024) return '~${estimatedBytes}B';
    if (estimatedBytes < 1024 * 1024) return '~${(estimatedBytes / 1024).toStringAsFixed(0)}KB';
    return '~${(estimatedBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
