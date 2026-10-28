import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meal_rescue/core/constants/app_constants.dart';
import 'package:meal_rescue/core/utils/image_codec.dart';

void main() {
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
  final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 9]);

  test('detects JPG and PNG by signature, not file name', () {
    expect(sniffImageMime(jpeg), 'image/jpeg');
    expect(sniffImageMime(png), 'image/png');
    expect(sniffImageMime(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });

  test('encode/decode round trip', () {
    final uri = encodeImageDataUri(jpeg);
    expect(uri, startsWith('data:image/jpeg;base64,'));
    expect(isDataUri(uri), isTrue);
    expect(decodeImageDataUri(uri), jpeg);
  });

  test('rejects other file types', () {
    expect(() => encodeImageDataUri(Uint8List.fromList([1, 2, 3, 4])),
        throwsFormatException);
  });

  test('rejects oversized images', () {
    final big = Uint8List(kMaxImageBytes + 1)..setRange(0, 3, [0xFF, 0xD8, 0xFF]);
    expect(() => encodeImageDataUri(big), throwsA(isA<ImageTooLargeException>()));
  });

  test('decode returns null for http urls and garbage', () {
    expect(decodeImageDataUri('https://example.com/a.jpg'), isNull);
    expect(decodeImageDataUri('data:image/png;base64,!!!'), isNull);
  });
}
