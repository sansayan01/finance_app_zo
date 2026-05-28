import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart' as platform;

/// Downloads bytes as a file. On web, triggers browser download.
/// Returns true if handled (web), false if caller should use native IO.
bool downloadFileForWeb(Uint8List bytes, String fileName, String mimeType) {
  if (!kIsWeb) return false;
  return platform.downloadFile(bytes, fileName, mimeType);
}
