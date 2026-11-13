// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:chessyar/services/pgn/pgn_parser.dart';
import 'package:dartchess/dartchess.dart';

/// Sample covering every messy-real-world case the user reported:
/// prose noise, multi-game collection, comments, nested variations, NAGs,
/// glued move numbers, an FEN exercise and a `;` line comment.
const sample = r'''
Some intro prose about the openings collection — will be skipped.

[Event "Casual game"]
[Site "Tehran"]
[Date "2024.01.05"]
[White "Ali"]
[Black "Sara"]
[Result "1-0"]

1. e4 {The best by test; also 1. d4 is fine} 1... e5 2. Nf3 (2. f4 {King's Gambit!} 2... exf4 (2... d5 3. exd5) 3. Nf3) 2... Nc6 3. Bb5 a6 $1 4. Ba4 Nf6 5. O-O 1-0

Trailing prose between games.

[Event "Puzzle 1"]
[FEN "r1bqkbnr/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4"]
[SetUp "1"]
[Result "*"]

{Mate in one} 1. Qxf7# *

[Event "Blitz Arena"]
[White "Reza"]
[Black "Nima"]
[Result "1/2-1/2"]
[ECO "C01"]

1.e4 e6 2.d4 d5 3.Nc3 ; French Defence main line
3... Nf6 4. Bg5 Be7 1/2-1/2
''';

final failures = <String>[];

void check(bool cond, String label) {
  if (cond) {
    print('ok   $label');
  } else {
    failures.add(label);
    print('FAIL $label');
  }
}

