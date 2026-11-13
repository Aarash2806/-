import 'dart:convert';

/// Decodes raw PGN bytes into text, tolerating the encoding chaos of real
/// world files: UTF-8 (with/without BOM), UTF-16 LE/BE (Notepad "Unicode"
/// mode) and legacy Windows-1252 / Latin-1 exports.
class DecodedText {
  const DecodedText(this.text, this.encoding);

  final String text;

  /// Human-readable label, e.g. 'UTF-8', 'UTF-16LE', 'CP1252/Latin-1'.
  final String encoding;
}

DecodedText decodePgnBytes(List<int> raw) {
  if (raw.isEmpty) return const DecodedText('', 'empty');

  // UTF-16 LE BOM (FF FE).
  if (raw.length >= 2 && raw[0] == 0xFF && raw[1] == 0xFE) {
    return DecodedText(_decodeUtf16(raw.sublist(2), littleEndian: true), 'UTF-16LE');
  }
  // UTF-16 BE BOM (FE FF).
  if (raw.length >= 2 && raw[0] == 0xFE && raw[1] == 0xFF) {
    return DecodedText(_decodeUtf16(raw.sublist(2), littleEndian: false), 'UTF-16BE');
  }

  var body = raw;
  var hadBom = false;
  if (raw.length >= 3 && raw[0] == 0xEF && raw[1] == 0xBB && raw[2] == 0xBF) {
    body = raw.sublist(3);
    hadBom = true;
  }

  try {
    return DecodedText(utf8.decode(body), hadBom ? 'UTF-8 (BOM)' : 'UTF-8');
  } on FormatException {
    // Invalid UTF-8: fall back to legacy single-byte encodings (old ChessBase
    // exports, European names, curly quotes and dashes).
    return DecodedText(
      _decodeCp1252(body),
      hadBom ? 'CP1252 (BOM→fallback)' : 'CP1252/Latin-1',
    );
  }
}

String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
  int unitAt(int i) => littleEndian
      ? (bytes[i] | (bytes[i + 1] << 8))
      : ((bytes[i] << 8) | bytes[i + 1]);

  final sb = StringBuffer();
  var i = 0;
  while (i + 1 < bytes.length) {
    var unit = unitAt(i);
    i += 2;
    if (unit >= 0xD800 && unit <= 0xDBFF && i + 1 < bytes.length) {
      final lo = unitAt(i);
      if (lo >= 0xDC00 && lo <= 0xDFFF) {
        unit = 0x10000 + ((unit - 0xD800) << 10) + (lo - 0xDC00);
        i += 2;
      }
    }
    sb.writeCharCode(unit);
  }
  return sb.toString();
}

/// Windows-1252 mappings for 0x80..0x9F (undefined slots map to U+FFFD).
const List<int?> _cp1252High = [
  0x20AC, null, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, null, 0x017D, null, //
  0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, //
  0x2122, 0x0161, 0x203A, 0x0153, null, 0x017E, 0x0178, //
];

String _decodeCp1252(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    if (b >= 0x80 && b <= 0x9F) {
      final cp = _cp1252High[b - 0x80];
      sb.writeCharCode(cp ?? 0xFFFD);
    } else {
      sb.writeCharCode(b); // Latin-1 range maps 1:1
    }
  }
  return sb.toString();
}
