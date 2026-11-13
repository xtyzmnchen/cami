import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'game_kit.dart';
import 'sprites.dart';

/// 水果忍者式：水果抛起，手指划开；贴图不用表情。
class SliceFruitGame extends StatefulWidget {
  const SliceFruitGame({super.key, required this.onScore});
  final ValueChanged<int> onScore;

  @override
  State<SliceFruitGame> createState() => _SliceFruitGameState();
}

class _Fruit {
  _Fruit({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.asset,
    required this.color,
    required this.bomb,
    required this.spin,
    required this.radius,
  });

  double x;
  double y;
  double vx;
  double vy;
  final String asset;
  final Color color;
  final bool bomb;
  double spin;
  final double radius;
  var alive = true;
  var sliceT = 0.0;
  Offset? sliceDir;
}

class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.color);
  double x;
  double y;
  double vx;
  double vy;
  final Color color;
  var life = 1.0;
}

class _SliceFruitGameState extends State<SliceFruitGame> {
  static const _fruitColors = [
    Color(0xFFFF6B6B),
    Color(0xFF3CB371),
    Color(0xFFFF9F43),
    Color(0xFFFFD56A),
    Color(0xFF9B59B6),
    Color(0xFFFF6B9A),
    Color(0xFFFF8FAB),
    Color(0xFF7DCEA0),
    Color(0xFFE74C3C),
  ];

  final _rng = Random();
  final _progress = GameProgress(lives: 3);
  final _items = <_Fruit>[];
  final _sparks = <_Spark>[];
  final _trail = <Offset>[];
  var _slicedLevel = 0;
  Timer? _timer;
  Size _size = Size.zero;
  var _spawnCool = 0.0;

