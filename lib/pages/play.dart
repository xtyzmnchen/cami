import 'dart:async';

import 'package:flutter/material.dart';
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

  Future<void> _persist(int seconds) async {
    if (widget.testing || !mounted) return;
    final store = context.read<Store>();
    await store.savePlaySecondsLeft(store.todayKey, seconds);
  }

  Future<void> _finish({bool timeUp = false}) async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    final remain = left.clamp(0, playBudgetSeconds);
    final say = !widget.testing && (timeUp || remain <= 0)
        ? (score >= 20 ? context.l10n.awesome : context.l10n.timeUp)
        : null;
    if (!widget.testing) {
      await _persist(remain);
      if (say != null) await Voice.say(say);
    }
    if (mounted) Navigator.pop(context, remain <= 0 && !widget.testing);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final clock = '${(left ~/ 60).toString().padLeft(2, '0')}:${(left % 60).toString().padLeft(2, '0')}';
    final title = s.gameName(widget.kind);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: RoseBackdrop(
        intensity: 0.35,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(widget.testing ? s.testingSuffix(title) : title),
            leading: IconButton(onPressed: _finish, icon: const Icon(Icons.close)),
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: CamiColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${s.scoreThisRound} $score', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                            Text(
                              widget.testing ? s.testingNoTime : s.keepTimeOnExit,
                              style: const TextStyle(color: CamiColors.muted, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      CountdownRing(
                        label: clock,
                        progress: left / playBudgetSeconds,
                        size: 72,
                        fontSize: 15,
                        stroke: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(child: _game()),
                TextButton(
                  onPressed: _finish,
                  child: Text(
                    widget.testing
                        ? s.exitTest
                        : (left > 0 ? s.exitKeepTime : s.timeUp),
                    style: const TextStyle(color: CamiColors.roseDeep, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
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
      GameKind.snake => SnakeGame(onScore: scored),
      GameKind.memory => MemoryGame(onScore: scored),
      GameKind.catchFruit => CatchFruitGame(onScore: scored),
      GameKind.sliceFruit => SliceFruitGame(onScore: scored),
      GameKind.whackMole => WhackMoleGame(onScore: scored),
      GameKind.match3 => Match3Game(onScore: scored),
      GameKind.runner => RunnerGame(onScore: scored),
    };
  }
}
