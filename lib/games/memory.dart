import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'game_kit.dart';
import 'sprites.dart';

class MemoryGame extends StatefulWidget {
  const MemoryGame({super.key, required this.onScore});
  final ValueChanged<int> onScore;

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  final _progress = GameProgress(lives: 3);
  late List<String> _deck;
  final _open = <int>[];
  final _known = <int>{};
  var _lock = false;
  var _moves = 0;
  var _pairsThisRound = 0;
  DateTime? _started;

  int get _pairCount => (3 + (_progress.level - 1)).clamp(3, 8);
  int get _cols => _pairCount <= 4 ? 3 : 4;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progress.isEn = Localizations.localeOf(context).languageCode == 'en';
  }

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    final n = _pairCount;
    final faces = (GameSprites.memoryFaces.toList()..shuffle(Random())).take(n).toList();
    _deck = [...faces, ...faces]..shuffle(Random());
    _open.clear();
    _known.clear();
    _lock = false;
    _moves = 0;
    _pairsThisRound = 0;
    _started = DateTime.now();
  }

  void _tap(int index) {
    if (_lock || _known.contains(index) || _open.contains(index) || _progress.lives <= 0) return;
    HapticFeedback.selectionClick();
    setState(() => _open.add(index));
    if (_open.length < 2) return;
    _moves++;
    final a = _open[0];
    final b = _open[1];
    if (_deck[a] == _deck[b]) {
      _known.addAll([a, b]);
      _open.clear();
      _pairsThisRound++;
      _progress.hitCombo();
      final bonus = _progress.combo >= 3 ? 2 : 1;
      _progress.score += bonus;
      widget.onScore(_progress.score);
      if (_known.length == _deck.length) {
        final secs = DateTime.now().difference(_started ?? DateTime.now()).inSeconds;
        final moveBonus = max(0, _pairCount * 2 - _moves);
        _progress.score += 5 + moveBonus + max(0, 30 - secs);
        widget.onScore(_progress.score);
        _progress.levelUp(
          onScore: widget.onScore,
          label: secs < 25 ? _progress.t('超快通关！第 ${_progress.level} 关', 'Speedy clear! Level ${_progress.level}') : _progress.t('第 ${_progress.level} 关 · 卡片更多了', 'Level ${_progress.level} · more cards'),
        );
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) setState(_deal);
        });
      }
    } else {
      _lock = true;
      _progress.breakCombo();
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() {
          _open.clear();
          _lock = false;
          if (_moves > _pairCount * 4) {
            _progress.loseLife();
            _progress.showBanner(_progress.t('步数太多，掉一颗心', 'Too many moves — lost a heart'));
            _moves = 0;
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      progress: _progress,
      hint: _progress.t('翻开两张一样的 · 连对有加分 · 越快星星越多', 'Match pairs · combos score · faster = more stars'),
      child: GameStage(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  Text('配对 $_pairsThisRound/$_pairCount', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('步数 $_moves', style: const TextStyle(color: CamiColors.muted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _cols,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.92,
                ),
                itemCount: _deck.length,
                itemBuilder: (_, i) {
                  final shown = _open.contains(i) || _known.contains(i);
                  final matched = _known.contains(i);
                  return GestureDetector(
                    onTap: () => _tap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: matched ? CamiColors.gold : Colors.white70, width: 1.6),
                        boxShadow: [
                          BoxShadow(
                            color: CamiColors.rose.withValues(alpha: 0.22),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: shown
                            ? GameSprites.tile(_deck[i], radius: 0, fit: BoxFit.cover)
                            : GameSprites.tile(GameSprites.cardBack, radius: 0, fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
