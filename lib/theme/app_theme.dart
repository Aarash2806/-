import 'package:material_ui/material_ui.dart';

/// Board color themes, Lichess-style (light/dark square colors).
class BoardTheme {
  final String id;
  final String name;
  final Color light;
  final Color dark;

  const BoardTheme(this.id, this.name, this.light, this.dark);
}

const List<BoardTheme> kBoardThemes = [
  BoardTheme('brown', 'قهوه‌ای کلاسیک', Color(0xFFF0D9B5), Color(0xFFB58863)),
  BoardTheme('blue', 'آبی', Color(0xFFDEE3E6), Color(0xFF8CA2AD)),
  BoardTheme('green', 'سبز', Color(0xFFFFFFDD), Color(0xFF86A666)),
  BoardTheme('purple', 'بنفش', Color(0xFFE6DCF2), Color(0xFF9A8AB8)),
  BoardTheme('grey', 'خاکستری', Color(0xFFE8E8E8), Color(0xFF7D7D7D)),
  BoardTheme('coral', 'مرجانی', Color(0xFFFFE6E0), Color(0xFFCC7A6E)),
];

const Color kNavyBg = Color(0xFF0E1420);
const Color kNavySurface = Color(0xFF151C2C);
const Color kNavyPanel = Color(0xFF121A28);
const Color kNavyCard = Color(0xFF1A2233);
const Color kGold = Color(0xFFC9A227);
const Color kGoldLight = Color(0xFFE8C558);
const Color kTextMain = Color(0xFFE7EAF2);
const Color kTextDim = Color(0xFF9AA3B8);

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Vazirmatn',
    colorScheme: const ColorScheme.dark(
      primary: kGold,
      onPrimary: Color(0xFF14100A),
      secondary: Color(0xFF8CA2AD),
      onSecondary: Color(0xFF10161F),
      surface: kNavySurface,
      onSurface: kTextMain,
      error: Color(0xFFE06C5A),
      outline: Color(0xFF3A445C),
    ),
    scaffoldBackgroundColor: kNavyBg,
    cardColor: kNavyCard,
    dividerColor: Color(0xFF2A3348),
    appBarTheme: const AppBarTheme(
      backgroundColor: kNavyBg,
      foregroundColor: kTextMain,
      elevation: 0,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: kNavyCard),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: kNavyCard,
      contentTextStyle: TextStyle(fontFamily: 'Vazirmatn', color: kTextMain),
      behavior: SnackBarBehavior.floating,
    ),
  );
  return base;
}
