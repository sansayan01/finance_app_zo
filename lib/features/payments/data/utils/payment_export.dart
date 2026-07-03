import 'dart:typed_data';

import '../../../../core/models/statement_org_info.dart';
import '../providers/payment_providers.dart';
import '../services/payment_pdf_service.dart';

class PaymentExport {
  static Future<Uint8List> generatePdf(TodayPaymentData data, String dateLabel, {StatementOrgInfo? orgInfo}) {
    return PaymentPdfService.generate(data: data, dateLabel: dateLabel, orgInfo: orgInfo);
  }

  static Future<void> sharePdf(TodayPaymentData data, String dateLabel, {StatementOrgInfo? orgInfo}) {
    return PaymentPdfService.share(data: data, dateLabel: dateLabel, orgInfo: orgInfo);
  }
}
