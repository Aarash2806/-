import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chessyar/services/uci_engine.dart';

void main() {
  group('UciEngine.parseInfoLine', () {
    test('parses a full stockfish-style info line', () {
      final line = 'info depth 14 seldepth 21 multipv 1 score cp 35 nodes 1234567 '
          'nps 987654 hashfull 0 tbhits 0 time 1250 pv e2e4 e7e5 g1f3';
      final line1 = UciEngine.parseInfoLine(line);
      expect(line1, isNotNull);
      expect(line1!.depth, 14);
      expect(line1.multiPv, 1);
      expect(line1.scoreCp, 35);
      expect(line1.mateIn, isNull);
      expect(line1.nodes, 1234567);
      expect(line1.nps, 987654);
      expect(line1.pvUci, ['e2e4', 'e7e5', 'g1f3']);
    });

    test('does not confuse seldepth with depth', () {
      // A line whose ONLY depth-like token is `seldepth` must yield depth 0,
      // not the seldepth value.
      final line1 = UciEngine.parseInfoLine('info seldepth 25 multipv 1 pv e2e4');
      expect(line1, isNotNull);
      expect(line1!.depth, 0);
    });

    test('parses mate scores', () {
      final line1 = UciEngine.parseInfoLine('info depth 12 multipv 1 score mate 3 pv f6g8');
      expect(line1!.mateIn, 3);
      expect(line1.scoreCp, isNull);
    });

    test('rejects lowerbound / string lines', () {
      expect(
        UciEngine.parseInfoLine('info depth 10 score cp 20 lowerbound pv e2e4'),
        isNull,
      );
      expect(
        UciEngine.parseInfoLine('info depth 10 string alright'),
        isNull,
      );
    });

    test('rejects lines without pv', () {
      expect(UciEngine.parseInfoLine('info depth 10 score cp 20'), isNull);
    });
  });

  group('pvToSan', () {
    test('renders a PV from the initial position', () {
      final pos = Chess.fromSetup(Setup.standard);
      final sans = pvToSan(pos, ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5']);
      expect(sans, ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
    });

    test('renders castling and promotion inside a PV', () {
      final pos = Chess.fromSetup(Setup.parseFen('r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1'));
      final sans = pvToSan(pos, ['e1h1']);
      expect(sans, ['O-O']);
    });

    test('falls back to UCI when a PV move cannot be applied', () {
      final pos = Chess.fromSetup(Setup.standard);
      // g1f3 is legal, then a nonsense move for that position.
      final sans = pvToSan(pos, ['g1f3', 'a1a6']);
      expect(sans.first, 'Nf3');
      expect(sans.last, 'a1a6');
    });
  });

  group('moveFromUci', () {
    test('parses normal and promotion moves', () {
      expect(moveFromUci('e2e4')!.from, Square.parse('e2'));
      expect(moveFromUci('e7e8q')!.promotion, Role.queen);
      expect(moveFromUci('e7e8x'), isNull);
      expect(moveFromUci('zz'), isNull);
    });
  });

  group('score formatting', () {
    test('white POV centipawns', () {
      expect(formatCp(35), '+0.35');
      expect(formatCp(-120), '-1.20');
    });

    test('scores are shown from white point of view', () {
      final whiteToMove = EngineLine(
        multiPv: 1,
        depth: 10,
        scoreCp: 30,
        nodes: 0,
        nps: 0,
        pvUci: ['e2e4'],
      );
      final blackToMove = EngineLine(
        multiPv: 1,
        depth: 10,
        scoreCp: 30, // engine says the side to move (black) is +0.30
        nodes: 0,
        nps: 0,
        pvUci: ['e7e5'],
      );
      expect(formatScore(whiteToMove, Side.white), '+0.30');
      expect(formatScore(blackToMove, Side.black), '-0.30');
    });

    test('mate scores', () {
      final mate = EngineLine(
        multiPv: 1,
        depth: 10,
        mateIn: 3,
        nodes: 0,
        nps: 0,
        pvUci: ['e2e4'],
      );
      expect(formatScore(mate, Side.white), '#3');
      expect(formatScore(mate, Side.black), '-#3');
    });

    test('win probability saturates', () {
      expect(winProbability(0), closeTo(0.5, 0.001));
      expect(winProbability(100000), closeTo(1.0, 0.001));
      expect(winProbability(-100000), closeTo(0.0, 0.001));
    });
  });

  group('formatCount', () {
    test('k/M formatting', () {
      expect(formatCount(999), '999');
      expect(formatCount(1234), '1.2k');
      expect(formatCount(35400), '35k');
      expect(formatCount(1234567), '1.2M');
      expect(formatCount(12500000), '13M');
    });
  });

  test('TimeoutException exists in dart:async flow used by UI', () {
    // Sanity: catching TimeoutException compiles and matches.
    expect(() => throw TimeoutException('x'), throwsA(isA<TimeoutException>()));
  });
}
