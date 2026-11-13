import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chessyar/state/game_controller.dart';

void main() {
  test('legal moves are played and SAN is recorded', () {
    final game = GameController();
    game.play(NormalMove(from: Square.parse('e2')!, to: Square.parse('e4')!));
    game.play(NormalMove(from: Square.parse('e7')!, to: Square.parse('e5')!));
    game.play(NormalMove(from: Square.parse('g1')!, to: Square.parse('f3')!));
    expect(game.records.length, 3);
    expect(game.records[0].san, 'e4');
    expect(game.records[2].san, 'Nf3');
    expect(game.turn, Side.black);
    expect(game.fen, 'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2');
  });

  test('illegal moves are ignored', () {
    final game = GameController();
    game.play(NormalMove(from: Square.parse('e2')!, to: Square.parse('e5')!));
    expect(game.records, isEmpty);
    expect(game.turn, Side.white);
  });

  test('undo restores the previous position', () {
    final game = GameController();
    game.play(NormalMove(from: Square.parse('e2')!, to: Square.parse('e4')!));
    game.undo();
    expect(game.records, isEmpty);
    expect(game.turn, Side.white);
    expect(game.fen, GameController.initialFen);
  });

  test('castling is handled by the rules engine', () {
    final game = GameController();
    game.loadFen('r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1');
    // dartchess encodes castling as king -> rook square (Chess960 style).
    game.play(NormalMove(from: Square.parse('e1')!, to: Square.parse('h1')!));
    expect(game.records.single.san, 'O-O');
    expect(game.fen.startsWith('r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R4RK1 b kq - 1 1'), isTrue);
  });

  test('promotion requires a choice and produces =Q SAN', () {
    final game = GameController();
    expect(game.needsPromotion(Square.parse('e2')!, Square.parse('e4')!), isFalse);
    game.loadFen('8/P6k/8/8/8/8/8/7K w - - 0 1');
    expect(game.needsPromotion(Square.parse('a7')!, Square.parse('a8')!), isTrue);
    game.play(NormalMove(from: Square.parse('a7')!, to: Square.parse('a8')!, promotion: Role.queen));
    expect(game.records.single.san, contains('=Q'));
  });

  test('checkmate is detected', () {
    final game = GameController();
    game.loadFen('6k1/5ppp/8/8/8/8/5PPP/4R1K1 w - - 0 1');
    game.play(NormalMove(from: Square.parse('e1')!, to: Square.parse('e8')!));
    expect(game.isGameOver, isTrue);
    expect(game.outcome?.winner, Side.white);
    expect(game.records.single.san, 'Re8#');
  });

  test('pgn output contains headers and move numbers', () {
    final game = GameController();
    game.play(NormalMove(from: Square.parse('e2')!, to: Square.parse('e4')!));
    final pgn = game.pgn;
    expect(pgn, contains('[Event "ChessYar Professional"]'));
    expect(pgn, contains('1. e4'));
  });
}
