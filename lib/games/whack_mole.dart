import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../services/voice.dart';
import '../theme.dart';
import 'game_kit.dart';
import 'sprites.dart';

/// 打地鼠（横屏街机版）
/// · 固定 3×3 洞，铺满可用区域，不再被 GridView 裁切
/// · 普通地鼠 +10，金色 +50；连击加分
/// · 漏掉地鼠 / 打到炸弹扣命；3 命结算后再玩
/// · 分数越高出得越快、同时越多（适合二年级）
class WhackMoleGame extends StatefulWidget {
  const WhackMoleGame({super.key, required this.onScore});
  final ValueChanged<int> onScore;

  @override
  State<WhackMoleGame> createState() => _WhackMoleGameState();
}

enum _Kind { mole, gold, bomb }

class _Hole {
  var up = false;
  var hit = false;
  var kind = _Kind.mole;
  var life = 0.0;
  var maxLife = 0.9;
  /// 0 刚冒头 → 1 完全露出；hit 后砸扁
  var pop = 0.0;
}

class _Float {
  _Float(this.x, this.y, this.text, this.color);
  double x;
  double y;
  final String text;
  final Color color;
  double life = 1;
}

class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.color);
  double x, y, vx, vy;
  final Color color;
  double life = 1;
}

class _WhackMoleGameState extends State<WhackMoleGame> with SingleTickerProviderStateMixin {
  static const _cols = 3;
  static const _rows = 3;
  static const _count = 9;

  final _rng = Random();
  final _progress = GameProgress(lives: 3);
  late final List<_Hole> _holes;
  final _floats = <_Float>[];
  final _sparks = <_Spark>[];
  var _spawnCool = 0.4;
  var _bonkIndex = -1;
  var _bonkT = 0.0;
  var _hammerX = 0.5;
  var _hammerY = 0.5;
  var _showHammer = false;
  var _caught = 0;
  var _best = 0;
  var _lastPraiseAt = 0;
  var _gameOver = false;
  var _elapsed = 0.0;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// 难度随时间和分数缓缓加快
  double get _upTime {
    final t = _elapsed;
    return max(0.45, 1.2 - t * 0.012 - _progress.score * 0.0004);
  }

  double get _spawnGap => max(0.22, 0.75 - _elapsed * 0.008 - _progress.score * 0.0005);

  int get _maxActive {
    if (_progress.score >= 200 || _elapsed > 45) return 3;
    if (_progress.score >= 80 || _elapsed > 20) return 2;
    return 1;
  }

  double get _bombChance => min(0.16, 0.04 + _elapsed * 0.002);
  double get _goldChance => 0.1;

  int get _ratingStars {
    final s = _progress.score;
    if (s >= 400) return 3;
    if (s >= 180) return 2;
    if (s >= 60) return 1;
    return 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progress.isEn = Localizations.localeOf(context).languageCode == 'en';
  }

  @override
  void initState() {
    super.initState();
    _holes = List.generate(_count, (_) => _Hole());
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    unawaited(Voice.stop());
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _step(dt);
  }

  void _step(double dt) {
    if (_gameOver) {
      setState(() {
        _tickFx(dt);
        if (_bonkT > 0) _bonkT = max(0, _bonkT - dt);
      });
      return;
    }

    setState(() {
      _elapsed += dt;
      if (_bonkT > 0) _bonkT = max(0, _bonkT - dt);
      if (_bonkT <= 0) _showHammer = false;

      _spawnCool -= dt;
      var active = _holes.where((h) => h.up && !h.hit).length;
      if (_spawnCool <= 0 && active < _maxActive) {
        final burst = active == 0 && _maxActive >= 2 && _rng.nextDouble() < 0.35 ? 2 : 1;
        for (var n = 0; n < burst; n++) {
          active = _holes.where((h) => h.up && !h.hit).length;
          if (active >= _maxActive) break;
          _spawnOne();
        }
        _spawnCool = _spawnGap * (0.7 + _rng.nextDouble() * 0.5);
      }

      for (final h in _holes) {
        if (!h.up) continue;
        if (h.hit) {
          h.pop = max(0, h.pop - dt * 4);
          h.life -= dt;
          if (h.life <= 0) {
            h.up = false;
            h.hit = false;
            h.pop = 0;
          }
          continue;
        }
        // 冒出动画
        h.pop = min(1, h.pop + dt * 5);
        h.life -= dt;
        if (h.life <= 0) {
          if (h.kind != _Kind.bomb) {
            _progress.breakCombo();
            _progress.loseLife();
            _floats.add(
              _Float(0.5, 0.12, _progress.t('跑掉了 -1♥', 'Escaped -1♥'), const Color(0xFFFF6B6B)),
            );
            if (_progress.lives <= 0) {
              _endRun();
              return;
            }
          }
          h.up = false;
          h.pop = 0;
        }
      }

      _tickFx(dt);
    });
  }

