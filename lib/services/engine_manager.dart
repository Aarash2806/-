import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../state/app_settings.dart';
import 'uci_engine.dart';

/// Description of an engine available to the app.
class EngineInfo {
  final String id;
  final String displayName;
  final String path;
  final List<String> args;
  final bool builtIn;

  const EngineInfo({
    required this.id,
    required this.displayName,
    required this.path,
    this.args = const <String>[],
    required this.builtIn,
  });

  EngineInfo copyWith({String? displayName}) => EngineInfo(
        id: id,
        displayName: displayName ?? this.displayName,
        path: path,
        args: args,
        builtIn: builtIn,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'path': path,
        'args': args,
      };

  static EngineInfo fromJson(Map<String, dynamic> json) => EngineInfo(
        id: json['id'] as String,
        displayName: (json['displayName'] as String?) ?? 'Engine',
        path: json['path'] as String,
        args: ((json['args'] as List<dynamic>?) ?? const <dynamic>[])
            .map((e) => e.toString())
            .toList(),
        builtIn: false,
      );
}

/// Discovers engines: the three built-ins that ship next to the app exe
/// (`<exeDir>/engines/**.exe`, downloaded by the CI pipeline) plus custom
/// engines the user registered in Settings.
class EngineManager extends ChangeNotifier {
  final List<EngineInfo> _builtIn = <EngineInfo>[];
  final List<EngineInfo> _custom = <EngineInfo>[];

  List<EngineInfo> get builtIn => List.unmodifiable(_builtIn);
  List<EngineInfo> get custom => List.unmodifiable(_custom);
  List<EngineInfo> get all => [..._builtIn, ..._custom];

  EngineInfo? byId(String? id) {
    if (id == null) return null;
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Re-scans the engines folder and the user-defined engine list.
  Future<void> refresh() async {
    _builtIn.clear();
    _builtIn.addAll(_scanBuiltIns());
    _custom
      ..clear()
      ..addAll(appSettings.customEngines.map(EngineInfo.fromJson));
    notifyListeners();
  }

  List<EngineInfo> _scanBuiltIns() {
    final out = <EngineInfo>[];
    try {
      if (!Platform.isWindows) return out;
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final sep = Platform.pathSeparator;
      final dir = Directory('$exeDir${sep}engines');
      if (!dir.existsSync()) return out;

      for (final entity in dir.listSync()) {
        if (entity is Directory) {
          for (final f in entity.listSync()) {
            if (f is File && f.path.toLowerCase().endsWith('.exe')) {
              out.add(_engineFromFile(f.path));
            }
          }
        } else if (entity is File && entity.path.toLowerCase().endsWith('.exe')) {
          out.add(_engineFromFile(entity.path));
        }
      }
    } catch (_) {
      // Discovery must never crash the app.
    }
    return out;
  }

  EngineInfo _engineFromFile(String path) {
    final file = File(path);
    final base = file.uri.pathSegments.last.toLowerCase().replaceAll('.exe', '');
    final display = switch (base) {
      final b when b.contains('stockfish') => 'Stockfish',
      final b when b.contains('berserk') => 'Berserk',
      final b when b.contains('viridithas') => 'Viridithas',
      _ => file.uri.pathSegments.last.replaceAll(RegExp(r'\.exe$', caseSensitive: false), ''),
    };
    return EngineInfo(
      id: 'builtin:$base',
      displayName: display,
      path: path,
      builtIn: true,
    );
  }

  /// Verifies a candidate engine by performing a real UCI handshake.
  /// Returns the `id name` reported by the engine.
  /// Throws [TimeoutException] when the binary does not speak UCI.
  Future<String> testEngine(EngineInfo info, {Duration timeout = const Duration(seconds: 8)}) {
    return _test(info.path, info.args, timeout);
  }

  Future<String> _test(String path, List<String> args, Duration timeout) async {
    final engine = UciEngine(path: path, args: args, threads: 1, hashMb: 16);
    var started = false;
    try {
      await engine.start(timeout: timeout);
      started = true;
      return engine.reportedName.isEmpty ? path : engine.reportedName;
    } finally {
      if (started) await engine.dispose();
    }
  }
}

final EngineManager engineManager = EngineManager();
