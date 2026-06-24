import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrPng {
  /// Renders a QR code to PNG bytes off-screen.
  ///
  /// Uses branded teal-navy styling for a premium appearance.
  static Future<Uint8List?> generate(String data, {double size = 200}) async {
    try {
      final painter = QrPainter(
        data: data,
        version: QrVersions.auto,
        gapless: true,
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF0B1D3A), // Navy 900
        ),
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF0E8A7D), // Teal 600
        ),
      );
      final image = await painter.toImage(size);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Generates a branded QR code encoding structured verification data.
  ///
  /// Format: `VERIFY|<statementRef>|<hashPrefix>|<loanNumber>`
  /// This allows scanning the QR to verify statement authenticity.
  static Future<Uint8List?> generateVerification({
    required String loanNumber,
    String? statementRef,
    String? securityHash,
    double size = 200,
  }) async {
    final ref = statementRef ?? 'N/A';
    final hashPrefix = (securityHash ?? '').length >= 16
        ? securityHash!.substring(0, 16)
        : (securityHash ?? 'N/A');
    final payload = 'VERIFY|$ref|$hashPrefix|$loanNumber';
    return generate(payload, size: size);
  }
}
