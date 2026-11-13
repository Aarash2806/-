import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Global app settings (persisted with shared_preferences).
class AppSettings extends ChangeNotifier {
  int boardThemeIndex = 0;
  bool soundEnabled = true;
  double soundVolume = 0.8;

  // Analysis defaults.
  int analysisDepth = 14;
  int analysisMultiPv = 1;

  /// User-registered engines (see Settings > Engines), stored as JSON.
  List<Map<String, dynamic>> customEngines = <Map<String, dynamic>>[];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    boardThemeIndex = p.getInt('boardThemeIndex') ?? 0;
    if (boardThemeIndex < 0 || boardThemeIndex >= kBoardThemes.length) {
      boardThemeIndex = 0;
    }
    soundEnabled = p.getBool('soundEnabled') ?? true;
    soundVolume = p.getDouble('soundVolume') ?? 0.8;
    analysisDepth = p.getInt('analysisDepth') ?? 14;
    analysisMultiPv = p.getInt('analysisMultiPv') ?? 1;
    final enginesJson = p.getString('customEngines');
    if (enginesJson != null && enginesJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(enginesJson) as List<dynamic>;
        customEngines = decoded.cast<Map<String, dynamic>>();
      } catch (_) {
        customEngines = [];
      }
    }
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

  Future<void> setSoundVolume(double value) async {
    soundVolume = value.clamp(0.0, 1.0);
    final p = await SharedPreferences.getInstance();
    await p.setDouble('soundVolume', soundVolume);
    notifyListeners();
  }

  Future<void> setAnalysisDepth(int value) async {
    analysisDepth = value.clamp(6, 30);
    final p = await SharedPreferences.getInstance();
    await p.setInt('analysisDepth', analysisDepth);
    notifyListeners();
  }

  Future<void> setAnalysisMultiPv(int value) async {
    analysisMultiPv = value.clamp(1, 3);
    final p = await SharedPreferences.getInstance();
    await p.setInt('analysisMultiPv', analysisMultiPv);
    notifyListeners();
  }

  Future<void> addCustomEngine(String name, String path, List<String> args) async {
    final id = 'custom:${DateTime.now().microsecondsSinceEpoch}';
    customEngines = [
      ...customEngines,
      {
        'id': id,
        'displayName': name,
        'path': path,
        'args': args,
      }
    ];
    await _persistEngines();
    notifyListeners();
  }

  Future<void> removeCustomEngine(String id) async {
    customEngines = customEngines.where((e) => e['id'] != id).toList();
    await _persistEngines();
    notifyListeners();
  }

  Future<void> _persistEngines() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('customEngines', jsonEncode(customEngines));
  }
}

final AppSettings appSettings = AppSettings();