  void _tickFx(double dt) {
    for (final f in _floats) {
      f.y -= 0.25 * dt;
      f.life -= dt * 1.2;
    }
    _floats.removeWhere((f) => f.life <= 0);
    for (final s in _sparks) {
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vy += 1.5 * dt;
      s.life -= dt * 2.4;
    }
    _sparks.removeWhere((s) => s.life <= 0);
  }

  void _spawnOne() {
    final free = <int>[];
    for (var i = 0; i < _holes.length; i++) {
      if (!_holes[i].up) free.add(i);
    }
    if (free.isEmpty) return;
    final i = free[_rng.nextInt(free.length)];
    final h = _holes[i];
    h.up = true;
    h.hit = false;
    h.pop = 0;
    final r = _rng.nextDouble();
    if (r < _bombChance) {
      h.kind = _Kind.bomb;
    } else if (r < _bombChance + _goldChance) {
      h.kind = _Kind.gold;
    } else {
      h.kind = _Kind.mole;
    }
    final lifeScale = h.kind == _Kind.gold ? 0.75 : (h.kind == _Kind.bomb ? 1.1 : 1);
    h.maxLife = _upTime * lifeScale * (0.85 + _rng.nextDouble() * 0.25);
    h.life = h.maxLife;
  }

  void _tapHole(int index, Offset local, Size board) {
    if (_gameOver) return;
    final h = _holes[index];
    final cx = ((index % _cols) + 0.5) / _cols;
    final cy = ((index ~/ _cols) + 0.55) / _rows;
    _hammerX = cx;
    _hammerY = cy;
    _showHammer = true;
    _bonkIndex = index;
    _bonkT = 0.28;

    if (!h.up || h.hit) {
      // 空点：断连击
      _progress.breakCombo();
      HapticFeedback.selectionClick();
      return;
    }

    h.hit = true;
    h.life = min(h.life, 0.22);

    if (h.kind == _Kind.bomb) {
      unawaited(bombHitFeedback());
      _burst(cx, cy, const Color(0xFFFF4D6D));
      _progress.loseLife(haptic: false);
      _progress.breakCombo();
      _floats.add(_Float(cx, cy - 0.08, _progress.t('炸弹！', 'Bomb!'), const Color(0xFFFF4D6D)));
      if (_progress.lives <= 0) _endRun();
      setState(() {});
      return;
    }

    HapticFeedback.mediumImpact();
    _progress.hitCombo();
    var gain = h.kind == _Kind.gold ? 50 : 10;
    if (_progress.combo >= 5) {
      gain += 10;
    } else if (_progress.combo >= 3) {
      gain += 5;
    }
    _progress.score += gain;
    _caught++;
    if (_progress.score > _best) _best = _progress.score;
    widget.onScore(_progress.score);
    _burst(cx, cy, h.kind == _Kind.gold ? const Color(0xFFFFB800) : const Color(0xFFFF8FAB));
    _floats.add(
      _Float(
        cx,
        cy - 0.1,
        h.kind == _Kind.gold ? '+$gain ★' : (_progress.combo >= 3 ? 'x${_progress.combo} +$gain' : '+$gain'),
        h.kind == _Kind.gold ? const Color(0xFFFFB800) : CamiColors.roseDeep,
      ),
    );
    _maybePraise();
    setState(() {});
  }

  void _burst(double x, double y, Color c) {
    for (var i = 0; i < 10; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final sp = 0.2 + _rng.nextDouble() * 0.45;
      _sparks.add(_Spark(x, y, cos(a) * sp, sin(a) * sp - 0.15, Color.lerp(c, Colors.white, _rng.nextDouble() * 0.4)!));
    }
  }

  void _maybePraise() {
    const step = 50;
    if (_progress.score < step) return;
    final mark = (_progress.score ~/ step) * step;
    if (mark <= _lastPraiseAt) return;
    _lastPraiseAt = mark;
    final zh = mark < 100
        ? '打得好！'
        : mark < 200
            ? '你太棒了！'
            : mark < 300
                ? '继续努力！'
                : '超级厉害！';
    final en = mark < 100
        ? 'Nice hit!'
        : mark < 200
            ? "You're awesome!"
            : mark < 300
                ? 'Keep going!'
                : 'Super!';
    unawaited(_progress.isEn ? Voice.sayEn(en) : Voice.say(zh));
  }

