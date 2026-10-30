import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

class MathQuizGame extends StatefulWidget {
  const MathQuizGame({super.key, required this.onScore});
  final ValueChanged<int> onScore;

  @override
  State<MathQuizGame> createState() => _MathQuizGameState();
}

class _MathQuizGameState extends State<MathQuizGame> {
  final _rng = Random();
  late String _prompt;
  late int _answer;
  late List<int> _choices;
  var _score = 0;
  String? _hint;

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    final multiply = _rng.nextBool();
    if (multiply) {
      final a = _rng.nextInt(8) + 2;
      final b = _rng.nextInt(8) + 2;
      _answer = a * b;
      _prompt = '$a × $b';
    } else if (_rng.nextBool()) {
      final a = _rng.nextInt(40) + 10;
      final b = _rng.nextInt(40) + 10;
      _answer = a + b;
      _prompt = '$a + $b';
    } else {
      final a = _rng.nextInt(60) + 20;
      final b = _rng.nextInt(a);
      _answer = a - b;
      _prompt = '$a − $b';
    }
    final set = <int>{_answer};
    while (set.length < 4) {
      set.add(_answer + _rng.nextInt(11) - 5);
    }
    _choices = set.where((n) => n >= 0).toList();
    while (_choices.length < 4) {
      _choices.add(_answer + _choices.length + 1);
    }
    _choices.shuffle(_rng);
    _hint = null;
  }

  void _pick(int value) {
    if (value == _answer) {
      setState(() {
        _score++;
        widget.onScore(_score);
        _next();
      });
    } else {
      setState(() => _hint = '再想想，答案是 $_answer');
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(_next);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('答对 $_score 题', style: const TextStyle(fontWeight: FontWeight.w700)),
        const Spacer(),
        Text(_prompt, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w600)),
        if (_hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_hint!, style: const TextStyle(color: CamiColors.roseDeep)),
          ),
        const Spacer(),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          childAspectRatio: 2.4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (final choice in _choices)
              FilledButton(
                onPressed: () => _pick(choice),
                style: FilledButton.styleFrom(backgroundColor: CamiColors.rose),
                child: Text('$choice', style: const TextStyle(fontSize: 22)),
              ),
          ],
        ),
      ],
    );
  }
}
