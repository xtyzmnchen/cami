import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

class MemoryGame extends StatefulWidget {
  const MemoryGame({super.key, required this.onScore});
  final ValueChanged<int> onScore;

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  static const _icons = [
    Icons.spa,
    Icons.local_florist,
    Icons.workspace_premium,
    Icons.favorite,
    Icons.star,
    Icons.wb_sunny,
  ];
  late List<int> _deck;
  final _open = <int>[];
  final _known = <int>{};
  var _lock = false;
  var _score = 0;

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  void _shuffle() {
    _deck = [..._icons.asMap().keys, ..._icons.asMap().keys]..shuffle(Random());
    _open.clear();
    _known.clear();
  }

  void _tap(int index) {
    if (_lock || _known.contains(index) || _open.contains(index)) return;
    setState(() => _open.add(index));
    if (_open.length < 2) return;
    final a = _open[0];
    final b = _open[1];
    if (_deck[a] == _deck[b]) {
      _known.addAll([a, b]);
      _open.clear();
      _score++;
      widget.onScore(_score);
      if (_known.length == _deck.length) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) setState(_shuffle);
        });
      }
    } else {
      _lock = true;
      Future.delayed(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        setState(() {
          _open.clear();
          _lock = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('配成 $_score 对', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: _deck.length,
            itemBuilder: (_, i) {
              final shown = _open.contains(i) || _known.contains(i);
              return GestureDetector(
                onTap: () => _tap(i),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: shown ? Colors.white : CamiColors.rose,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: CamiColors.line),
                  ),
                  child: Icon(
                    shown ? _icons[_deck[i]] : Icons.favorite_border,
                    color: shown ? CamiColors.roseDeep : Colors.white,
                    size: 32,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
