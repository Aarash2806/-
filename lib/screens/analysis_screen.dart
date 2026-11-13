import 'package:dartchess/dartchess.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../state/app_settings.dart';
import '../state/game_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/chessboard.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final GameController _game = GameController();
  final ScrollController _movesScroll = ScrollController();

  BoardTheme get _theme =>
      kBoardThemes[appSettings.boardThemeIndex.clamp(0, kBoardThemes.length - 1)];

  @override
  void dispose() {
    _movesScroll.dispose();
    _game.dispose();
    super.dispose();
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
          _game.play(NormalMove(from: selected, to: square));
          _scrollMovesToEnd();
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
      _game.play(NormalMove(from: from, to: to, promotion: role));
      _scrollMovesToEnd();
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
              hintText: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_game, appSettings]),
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
            SizedBox(width: 340, child: _movesPanel()),
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
          Text(
            _statusText,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
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
          onPressed: _copyPgn,
          icon: const Icon(Icons.download, size: 18),
          label: const Text('کپی PGN'),
        ),
      ],
    );
  }

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
