import 'package:audioplayers/audioplayers.dart';

import '../state/app_settings.dart';

enum GameSound { move, capture, check, castle, promote, gameEnd }

/// Plays the bundled Lichess-style sound set (locally synthesized WAVs,
/// see ATTRIBUTION.md). Audio failures are swallowed so the chess UI is
/// never disturbed.
class SoundService {
  AudioPlayer? _player;
  bool _broken = false;

  Future<void> play(GameSound sound) async {
    if (_broken || !appSettings.soundEnabled) return;
    try {
      _player ??= AudioPlayer(playerId: 'chessyar-sfx')
        ..setReleaseMode(ReleaseMode.stop);
      await _player!.setVolume(appSettings.soundVolume);
      await _player!.play(AssetSource('sounds/${sound.assetName}.wav'));
    } catch (_) {
      // Do not retry endlessly on broken audio stacks.
      _broken = true;
    }
  }

  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}

extension on GameSound {
  String get assetName => switch (this) {
        GameSound.move => 'move',
        GameSound.capture => 'capture',
        GameSound.check => 'check',
        GameSound.castle => 'castle',
        GameSound.promote => 'promote',
        GameSound.gameEnd => 'game_end',
      };
}
