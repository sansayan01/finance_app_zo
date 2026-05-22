import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoanStatementArchive {
  final String id;
  final String statementRef;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String variant;
  final String format;
  final String filePath;
  final int? fileSizeBytes;
  final String sha256Hash;
  final String? generatedByName;
  final DateTime generatedAt;

  LoanStatementArchive({
    required this.id,
    required this.statementRef,
    required this.periodStart,
    required this.periodEnd,
    required this.variant,
    required this.format,
    required this.filePath,
    this.fileSizeBytes,
    required this.sha256Hash,
    this.generatedByName,
    required this.generatedAt,
  });

  factory LoanStatementArchive.fromJson(Map<String, dynamic> j) =>
      LoanStatementArchive(
        id: j['id'] as String,
        statementRef: j['statement_ref'] as String,
        periodStart: DateTime.parse(j['period_start'] as String),
        periodEnd: DateTime.parse(j['period_end'] as String),
        variant: j['variant'] as String,
        format: j['format'] as String,
        filePath: j['file_path'] as String,
        fileSizeBytes: (j['file_size_bytes'] as num?)?.toInt(),
        sha256Hash: j['sha256_hash'] as String,
        generatedByName: j['generated_by_name'] as String?,
        generatedAt: DateTime.parse(j['generated_at'] as String),
      );
}

class LoanStatementArchiveService {
  final SupabaseClient _client;
  final String _orgId;
  static const String bucket = 'loan-statements';

  LoanStatementArchiveService(this._client, this._orgId);

  /// SHA-256 of the bytes, hex-encoded.
  static String hashBytes(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Uploads the file and inserts a metadata row. Returns the archive row.
  Future<LoanStatementArchive> archive({
    required String loanId,
    required Uint8List bytes,
    required String statementRef,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String variant,
    required String format,
    required String fileExtension,
    String? mimeType,
    String? generatedByUserId,
    String? generatedByName,
  }) async {
    final hash = hashBytes(bytes);
    final filePath = '$_orgId/$loanId/$statementRef.$fileExtension';

    await _client.storage.from(bucket).uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType ?? 'application/octet-stream',
            upsert: true,
          ),
        );

    final row = await _client.from('loan_statements').insert({
      'org_id': _orgId,
      'loan_id': loanId,
      'statement_ref': statementRef,
      'period_start': periodStart.toIso8601String().split('T').first,
      'period_end': periodEnd.toIso8601String().split('T').first,
      'variant': variant,
      'format': format,
      'file_path': filePath,
      'file_size_bytes': bytes.length,
      'sha256_hash': hash,
      'generated_by': generatedByUserId,
      'generated_by_name': generatedByName,
    }).select().single();

    return LoanStatementArchive.fromJson(row);
  }

  Future<List<LoanStatementArchive>> listForLoan(String loanId) async {
    final rows = await _client
        .from('loan_statements')
        .select()
        .eq('loan_id', loanId)
        .order('generated_at', ascending: false);

    return (rows as List)
        .map((r) =>
            LoanStatementArchive.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Returns a short-lived signed URL (default 5 minutes).
  Future<String> signedUrl(String filePath, {int expiresSeconds = 300}) {
    return _client.storage.from(bucket).createSignedUrl(filePath, expiresSeconds);
  }

  Future<Uint8List> download(String filePath) async {
    return _client.storage.from(bucket).download(filePath);
  }

  Future<void> delete(String archiveId, String filePath) async {
    await _client.storage.from(bucket).remove([filePath]);
    await _client.from('loan_statements').delete().eq('id', archiveId);
  }
}
