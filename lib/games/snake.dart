import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'game_kit.dart';
import 'sprites.dart';

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
  final _progress = GameProgress(lives: 3);
  late List<Point<int>> _snake;
  var _dir = const Point<int>(1, 0);
  var _next = const Point<int>(1, 0);
  late Point<int> _food;
  var _foodBonus = false;
  var _eatenThisLevel = 0;
  Timer? _timer;

  int get _intervalMs => max(90, 300 - (_progress.level - 1) * 22);
  int get _need => 4 + _progress.level;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progress.isEn = Localizations.localeOf(context).languageCode == 'en';
  }

  @override
  void initState() {
    super.initState();
    _boot();
    _restartTimer();
  }

  void _boot() {
    _snake = [const Point(5, 8), const Point(4, 8), const Point(3, 8)];
    _dir = const Point(1, 0);
    _next = _dir;
    _food = _freeCell();
    _foodBonus = false;
    _eatenThisLevel = 0;
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _intervalMs), (_) => _tick());
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
    if (_progress.lives <= 0) return;
    _dir = _next;
    final head = Point(_snake.first.x + _dir.x, _snake.first.y + _dir.y);
    if (head.x < 0 || head.y < 0 || head.x >= cols || head.y >= rows || _snake.contains(head)) {
      setState(() {
        _progress.loseLife();
        _progress.showBanner(_progress.lives > 0 ? _progress.t('撞到了！还剩 ${_progress.lives} 心', 'Ouch! ${_progress.lives} hearts left') : _progress.t('本局结束，再开一局', 'Round over — try again'));
        if (_progress.lives > 0) {
          _boot();
        } else {
          _progress.lives = 3;
          _progress.level = max(1, _progress.level - 1);
          _boot();
          _restartTimer();
        }
      });
      return;
    }
    setState(() {
      _progress.clearBannerIfNeeded();
      _snake.insert(0, head);
      if (head == _food) {
        HapticFeedback.selectionClick();
        final gain = _foodBonus ? 3 : 1;
        _progress.score += gain;
        _progress.hitCombo();
        if (_progress.combo >= 3) _progress.score++;
        widget.onScore(_progress.score);
        _eatenThisLevel++;
        _foodBonus = _rng.nextDouble() < 0.18;
        _food = _freeCell();
        if (_eatenThisLevel >= _need) {
          _progress.levelUp(onScore: widget.onScore, label: _progress.t('第 ${_progress.level} 关！蛇更快了', 'Level ${_progress.level}! Snake faster'));
          _eatenThisLevel = 0;
          _restartTimer();
        }
      } else {
        _snake.removeLast();
        if (_progress.combo > 0 && _rng.nextDouble() < 0.02) {
          // soft decay unused
        }
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
    return GameFrame(
      progress: _progress,
      hint: _progress.t('滑动转向 · 金色果子 3 分 · 连吃有奖励', 'Swipe to turn · gold fruit 3 pts · combos bonus'),
      child: GameStage(
        child: GestureDetector(
          onVerticalDragUpdate: (d) {
            if (d.delta.dy.abs() > 6) _turn(d.delta.dy > 0 ? const Point(0, 1) : const Point(0, -1));
          },
          onHorizontalDragUpdate: (d) {
            if (d.delta.dx.abs() > 6) _turn(d.delta.dx > 0 ? const Point(1, 0) : const Point(-1, 0));
          },
          child: LayoutBuilder(
            builder: (context, box) {
              final cellW = box.maxWidth / cols;
              final cellH = box.maxHeight / rows;
              return Stack(
                children: [
                  // checkerboard
                  for (var y = 0; y < rows; y++)
                    for (var x = 0; x < cols; x++)
                      Positioned(
                        left: x * cellW,
                        top: y * cellH,
                        width: cellW,
                        height: cellH,
                        child: Container(
                          margin: const EdgeInsets.all(1.2),
                          decoration: BoxDecoration(
                            color: (x + y).isEven ? const Color(0xFFFFF0F5) : const Color(0xFFFFE4EF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  Positioned(
                    left: _food.x * cellW + 1,
                    top: _food.y * cellH + 1,
                    width: cellW - 2,
                    height: cellH - 2,
                    child: GameSprites.img(_foodBonus ? GameSprites.star : GameSprites.apple, size: cellW - 2),
                  ),
                  for (var i = 0; i < _snake.length; i++)
                    Positioned(
                      left: _snake[i].x * cellW + 2,
                      top: _snake[i].y * cellH + 2,
                      width: cellW - 4,
                      height: cellH - 4,
                      child: i == 0
                          ? GameSprites.img(GameSprites.strawberry, size: cellW - 4)
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [CamiColors.rose, Color(0xFFFFB6D0)]),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(color: CamiColors.roseDeep.withValues(alpha: 0.25), blurRadius: 4),
                                ],
                              ),
                            ),
                    ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Text(
                      '本关再吃 ${_need - _eatenThisLevel} 个升级',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: CamiColors.roseDeep, fontSize: 12),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
