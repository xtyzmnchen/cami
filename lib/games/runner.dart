import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme.dart';

class RunnerGame extends StatefulWidget {
  const RunnerGame({super.key, required this.onScore});
  final ValueChanged<int> onScore;

  @override
  State<RunnerGame> createState() => _RunnerGameState();
}

class _Block {
  _Block(this.x);
  double x;
  bool scored = false;
}

class _RunnerGameState extends State<RunnerGame> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final _rng = Random();
  final _obstacles = <_Block>[_Block(520), _Block(760)];
  var _y = 0.0;
  var _vy = 0.0;
  var _score = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_frame)..start();
  }

  void _frame(Duration elapsed) {
    final dt = (_last == Duration.zero ? 16 : elapsed.inMilliseconds - _last.inMilliseconds) / 16.0;
    _last = elapsed;
    if (!mounted) return;
    setState(() {
      _vy += 0.7 * dt;
      _y = min(0, _y + _vy * dt);
      if (_y > -1) {
        _y = 0;
        _vy = 0;
      }
      for (final block in _obstacles) {
        block.x -= 4.2 * dt;
        final hit = block.x < 78 && block.x > 40 && _y > -28;
        if (hit) block.x = -40;
        if (!block.scored && block.x < 40 && !hit) {
          block.scored = true;
          _score++;
          widget.onScore(_score);
        }
      }
      _obstacles.removeWhere((block) => block.x < -30);
      if (_obstacles.isEmpty || _obstacles.last.x < 280) {
        _obstacles.add(_Block(420 + _rng.nextDouble() * 180));
      }
    });
  }

  void _jump() {
    if (_y == 0) _vy = -12.5;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _jump,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text('跳过 $_score 个', style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: LayoutBuilder(builder: (context, box) {
              return Stack(
                children: [
                  Positioned(
                    left: 48,
                    bottom: 28 - _y,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: CamiColors.rose,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.favorite, color: Colors.white, size: 18),
                    ),
                  ),
                  for (final block in _obstacles)
                    Positioned(
                      left: block.x,
                      bottom: 28,
                      child: Container(
                        width: 22,
                        height: 32,
                        decoration: BoxDecoration(
                          color: CamiColors.gold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 24,
                    child: Divider(color: CamiColors.line, thickness: 3),
                  ),
                ],
              );
            }),
          ),
          const Text('点一下就跳', style: TextStyle(color: CamiColors.muted)),
          const Spacer(),
        ],
      ),
    );
  }
}
