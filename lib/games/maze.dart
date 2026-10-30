import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

class MazeGame extends StatefulWidget {
  const MazeGame({super.key, required this.onScore});
  final ValueChanged<int> onScore;

  @override
  State<MazeGame> createState() => _MazeGameState();
}

class _MazeGameState extends State<MazeGame> {
  static const n = 11;
  late List<List<bool>> _open;
  var _x = 1;
  var _y = 1;
  var _score = 0;

  @override
  void initState() {
    super.initState();
    _carve();
  }

  void _carve() {
    _open = List.generate(n, (_) => List.filled(n, false));
    final rng = Random();
    void visit(int x, int y) {
      _open[y][x] = true;
      final dirs = [
        const Point(0, -2),
        const Point(0, 2),
        const Point(-2, 0),
        const Point(2, 0),
      ]..shuffle(rng);
      for (final dir in dirs) {
        final nx = x + dir.x;
        final ny = y + dir.y;
        if (nx <= 0 || ny <= 0 || nx >= n - 1 || ny >= n - 1 || _open[ny][nx]) continue;
        _open[y + dir.y ~/ 2][x + dir.x ~/ 2] = true;
        visit(nx, ny);
      }
    }

    visit(1, 1);
    _open[n - 2][n - 2] = true;
    _x = 1;
    _y = 1;
  }

  void _move(int dx, int dy) {
    final nx = _x + dx;
    final ny = _y + dy;
    if (nx < 0 || ny < 0 || nx >= n || ny >= n || !_open[ny][nx]) return;
    setState(() {
      _x = nx;
      _y = ny;
      if (_x == n - 2 && _y == n - 2) {
        _score++;
        widget.onScore(_score);
        _carve();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('找到 $_score 顶皇冠', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: n),
              itemCount: n * n,
              itemBuilder: (_, i) {
                final x = i % n;
                final y = i ~/ n;
                if (!_open[y][x]) return const ColoredBox(color: Color(0xFFFFC8DC));
                if (x == _x && y == _y) {
                  return const Icon(Icons.favorite, color: CamiColors.rose, size: 16);
                }
                if (x == n - 2 && y == n - 2) {
                  return const Icon(Icons.workspace_premium, color: CamiColors.gold, size: 16);
                }
                return const ColoredBox(color: Colors.white);
              },
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(onPressed: () => _move(0, -1), icon: const Icon(Icons.keyboard_arrow_up)),
            IconButton(onPressed: () => _move(-1, 0), icon: const Icon(Icons.keyboard_arrow_left)),
            IconButton(onPressed: () => _move(1, 0), icon: const Icon(Icons.keyboard_arrow_right)),
            IconButton(onPressed: () => _move(0, 1), icon: const Icon(Icons.keyboard_arrow_down)),
          ],
        ),
      ],
    );
  }
}
