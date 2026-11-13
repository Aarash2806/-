import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';

/// One MultiPV line reported by the engine (`info ... pv ...`).
class EngineLine {
  final int multiPv;
  final int depth;
  final int? scoreCp; // centipawns, from the point of view of the side to move
  final int? mateIn; // mate in N (positive: side to move mates)
  final int nodes;
  final int nps;
  final List<String> pvUci;

  const EngineLine({
    required this.multiPv,
    required this.depth,
    required this.nodes,
    required this.nps,
    required this.pvUci,
    this.scoreCp,
    this.mateIn,
  });
}

/// A real UCI engine client: spawns the engine executable as an OS process
/// (`dart:io Process.start`), performs the UCI handshake and streams parsed
/// analysis lines. No simulation anywhere - the engine really runs.
class UciEngine {
  UciEngine({
    required this.path,
    this.args = const <String>[],
    this.threads = 2,
    this.hashMb = 64,
    this.multiPv = 1,
    this.onSnapshot,
    this.onBestMove,
    this.onClosed,
  });

  final String path;
  final List<String> args;
  final int threads;
  final int hashMb;
  final int multiPv;

  /// Called on every complete MultiPV snapshot while searching.
  void Function(List<EngineLine> lines)? onSnapshot;

  /// Called when the engine reports `bestmove`.
  void Function(String bestMoveUci)? onBestMove;

  /// Called when the engine process exits.
  void Function()? onClosed;

  Process? _proc;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  Completer<void>? _uciOk;
  Completer<void>? _readyOk;
  Completer<String>? _bestMove;
  final Map<int, EngineLine> _lines = <int, EngineLine>{};
  bool _running = false;
  String _idName = '';

  bool get isRunning => _running;
  String get reportedName => _idName;

  /// Starts the process and performs `uci`/`isready` handshakes.
  /// Throws [TimeoutException] when the binary is not a responsive UCI engine.
  Future<void> start({Duration timeout = const Duration(seconds: 10)}) async {
    if (_running) return;
    final proc = await Process.start(path, args, runInShell: false);
    _proc = proc;
    _running = true;
    _idName = '';

    _stdoutSub = proc.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleLine, onDone: () => _markClosed());
    _stderrSub = proc.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((_) {}, onDone: () => _markClosed());
    unawaited(proc.exitCode.then((_) => _markClosed()));

    _uciOk = Completer<void>();
    _send('uci');
    await _uciOk!.future.timeout(timeout);

    _send('setoption name Threads value $threads');
    _send('setoption name Hash value $hashMb');

    _readyOk = Completer<void>();
    _send('isready');
    await _readyOk!.future.timeout(timeout);
    _send('ucinewgame');
  }

  void _markClosed() {
    if (!_running) return;
    _running = false;
    onClosed?.call();
  }

  void _handleLine(String line) {
    final l = line.trim();
    if (l.startsWith('id name ')) {
      _idName = l.substring(8).trim();
      return;
    }
    if (l == 'uciok') {
      _uciOk?.complete();
      return;
    }
    if (l == 'readyok') {
      _readyOk?.complete();
      return;
    }
    if (l.startsWith('bestmove')) {
      final parts = l.split(' ');
      if (parts.length >= 2) {
        _bestMove?.complete(parts[1]);
        onBestMove?.call(parts[1]);
      }
      return;
    }
    if (l.startsWith('info ')) {
      final parsed = parseInfoLine(l);
      if (parsed != null) {
        _lines[parsed.multiPv] = parsed;
        final snapshot = [..._lines.values]..sort((a, b) => a.multiPv.compareTo(b.multiPv));
        onSnapshot?.call(snapshot);
      }
    }
  }

  /// Parses an `info` line carrying a PV. Returns null for incomplete or
  /// unreliable lines (`string`, lowerbound/upperbound). Public for tests.
  static EngineLine? parseInfoLine(String line) {
    if (line.contains(' string ') || line.contains('lowerbound') || line.contains('upperbound')) {
      return null;
    }
    int? depth, multiPv, scoreCp, mateIn, nodes, nps;
    String? pv;

    for (final m in _depthRe.allMatches(line)) {
      depth = int.parse(m.group(1)!);
    }
    for (final m in _mpvRe.allMatches(line)) {
      multiPv = int.parse(m.group(1)!);
    }
    for (final m in _nodesRe.allMatches(line)) {
      nodes = int.parse(m.group(1)!);
    }
    for (final m in _npsRe.allMatches(line)) {
      nps = int.parse(m.group(1)!);
    }

    final score = _scoreRe.firstMatch(line);
    if (score != null) {
      final value = int.parse(score.group(2)!);
      if (score.group(1) == 'cp') {
        scoreCp = value;
      } else {
        mateIn = value;
      }
    }

    final pvMatch = _pvRe.firstMatch(line);
    if (pvMatch != null) pv = pvMatch.group(1)!.trim();

    if (pv == null || pv.isEmpty) return null;

    return EngineLine(
      multiPv: multiPv ?? 1,
      depth: depth ?? 0,
      scoreCp: scoreCp,
      mateIn: mateIn,
      nodes: nodes ?? 0,
      nps: nps ?? 0,
      pvUci: pv.split(' ').where((m) => m.isNotEmpty).toList(),
    );
  }

  // Leading space / line-start guards prevent matching inside `seldepth`.
  static final RegExp _depthRe = RegExp(r'(?:^| )depth (\d+)');
  static final RegExp _mpvRe = RegExp(r'(?:^| )multipv (\d+)');
  static final RegExp _scoreRe = RegExp(r' score (cp|mate) (-?\d+)');
  static final RegExp _nodesRe = RegExp(r'(?:^| )nodes (\d+)');
  static final RegExp _npsRe = RegExp(r'(?:^| )nps (\d+)');
  static final RegExp _pvRe = RegExp(r' pv (.+)$');

  void _send(String cmd) {
    _proc?.stdin.writeln(cmd);
  }

  /// Starts (or restarts) a search on the given position.
  Future<void> analyze({required String fen, required int depth, required int multiPv}) async {
    await stopSearch();
    _lines.clear();
    _send('setoption name MultiPV value $multiPv');
    _send('position fen $fen');
    _send('go depth $depth');
  }

  /// Asks the engine to stop the current search.
  Future<void> stopSearch() async {
    _send('stop');
  }

  Future<void> dispose() async {
    _send('quit');
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _proc?.kill();
    _running = false;
    _proc = null;
  }
}

