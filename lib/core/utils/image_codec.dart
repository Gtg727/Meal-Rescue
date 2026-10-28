import 'dart:convert';
import 'dart:typed_data';

import '../constants/app_constants.dart';

/// Food photos are stored inside the Firestore listing document as a
/// `data:` URI (no Firebase Storage needed, so it works on the free plan).
/// The picker already downsizes and compresses the image; this only checks
/// the type and size and builds the string.

/// Thrown message is shown to the user as-is.
class ImageTooLargeException implements Exception {
  const ImageTooLargeException();
  @override
  String toString() =>
      'That photo is too large. Pick a smaller one (max ${kMaxImageBytes ~/ 1024} KB after compression).';
}

/// Returns "image/png", "image/jpeg" or null when the bytes are neither.
String? sniffImageMime(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  return null;
}

/// Builds a `data:` URI. Throws [FormatException] for non JPG/PNG data and
/// [ImageTooLargeException] when above [kMaxImageBytes].
String encodeImageDataUri(Uint8List bytes) {
  final mime = sniffImageMime(bytes);
  if (mime == null) {
    throw const FormatException('Only JPG or PNG images are allowed.');
  }
  if (bytes.length > kMaxImageBytes) throw const ImageTooLargeException();
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

bool isDataUri(String value) => value.startsWith('data:image/');

/// Decodes a `data:` URI produced by [encodeImageDataUri]; null if invalid.
Uint8List? decodeImageDataUri(String value) {
  if (!isDataUri(value)) return null;
  final comma = value.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(value.substring(comma + 1));
  } catch (_) {
    return null;
  }
}
