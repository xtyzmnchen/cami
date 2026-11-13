import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'game_kit.dart';
import 'sprites.dart';

class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key, required this.onScore, this.onQuit});
  final ValueChanged<int> onScore;
  /// 选择不继续时退出整局游戏页。
  final VoidCallback? onQuit;

  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame> {
  // 横屏棋盘：更宽更矮，配合正方形格子
  static const cols = 18;
  static const rows = 10;
  final _rng = Random();
  final _progress = GameProgress(lives: 3);
  late List<Point<int>> _snake;
  var _dir = const Point<int>(1, 0);
  var _next = const Point<int>(1, 0);
  late Point<int> _food;
  var _foodBonus = false;
  var _eatenThisLevel = 0;
  var _asking = false;
  Timer? _timer;

  /// 开局慢，蛇越长（吃得越多）越快；关卡再略微加压。
  int get _intervalMs {
    final grown = max(0, _snake.length - 3);
    return max(120, 520 - grown * 22 - (_progress.level - 1) * 10);
  }

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
    final midY = rows ~/ 2;
    final midX = cols ~/ 2;
    _snake = [
      Point(midX, midY),
      Point(midX - 1, midY),
      Point(midX - 2, midY),
    ];
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
    if (_asking || _progress.lives <= 0) return;
    _dir = _next;
    final head = Point(_snake.first.x + _dir.x, _snake.first.y + _dir.y);
    if (head.x < 0 || head.y < 0 || head.x >= cols || head.y >= rows || _snake.contains(head)) {
      _timer?.cancel();
      setState(() {
        _progress.loseLife();
        _asking = true;
      });
      unawaited(_askNextRound());
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
        // 每吃一个就按蛇长提速
        _restartTimer();
        if (_eatenThisLevel >= _need) {
          _progress.levelUp(onScore: widget.onScore, label: _progress.t('第 ${_progress.level} 关！蛇更快了', 'Level ${_progress.level}! Snake faster'));
          _eatenThisLevel = 0;
          _restartTimer();
        }
      } else {
        _snake.removeLast();
      }
    });
  }

  Future<void> _askNextRound() async {
    if (!mounted) return;
    final livesLeft = _progress.lives;
    final title = livesLeft > 0
        ? _progress.t('撞到了', 'Crashed')
        : _progress.t('没有命了', 'No lives left');
    final body = livesLeft > 0
        ? _progress.t('还剩 $livesLeft 条命，要下一局吗？', '$livesLeft lives left. Play next round?')
        : _progress.t('要重新开始下一局吗？', 'Start a new round?');
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_progress.t('退出', 'Quit')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_progress.t('下一局', 'Next round')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (go == true) {
      setState(() {
        if (livesLeft <= 0) {
          _progress.lives = 3;
          _progress.level = max(1, _progress.level - 1);
        }
        _boot();
        _asking = false;
      });
      _restartTimer();
    } else {
      _asking = false;
      widget.onQuit?.call();
    }
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
              // 横屏时用正方形格子，避免蛇身/水果被拉扁
              final cell = min(box.maxWidth / cols, box.maxHeight / rows);
              final boardW = cell * cols;
              final boardH = cell * rows;
              final ox = (box.maxWidth - boardW) / 2;
              final oy = (box.maxHeight - boardH) / 2;
              final pad = max(1.0, cell * 0.06);
              return Stack(
                children: [
                  Positioned(
                    left: ox,
                    top: oy,
                    width: boardW,
                    height: boardH,
                    child: Stack(
                      children: [
                        for (var y = 0; y < rows; y++)
                          for (var x = 0; x < cols; x++)
                            Positioned(
                              left: x * cell,
                              top: y * cell,
                              width: cell,
                              height: cell,
                              child: Container(
                                margin: EdgeInsets.all(pad),
                                decoration: BoxDecoration(
                                  color: (x + y).isEven ? const Color(0xFFFFF0F5) : const Color(0xFFFFE4EF),
                                  borderRadius: BorderRadius.circular(cell * 0.18),
                                ),
                              ),
                            ),
                        Positioned(
                          left: _food.x * cell + pad,
                          top: _food.y * cell + pad,
                          width: cell - pad * 2,
                          height: cell - pad * 2,
                          child: GameSprites.img(
                            _foodBonus ? GameSprites.star : GameSprites.apple,
                            size: cell - pad * 2,
                          ),
                        ),
                        for (var i = 0; i < _snake.length; i++)
                          Positioned(
                            left: _snake[i].x * cell + pad * 1.5,
                            top: _snake[i].y * cell + pad * 1.5,
                            width: cell - pad * 3,
                            height: cell - pad * 3,
                            child: i == 0
                                ? GameSprites.img(GameSprites.strawberry, size: cell - pad * 3)
                                : DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [CamiColors.rose, Color(0xFFFFB6D0)]),
                                      borderRadius: BorderRadius.circular(cell * 0.28),
                                      boxShadow: [
                                        BoxShadow(color: CamiColors.roseDeep.withValues(alpha: 0.25), blurRadius: 4),
                                      ],
                                    ),
                                  ),
                          ),
                      ],
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