// ---------------------------------------------------------------------------
// Helpers used by the UI (pure functions -> unit-testable).
// ---------------------------------------------------------------------------

/// Converts a UCI move string like `e2e4` / `e7e8q` into a [NormalMove].
NormalMove? moveFromUci(String uci) {
  if (uci.length < 4) return null;
  final from = Square.parse(uci.substring(0, 2));
  final to = Square.parse(uci.substring(2, 4));
  if (from == null || to == null) return null;
  Role? promotion;
  if (uci.length == 5) {
    switch (uci[4]) {
      case 'q':
        promotion = Role.queen;
      case 'r':
        promotion = Role.rook;
      case 'b':
        promotion = Role.bishop;
      case 'n':
        promotion = Role.knight;
      default:
        return null;
    }
  }
  return NormalMove(from: from, to: to, promotion: promotion);
}

/// Renders an engine PV as a SAN sequence, starting from [start].
/// Moves that cannot be applied (position drift) fall back to UCI notation.
List<String> pvToSan(Position start, List<String> pv) {
  final out = <String>[];
  var pos = start;
  for (final uci in pv) {
    final move = moveFromUci(uci);
    if (move == null) break;
    try {
      final (next, san) = pos.makeSan(move);
      out.add(san);
      pos = next;
    } catch (_) {
      out.add(uci);
      break;
    }
  }
  return out;
}

/// Formats centipawns from white's point of view, e.g. `+0.35` / `-1.20`.
String formatCp(int cpWhitePov) {
  final pawns = cpWhitePov / 100.0;
  final sign = pawns >= 0 ? '+' : '-';
  final abs = pawns.abs().toStringAsFixed(2);
  return '$sign$abs';
}

/// Human readable score for a line, always from white's point of view.
/// `turn` is the side to move in the analyzed position.
String formatScore(EngineLine line, Side turn) {
  if (line.mateIn != null) {
    final whiteMates = (turn == Side.white) == (line.mateIn! > 0);
    final n = line.mateIn!.abs();
    return whiteMates ? '#$n' : '-#$n';
  }
  final cp = line.scoreCp ?? 0;
  return formatCp(turn == Side.white ? cp : -cp);
}

/// Win probability in [0,1] (white POV) used by the evaluation bar.
double winProbability(int cpWhitePov) {
  return 1 / (1 + math.exp(-0.004 * cpWhitePov));
}

/// Compact node/NPS counters, e.g. `1.2M`, `354k`.
String formatCount(int n) {
  if (n >= 1000000) {
    final v = n / 1000000;
    return v >= 10 ? '${v.toStringAsFixed(0)}M' : '${v.toStringAsFixed(1)}M';
  }
  if (n >= 1000) {
    final v = n / 1000;
    return v >= 10 ? '${v.toStringAsFixed(0)}k' : '${v.toStringAsFixed(1)}k';
  }
  return '$n';
}
