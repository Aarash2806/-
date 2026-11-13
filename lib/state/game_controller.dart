import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

/// One played move, remembering the position before it (for undo).
class MoveRecord {
  final Position before;
  final NormalMove move;
  final String san;

  const MoveRecord(this.before, this.move, this.san);
}

/// Holds the current game state for the analysis board.
/// All rules (legal moves, castling, en passant, promotion, check/mate)
/// come from the battle-tested dartchess library used by Lichess.
class GameController extends ChangeNotifier {
  static const String initialFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  static Position _newChess() => Chess.fromSetup(Setup.parseFen(initialFen));

  Position _position = _newChess();
  final List<MoveRecord> _records = <MoveRecord>[];
  Side _startTurn = Side.white;
  Square? selected;
  bool flipped = false;

  Position get position => _position;
  List<MoveRecord> get records => List.unmodifiable(_records);
  Side get turn => _position.turn;
  bool get isCheck => _position.isCheck;
  bool get isGameOver => _position.isGameOver;
  bool get isStalemate => _position.isStalemate;
  Outcome? get outcome => _position.outcome;
  String get fen => _position.fen;
  bool get canUndo => _records.isNotEmpty;
  bool get startTurnIsBlack => _startTurn == Side.black;

  Square? get lastFrom => _records.isEmpty ? null : _records.last.move.from;
  Square? get lastTo => _records.isEmpty ? null : _records.last.move.to;

  Square? get checkKingSquare =>
      _position.isCheck ? _position.board.kingOf(_position.turn) : null;

  Map<Square, SquareSet> get legalMoves => _position.legalMoves;

  SquareSet? targetsFor(Square? square) {
    if (square == null) return null;
    return _position.legalMoves[square];
  }

  void select(Square? square) {
    selected = (selected == square) ? null : square;
    notifyListeners();
  }

  bool isLegalMove(Square from, Square to) =>
      _position.legalMoves[from]?.has(to) ?? false;

  /// True when moving the pawn on [from] to [to] requires choosing a piece.
  bool needsPromotion(Square from, Square to) {
    final piece = _position.board.pieceAt(from);
    if (piece == null || piece.role != Role.pawn) return false;
    final r = to.rank;
    return (piece.color == Side.white && r == 7) ||
        (piece.color == Side.black && r == 0);
  }

  void play(NormalMove move) {
    if (!isLegalMove(move.from, move.to)) return;
    final (nextPos, san) = _position.makeSan(move);
    _records.add(MoveRecord(_position, move, san));
    _position = nextPos;
    selected = null;
    notifyListeners();
  }

  void undo() {
    if (_records.isEmpty) return;
    _position = _records.removeLast().before;
    selected = null;
    notifyListeners();
  }

  void newGame() {
    _position = _newChess();
    _records.clear();
    _startTurn = Side.white;
    selected = null;
    notifyListeners();
  }

  /// Loads a FEN. Throws [FormatException]-family errors from dartchess on
  /// invalid input; the previous state stays intact in that case.
  void loadFen(String fen) {
    final pos = Chess.fromSetup(Setup.parseFen(fen.trim()));
    _position = pos;
    _records.clear();
    _startTurn = pos.turn;
    selected = null;
    notifyListeners();
  }

  String get resultString {
    final winner = outcome?.winner;
    if (winner == Side.white) return '1-0';
    if (winner == Side.black) return '0-1';
    if (outcome != null) return '1/2-1/2';
    return '*';
  }

  String get pgn {
    final now = DateTime.now();
    final date =
        '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
    final sb = StringBuffer();
    sb.writeln('[Event "ChessYar Professional"]');
    sb.writeln('[Site "Local"]');
    sb.writeln('[Date "$date"]');
    sb.writeln('[White "White"]');
    sb.writeln('[Black "Black"]');
    sb.writeln('[Result "$resultString"]');
    sb.writeln();
    for (var i = 0; i < _records.length; i++) {
      final n = i + (_startTurn == Side.black ? 1 : 0);
      final moveNo = n ~/ 2 + 1;
      if (n.isEven) {
        sb.write('$moveNo. ${_records[i].san} ');
      } else {
        sb.write('$moveNo... ${_records[i].san} ');
      }
    }
    sb.write(resultString);
    return sb.toString();
  }
}
