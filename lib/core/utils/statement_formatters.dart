import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

/// Shared formatters for PDF/CSV/Excel statement generation.
///
/// These intentionally avoid `NumberFormat.currency(locale: 'en_IN')` because
/// intl locale data must be initialised first — without it the formatter
/// throws "Unexpected null value".  The manual grouping below is safe in
/// any context (background isolate, headless PDF build, etc.).
class StatementFormatters {
  StatementFormatters._();

  /// Replaces lone surrogates (D800–DFFF) and other invalid Unicode code
  /// points with U+FFFD so the result can be safely UTF-8 encoded by
  /// `pdf`, `crypto`, or `csv` packages. Without this, a stray surrogate
  /// or malformed byte causes:
  ///   `FormatException: Unexpected extension byte (at offset ...)`
  /// and the entire PDF/CSV build aborts.
  ///
  /// Returns `''` for `null` input so callers can pass nullable strings.
  static String sanitizeForEncoding(String? s) {
    if (s == null || s.isEmpty) return '';

    // Step 1: Replace surrogates with U+FFFD
    final buf = StringBuffer();
    for (final rune in s.runes) {
      if (rune >= 0xD800 && rune <= 0xDFFF) {
        buf.writeCharCode(0xFFFD); // replacement character
      } else {
        buf.writeCharCode(rune);
      }
    }

    final cleaned = buf.toString();

    // Step 2: Verify UTF-8 validity
    try {
      utf8.encode(cleaned);
      return cleaned;
    } catch (_) {
      // Step 3: If still invalid, manually encode runes to UTF-8 bytes
      // using proper variable-length encoding, then decode with replacement
      final bytes = <int>[];
      for (final rune in cleaned.runes) {
        if (rune < 0x80) {
          bytes.add(rune);
        } else if (rune < 0x800) {
          bytes.add(0xC0 | (rune >> 6));
          bytes.add(0x80 | (rune & 0x3F));
        } else if (rune < 0x10000) {
          bytes.add(0xE0 | (rune >> 12));
          bytes.add(0x80 | ((rune >> 6) & 0x3F));
          bytes.add(0x80 | (rune & 0x3F));
        } else {
          bytes.add(0xF0 | (rune >> 18));
          bytes.add(0x80 | ((rune >> 12) & 0x3F));
          bytes.add(0x80 | ((rune >> 6) & 0x3F));
          bytes.add(0x80 | (rune & 0x3F));
        }
      }
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _isoDateFmt = DateFormat('yyyy-MM-dd');
  static final _timestampFmt = DateFormat('dd MMM yyyy, hh:mm a');

  // ── Currency ──────────────────────────────────────────────────────────

  /// Indian-style currency: "Rs. 1,23,456.78"
  static String money(num v) {
    final negative = v < 0;
    final n = v.abs();
    final whole = n.truncate();
    final fraction = ((n - whole) * 100).round();
    final wholeStr = whole.toString();

    String grouped;
    if (wholeStr.length <= 3) {
      grouped = wholeStr;
    } else {
      final last3 = wholeStr.substring(wholeStr.length - 3);
      final rest = wholeStr.substring(0, wholeStr.length - 3);
      final restRev = rest.split('').reversed.join();
      final buf = StringBuffer();
      for (var i = 0; i < restRev.length; i++) {
        if (i > 0 && i % 2 == 0) buf.write(',');
        buf.write(restRev[i]);
      }
      grouped = '${buf.toString().split('').reversed.join()},$last3';
    }
    final fracStr = fraction.toString().padLeft(2, '0');
    return '${negative ? '-' : ''}Rs. $grouped.$fracStr';
  }

  /// Raw Indian-style number without "Rs. " prefix.
  /// Useful when the currency symbol is already in a column header.
  static String number(num v) {
    final negative = v < 0;
    final n = v.abs();
    final whole = n.truncate();
    final wholeStr = whole.toString();

    String grouped;
    if (wholeStr.length <= 3) {
      grouped = wholeStr;
    } else {
      final last3 = wholeStr.substring(wholeStr.length - 3);
      final rest = wholeStr.substring(0, wholeStr.length - 3);
      final restRev = rest.split('').reversed.join();
      final buf = StringBuffer();
      for (var i = 0; i < restRev.length; i++) {
        if (i > 0 && i % 2 == 0) buf.write(',');
        buf.write(restRev[i]);
      }
      grouped = '${buf.toString().split('').reversed.join()},$last3';
    }
    return '${negative ? '-' : ''}$grouped';
  }

  /// Compact money format: "1.2L", "45K", "890"
  static String shortMoney(num v) {
    final n = v.abs();
    final prefix = v < 0 ? '-' : '';
    if (n >= 10000000) {
      return '${prefix}Rs. ${(n / 10000000).toStringAsFixed(1)}Cr';
    } else if (n >= 100000) {
      return '${prefix}Rs. ${(n / 100000).toStringAsFixed(1)}L';
    } else if (n >= 1000) {
      return '${prefix}Rs. ${(n / 1000).toStringAsFixed(1)}K';
    }
    return '${prefix}Rs. ${n.toStringAsFixed(0)}';
  }

  // ── Percentages ───────────────────────────────────────────────────────

  /// Formats as "12.5%" with one decimal place.
  static String percentage(num v) => '${v.toStringAsFixed(1)}%';

  // ── Dates ─────────────────────────────────────────────────────────────

  /// "dd MMM yyyy" — e.g. "04 Jun 2026"
  static String date(DateTime d) => _dateFmt.format(d);

  /// "yyyy-MM-dd" — ISO format, ideal for CSV headers / machine parsing.
  static String isoDate(DateTime d) => _isoDateFmt.format(d);

  /// "dd MMM yyyy, hh:mm AM/PM" — e.g. "04 Jun 2026, 02:30 PM"
  static String timestamp(DateTime d) => _timestampFmt.format(d);

  // ── Labels ────────────────────────────────────────────────────────────

  /// Human-readable days label: "1 day", "3 days", "0 days"
  static String daysLabel(int d) => '$d day${d == 1 ? '' : 's'}';

  // ── Health Grade ──────────────────────────────────────────────────────

  /// Computes an account health grade (A–E) from payment metrics.
  ///
  /// - [onTimeCount]: number of EMIs paid on or before due date
  /// - [totalDue]: total EMIs that have reached their due date
  /// - [currentOverdueCount]: number of currently overdue EMIs
  /// - [maxDaysOverdue]: maximum days any EMI is currently overdue
  static String healthGrade({
    required int onTimeCount,
    required int totalDue,
    required int currentOverdueCount,
    required int maxDaysOverdue,
  }) {
    if (totalDue == 0) return 'A'; // No EMIs due yet — excellent standing

    final onTimeRatio = totalDue > 0 ? onTimeCount / totalDue : 1.0;

    // Grade A: ≥95% on-time, no current overdue
    if (onTimeRatio >= 0.95 && currentOverdueCount == 0) return 'A';

    // Grade B: ≥85% on-time, ≤1 overdue, <30 days
    if (onTimeRatio >= 0.85 && currentOverdueCount <= 1 && maxDaysOverdue < 30) {
      return 'B';
    }

    // Grade C: ≥70% on-time, <60 days overdue
    if (onTimeRatio >= 0.70 && maxDaysOverdue < 60) return 'C';

    // Grade D: ≥50% on-time, <90 days overdue
    if (onTimeRatio >= 0.50 && maxDaysOverdue < 90) return 'D';

    // Grade E: everything else
    return 'E';
  }

  /// Human-readable label for a health grade.
  static String healthGradeLabel(String grade) {
    switch (grade) {
      case 'A': return 'Excellent';
      case 'B': return 'Good';
      case 'C': return 'Fair';
      case 'D': return 'Needs Attention';
      case 'E': return 'Critical';
      default:  return 'Unknown';
    }
  }

  // ── Security ──────────────────────────────────────────────────────────

  /// Generates a SHA-256 hash of key loan data for tamper detection.
  ///
  /// The hash is deterministic — same inputs always produce the same hash.
  /// Printed on the statement so the document can be verified against the
  /// source system.
  static String securityHash({
    required String loanNumber,
    required double amount,
    required double outstandingBalance,
    required int totalEmis,
    required int paidEmis,
    required DateTime generatedAt,
  }) {
    final payload = [
      'LN:${sanitizeForEncoding(loanNumber)}',
      'AMT:${amount.toStringAsFixed(2)}',
      'OS:${outstandingBalance.toStringAsFixed(2)}',
      'TE:$totalEmis',
      'PE:$paidEmis',
      'GEN:${generatedAt.toUtc().toIso8601String()}',
    ].join('|');

    final digest = sha256.convert(utf8.encode(payload));
    return digest.toString().toUpperCase();
  }

  // ── Image validation ──────────────────────────────────────────────────

  /// Returns true only if [bytes] looks like a real PNG or JPEG image.
  /// pdf widgets throw when fed garbage bytes (empty buffer, SVG, HTML error
  /// page), so we sniff the magic numbers before embedding.
  static bool isValidImage(Uint8List? bytes) {
    if (bytes == null || bytes.length < 8) return false;
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    final isPng = bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
    if (isPng) return true;
    // JPEG: FF D8 FF
    final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    return isJpeg;
  }
}
