import 'dart:convert';

/// Decodifica contenido Quoted-Printable (RFC 2045) usado en vCard/VCF.
///
/// Solo decodifica secuencias válidas `=HH` donde HH son dos dígitos
/// hexadecimales. Cualquier otro `=` aislado se deja tal cual para evitar
/// dañar texto que no esté codificado.
///
/// No aplica decodificación dos veces: si el texto ya fue decodificado, las
/// secuencias `=XX` restantes se dejan como están.
class QuotedPrintableDecoder {
  static String decode(String input) {
    final bytes = <int>[];
    var i = 0;
    while (i < input.length) {
      final ch = input[i];
      if (ch == '=' && i + 2 < input.length) {
        final hex = input.substring(i + 1, i + 3);
        final decoded = _tryParseHex(hex);
        if (decoded != null) {
          bytes.add(decoded);
          i += 3;
          continue;
        }
      }
      // Soft line break: "=\r\n" o "=\n" se omite por completo
      if (ch == '=' && i + 1 < input.length) {
        final next = input[i + 1];
        if (next == '\r' || next == '\n') {
          i += (next == '\r' && i + 2 < input.length && input[i + 2] == '\n') ? 3 : 2;
          continue;
        }
      }
      // Carácter normal: codificar a bytes UTF-8 para que las secuencias =HH
      // se ensamblen como bytes UTF-8 antes de decodificar.
      bytes.addAll(utf8.encode(input[i]));
      i++;
    }
    return _utf8DecodeSafe(bytes);
  }

  static int? _tryParseHex(String hex) {
    try {
      return int.parse(hex, radix: 16);
    } on FormatException {
      return null;
    }
  }
}

/// Decodifica bytes como UTF-8 sin lanzar excepciones.
/// Los bytes inválidos se reemplazan con el carácter de reemplazo U+FFFD.
String _utf8DecodeSafe(List<int> bytes) {
  final result = StringBuffer();
  var i = 0;
  while (i < bytes.length) {
    final b = bytes[i];
    if (b < 0x80) {
      result.writeCharCode(b);
      i++;
    } else if (b < 0xC0) {
      result.writeCharCode(0xFFFD);
      i++;
    } else if (b < 0xE0) {
      if (i + 1 < bytes.length &&
          bytes[i + 1] >= 0x80 && bytes[i + 1] < 0xC0) {
        result.writeCharCode(((b & 0x1F) << 6) | (bytes[i + 1] & 0x3F));
        i += 2;
      } else {
        result.writeCharCode(0xFFFD);
        i++;
      }
    } else if (b < 0xF0) {
      if (i + 2 < bytes.length &&
          bytes[i + 1] >= 0x80 && bytes[i + 1] < 0xC0 &&
          bytes[i + 2] >= 0x80 && bytes[i + 2] < 0xC0) {
        result.writeCharCode(
            ((b & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) | (bytes[i + 2] & 0x3F));
        i += 3;
      } else {
        result.writeCharCode(0xFFFD);
        i++;
      }
    } else {
      result.writeCharCode(0xFFFD);
      i++;
    }
  }
  return result.toString();
}

/// Decodifica el valor de un campo vCard que puede venir en Quoted-Printable.
///
/// El parámetro [raw] es el valor ya separado del nombre de campo (es decir,
/// el texto que aparece tras el primer `:` en la línea vCard). No se asume
/// que contenga parámetros ni dos puntos adicionales.
///
/// Si el valor contiene secuencias `=HH` válidas, se decodifican.
/// Cualquier otro `=` aislado se deja tal cual para evitar dañar texto
/// que no esté codificado.
String decodeVCardValue(String raw) {
  // Decodifica Quoted-Printable directamente sobre el valor (el texto ya
  // esta separado del nombre de campo). Con la lectura del archivo como
  // UTF-8, el resultado ya esta en UTF-8 correcto; no se aplica conversion
  // Latin-1 porque eso produciria doble decodificacion (mojibake) como
  // "JosÃ©" en lugar de "José".
  return QuotedPrintableDecoder.decode(raw);
}

/// Codifica un valor a Quoted-Printable para exportación vCard cuando sea
/// necesario (caracteres fuera de ASCII imprimible).
String encodeVCardValue(String value, {bool forceQuotedPrintable = false}) {
  final needsEncoding = value.contains(RegExp(r'[^\x20-\x7E]')) ||
      value.contains('=') ||
      value.contains(';') ||
      value.contains(':') ||
      value.contains(',');

  if (!needsEncoding && !forceQuotedPrintable) {
    return value;
  }

  final bytes = utf8.encode(value);
  final result = StringBuffer();
  for (final b in bytes) {
    final ch = String.fromCharCode(b);
    if ((b >= 0x20 && b <= 0x7E && ch != '=') || b == 0x09) {
      result.write(ch);
    } else if (b == 0x20) {
      result.write('=20');
    } else {
      result.write('=${b.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }
  return result.toString();
}

/// Detecta y elimina el BOM (Byte Order Mark) UTF-8 si está presente al inicio.
String stripUtf8Bom(String input) {
  const bom = '\uFEFF';
  if (input.startsWith(bom)) {
    return input.substring(bom.length);
  }
  return input;
}