  void _endRun() {
    if (_gameOver) return;
    _gameOver = true;
    for (final h in _holes) {
      h.up = false;
      h.hit = false;
      h.pop = 0;
    }
    _progress.stars = _ratingStars;
    final stars = _ratingStars;
    unawaited(
      Voice.say(
        stars >= 3
            ? '太厉害了，三颗星！'
            : stars >= 2
                ? '很棒，两颗星！'
                : stars >= 1
                    ? '不错哦，再接再厉！'
                    : '没关系，再试一次！',
      ),
    );
  }

  void _restart() {
    _gameOver = true;
    for (final h in _holes) {
      h.up = false;
      h.hit = false;
      h.pop = 0;
    }
    _floats.clear();
    _sparks.clear();
    if (!mounted) return;
    setState(() {
      _gameOver = false;
      _progress.score = 0;
      _progress.lives = 3;
      _progress.combo = 0;
      _progress.stars = 0;
      _progress.level = 1;
      _caught = 0;
      _lastPraiseAt = 0;
      _elapsed = 0;
      _spawnCool = 0.5;
      _bonkT = 0;
      _showHammer = false;
      _last = Duration.zero;
    });
    widget.onScore(0);
  }

  @override
  Widget build(BuildContext context) {
    final en = _progress.isEn;
    return Column(
      children: [
        _WhackHud(
          score: _progress.score,
          combo: _progress.combo,
          lives: _progress.lives,
          activeHint: _maxActive,
          isEn: en,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              // 横屏：按可用区域算出最大正方形格子的 3×3 棋盘，居中
              final pad = 6.0;
              final usableW = c.maxWidth - pad * 2;
              final usableH = c.maxHeight - pad * 2;
              final cell = min(usableW / _cols, usableH / _rows);
              final boardW = cell * _cols;
              final boardH = cell * _rows;
              final left = (c.maxWidth - boardW) / 2;
              final top = (c.maxHeight - boardH) / 2;

              return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _MeadowPainter(t: _elapsed), size: Size.infinite),
                    // 棋盘底座
                    Positioned(
                      left: left,
                      top: top,
                      width: boardW,
                      height: boardH,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF7BC96F), Color(0xFF4A9B45)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (var i = 0; i < _count; i++)
                              _buildHole(
                                i,
                                cell,
                                Size(boardW, boardH),
                              ),
                            // 锤子跟随点击
                            if (_showHammer && _bonkT > 0)
                              Positioned(
                                left: _hammerX * boardW - cell * 0.28,
                                top: _hammerY * boardH - cell * 0.55 - (1 - _bonkT / 0.28) * cell * 0.15,
                                child: Opacity(
                                  opacity: (_bonkT / 0.28).clamp(0.0, 1.0),
                                  child: Transform.rotate(
                                    angle: -0.9 + (1 - _bonkT / 0.28) * 1.3,
                                    child: Image.asset(
                                      GameSprites.whackHammer,
                                      width: cell * 0.55,
                                      height: cell * 0.55,
                                      filterQuality: FilterQuality.high,
                                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                              ),
                            for (final s in _sparks)
                              Positioned(
                                left: s.x * boardW,
                                top: s.y * boardH,
                                child: Opacity(
                                  opacity: s.life.clamp(0.0, 1.0),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                                  ),
                                ),
                              ),
                            for (final f in _floats)
                              Positioned(
                                left: f.x * boardW - 40,
                                top: f.y * boardH,
                                child: Opacity(
                                  opacity: f.life.clamp(0.0, 1.0),
                                  child: Text(
                                    f.text,
                                    style: TextStyle(
                                      color: f.color,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      shadows: const [Shadow(color: Colors.white, blurRadius: 6)],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 8,
                      child: _Tip(
                        text: en
                            ? 'Mole +10 · Gold +50 · Miss / bomb = -♥'
                            : '地鼠+10 · 金色+50 · 跑掉/炸弹扣命',
                      ),
                    ),
                    if (_gameOver)
                      _OverPanel(
                        score: _progress.score,
                        best: _best,
                        stars: _ratingStars,
                        caught: _caught,
                        isEn: en,
                        onRetry: _restart,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHole(int i, double cell, Size board) {
    final h = _holes[i];
    final col = i % _cols;
    final row = i ~/ _cols;
    final holeSize = cell * 0.78;
    final moleSize = cell * 0.62;

    return Positioned(
      left: col * cell,
      top: row * cell,
      width: cell,
      height: cell,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _tapHole(i, d.localPosition, board),
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // 土堆
            Positioned(
              bottom: cell * 0.08,
              child: Image.asset(
                GameSprites.whackDirt,
                width: holeSize,
                height: holeSize * 0.55,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: holeSize,
                  height: holeSize * 0.35,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5A2B),
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
            ),
            // 洞口
            Positioned(
              bottom: cell * 0.06,
              child: Image.asset(
                GameSprites.whackHole,
                width: holeSize,
                height: holeSize * 0.55,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: holeSize * 0.85,
                  height: holeSize * 0.35,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3A2210),
                    borderRadius: BorderRadius.all(Radius.elliptical(80, 40)),
                  ),
                ),
              ),
            ),
            // 地鼠 / 炸弹（从洞里升起，底部裁剪）
            if (h.up)
              Positioned(
                bottom: cell * 0.22 + h.pop * cell * 0.28 - (h.hit ? cell * 0.12 : 0),
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: (0.35 + h.pop * 0.65).clamp(0.2, 1.0),
                    child: Opacity(
                      opacity: h.hit ? 0.55 : 1,
                      child: Transform.scale(
                        scaleX: h.hit ? 1.15 : 1,
                        scaleY: h.hit ? 0.7 : (0.85 + h.pop * 0.2),
                        child: h.kind == _Kind.bomb
                            ? GameSprites.img(GameSprites.bomb, size: moleSize * 0.9)
                            : Image.asset(
                                h.kind == _Kind.gold ? GameSprites.whackMoleGold : GameSprites.whackMole,
                                width: moleSize,
                                height: moleSize,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (_, __, ___) => GameSprites.img(GameSprites.whackMole, size: moleSize),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_bonkT > 0 && _bonkIndex == i && h.hit && h.kind != _Kind.bomb)
              Positioned(
                top: cell * 0.08,
                child: Opacity(
                  opacity: (_bonkT / 0.28).clamp(0.0, 1.0),
                  child: Icon(Icons.star_rounded, color: CamiColors.gold, size: cell * 0.28),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WhackHud extends StatelessWidget {
  const _WhackHud({
    required this.score,
    required this.combo,
    required this.lives,
    required this.activeHint,
    required this.isEn,
  });

  final int score;
  final int combo;
  final int lives;
  final int activeHint;
  final bool isEn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFE8F8EF), Color(0xFFFFF0F5)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CamiColors.line),
      ),
      child: Row(
        children: [
          _pill(isEn ? 'Score' : '得分', '$score'),
          const SizedBox(width: 8),
          if (combo > 1) ...[
            _pill(isEn ? 'Combo' : '连击', 'x$combo', hot: true),
            const SizedBox(width: 8),
          ],
          Text(
            isEn ? 'Up to $activeHint at once' : '同时最多 $activeHint 只',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CamiColors.ink.withValues(alpha: 0.65)),
          ),
          const Spacer(),
          for (var i = 0; i < 3; i++)
            Icon(
              i < lives ? Icons.favorite : Icons.favorite_border,
              size: 20,
              color: i < lives ? CamiColors.roseDeep : CamiColors.line,
            ),
        ],
      ),
    );
  }

  Widget _pill(String label, String value, {bool hot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hot ? CamiColors.roseDeep : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: hot ? CamiColors.roseDeep : CamiColors.line),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: hot ? Colors.white : CamiColors.ink),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _OverPanel extends StatelessWidget {
  const _OverPanel({
    required this.score,
    required this.best,
    required this.stars,
    required this.caught,
    required this.isEn,
    required this.onRetry,
  });

  final int score;
  final int best;
  final int stars;
  final int caught;
  final bool isEn;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: CamiColors.rose.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isEn ? 'Round over' : '本局结束', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Icon(
                      i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: CamiColors.gold,
                      size: 36,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isEn ? 'Score $score' : '得分 $score',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFFF6B9A)),
              ),
              Text(
                isEn ? 'Whacked $caught · Best $best' : '打中 $caught 只 · 最高 $best',
                style: TextStyle(color: CamiColors.ink.withValues(alpha: 0.65), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: CamiColors.roseDeep,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(isEn ? 'Play again' : '再玩一次', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeadowPainter extends CustomPainter {
  _MeadowPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        const [Color(0xFF9AD7FF), Color(0xFFEAF8E8), Color(0xFFC8ECA0)],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawRect(Offset.zero & size, sky);

    // soft hills
    final hill = Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.42, size.width * 0.5, size.height * 0.55)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.68, size.width, size.height * 0.5)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFF8FD18A).withValues(alpha: 0.7));

    final sun = Offset(size.width * 0.88, size.height * 0.14);
    canvas.drawCircle(
      sun,
      28,
      Paint()
        ..shader = ui.Gradient.radial(sun, 28, [
          const Color(0xFFFFF3A0),
          const Color(0xFFFFC85A).withValues(alpha: 0.1),
        ]),
    );
  }

  @override
  bool shouldRepaint(covariant _MeadowPainter oldDelegate) => oldDelegate.t != t;
}
