/// Run this script to generate placeholder preset launcher icons.
/// Usage: dart run scripts/generate_preset_icons.dart
///
/// For production, replace these with professionally designed icons.
/// This script creates simple colored squares as placeholders so the
/// activity-alias entries don't crash the app.
///
/// IMPORTANT: For real icons, use a tool like:
/// - https://www.appicon.co/
/// - flutter_launcher_icons package
/// - Android Studio Image Asset Studio
///
/// Each preset needs icons at these Android densities:
///   mdpi: 48x48, hdpi: 72x72, xhdpi: 96x96, xxhdpi: 144x144, xxxhdpi: 192x192
library;

// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

// Minimal valid PNG generator (single-color square)
Uint8List generateMinimalPng(int size, int r, int g, int b) {
  // PNG file structure:
  // Signature + IHDR + IDAT (uncompressed) + IEND

  final signature = [137, 80, 78, 71, 13, 10, 26, 10];

  // IHDR chunk
  final ihdr = <int>[
    0, 0, 0, 13, // length
    73, 72, 68, 82, // "IHDR"
    ...intToBytes(size, 4), // width
    ...intToBytes(size, 4), // height
    8, // bit depth
    2, // color type (RGB)
    0, // compression
    0, // filter
    0, // interlace
  ];
  ihdr.addAll(crc32Bytes(ihdr.sublist(4)));

  // IDAT chunk - raw pixel data with zlib wrapper
  final rawData = <int>[];
  for (var y = 0; y < size; y++) {
    rawData.add(0); // filter byte (none)
    for (var x = 0; x < size; x++) {
      rawData.addAll([r, g, b]);
    }
  }

  // Wrap in zlib (deflate with no compression)
  final zlibData = wrapZlib(rawData);
  final idat = <int>[
    ...intToBytes(zlibData.length, 4),
    73, 68, 65, 84, // "IDAT"
    ...zlibData,
  ];
  idat.addAll(crc32Bytes(idat.sublist(4)));

  // IEND chunk
  final iend = <int>[
    0, 0, 0, 0, // length
    73, 69, 78, 68, // "IEND"
  ];
  iend.addAll(crc32Bytes(iend.sublist(4)));

  return Uint8List.fromList([...signature, ...ihdr, ...idat, ...iend]);
}

List<int> intToBytes(int value, int byteCount) {
  final bytes = <int>[];
  for (var i = byteCount - 1; i >= 0; i--) {
    bytes.add((value >> (i * 8)) & 0xFF);
  }
  return bytes;
}

List<int> wrapZlib(List<int> data) {
  // Minimal zlib: CMF + FLG + uncompressed deflate blocks + Adler32
  final result = <int>[0x78, 0x01]; // CMF=deflate, FLG=no dict

  // Split into blocks of max 65535 bytes
  var offset = 0;
  while (offset < data.length) {
    final remaining = data.length - offset;
    final blockSize = remaining > 65535 ? 65535 : remaining;
    final isLast = (offset + blockSize) >= data.length;

    result.add(isLast ? 1 : 0); // BFINAL + BTYPE=00 (no compression)
    result.add(blockSize & 0xFF);
    result.add((blockSize >> 8) & 0xFF);
    result.add((~blockSize) & 0xFF);
    result.add(((~blockSize) >> 8) & 0xFF);
    result.addAll(data.sublist(offset, offset + blockSize));
    offset += blockSize;
  }

  // Adler32
  var s1 = 1;
  var s2 = 0;
  for (final byte in data) {
    s1 = (s1 + byte) % 65521;
    s2 = (s2 + s1) % 65521;
  }
  final adler = (s2 << 16) | s1;
  result.addAll(intToBytes(adler, 4));

  return result;
}

// CRC32 for PNG chunks
final _crcTable = _makeCrcTable();

List<int> _makeCrcTable() {
  final table = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      if ((c & 1) != 0) {
        c = 0xEDB88320 ^ ((c >> 1) & 0x7FFFFFFF);
      } else {
        c = (c >> 1) & 0x7FFFFFFF;
      }
    }
    table[n] = c;
  }
  return table;
}

List<int> crc32Bytes(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ ((crc >> 8) & 0x00FFFFFF);
  }
  crc = crc ^ 0xFFFFFFFF;
  return intToBytes(crc, 4);
}

void main() {
  final presets = {
    'ic_launcher': [79, 70, 229], // Indigo (default)
    'ic_launcher_bank_blue': [30, 64, 175], // Bank Blue
    'ic_launcher_savings_green': [5, 150, 105], // Savings Green
    'ic_launcher_micro_orange': [234, 88, 12], // Micro Orange
    'ic_launcher_trust_purple': [124, 58, 237], // Trust Purple
    'ic_launcher_field_teal': [13, 148, 136], // Field Teal
  };

  final densities = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  final basePath = 'android/app/src/main/res';

  for (final density in densities.entries) {
    final dir = Directory('$basePath/${density.key}');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    for (final preset in presets.entries) {
      final file = File('${dir.path}/${preset.key}.png');
      final png = generateMinimalPng(
        density.value,
        preset.value[0],
        preset.value[1],
        preset.value[2],
      );
      file.writeAsBytesSync(png);
      print('✅ Generated: ${file.path} (${density.value}x${density.value})');
    }
  }

  // Also generate preview icons for the Flutter UI
  final assetsDir = Directory('assets/icons');
  if (!assetsDir.existsSync()) assetsDir.createSync(recursive: true);

  final previewPresets = {
    'preset_default.png': [79, 70, 229],
    'preset_bank_blue.png': [30, 64, 175],
    'preset_savings_green.png': [5, 150, 105],
    'preset_micro_orange.png': [234, 88, 12],
    'preset_trust_purple.png': [124, 58, 237],
    'preset_field_teal.png': [13, 148, 136],
  };

  for (final preset in previewPresets.entries) {
    final file = File('${assetsDir.path}/${preset.key}');
    final png = generateMinimalPng(128, preset.value[0], preset.value[1], preset.value[2]);
    file.writeAsBytesSync(png);
    print('✅ Generated preview: ${file.path}');
  }

  print('\n🎉 All preset icons generated successfully!');
  print('⚠️  These are placeholder colored squares. Replace with real icons before release.');
}
