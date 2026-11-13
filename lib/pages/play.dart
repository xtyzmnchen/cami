import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../games/catch_fruit.dart';
import '../games/memory.dart';
import '../games/match3.dart';
import '../games/runner.dart';
import '../games/slice_fruit.dart';
import '../games/snake.dart';
import '../games/whack_mole.dart';
import '../l10n/l10n.dart';
import '../logic.dart';
import '../services/game_bgm.dart';
import '../services/voice.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class PlayPage extends StatefulWidget {
  const PlayPage({super.key, required this.kind, this.testing = false});
  final GameKind kind;
  /// 测试模式：不扣今日游玩时间。
  final bool testing;

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  late int left;
  var score = 0;
  var best = 0;
  Timer? _timer;
  var _closed = false;

  @override
  void initState() {
    super.initState();
    unawaited(() async {
      try {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } catch (_) {}
    }());
    unawaited(GameBgm.start(widget.kind));
    if (widget.testing) {
      left = playBudgetSeconds;
    } else {
      final remain = context.read<Store>().playSecondsLeftToday();
      left = remain.clamp(0, playBudgetSeconds);
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _closed) return;
      setState(() => left--);
      if (left <= 0) {
        left = 0;
        _finish(timeUp: true);
      } else if (!widget.testing && left % 15 == 0) {
        unawaited(_persist(left));
      }
    });
  }

  Future<void> _restorePortrait() async {
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
    } catch (_) {
      // iOS 在横竖屏切换未完成时会抛 UISceneError，忽略即可
    }
  }

  Future<void> _persist(int seconds) async {
    if (widget.testing || !mounted) return;
    final store = context.read<Store>();
    await store.savePlaySecondsLeft(store.todayKey, seconds);
  }

  Future<void> _finish({bool timeUp = false}) async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    await GameBgm.stop();
    final remain = left.clamp(0, playBudgetSeconds);
    final say = !widget.testing && (timeUp || remain <= 0)
        ? (score >= 20 ? context.l10n.awesome : context.l10n.timeUp)
        : null;
    if (!widget.testing) {
      await _persist(remain);
      if (say != null) await Voice.say(say);
    }
    await _restorePortrait();
    if (mounted) Navigator.pop(context, remain <= 0 && !widget.testing);
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(GameBgm.stop());
    // 异常退出时也尽量回到竖屏
    unawaited(_restorePortrait());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final clock = '${(left ~/ 60).toString().padLeft(2, '0')}:${(left % 60).toString().padLeft(2, '0')}';
    final title = s.gameName(widget.kind);
    final pad = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0F14),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: _game()),
            Positioned(
              left: pad.left + 12,
              right: pad.right + 12,
              top: pad.top + 8,
              child: Row(
                children: [
                  Material(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: _finish,
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: s.close,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.testing ? s.testingSuffix(title) : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${s.scoreThisRound} $score',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () async {
                        await GameBgm.toggleMute();
                        if (mounted) setState(() {});
                      },
                      icon: Icon(
                        GameBgm.muted ? Icons.volume_off_rounded : Icons.music_note_rounded,
                        color: Colors.white,
                      ),
                      tooltip: GameBgm.muted ? '音乐关' : '音乐开',
                    ),
                  ),
                  const SizedBox(width: 8),
                  CountdownRing(
                    label: clock,
                    progress: left / playBudgetSeconds,
                    size: 64,
                    fontSize: 13,
                    stroke: 4,
                    labelColor: Colors.white,
                    trackColor: Colors.white24,
                    activeColor: CamiColors.rose,
                    fillColor: Colors.black.withValues(alpha: 0.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _game() {
    void scored(int value) {
      setState(() {
        score = value;
        if (value > best) best = value;
      });
    }

    return switch (widget.kind) {
      GameKind.snake => SnakeGame(onScore: scored, onQuit: _finish),
      GameKind.memory => MemoryGame(onScore: scored),
      GameKind.catchFruit => CatchFruitGame(onScore: scored),
      GameKind.sliceFruit => SliceFruitGame(onScore: scored),
      GameKind.whackMole => WhackMoleGame(onScore: scored),
      GameKind.match3 => Match3Game(onScore: scored),
      GameKind.runner => RunnerGame(onScore: scored),
    };
  }
}
