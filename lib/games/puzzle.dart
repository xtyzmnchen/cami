import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

class PuzzleGame extends StatefulWidget {
  const PuzzleGame({super.key, required this.onScore});
  final ValueChanged<int> onScore;

  @override
  State<PuzzleGame> createState() => _PuzzleGameState();
}

class _PuzzleGameState extends State<PuzzleGame> {
  late List<int> _tiles;
  var _score = 0;

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  void _shuffle() {
    final rng = Random();
    while (true) {
      _tiles = List.generate(9, (i) => i)..shuffle(rng);
      if (_solvable(_tiles) && !_solved()) break;
    }
  }

  bool _solvable(List<int> tiles) {
    var inversions = 0;
    for (var i = 0; i < tiles.length; i++) {
      if (tiles[i] == 0) continue;
      for (var j = i + 1; j < tiles.length; j++) {
        if (tiles[j] != 0 && tiles[i] > tiles[j]) inversions++;
      }
    }
    return inversions.isEven;
  }

  bool _solved() {
    for (var i = 0; i < 8; i++) {
      if (_tiles[i] != i + 1) return false;
    }
    return _tiles[8] == 0;
  }

  void _tap(int index) {
    final empty = _tiles.indexOf(0);
    final sameRow = index ~/ 3 == empty ~/ 3;
    final beside = (index - empty).abs() == 1 && sameRow || (index - empty).abs() == 3;
    if (!beside) return;
    setState(() {
      final swap = _tiles[index];
      _tiles[index] = 0;
      _tiles[empty] = swap;
      if (_solved()) {
        _score++;
        widget.onScore(_score);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(_shuffle);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('拼好 $_score 次', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1,
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (var i = 0; i < 9; i++)
                GestureDetector(
                  onTap: () => _tap(i),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _tiles[i] == 0 ? Colors.transparent : CamiColors.blush,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        _tiles[i] == 0 ? '' : '${_tiles[i]}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: CamiColors.roseDeep),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Text('点旁边的数字，把它滑进空格', style: TextStyle(color: CamiColors.muted)),
      ],
    );
  }
}
