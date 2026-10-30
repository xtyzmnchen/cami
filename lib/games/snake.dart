import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key, required this.onScore});
  final ValueChanged<int> onScore;

  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame> {
  static const cols = 12;
  static const rows = 16;
  final _rng = Random();
  late List<Point<int>> _snake;
  var _dir = const Point<int>(1, 0);
  var _next = const Point<int>(1, 0);
  late Point<int> _apple;
  var _score = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _resetSnake();
    _timer = Timer.periodic(const Duration(milliseconds: 280), (_) => _tick());
  }

  void _resetSnake() {
    _snake = [const Point(3, 8), const Point(2, 8), const Point(1, 8)];
    _dir = const Point(1, 0);
    _next = _dir;
    _apple = _freeCell();
  }

  Point<int> _freeCell() {
    while (true) {
      final cell = Point(_rng.nextInt(cols), _rng.nextInt(rows));
      if (!_snake.contains(cell)) return cell;
    }
  }

  void _turn(Point<int> dir) {
    if (dir.x == -_dir.x && dir.y == -_dir.y) return;
    _next = dir;
  }

  void _tick() {
    _dir = _next;
    final head = Point(_snake.first.x + _dir.x, _snake.first.y + _dir.y);
    if (head.x < 0 || head.y < 0 || head.x >= cols || head.y >= rows || _snake.contains(head)) {
      setState(_resetSnake);
      return;
    }
    setState(() {
      _snake.insert(0, head);
      if (head == _apple) {
        _score++;
        widget.onScore(_score);
        _apple = _freeCell();
      } else {
        _snake.removeLast();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('吃到 $_score 颗', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Expanded(
          child: GestureDetector(
            onVerticalDragUpdate: (d) => _turn(d.delta.dy > 0 ? const Point(0, 1) : const Point(0, -1)),
            onHorizontalDragUpdate: (d) => _turn(d.delta.dx > 0 ? const Point(1, 0) : const Point(-1, 0)),
            child: AspectRatio(
              aspectRatio: cols / rows,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols),
                itemCount: cols * rows,
                itemBuilder: (_, i) {
                  final cell = Point(i % cols, i ~/ cols);
                  Color color = const Color(0xFFFFE8F0);
                  if (_snake.first == cell) {
                    color = CamiColors.roseDeep;
                  } else if (_snake.contains(cell)) {
                    color = CamiColors.rose;
                  } else if (cell == _apple) {
                    color = CamiColors.gold;
                  }
                  return Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                  );
                },
              ),
            ),
          ),
        ),
        const Text('手指滑动改变方向', style: TextStyle(color: CamiColors.muted)),
      ],
    );
  }
}
