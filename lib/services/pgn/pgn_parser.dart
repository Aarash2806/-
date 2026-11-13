import 'dart:io' as io;

import 'package:dartchess/dartchess.dart';

import 'pgn_encoding.dart';
import 'pgn_normalizer.dart';

export 'pgn_encoding.dart' show DecodedText, decodePgnBytes;

/// A validated mainline half-move with full position context.
class PgnMainlineMove {
  const PgnMainlineMove({
    required this.ply,
    required this.moveNumber,
    required this.white,
    required this.san,
    required this.move,
    required this.fenBefore,
    required this.fenAfter,
    required this.isCapture,
    required this.isCheck,
    required this.isMate,
    this.nags = const [],
    this.startingComments = const [],
    this.comments = const [],
  });

  /// 1-based half-move index inside the line.
  final int ply;

  /// Full-move number (1 for 1.e4 and 1...e5).
  final int moveNumber;
  final bool white;

  /// SAN exactly as found in the PGN (may include +/# and !? glyphs).
  final String san;

  /// Validated dartchess move object (legal by construction).
  final Move move;
  final String fenBefore;
  final String fenAfter;
  final bool isCapture;
  final bool isCheck;
  final bool isMate;

  /// NAG codes attached to this move ($1 = !, $2 = ?, ...).
  final List<int> nags;

  /// Comments written BEFORE this move.
  final List<String> startingComments;

  /// Comments written AFTER this move.
  final List<String> comments;

  String get cleanSan => san.replaceAll(RegExp(r'[!?]'), '');
}

/// One game read from a PGN document.
class ChessYarPgnGame {
  ChessYarPgnGame._({
    required this.headers,
    required this.tree,
    required this.startFen,
    required this.mainline,
    required this.variationCount,
    required this.commentCount,
    required this.warnings,
    required this.illegalMoves,
    required this.initialComments,
  });

  final Map<String, String> headers;

  /// Full move tree (mainline + sidelines) as parsed by dartchess.
  final PgnNode<PgnNodeData> tree;
  final String startFen;

  /// Validated mainline with FEN before/after every move.
  final List<PgnMainlineMove> mainline;

  /// Number of alternative branch points in the whole tree.
  final int variationCount;
  final int commentCount;
  final List<String> warnings;
  final int illegalMoves;

  /// Comments written before the first move of the game.
  final List<String> initialComments;

  bool get isExercise =>
      (headers['FEN'] ?? '').trim().isNotEmpty && headers['SetUp'] != '0';

  bool get hasVariations => variationCount > 0;

  String get white => headers['White'] ?? '?';
  String get black => headers['Black'] ?? '?';
  String get event => headers['Event'] ?? '';
  String get site => headers['Site'] ?? '';
  String get date => headers['UTCDate'] ?? headers['Date'] ?? '';
  String get eco => headers['ECO'] ?? '';
  String get openingName => headers['Opening'] ?? headers['Variation'] ?? '';
  String get result => headers['Result'] ?? '*';
  String get label => '$white — $black';

  String get subtitle {
    final parts = <String>[
      if (event.isNotEmpty && event != '?') event,
      if (date.isNotEmpty && date != '?') date,
      if (eco.isNotEmpty) 'ECO $eco',
      result,
      '${mainline.length} حرکت',
    ];
    return parts.join(' · ');
  }
}

/// Result of parsing a whole document (file bytes or pasted text).
class PgnLoadResult {
  const PgnLoadResult({
    required this.games,
    required this.warnings,
    required this.encoding,
  });

  final List<ChessYarPgnGame> games;
  final List<String> warnings;

  /// Detected encoding label ('UTF-8', 'CP1252/Latin-1', 'UTF-16LE', ...).
  final String encoding;

  int get exerciseCount => games.where((g) => g.isExercise).length;
  int get totalIllegalMoves =>
      games.fold(0, (a, g) => a + g.illegalMoves);
  int get totalVariations => games.fold(0, (a, g) => a + g.variationCount);
}

/// ChessYar PGN facade: reads EVERY kind of PGN file —
/// single games, multi-game collections, training/exercise books (FEN),
/// files full of comments and nested variations, files with stray prose,
/// glued move numbers (1.e4), legacy encodings and old macOS line endings.
///
/// SAN validation is done with the real dartchess rules engine (the library
/// used by Lichess) — no guessing, no simulation.
class PgnDocument {
  /// Parses raw text (already decodable, e.g. pasted into a dialog).
  static PgnLoadResult parseText(String raw) {
    final warnings = <String>[];
    final normalized = normalizePgnText(raw);
    final trees = PgnGame.parseMultiGamePgn(
      normalized,
      initHeaders: PgnGame.emptyHeaders,
    );

    final games = <ChessYarPgnGame>[];
    for (final tree in trees) {
      final game = _validate(tree);
      // Drop prose-only chunks that produced neither moves nor headers.
      if (game.mainline.isEmpty && game.headers.isEmpty) continue;
      if (game.headers.isNotEmpty && game.mainline.isEmpty) {
        game.warnings.add('بازی بدون حرکت (فقط سرصفحه)');
      }
      games.add(game);
    }

    if (games.isEmpty) warnings.add('هیچ بازی معتبری در متن پیدا نشد');
    return PgnLoadResult(games: games, warnings: warnings, encoding: 'UTF-8');
  }

