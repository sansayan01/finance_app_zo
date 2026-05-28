import 'dart:typed_data';

/// Stub for non-web platforms. Always returns false.
bool downloadFile(Uint8List bytes, String fileName, String mimeType) {
  return false;
}
