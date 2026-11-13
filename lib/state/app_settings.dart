import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Global app settings (persisted with shared_preferences).
class AppSettings extends ChangeNotifier {
  int boardThemeIndex = 0;
  bool soundEnabled = true;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    boardThemeIndex = p.getInt('boardThemeIndex') ?? 0;
    if (boardThemeIndex < 0 || boardThemeIndex >= kBoardThemes.length) {
      boardThemeIndex = 0;
    }
    soundEnabled = p.getBool('soundEnabled') ?? true;
    notifyListeners();
  }

  Future<void> setBoardTheme(int index) async {
    boardThemeIndex = index;
    final p = await SharedPreferences.getInstance();
    await p.setInt('boardThemeIndex', index);
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    soundEnabled = value;
    final p = await SharedPreferences.getInstance();
    await p.setBool('soundEnabled', value);
    notifyListeners();
  }
}

final AppSettings appSettings = AppSettings();
