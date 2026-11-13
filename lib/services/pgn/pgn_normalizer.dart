/// Prepares messy real-world PGN text for the dartchess parser:
///  - normalizes line endings (\r\n, \r → \n)
///  - strips NUL bytes and stray BOM characters (broken-encoding artifacts)
///  - splits `[Tag "..."]1. e4` glue into two lines
///  - guarantees an empty line before the first header of every game so that
///    multi-game collections always split correctly
String normalizePgnText(String input) {
  var text = input
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\u0000', '')
      .replaceAll('\uFEFF', '');

  final headerLine = RegExp(r'^\[\s*(\w+)\s+"((?:[^"\\]|\\.)*)"\s*\]');

  final out = StringBuffer();
  var prevWasHeader = false;
  var wroteAnything = false;

  for (final rawLine in text.split('\n')) {
    final isHeader = headerLine.hasMatch(rawLine);

    // Split "[Black \"x\"]1. e4 e5" glue into a header line + a moves line.
    var line = rawLine;
    if (isHeader) {
      final m = headerLine.firstMatch(rawLine)!;
      final rest = rawLine.substring(m.end).trim();
      if (rest.isNotEmpty) {
        line = '${rawLine.substring(0, m.end)}\n$rest';
      }
    }

    // Blank line before the FIRST header of a new game (after movetext or
    // prose) so the multi-game splitter sees a clean boundary.
    if (isHeader && !prevWasHeader && wroteAnything) {
      out.writeln();
    }

    out
      ..write(line)
      ..writeln();
    prevWasHeader = isHeader;
    wroteAnything = true;
  }

  return out.toString();
}
