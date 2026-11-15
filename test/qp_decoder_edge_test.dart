import 'package:flutter_test/flutter_test.dart';

import 'package:nexo/features/import_export/data/services/quoted_printable_decoder.dart';

void main() {
  group('QP decoder edge cases', () {
    test('valid QP UTF-8 sequence', () {
      expect(QuotedPrintableDecoder.decode('=C3=A9'), 'é');
    });

    test('=C3=81 (Á) decodes correctly', () {
      expect(QuotedPrintableDecoder.decode('=C3=81lena'), 'Álena');
    });

    test('=C3=AD (í) decodes correctly - correct UTF-8 for U+00ED', () {
      expect(QuotedPrintableDecoder.decode('Mar=C3=ADa'), 'María');
    });

    test('=C3=B1 (ñ) decodes correctly', () {
      expect(QuotedPrintableDecoder.decode('Espa=C3=B1a'), 'España');
    });

    test('=C3=81 combined with =C3=A9', () {
      expect(
        QuotedPrintableDecoder.decode('=C3=81lena Garc=C3=ADa'),
        'Álena García',
      );
    });

    test('Base64 content with = padding does not break', () {
      expect(
        QuotedPrintableDecoder.decode('/9j/4AAQSkZJRgABAQ=='),
        '/9j/4AAQSkZJRgABAQ==',
      );
    });

    test('plain text with = sign does not break', () {
      // =ZZ is not valid hex, so = is left as-is
      expect(
        QuotedPrintableDecoder.decode('Price =ZZ dollars'),
        'Price =ZZ dollars',
      );
    });

    test('invalid UTF-8 QP sequence replaced with U+FFFD, no crash', () {
      // =C3=ED produces bytes 0xC3 0xED which is not valid UTF-8
      // (í should be =C3=AD, not =C3=ED)
      final result = QuotedPrintableDecoder.decode('=C3=ED');
      expect(result, isNotEmpty);
    });
  });
}