  /// Parses raw file bytes with automatic encoding detection.
  static PgnLoadResult parseBytes(List<int> bytes) {
    final decoded = decodePgnBytes(bytes);
    final res = parseText(decoded.text);
    return PgnLoadResult(
      games: res.games,
      warnings: res.warnings,
      encoding: decoded.encoding,
    );
  }

  /// Desktop convenience: parse a file directly.
  static PgnLoadResult parseFileSync(String path) =>
      parseBytes(io.File(path).readAsBytesSync());

  // ------------------------------------------------------------------ internals

  static ChessYarPgnGame _validate(PgnGame<PgnNodeData> g) {
    final warnings = <String>[];

    Position pos;
    try {
      pos = PgnGame.startingPosition(g.headers, ignoreImpossibleCheck: true);
    } catch (_) {
      pos = Chess.initial;
      warnings.add('FEN نامعتبر در سرصفحه — از وضعیت شروع استاندارد استفاده شد');
    }
    final startFen = pos.fen;

    var ply0 = _startingPly(startFen);
    final main = <PgnMainlineMove>[];
    var illegal = 0;
    final startPly = ply0;

    for (final node in g.moves.mainline()) {
      final move = pos.parseSan(node.san);
      if (move == null) {
        illegal++;
        if (warnings.length < 10) {
          warnings.add('حرکت نامعتبر رد شد: ${node.san}');
        }
        continue;
      }
      final fenBefore = pos.fen;
      final newPos = pos.play(move);
      final whiteMove = newPos.turn == Side.black;
      main.add(PgnMainlineMove(
        ply: ply0 + 1,
        moveNumber: ply0 ~/ 2 + 1,
        white: whiteMove,
        san: node.san,
        move: move,
        fenBefore: fenBefore,
        fenAfter: newPos.fen,
        isCapture: _isCapture(pos, move, fenBefore),
        isCheck: node.san.contains('+'),
        isMate: node.san.contains('#'),
        nags: node.nags ?? const [],
        // Game-level initial comments are surfaced under the first move
        // (the way Lichess renders them).
        startingComments: ply0 == startPly
            ? [...g.comments, ...(node.startingComments ?? const [])]
            : (node.startingComments ?? const []),
        comments: node.comments ?? const [],
      ));
      pos = newPos;
      ply0++;
    }

    return ChessYarPgnGame._(
      headers: g.headers,
      tree: g.moves,
      startFen: startFen,
      mainline: main,
      variationCount: _countBranchPoints(g.moves),
      commentCount: _countComments(g.moves) + g.comments.length,
      warnings: warnings,
      illegalMoves: illegal,
      initialComments: g.comments,
    );
  }

  /// 0-based starting ply derived from the FEN (handles exercise books that
  /// start from a middlegame position).
  static int _startingPly(String fen) {
    try {
      final setup = Setup.parseFen(fen);
      return (setup.fullmoves - 1) * 2 + (setup.turn == Side.white ? 0 : 1);
    } catch (_) {
      return 0;
    }
  }

  static bool _isCapture(Position pos, Move move, String fenBefore) {
    if (pos.board.pieceAt(move.to) != null) return true;
    // En passant: 4th FEN field holds the ep target square.
    if (move is NormalMove) {
      final piece = pos.board.pieceAt(move.from);
      final parts = fenBefore.split(' ');
      if (piece != null &&
          piece.role == Role.pawn &&
          parts.length > 3 &&
          parts[3].length == 2) {
        return Square.parse(parts[3]) == move.to;
      }
    }
    return false;
  }

  /// Counts branch points: every child beyond the mainline continuation.
  static int _countBranchPoints(PgnNode<PgnNodeData> node) {
    var count = node.children.length > 1 ? node.children.length - 1 : 0;
    for (final child in node.children) {
      count += _countBranchPoints(child);
    }
    return count;
  }

  static int _countComments(PgnNode<PgnNodeData> node) {
    var count = 0;
    for (final child in node.children) {
      final d = child.data;
      if (d.startingComments != null) count += d.startingComments!.length;
      if (d.comments != null) count += d.comments!.length;
      count += _countComments(child);
    }
    return count;
  }
}
