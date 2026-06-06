import 'dart:typed_data';
import 'package:intl/intl.dart';

/// Shared formatters for PDF/CSV/Excel statement generation.
///
/// These intentionally avoid `NumberFormat.currency(locale: 'en_IN')` because
/// intl locale data must be initialised first — without it the formatter
/// throws "Unexpected null value".  The manual grouping below is safe in
/// any context (background isolate, headless PDF build, etc.).
class StatementFormatters {
  StatementFormatters._();

  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _isoDateFmt = DateFormat('yyyy-MM-dd');

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

  // ── Dates ─────────────────────────────────────────────────────────────

  /// "dd MMM yyyy" — e.g. "04 Jun 2026"
  static String date(DateTime d) => _dateFmt.format(d);

  /// "yyyy-MM-dd" — ISO format, ideal for CSV headers / machine parsing.
  static String isoDate(DateTime d) => _isoDateFmt.format(d);

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
