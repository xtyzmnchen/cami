import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

class CatchFruitGame extends StatefulWidget {
  const CatchFruitGame({super.key, required this.onScore});
  final ValueChanged<int> onScore;

  @override
  State<CatchFruitGame> createState() => _CatchFruitGameState();
}

class _Fruit {
  _Fruit(this.x, this.y, this.color);
  double x;
  double y;
  final Color color;
}

class _CatchFruitGameState extends State<CatchFruitGame> {
  final _rng = Random();
  final _fruits = <_Fruit>[];
  var _basket = 0.5;
  var _score = 0;
  Timer? _timer;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) => _tick());
  }

  void _tick() {
    if (_size == Size.zero) return;
    setState(() {
      if (_rng.nextDouble() < 0.04) {
        _fruits.add(_Fruit(_rng.nextDouble(), 0, _rng.nextBool() ? CamiColors.rose : CamiColors.gold));
      }
      for (final fruit in _fruits) {
        fruit.y += 0.012;
      }
      final basketLeft = _basket - 0.12;
      final basketRight = _basket + 0.12;
      _fruits.removeWhere((fruit) {
        if (fruit.y < 0.86) return false;
        final caught = fruit.x >= basketLeft && fruit.x <= basketRight && fruit.y < 0.96;
        if (caught) {
          _score++;
          widget.onScore(_score);
        }
        return true;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _size = Size(constraints.maxWidth, constraints.maxHeight);
      return GestureDetector(
        onHorizontalDragUpdate: (d) {
          setState(() {
            _basket = (_basket + d.delta.dx / constraints.maxWidth).clamp(0.12, 0.88);
          });
        },
        child: Stack(
          children: [
            const Align(
              alignment: Alignment.topCenter,
              child: Text('拖动篮子接住水果'),
            ),
            for (final fruit in _fruits)
              Positioned(
                left: fruit.x * constraints.maxWidth - 16,
                top: fruit.y * constraints.maxHeight,
                child: Icon(Icons.spa, color: fruit.color, size: 32),
              ),
            Positioned(
              left: _basket * constraints.maxWidth - 36,
              bottom: 24,
              child: Container(
                width: 72,
                height: 28,
                decoration: BoxDecoration(
                  color: CamiColors.roseDeep,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 8,
              child: Text('$_score', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    });
  }
}
