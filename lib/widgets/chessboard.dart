import 'package:dartchess/dartchess.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// Lichess-style chessboard: cburnett SVG pieces, last-move / selection /
/// check highlights, coordinates, legal-move dots and capture rings.
class Chessboard extends StatelessWidget {
  final Position position;
  final BoardTheme theme;
  final bool flipped;
  final Square? selected;
  final SquareSet? targets;
  final Square? lastFrom;
  final Square? lastTo;
  final Square? checkSquare;
  final void Function(Square square) onSquareTap;

  const Chessboard({
    super.key,
    required this.position,
    required this.theme,
    required this.flipped,
    required this.onSquareTap,
    this.selected,
    this.targets,
    this.lastFrom,
    this.lastTo,
    this.checkSquare,
  });

  String pieceAsset(Piece piece) =>
      'assets/pieces/cburnett/${piece.color == Side.white ? 'w' : 'b'}'
      '${piece.role.letter.toUpperCase()}.svg';

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;
          final sq = side / 8;
          // The grid itself is always laid out LTR (white orientation:
          // a1 bottom-left). App-level RTL must not mirror the squares.
          return Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: side,
              height: side,
              child: Column(
                children: List.generate(8, (row) {
                  final rank = flipped ? row : 7 - row;
                  return Row(
                    children: List.generate(8, (col) {
                      final file = flipped ? 7 - col : col;
                      final square = Square(rank * 8 + file);
                      return _squareWidget(square, file, rank, sq);
                    }),
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _squareWidget(Square square, int file, int rank, double sq) {
    final isLight = (file + rank) % 2 == 0;
    final baseColor = isLight ? theme.light : theme.dark;

    final isLast = (square == lastFrom || square == lastTo);
    final isSelected = square == selected;
    final isCheck = square == checkSquare;
    final piece = position.board.pieceAt(square);
    final hasTarget = targets?.has(square) ?? false;

    // Capture ring only for enemy pieces; empty squares (incl. castling
    // destinations on our own rook, which dartchess encodes as king->rook)
    // get the plain dot marker.
    final isCapture = hasTarget && piece != null && piece.color != position.turn;

    Widget? marker;
    if (isCapture) {
      marker = Center(
        child: Container(
          width: sq * 0.92,
          height: sq * 0.92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.20),
              width: sq * 0.07,
            ),
          ),
        ),
      );
    } else if (hasTarget) {
      marker = Center(
        child: Container(
          width: sq * 0.30,
          height: sq * 0.30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.18),
          ),
        ),
      );
    }

    Widget? pieceWidget;
    if (piece != null) {
      pieceWidget = Center(
        child: SvgPicture.asset(pieceAsset(piece), width: sq * 0.84),
      );
    }

    Widget? coord;
    final coordColor = isLight ? theme.dark : theme.light;
    if (file == 0) {
      coord = Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.all(sq * 0.05),
          child: Text(
            '${rank + 1}',
            style: TextStyle(
              fontSize: sq * 0.22,
              fontWeight: FontWeight.bold,
              color: coordColor,
            ),
          ),
        ),
      );
    }
    if (rank == 0) {
      coord = Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: EdgeInsets.all(sq * 0.05),
          child: Text(
            String.fromCharCode(97 + file),
            style: TextStyle(
              fontSize: sq * 0.22,
              fontWeight: FontWeight.bold,
              color: coordColor,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSquareTap(square),
      child: Container(
        width: sq,
        height: sq,
        color: baseColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isLast || isSelected)
              Container(color: Color.fromRGBO(155, 199, 0, 0.45)),
            if (isCheck)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF4545).withValues(alpha: 0.85),
                      const Color(0xFFFF4545).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ?pieceWidget,
            ?marker,
            ?coord,
          ],
        ),
      ),
    );
  }
}