void main() {
  final res = PgnDocument.parseText(sample);
  check(res.games.length == 3, '3 games found (got ${res.games.length})');

  final g0 = res.games[0];
  check(g0.white == 'Ali' && g0.black == 'Sara', 'player headers');
  final sans = g0.mainline.map((m) => m.san).toList();
  check(
    sans.join(' ') == 'e4 e5 Nf3 Nc6 Bb5 a6 Ba4 Nf6 O-O',
    'mainline of game 1 (got: ${sans.join(" ")})',
  );
  check(g0.mainline.first.fenAfter.startsWith('rnbqkbnr/pppppppp/8/8/4P3'),
      'fenAfter of 1.e4');
  check(g0.mainline[1].fenBefore == g0.mainline[0].fenAfter,
      'fen chain continuity');
  check(!g0.mainline[4].isCapture, 'Bb5 is not a capture');
  check(g0.variationCount >= 2, 'variation count (got ${g0.variationCount})');
  check(g0.commentCount >= 2, 'comment count (got ${g0.commentCount})');
  check(g0.mainline[5].nags.contains(1), 'NAG \$1 attached to a6');
  check(g0.result == '1-0', 'result header');

  // variation tree: after 1...e5 the King's Gambit sideline hangs off e5,
  // and the nested d5 line hangs off the f4 branch point (sibling of exf4).
  final e4 = g0.tree.children[0];
  final e5 = e4.children[0];
  check(e5.children.length == 2, 'sideline branch at e5');
  check(e5.children[1].data.san == 'f4', 'sideline is 2.f4');
  final f4 = e5.children[1];
  check(f4.children[0].data.san == 'exf4', 'sideline continues exf4');
  check(f4.children.length == 2, 'nested variation hangs off f4');
  check(f4.children[1].data.san == 'd5', 'nested alt is 2...d5');
  check(f4.children[1].children[0].data.san == 'exd5', 'nested line continues exd5');
  check(f4.data.comments?.isNotEmpty == true,
      "comment inside variation (King's Gambit)");

  final g1 = res.games[1];
  check(g1.isExercise, 'FEN exercise detected');
  check(g1.mainline.length == 1, 'exercise has 1 solution move');
  check(g1.mainline.first.san == 'Qxf7#', 'solution is Qxf7#');
  check(g1.mainline.first.isMate, 'solution flagged as mate');
  check(g1.mainline.first.startingComments.contains('Mate in one') ||
          g1.initialComments.contains('Mate in one'),
      'exercise initial comment');
  check(g1.mainline.first.moveNumber == 4,
      'exercise move number from FEN (fullmove 4)');
  check(g1.startFen != Chess.initial.fen, 'exercise start FEN differs from start');

  final g2 = res.games[2];
  check(g2.eco == 'C01' && g2.result == '1/2-1/2', 'ECO + draw result');
  check(g2.mainline.length == 8, 'game 3 length (got ${g2.mainline.length})');
  check(g2.mainline[0].san == 'e4', 'glued "1.e4" parsed');
  check(g2.mainline[5].san == 'Nf6', '; line comment does not break parsing');

  check(res.totalIllegalMoves == 0, 'no illegal moves in sample');

  // ------------------------------------------------------ headerless movetext
  final r2 = PgnDocument.parseText('1. d4 d5 2. c4 e6 3. Nc3 *');
  check(r2.games.length == 1 && r2.games.first.mainline.length == 5,
      'headerless movetext game');

  // ------------------------------------------------------ illegal move tolerated
  final r3 =
      PgnDocument.parseText('1. e4 e5 2. Qh5 Nf6 3. Bc4 Na6 4. O-O-O 5. Bxa6 *');
  check(r3.games.first.illegalMoves == 1,
      'illegal move counted (O-O-O blocked by knight)');
  check(r3.games.first.mainline.length == 7, 'rest of line stays intact');

  // ------------------------------------------------------ encodings
  // cp1252 bytes for: [White "José"]
  final cpBytes = <int>[
    ...ascii.encode('[White "Jos'),
    0xE9,
    ...ascii.encode('"]\n\n1. e4 *\n'),
  ];
  final r4 = PgnDocument.parseBytes(cpBytes);
  check(r4.encoding.startsWith('CP1252'), 'cp1252 detected (got ${r4.encoding})');
  check(r4.games.first.white == 'José', 'cp1252 accented name decoded');

  final bomBytes = <int>[
    0xEF, 0xBB, 0xBF,
    ...utf8.encode('[Event "B"]\n\n1. e4 *\n'),
  ];
  final r5 = PgnDocument.parseBytes(bomBytes);
  check(r5.games.length == 1 && r5.games.first.event == 'B', 'UTF-8 BOM');

  final u16 = <int>[0xFF, 0xFE, ..._utf16le('[Event "U16"]\n\n1. e4 *\n')];
  final r6 = PgnDocument.parseBytes(u16);
  check(r6.games.length == 1 && r6.games.first.event == 'U16', 'UTF-16LE file');

  // ------------------------------------------------------ glued header line
  final r7 = PgnDocument.parseText(
      '[Event "Glued"]\n[White "A"]\n[Black "B"]\n[Result "*"]\n1. e4 e5 *\n');
  check(r7.games.length == 1 && r7.games.first.mainline.length == 2,
      'movetext glued after last header');

  // ------------------------------------------------------ collection of 30
  final big = StringBuffer();
  for (var i = 0; i < 30; i++) {
    big
      ..writeln('[Event "G$i"]')
      ..writeln('[Result "*"]')
      ..writeln()
      ..writeln('1. e4 e5 *')
      ..writeln();
  }
  final r8 = PgnDocument.parseText(big.toString());
  check(r8.games.length == 30, '30-game collection (got ${r8.games.length})');

  // ------------------------------------------------------ CRLF line endings
  final r9 = PgnDocument.parseText(
      '[Event "CRLF"]\r\n[White "W"]\r\n[Black "B"]\r\n[Result "*"]\r\n\r\n1. d4 *\r\n');
  check(r9.games.length == 1 && r9.games.first.mainline.length == 1,
      'CRLF normalized');

  if (failures.isEmpty) {
    print('ALL PGN TESTS PASSED');
  } else {
    print('FAILED: ${failures.length} test(s)');
    exitCode = 1;
  }
}

List<int> _utf16le(String s) {
  final out = <int>[];
  for (final cu in s.codeUnits) {
    out..add(cu & 0xFF)..add((cu >> 8) & 0xFF);
  }
  return out;
}
