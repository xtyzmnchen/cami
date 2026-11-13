import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../logic.dart';

/// 按游戏类型播放专属循环 BGM（低音量，语音时压低）。
class GameBgm {
  GameBgm._();

  static final AudioPlayer _player = AudioPlayer();
  static var _ready = false;
  static var _playing = false;
  static var _muted = false;
  static GameKind? _kind;
  static const _normalVol = 0.32;
  static const _duckVol = 0.08;

  static bool get muted => _muted;

  static String assetFor(GameKind kind) => switch (kind) {
        GameKind.snake => 'audio/bgm_snake.wav',
        GameKind.memory => 'audio/bgm_memory.wav',
        GameKind.catchFruit => 'audio/bgm_catch_fruit.wav',
        GameKind.sliceFruit => 'audio/bgm_slice_fruit.wav',
        GameKind.whackMole => 'audio/bgm_whack_mole.wav',
        GameKind.match3 => 'audio/bgm_match3.wav',
        GameKind.runner => 'audio/bgm_runner.wav',
      };

  static Future<void> _ensure() async {
    if (_ready || kIsWeb) return;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(_normalVol);
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      _ready = true;
    } catch (_) {}
  }

  static Future<void> start(GameKind kind) async {
    _kind = kind;
    if (kIsWeb || _muted) return;
    await _ensure();
    try {
      await _player.stop();
      await _player.setVolume(_normalVol);
      await _player.play(AssetSource(assetFor(kind)));
      _playing = true;
    } catch (_) {
      _playing = false;
    }
  }

  static Future<void> stop() async {
    if (!_playing && !_ready) return;
    try {
      await _player.stop();
    } catch (_) {}
    _playing = false;
  }

  static Future<void> duck() async {
    if (!_playing || _muted) return;
    try {
      await _player.setVolume(_duckVol);
    } catch (_) {}
  }

  static Future<void> unduck() async {
    if (!_playing || _muted) return;
    try {
      await _player.setVolume(_normalVol);
    } catch (_) {}
  }

  static Future<void> setMuted(bool value) async {
    _muted = value;
    if (value) {
      await stop();
    } else if (_kind != null) {
      await start(_kind!);
    }
  }

  static Future<void> toggleMute() => setMuted(!_muted);
}