  int get _need => 8 + _progress.level * 3;
  double get _bombChance => min(0.34, 0.12 + _progress.level * 0.028);
  double get _spawnGap => max(0.28, 0.7 - _progress.level * 0.05);
  double get _fruitRadius => max(22, 34.0 - _progress.level * 1.2);
  int get _bombPenalty => 3 + _progress.level;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progress.isEn = Localizations.localeOf(context).languageCode == 'en';
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick(0.016));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _spawn({int count = 1}) {
    final w = _size.width;
    final h = _size.height;
    if (w <= 0 || h <= 0) return;
    for (var i = 0; i < count; i++) {
      final bomb = _rng.nextDouble() < _bombChance;
      final fi = _rng.nextInt(GameSprites.fruits.length);
      final x = w * (0.16 + _rng.nextDouble() * 0.68);
      final vx = (x < w / 2 ? 1 : -1) * (50 + _rng.nextDouble() * 100 + _progress.level * 8);
      final vy = -(540 + _rng.nextDouble() * 240 + _progress.level * 12);
      _items.add(
        _Fruit(
          x: x,
          y: h + 24 + i * 8,
          vx: vx,
          vy: vy,
          asset: bomb ? GameSprites.bomb : GameSprites.fruits[fi],
          color: bomb ? const Color(0xFF4A4A4A) : _fruitColors[fi % _fruitColors.length],
          bomb: bomb,
          spin: (_rng.nextDouble() - 0.5) * 7,
          radius: bomb ? 30 : _fruitRadius,
        ),
      );
    }
  }

  void _tick(double dt) {
    if (_size == Size.zero) return;
    setState(() {
      _progress.clearBannerIfNeeded();
      _spawnCool -= dt;
      if (_spawnCool <= 0) {
        final burst = _rng.nextDouble() < min(0.55, 0.25 + _progress.level * 0.04);
        _spawn(count: burst ? 2 + (_progress.level > 4 ? 1 : 0) : 1);
        _spawnCool = _spawnGap * (0.75 + _rng.nextDouble() * 0.5);
      }

      for (final f in _items) {
        if (!f.alive) {
          f.sliceT += dt;
          f.vy += 900 * dt;
          f.x += f.vx * dt;
          f.y += f.vy * dt;
          continue;
        }
        f.vy += 980 * dt;
        f.x += f.vx * dt;
        f.y += f.vy * dt;
        f.spin += dt * 2.4;
      }

      for (final s in _sparks) {
        s.life -= dt * 2.2;
        s.vy += 600 * dt;
        s.x += s.vx * dt;
        s.y += s.vy * dt;
      }
      _sparks.removeWhere((s) => s.life <= 0);

      _items.removeWhere((f) {
        if (f.alive && f.y > _size.height + 40 && f.vy > 0) {
          if (!f.bomb) {
            _progress.loseLife();
            _progress.breakCombo();
            _progress.showBanner(_progress.t('漏掉水果了', 'Missed a fruit'));
            if (_progress.lives <= 0) {
              _progress.lives = 3;
              _progress.level = max(1, _progress.level - 1);
              _slicedLevel = 0;
              _progress.showBanner(_progress.t('重新挑战第 ${_progress.level} 关', 'Retry level ${_progress.level}'));
            }
          }
          return true;
        }
        return !f.alive && f.sliceT > 0.55;
      });

      if (_trail.length > 12) {
        _trail.removeRange(0, _trail.length - 12);
      }
    });
  }

  bool _segmentHits(Offset a, Offset b, _Fruit f) {
    final ab = b - a;
    final ap = Offset(f.x, f.y) - a;
    final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (ab2 < 1) return (Offset(f.x, f.y) - a).distance <= f.radius;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / ab2).clamp(0.0, 1.0);
    final closest = a + ab * t;
    return (Offset(f.x, f.y) - closest).distance <= f.radius;
  }

  void _slash(Offset a, Offset b) {
    if ((b - a).distance < 8) return;
    var hit = false;
    for (final f in _items) {
      if (!f.alive || !_segmentHits(a, b, f)) continue;
      hit = true;
      f.alive = false;
      f.sliceDir = b - a;
      f.sliceT = 0;
      f.vx = (b.dx - a.dx).sign * (90 + _rng.nextDouble() * 130);
      f.vy = -50;

      for (var i = 0; i < 10; i++) {
        final ang = _rng.nextDouble() * pi * 2;
        final spd = 90 + _rng.nextDouble() * 170;
        _sparks.add(_Spark(f.x, f.y, cos(ang) * spd, sin(ang) * spd - 50, f.bomb ? const Color(0xFFFF5555) : f.color));
      }

      if (f.bomb) {
        unawaited(bombHitFeedback());
        _progress.loseLife(haptic: false);
        _progress.breakCombo();
        final penalty = _bombPenalty;
        _progress.score = max(0, _progress.score - penalty);
        widget.onScore(_progress.score);
        _progress.showBanner(_progress.t('炸弹！-$penalty分', 'Bomb! -$penalty pts'));
        if (_progress.lives <= 0) {
          _progress.lives = 3;
          _slicedLevel = 0;
          _progress.showBanner(_progress.t('心没了，本关重来 · 仍是第 ${_progress.level} 关', 'No hearts — retry Lv ${_progress.level}'));
        }
      } else {
        HapticFeedback.selectionClick();
        _progress.hitCombo();
        _progress.score += 1 + (_progress.combo >= 5 ? 2 : (_progress.combo >= 3 ? 1 : 0));
        _slicedLevel++;
        widget.onScore(_progress.score);
        if (_slicedLevel >= _need) {
          _slicedLevel = 0;
          _progress.levelUp(onScore: widget.onScore, label: _progress.t('第 ${_progress.level} 关！水果更密了', 'Level ${_progress.level}! Denser fruit'));
        }
      }
    }
    if (hit) setState(() {});
  }

  Widget _fruitVisual(_Fruit f) {
    final size = f.radius * 2;
    final img = GameSprites.img(f.asset, size: size);
    if (f.alive || f.sliceDir == null) {
      return Transform.rotate(angle: f.spin, child: img);
    }
    final ang = atan2(f.sliceDir!.dy, f.sliceDir!.dx);
    final alpha = (1 - f.sliceT).clamp(0.0, 1.0);
    return Opacity(
      opacity: alpha,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            for (final side in [-1.0, 1.0])
              Transform.translate(
                offset: Offset(side * (8 + f.sliceT * 40), f.sliceT * 10),
                child: Transform.rotate(
                  angle: f.spin + side * f.sliceT * 2,
                  child: ClipRect(
                    child: Align(
                      alignment: side < 0 ? Alignment.centerLeft : Alignment.centerRight,
                      widthFactor: 0.5,
                      child: Transform.rotate(angle: ang * 0.15, child: img),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      progress: _progress,
      hint: _progress.t('手指快速划过水果 · 躲开炸弹 · 连切加分', 'Swipe fruit · dodge bombs · combos score more'),
      child: LayoutBuilder(
        builder: (context, c) {
          _size = Size(c.maxWidth, c.maxHeight);
          return GameStage(
            child: Stack(
              children: [
                Positioned(
                  left: 12,
                  top: 10,
                  child: Text(
                    '再切 ${_need - _slicedLevel} 个升级',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: CamiColors.roseDeep, fontSize: 12),
                  ),
                ),
                for (final s in _sparks)
                  Positioned(
                    left: s.x - 3,
                    top: s.y - 3,
                    child: Container(
                      width: 6 * s.life,
                      height: 6 * s.life,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: s.color.withValues(alpha: s.life)),
                    ),
                  ),
                for (final f in _items)
                  Positioned(
                    left: f.x - f.radius,
                    top: f.y - f.radius,
                    child: _fruitVisual(f),
                  ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) {
                      _trail
                        ..clear()
                        ..add(d.localPosition);
                    },
                    onPanUpdate: (d) {
                      final prev = _trail.isEmpty ? d.localPosition : _trail.last;
                      _trail.add(d.localPosition);
                      if (_trail.length > 16) _trail.removeAt(0);
                      _slash(prev, d.localPosition);
                      setState(() {});
                    },
                    onPanEnd: (_) => setState(() => _trail.clear()),
                    child: CustomPaint(
                      painter: _TrailPainter(trail: List.of(_trail)),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.trail});
  final List<Offset> trail;

  @override
  void paint(Canvas canvas, Size size) {
    if (trail.length < 2) return;
    final path = Path()..moveTo(trail.first.dx, trail.first.dy);
    for (var i = 1; i < trail.length; i++) {
      path.lineTo(trail[i].dx, trail[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = CamiColors.roseDeep.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TrailPainter oldDelegate) => true;
}
