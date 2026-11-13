import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../services/engine_manager.dart';
import '../services/pgn/pgn_parser.dart';
import '../services/sound_service.dart';
import '../services/uci_engine.dart';
import '../state/app_settings.dart';
import '../state/game_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/chessboard.dart';
import 'settings_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final GameController _game = GameController();
  final ScrollController _movesScroll = ScrollController();
  final SoundService _sounds = SoundService();

  // --- engine state (real UCI processes, no simulation) ---
  EngineInfo? _selectedEngine;
  UciEngine? _engine;
  bool _engineStarting = false;
  bool _analyzing = false;
  String? _analyzedFen;
  bool _pendingGo = false;
  List<EngineLine> _lines = <EngineLine>[];
  String? _bestMoveUci;
  String? _engineError;

  BoardTheme get _theme =>
      kBoardThemes[appSettings.boardThemeIndex.clamp(0, kBoardThemes.length - 1)];

  bool _pgnBusy = false;

  @override
  void initState() {
    super.initState();
    _game.addListener(_onGameChanged);
    engineManager.refresh();
  }

  @override
  void dispose() {
    _game.removeListener(_onGameChanged);
    _engine?.dispose();
    _sounds.dispose();
    _movesScroll.dispose();
    _game.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ moves

  void _onGameChanged() {
    // Keep the running analysis glued to the position on the board.
    if (_analyzing && _analyzedFen != _game.fen && !_pendingGo) {
      _pendingGo = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pendingGo = false;
        if (mounted && _analyzing) _go();
      });
    }
  }

  void _playMove(NormalMove move) {
    if (!_game.isLegalMove(move.from, move.to)) return;
    _game.play(move);
    final san = _game.records.last.san;
    _soundForSan(san);
    if (_game.isGameOver) {
      Future.delayed(const Duration(milliseconds: 350), () {
        _sounds.play(GameSound.gameEnd);
      });
    }
    _scrollMovesToEnd();
  }

  void _soundForSan(String san) {
    if (san.contains('+') || san.contains('#')) {
      _sounds.play(GameSound.check);
    } else if (san.startsWith('O-O')) {
      _sounds.play(GameSound.castle);
    } else if (san.contains('=')) {
      _sounds.play(GameSound.promote);
    } else if (san.contains('x')) {
      _sounds.play(GameSound.capture);
    } else {
      _sounds.play(GameSound.move);
    }
  }

  void _scrollMovesToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_movesScroll.hasClients) {
        _movesScroll.jumpTo(_movesScroll.position.maxScrollExtent);
      }
    });
  }

  void _onSquareTap(Square square) {
    final selected = _game.selected;
    if (selected == square) {
      _game.select(null);
      return;
    }
    if (selected != null) {
      final movingPiece = _game.position.board.pieceAt(selected);
      if (movingPiece != null && _game.isLegalMove(selected, square)) {
        if (_game.needsPromotion(selected, square)) {
          _askPromotion(movingPiece.color, selected, square);
        } else {
          _playMove(NormalMove(from: selected, to: square));
        }
        return;
      }
    }
    // Select only pieces of the side to move.
    final piece = _game.position.board.pieceAt(square);
    if (piece != null && piece.color == _game.turn) {
      _game.select(square);
    } else {
      _game.select(null);
    }
  }

  Future<void> _askPromotion(Side color, Square from, Square to) async {
    final role = await showDialog<Role>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ارتقای سرباز'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final role in [Role.queen, Role.rook, Role.bishop, Role.knight])
              _PromotionChoice(
                color: color,
                role: role,
                onTap: () => Navigator.of(context).pop(role),
              ),
          ],
        ),
      ),
    );
    if (role != null) {
      _playMove(NormalMove(from: from, to: to, promotion: role));
    }
  }

  void _newGame() {
    _game.newGame();
    _movesScroll.jumpTo(0);
  }

  void _undo() {
    _game.undo();
    _scrollMovesToEnd();
  }

  void _flip() => setState(() => _game.flipped = !_game.flipped);

  Future<void> _copyFen() async {
    await Clipboard.setData(ClipboardData(text: _game.fen));
    _toast('FEN در حافظه کپی شد');
  }

  Future<void> _pasteFen() async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('درج FEN'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              hintText: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKB1R w KQkq - 0 1',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('لغو'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('بارگذاری'),
            ),
          ],
        );
      },
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      _game.loadFen(text);
      _movesScroll.jumpTo(0);
    } catch (_) {
      _toast('FEN نامعتبر است');
    }
  }

  Future<void> _copyPgn() async {
    await Clipboard.setData(ClipboardData(text: _game.pgn));
    _toast('PGN در حافظه کپی شد');
  }

  // -------------------------------------------------------------- PGN import
  // Reads EVERY kind of PGN: single games, multi-game collections,
  // exercise books with FEN positions, files full of comments/variations,
  // files with stray prose, old encodings (UTF-16 / CP1252) and CRLF.
  // SAN validation happens with the real dartchess rules engine.

  Future<void> _openPgnFile() async {
    const groups = [XTypeGroup(label: 'PGN', extensions: ['pgn', 'txt'])];
    final file = await openFile(acceptedTypeGroups: groups);
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      await _importPgn(bytes: bytes, sourceName: file.name);
    } catch (_) {
      _toast('خواندن فایل ممکن نشد');
    }
  }

  Future<void> _pastePgn() async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('درج متن PGN'),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 12,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 12, height: 1.5),
              decoration: const InputDecoration(
                hintText:
                    'متن کامل فایل PGN را اینجا بچسبانید — می‌تواند شامل چند بازی، کامنت و واریاسیون باشد',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('لغو'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('خواندن'),
            ),
          ],
        );
      },
    );
    if (text == null || text.trim().isEmpty) return;
    await _importPgn(text: text, sourceName: 'متن چسبانده‌شده');
  }

  Future<void> _importPgn({
    Uint8List? bytes,
    String? text,
    required String sourceName,
  }) async {
    setState(() => _pgnBusy = true);
    PgnLoadResult? loaded;
    try {
      loaded = bytes != null
          ? await compute(_parseBytesJob, bytes)
          : await compute(_parseTextJob, text!);
    } catch (_) {
      if (mounted) {
        setState(() => _pgnBusy = false);
        _toast('پردازش PGN با خطا مواجه شد');
      }
      return;
    }
    if (!mounted) return;
    setState(() => _pgnBusy = false);
    if (loaded == null) {
      _toast('پردازش PGN با خطا مواجه شد');
      return;
    }
    final res = loaded;

    if (res.games.isEmpty) {
      _toast('هیچ بازی معتبری در «$sourceName» پیدا نشد');
      return;
    }
    if (res.warnings.isNotEmpty) _toast(res.warnings.first);

    final game = await _pickPgnGame(res, sourceName);
    if (game == null) return;
    _game.loadPgnGame(game);
    _movesScroll.jumpTo(0);
    _toast('بازی «${game.label}» بارگذاری شد — ${game.mainline.length} حرکت');
  }

  static PgnLoadResult _parseBytesJob(Uint8List bytes) =>
      PgnDocument.parseBytes(bytes);

  static PgnLoadResult _parseTextJob(String text) =>
      PgnDocument.parseText(text);

  Future<ChessYarPgnGame?> _pickPgnGame(
      PgnLoadResult res, String sourceName) async {
    if (res.games.length == 1) return res.games.first;
    return showDialog<ChessYarPgnGame>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('«$sourceName» — ${res.games.length} بازی'),
        content: SizedBox(
          width: 480,
          height: 400,
          child: ListView.builder(
            itemCount: res.games.length,
            itemBuilder: (context, i) {
              final g = res.games[i];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  onTap: () => Navigator.of(context).pop(g),
                  leading: g.isExercise
                      ? const Icon(Icons.extension, color: kGold)
                      : CircleAvatar(
                          radius: 14,
                          child: Text('${i + 1}',
                              style: const TextStyle(fontSize: 12)),
                        ),
                  title: Text(g.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: Text(
                    g.subtitle,
                    style: const TextStyle(fontSize: 11, color: kTextDim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (g.isExercise)
                        const Icon(Icons.fitness_center,
                            size: 16, color: kGold),
                      if (g.hasVariations)
                        const Icon(Icons.account_tree,
                            size: 16, color: Color(0xFF6C9BD1)),
                      if (g.illegalMoves > 0)
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: Color(0xFFE06C5A)),
                      const Icon(Icons.chevron_left,
                          size: 18, color: kTextDim),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('انصراف'),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  String get _statusText {
    final winner = _game.outcome?.winner;
    if (winner == Side.white) return 'کیش و مات! سفید برنده شد';
    if (winner == Side.black) return 'کیش و مات! سیاه برنده شد';
    if (_game.outcome != null) {
      if (_game.isStalemate) return 'پات - مساوی';
      return 'مساوی';
    }
    if (_game.isCheck) return 'کیش! نوبت ${_game.turn == Side.white ? 'سفید' : 'سیاه'}';
    return 'نوبت ${_game.turn == Side.white ? 'سفید' : 'سیاه'}';
  }

  // ----------------------------------------------------------------- engine

  Future<void> _toggleAnalysis() async {
    if (_analyzing) {
      await _engine?.stopSearch();
      setState(() => _analyzing = false);
      return;
    }
    final info = _selectedEngine ?? _pickDefaultEngine();
    if (info == null) return;
    await _startEngine(info);
    if (mounted && _engine != null) {
      setState(() => _analyzing = true);
      _go();
    }
  }

  EngineInfo? _pickDefaultEngine() {
    final engines = engineManager.all;
    if (engines.isEmpty) return null;
    // Prefer Stockfish when several engines ship side by side.
    for (final e in engines) {
      if (e.displayName.toLowerCase().contains('stockfish')) return e;
    }
    return engines.first;
  }

  Future<void> _startEngine(EngineInfo info) async {
    setState(() {
      _engineStarting = true;
      _engineError = null;
    });
    if (_engine != null && _engine!.isRunning && _selectedEngine?.id == info.id) {
      setState(() => _engineStarting = false);
      return;
    }
    await _engine?.dispose();
    _engine = null;
    _selectedEngine = info;
    try {
      final engine = UciEngine(
        path: info.path,
        args: info.args,
        multiPv: appSettings.analysisMultiPv,
        onSnapshot: (lines) {
          if (!mounted) return;
          setState(() => _lines = lines);
        },
        onBestMove: (uci) {
          if (!mounted) return;
          setState(() => _bestMoveUci = uci);
        },
        onClosed: () {
          if (!mounted) return;
          setState(() {
            _analyzing = false;
            _engineStarting = false;
          });
        },
      );
      await engine.start();
      _engine = engine;
      setState(() => _engineStarting = false);
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _engineStarting = false;
        _engineError = 'موتور پاسخ نداد. مسیر انتخاب‌شده باید یک موتور UCI معتبر باشد.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _engineStarting = false;
        _engineError = 'اجرا شدن موتور ممکن نشد: ${e.toString()}';
      });
    }
  }

  void _go() {
    final engine = _engine;
    if (engine == null || !engine.isRunning) return;
    final fen = _game.fen;
    if (_analyzedFen == fen) return;
    _analyzedFen = fen;
    _bestMoveUci = null;
    setState(() => _lines = []);
    unawaited(engine.analyze(
      fen: fen,
      depth: appSettings.analysisDepth,
      multiPv: appSettings.analysisMultiPv,
    ));
  }

  void _restartIfAnalyzing() {
    if (_analyzing) {
      _analyzedFen = null;
      _go();
    }
  }

  Future<void> _switchEngine(EngineInfo? info) async {
    if (info == null || info.id == _selectedEngine?.id) return;
    final wasAnalyzing = _analyzing;
    await _engine?.stopSearch();
    await _engine?.dispose();
    _engine = null;
    _lines = [];
    _bestMoveUci = null;
    _analyzedFen = null;
    _selectedEngine = info;
    setState(() {});
    if (wasAnalyzing) {
      await _startEngine(info);
      if (mounted && _engine != null) {
        setState(() => _analyzing = true);
        _go();
      }
    }
  }

  String get _bestMoveSan {
    final uci = _bestMoveUci;
    if (uci == null) return '';
    if (_lines.isNotEmpty) {
      final sans = pvToSan(_game.position, _lines.first.pvUci);
      if (sans.isNotEmpty) return sans.first;
    }
    return uci;
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_game, appSettings, engineManager]),
      builder: (context, _) {
        final board = Chessboard(
          position: _game.position,
          theme: _theme,
          flipped: _game.flipped,
          selected: _game.selected,
          targets: _game.targetsFor(_game.selected),
          lastFrom: _game.lastFrom,
          lastTo: _game.lastTo,
          checkSquare: _game.checkKingSquare,
          onSquareTap: _onSquareTap,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _statusBar(),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: board,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _controlsRow(),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 340,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _enginePanel(),
                  const Divider(height: 1),
                  Expanded(child: _movesPanel()),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statusBar() {
    final gameOver = _game.isGameOver;
    final inCheck = _game.isCheck && !gameOver;
    final color = gameOver ? kGold : (inCheck ? const Color(0xFFE06C5A) : kTextDim);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: kNavyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF2A3348)),
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _game.turn == Side.white ? Colors.white : const Color(0xFF2B2B2B),
              border: Border.all(color: kGold, width: 1.5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          if (_game.importedLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kGold.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kGold.withValues(alpha: .35)),
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  _game.importedLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: kGoldLight, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _controlsRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _newGame,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('بازی جدید'),
        ),
        OutlinedButton.icon(
          onPressed: _game.canUndo ? _undo : null,
          icon: const Icon(Icons.undo, size: 18),
          label: const Text('برگشت'),
        ),
        OutlinedButton.icon(
          onPressed: _flip,
          icon: const Icon(Icons.flip, size: 18),
          label: const Text('چرخش تخته'),
        ),
        OutlinedButton.icon(
          onPressed: _copyFen,
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('کپی FEN'),
        ),
        OutlinedButton.icon(
          onPressed: _pasteFen,
          icon: const Icon(Icons.content_paste, size: 18),
          label: const Text('درج FEN'),
        ),
        OutlinedButton.icon(
          onPressed: _pgnBusy ? null : _openPgnFile,
          icon: const Icon(Icons.folder_open, size: 18),
          label: const Text('باز کردن PGN…'),
        ),
        OutlinedButton.icon(
          onPressed: _pgnBusy ? null : _pastePgn,
          icon: const Icon(Icons.paste, size: 18),
          label: const Text('درج PGN…'),
        ),
        OutlinedButton.icon(
          onPressed: _copyPgn,
          icon: const Icon(Icons.download, size: 18),
          label: const Text('کپی PGN'),
        ),
        if (_pgnBusy)
          const SizedBox(
            width: 180,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  // ------------------------------------------------------------ engine panel

  Widget _enginePanel() {
    return Container(
      color: kNavyPanel,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.memory, size: 18, color: kGold),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('موتور تحلیل', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              _engineStatusChip(),
            ],
          ),
          const SizedBox(height: 10),
          if (engineManager.all.isEmpty)
            _noEnginesCard()
          else ...[
            _engineSelector(),
            const SizedBox(height: 8),
            _depthRow(),
            const SizedBox(height: 8),
            _multiPvRow(),
            const SizedBox(height: 10),
            _analysisButton(),
            if (_engineError != null) ...[
              const SizedBox(height: 8),
              Text(
                _engineError!,
                style: const TextStyle(color: Color(0xFFE06C5A), fontSize: 12, height: 1.6),
              ),
            ],
            if (_lines.isNotEmpty) ...[
              const SizedBox(height: 12),
              _evalBar(),
              const SizedBox(height: 10),
              for (final line in _lines) _lineRow(line),
              const SizedBox(height: 8),
              _engineStats(),
            ],
            if (!_analyzing && _bestMoveUci != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kNavyCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A3348)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back, size: 14, color: kGold),
                    const SizedBox(width: 6),
                    const Text('بهترین حرکت:', style: TextStyle(color: kTextDim, fontSize: 12)),
                    const SizedBox(width: 6),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        _bestMoveSan,
                        style: const TextStyle(
                          color: kGoldLight,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _engineStatusChip() {
    final analyzing = _analyzing;
    final starting = _engineStarting;
    final (label, color) = starting
        ? ('اتصال...', const Color(0xFFE3B341))
        : analyzing
            ? ('در حال تحلیل', const Color(0xFF3FB950))
            : ('متوقف', kTextDim);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _noEnginesCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kNavyCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A3348)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'هیچ موتوری پیدا نشد. در نسخه‌ی نصب‌شده، Stockfish و Berserk و Viridithas '
            'به‌طور خودکار کنار برنامه قرار می‌گیرند. در حالت توسعه می‌توانید مسیر هر '
            'موتور UCI را در تنظیمات اضافه کنید.',
            style: TextStyle(fontSize: 12, color: kTextDim, height: 1.8),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('افزودن موتور در تنظیمات'),
          ),
        ],
      ),
    );
  }

  Widget _engineSelector() {
    final engines = engineManager.all;
    final selected = _selectedEngine ?? _pickDefaultEngine();
    if (selected != null && _selectedEngine == null) {
      _selectedEngine = selected;
    }
    return DropdownButtonFormField<EngineInfo>(
      initialValue: selected,
      isDense: true,
      dropdownColor: kNavyCard,
      decoration: const InputDecoration(
        labelText: 'موتور',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: [
        for (final e in engines)
          DropdownMenuItem(
            value: e,
            child: Text(
              e.builtIn ? e.displayName : '${e.displayName} (سفارشی)',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (e) => _switchEngine(e),
    );
  }

  Widget _depthRow() {
    return Row(
      children: [
        const Text('عمق:', style: TextStyle(fontSize: 13, color: kTextDim)),
        const SizedBox(width: 6),
        Text(
          '${appSettings.analysisDepth}',
          style: const TextStyle(color: kGoldLight, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Expanded(
          child: Slider(
            value: appSettings.analysisDepth.toDouble(),
            min: 6,
            max: 24,
            divisions: 18,
            activeColor: kGold,
            onChanged: (v) {
              appSettings.setAnalysisDepth(v.round());
              _restartIfAnalyzing();
            },
          ),
        ),
      ],
    );
  }

  Widget _multiPvRow() {
    return Row(
      children: [
        const Text('خطوط هم‌زمان:', style: TextStyle(fontSize: 13, color: kTextDim)),
        const Spacer(),
        for (final n in [1, 2, 3]) ...[
          const SizedBox(width: 6),
          ChoiceChip(
            label: Text('$n'),
            selected: appSettings.analysisMultiPv == n,
            onSelected: (_) {
              appSettings.setAnalysisMultiPv(n);
              _restartIfAnalyzing();
            },
            labelStyle: const TextStyle(fontSize: 12),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }

  Widget _analysisButton() {
    final hasEngine = _selectedEngine != null || _pickDefaultEngine() != null;
    return FilledButton.icon(
      onPressed: hasEngine && !_engineStarting ? _toggleAnalysis : null,
      style: FilledButton.styleFrom(
        backgroundColor: _analyzing ? const Color(0xFF3A2A2A) : null,
        foregroundColor: _analyzing ? const Color(0xFFE06C5A) : null,
      ),
      icon: _engineStarting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_analyzing ? Icons.stop : Icons.play_arrow, size: 18),
      label: Text(
        _analyzing ? 'توقف تحلیل' : (_engineStarting ? 'در حال اتصال...' : 'شروع تحلیل'),
      ),
    );
  }

  Widget _evalBar() {
    final first = _lines.first;
    final white01 = winProbability(_whitePovCp(first));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('ارزیابی', style: TextStyle(fontSize: 12, color: kTextDim)),
            const Spacer(),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                formatScore(first, _game.turn),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: kGoldLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Directionality(
          textDirection: TextDirection.ltr,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Stack(
                children: [
                  Container(color: const Color(0xFF2B2B2B)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: white01.clamp(0.02, 0.98),
                    child: Container(color: const Color(0xFFE9E4D9)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  int _whitePovCp(EngineLine line) {
    if (line.mateIn != null) {
      final whiteMates = (_game.turn == Side.white) == (line.mateIn! > 0);
      return whiteMates ? 100000 : -100000;
    }
    final cp = line.scoreCp ?? 0;
    return _game.turn == Side.white ? cp : -cp;
  }

  Widget _lineRow(EngineLine line) {
    final sans = pvToSan(_game.position, line.pvUci);
    final pvText = sans.isEmpty ? line.pvUci.join(' ') : sans.join(' ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: kGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                formatScore(line, _game.turn),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: kGoldLight,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'd${line.depth}',
            style: const TextStyle(fontSize: 11, color: kTextDim),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                pvText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _engineStats() {
    final first = _lines.first;
    return Row(
      children: [
        _statCell('عمق', '${first.depth}'),
        _statCell('گره‌ها', formatCount(first.nodes)),
        _statCell('سرعت', '${formatCount(first.nps)}/s'),
        const Spacer(),
      ],
    );
  }

  Widget _statCell(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: kTextDim)),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: kTextMain, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- moves panel

  Widget _movesPanel() {
    return Container(
      color: kNavyPanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'حرکت‌ها',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: _game.records.isEmpty
                  ? const Center(
                      child: Text(
                        'هنوز حرکتی انجام نشده است',
                        style: TextStyle(color: kTextDim),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      controller: _movesScroll,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: (_game.records.length + 1) ~/ 2,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (context, i) {
                        final white = _game.records[i * 2];
                        final blackIdx = i * 2 + 1;
                        final black =
                            blackIdx < _game.records.length ? _game.records[blackIdx] : null;
                        return Container(
                          color: i.isEven ? kNavySurface : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 36,
                                child: Text(
                                  '${i + 1}.',
                                  style: const TextStyle(color: kTextDim),
                                ),
                              ),
                              Expanded(child: Text(white.san)),
                              Expanded(
                                child: Text(black?.san ?? '',
                                    style: const TextStyle(color: kTextDim)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text('FEN', style: TextStyle(color: kTextDim, fontSize: 12)),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _copyFen,
                      icon: const Icon(Icons.copy, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kNavyCard,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      _game.fen,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: kTextDim, height: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromotionChoice extends StatelessWidget {
  final Side color;
  final Role role;
  final VoidCallback onTap;

  const _PromotionChoice({required this.color, required this.role, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: SvgPicture.asset(
          'assets/pieces/cburnett/'
          '${color == Side.white ? 'w' : 'b'}${role.letter.toUpperCase()}.svg',
          width: 56,
        ),
      ),
    );
  }
}
