import 'package:pdf/pdf.dart';

/// Shared PDF statement color palette.
///
/// Provides a consistent, bank-grade visual identity across loan and savings
/// statements. Uses [PdfColor.fromHex] for exact brand color values.
class StatementColors {
  StatementColors._();

  // ── Primary Brand ──
  static final navy900 = PdfColor.fromHex('#0B1D3A');
  static final navy800 = PdfColor.fromHex('#132D5E');
  static final navy700 = PdfColor.fromHex('#1A3C7A');
  static final navy600 = PdfColor.fromHex('#1E4D8E');
  static final navy100 = PdfColor.fromHex('#D6E4F7');
  static final navy50  = PdfColor.fromHex('#EBF1FB');

  // ── Accent ──
  static final teal600 = PdfColor.fromHex('#0E8A7D');
  static final teal500 = PdfColor.fromHex('#14B8A6');
  static final teal50  = PdfColor.fromHex('#E6F7F5');
  static final teal200 = PdfColor.fromHex('#90D5CE');
  static final teal100 = PdfColor.fromHex('#CCFBF1');

  // ── Premium Gold Accents ──
  static final gold700  = PdfColor.fromHex('#B8860B');
  static final gold500  = PdfColor.fromHex('#D4AF37');
  static final gold300  = PdfColor.fromHex('#E8D48B');
  static final gold100  = PdfColor.fromHex('#FDF6E3');
  static final gold50   = PdfColor.fromHex('#FFFDF5');

  // ── Semantic Status ──
  static final green700  = PdfColor.fromHex('#1B8A4A');
  static final green600  = PdfColor.fromHex('#16A34A');
  static final green50   = PdfColor.fromHex('#E8F5EE');
  static final green100  = PdfColor.fromHex('#D1FAE5');
  static final red700    = PdfColor.fromHex('#C0392B');
  static final red600    = PdfColor.fromHex('#DC2626');
  static final red50     = PdfColor.fromHex('#FCEAE8');
  static final red100    = PdfColor.fromHex('#FEE2E2');
  static final orange700 = PdfColor.fromHex('#D4760A');
  static final orange600 = PdfColor.fromHex('#EA580C');
  static final orange50  = PdfColor.fromHex('#FEF3E0');
  static final orange100 = PdfColor.fromHex('#FFEDD5');
  static final blue700   = PdfColor.fromHex('#2563EB');
  static final blue50    = PdfColor.fromHex('#EFF6FF');
  static final purple700 = PdfColor.fromHex('#7C3AED');
  static final purple50  = PdfColor.fromHex('#F3E8FF');

  // ── Neutral ──
  static final grey900 = PdfColor.fromHex('#111827');
  static final grey800 = PdfColor.fromHex('#1F2937');
  static final grey700 = PdfColor.fromHex('#374151');
  static final grey600 = PdfColor.fromHex('#4B5563');
  static final grey500 = PdfColor.fromHex('#6B7280');
  static final grey400 = PdfColor.fromHex('#9CA3AF');
  static final grey300 = PdfColor.fromHex('#D1D5DB');
  static final grey200 = PdfColor.fromHex('#E5E7EB');
  static final grey100 = PdfColor.fromHex('#F3F4F6');
  static final grey50  = PdfColor.fromHex('#F9FAFB');
  static final white   = PdfColor(1, 1, 1);

  // ── Watermark ──
  static final watermark = const PdfColor(0.85, 0.85, 0.85); // ~15% grey

  // ── Health Score Grades ──
  static final healthA    = PdfColor.fromHex('#059669'); // Emerald
  static final healthAbg  = PdfColor.fromHex('#D1FAE5');
  static final healthB    = PdfColor.fromHex('#16A34A'); // Green
  static final healthBbg  = PdfColor.fromHex('#DCFCE7');
  static final healthC    = PdfColor.fromHex('#CA8A04'); // Amber
  static final healthCbg  = PdfColor.fromHex('#FEF9C3');
  static final healthD    = PdfColor.fromHex('#EA580C'); // Orange
  static final healthDbg  = PdfColor.fromHex('#FFEDD5');
  static final healthE    = PdfColor.fromHex('#DC2626'); // Red
  static final healthEbg  = PdfColor.fromHex('#FEE2E2');

  // ── Helpers ──

  /// Returns the semantic color for a given EMI status string.
  static PdfColor statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':    return green700;
      case 'overdue': return red700;
      case 'pending': return orange700;
      case 'waived':  return purple700;
      case 'frozen':  return blue700;
      default:        return grey600;
    }
  }

  /// Returns the row background color for a given EMI status string.
  static PdfColor statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'paid':    return green50;
      case 'overdue': return red50;
      case 'pending': return orange50;
      case 'waived':  return purple50;
      case 'frozen':  return blue50;
      default:        return white;
    }
  }

  /// Returns the foreground color for a health grade letter.
  static PdfColor healthGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A': return healthA;
      case 'B': return healthB;
      case 'C': return healthC;
      case 'D': return healthD;
      case 'E': return healthE;
      default:  return grey500;
    }
  }

  /// Returns the background color for a health grade letter.
  static PdfColor healthGradeBg(String grade) {
    switch (grade.toUpperCase()) {
      case 'A': return healthAbg;
      case 'B': return healthBbg;
      case 'C': return healthCbg;
      case 'D': return healthDbg;
      case 'E': return healthEbg;
      default:  return grey100;
    }
  }
}
