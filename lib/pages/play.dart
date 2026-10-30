import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../games/catch_fruit.dart';
import '../games/math_quiz.dart';
import '../games/maze.dart';
import '../games/memory.dart';
import '../games/puzzle.dart';
import '../games/runner.dart';
import '../games/snake.dart';
import '../logic.dart';
import '../services/voice.dart';
import '../store.dart';
import '../widgets.dart';

class PlayPage extends StatefulWidget {
  const PlayPage({super.key, required this.kind});
  final GameKind kind;

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  static const total = 10 * 60;
  var left = total;
  var score = 0;
  Timer? _timer;
  var _closed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => left--);
      if (left <= 0) _finish();
    });
  }

  Future<void> _finish() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    final store = context.read<Store>();
    await store.finishPlay(store.todayKey);
    await Voice.say('时间到了');
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clock = '${(left ~/ 60).toString().padLeft(2, '0')}:${(left % 60).toString().padLeft(2, '0')}';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(gameTitles[widget.kind]!),
          leading: IconButton(onPressed: _finish, icon: const Icon(Icons.close)),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text('得分 $score', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
                  CountdownRing(
                    label: clock,
                    progress: left / total,
                    size: 88,
                    fontSize: 18,
                    stroke: 5,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _game()),
              TextButton(onPressed: _finish, child: const Text('退出后，这轮就用掉了')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _game() {
    void scored(int value) => setState(() => score = value);
    return switch (widget.kind) {
      GameKind.snake => SnakeGame(onScore: scored),
      GameKind.memory => MemoryGame(onScore: scored),
      GameKind.catchFruit => CatchFruitGame(onScore: scored),
      GameKind.maze => MazeGame(onScore: scored),
      GameKind.math => MathQuizGame(onScore: scored),
      GameKind.puzzle => PuzzleGame(onScore: scored),
      GameKind.runner => RunnerGame(onScore: scored),
    };
  }
}
