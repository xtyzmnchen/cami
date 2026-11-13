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

/// 接水果 — 常见街机规则（适合二年级）：
/// · 水果 +10，星星 +50；连击 5 送 +20
/// · 漏接水果：只断连击，不扣命
/// · 接到炸弹：扣 1 命；3 命用完 → 结算，再玩
/// · 「难度」每 100 分升 1 级，只负责加快下落（不是随便重置）
class CatchFruitGame extends StatefulWidget {
  const CatchFruitGame({super.key, required this.onScore});
  final ValueChanged<int> onScore;

  @override
  State<CatchFruitGame> createState() => _CatchFruitGameState();
}

class _Drop {
  _Drop({
    required this.x,
    required this.y,
    required this.asset,
    required this.bomb,
    required this.bonus,
    required this.speed,
    required this.size,
    required this.spin,
    required this.spinSpeed,
    required this.sway,
    required this.swayPhase,
  });

  double x;
  double y;
  final String asset;
  final bool bomb;
  final bool bonus;
  double speed;
  final double size;
  double spin;
  final double spinSpeed;
  final double sway;
  double swayPhase;
  double scale = 1;
  bool sinking = false;
  double sinkT = 0;
}

class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.color);
  double x;
  double y;
  double vx;
  double vy;
  final Color color;
  double life = 1;
}

class _FloatText {
  _FloatText(this.x, this.y, this.text, this.color);
  double x;
  double y;
  final String text;
  final Color color;
  double life = 1;
}

class _BasketFruit {
  _BasketFruit(this.asset, this.ox, this.oy, this.size, this.spin);
  final String asset;
  final double ox;
  final double oy;
  final double size;
  final double spin;
}

class _CatchFruitGameState extends State<CatchFruitGame> with SingleTickerProviderStateMixin {
  final _rng = Random();
  final _progress = GameProgress(lives: 3);
  final _drops = <_Drop>[];
  final _sparks = <_Spark>[];
  final _floats = <_FloatText>[];
  final _basketFruits = <_BasketFruit>[];
  var _basket = 0.5;
  var _basketV = 0.0;
  var _basketTilt = 0.0;
  var _caughtTotal = 0;
  var _cloudShift = 0.0;
  var _groundPulse = 0.0;
  var _lastPraiseAt = 0;
  var _bestScore = 0;
  var _gameOver = false;
  var _levelFlash = 0.0;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Size _size = Size.zero;
  double _spawnAcc = 0;

  /// 每 100 分升一级难度
  static const _ptsPerLevel = 100;

  double get _fallBase {
    final lv = (_progress.level - 1).clamp(0, 8);
    return min(0.45, 0.16 + lv * 0.032 + _progress.score * 0.0004);
  }

  double get _spawnPerSec {
    final lv = (_progress.level - 1).clamp(0, 10);
    return min(1.85, 0.7 + lv * 0.09);
  }

  double get _basketHalf => max(0.058, 0.08 - (_progress.level - 1) * 0.002);

  /// 本难度进度 0~1
  double get _levelProgress {
    final inLevel = _progress.score % _ptsPerLevel;
    return inLevel / _ptsPerLevel;
  }

  int get _ratingStars {
    final s = _progress.score;
    if (s >= 500) return 3;
    if (s >= 200) return 2;
    if (s >= 50) return 1;
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
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_size == Size.zero) return;
    final dt = _last == Duration.zero
        ? 1 / 60
        : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _step(dt);
  }

  void _step(double dt) {
    if (_gameOver) {
      setState(() {
        _groundPulse += dt;
        for (final s in _sparks) {
          s.x += s.vx * dt;
          s.y += s.vy * dt;
          s.vy += 1.8 * dt;
          s.life -= dt * 2.2;
        }
        _sparks.removeWhere((s) => s.life <= 0);
      });
      return;
    }

    setState(() {
      _cloudShift += dt * 12;
      _groundPulse += dt;
      if (_levelFlash > 0) _levelFlash = max(0, _levelFlash - dt);

      _spawnAcc += _spawnPerSec * dt;
      while (_spawnAcc >= 1) {
        _spawnAcc -= 1;
        _spawnOne();
      }

      _basketTilt += (_basketV * 14 - _basketTilt) * min(1, dt * 10);
      _basketV *= pow(0.05, dt).toDouble();

      const mouthY = 0.82;
      final left = _basket - _basketHalf * 0.92;
      final right = _basket + _basketHalf * 0.92;

      for (final d in _drops) {
        if (d.sinking) {
          d.sinkT = min(1, d.sinkT + dt * 3.6);
          final t = Curves.easeInCubic.transform(d.sinkT);
          d.x += (_basket - d.x) * min(1, dt * 14);
          d.y = ui.lerpDouble(d.y, mouthY + 0.06, t)!;
          d.scale = ui.lerpDouble(1, 0.42, t)!;
          d.spin += dt * 2;
          continue;
        }

        d.y += d.speed * dt;
        d.spin += d.spinSpeed * dt;
        d.swayPhase += dt * 2.4;
        d.x += sin(d.swayPhase) * d.sway * dt;
        d.x = d.x.clamp(0.06, 0.94);
        if (d.bomb) d.scale = 1 + sin(_groundPulse * 8) * 0.06;

        if (!d.bomb && d.y >= mouthY - 0.02 && d.y < mouthY + 0.08) {
          if (d.x >= left && d.x <= right) {
            _catchFruit(d, mouthY);
          }
        }
      }

      _drops.removeWhere((d) {
        if (d.sinking && d.sinkT >= 1) {
          if (!d.bomb) _stashInBasket(d.asset);
          return true;
        }
        return false;
      });

      for (final s in _sparks) {
        s.x += s.vx * dt;
        s.y += s.vy * dt;
        s.vy += 1.8 * dt;
        s.life -= dt * 2.2;
      }
      _sparks.removeWhere((s) => s.life <= 0);

      for (final f in _floats) {
        f.y -= 0.35 * dt;
        f.life -= dt * 1.1;
      }
      _floats.removeWhere((f) => f.life <= 0);

      // 先收集再删除，避免 removeWhere 过程中 clear 导致 ConcurrentModification
      final toRemove = <_Drop>[];
      var ended = false;
      for (final d in _drops) {
        if (d.sinking) continue;
        if (d.bomb && d.y >= mouthY - 0.01 && d.y < mouthY + 0.1) {
          if (d.x >= left && d.x <= right) {
            _burst(d.x, d.y, true);
            unawaited(bombHitFeedback());
            _progress.loseLife(haptic: false);
            _floats.add(
              _FloatText(d.x, d.y, _progress.t('碰到炸弹！', 'Bomb!'), const Color(0xFFFF4D6D)),
            );
            toRemove.add(d);
            if (_progress.lives <= 0) ended = true;
            continue;
          }
        }
        if (d.y >= 1.08) {
          if (!d.bomb) {
            _progress.breakCombo();
            _floats.add(
              _FloatText(
                d.x.clamp(0.15, 0.85),
                0.88,
                _progress.t('漏掉了', 'Miss'),
                const Color(0xFF8A6A74),
              ),
            );
          }
          toRemove.add(d);
        }
      }
      for (final d in toRemove) {
        _drops.remove(d);
      }
      if (ended) _endRun();
    });
  }

  void _catchFruit(_Drop d, double mouthY) {
    d.sinking = true;
    d.sinkT = 0;
    HapticFeedback.lightImpact();
    _progress.hitCombo();
    _caughtTotal++;

    var gain = d.bonus ? 50 : 10;
    // 连击加成
    if (_progress.combo >= 5) {
      gain += 20;
    } else if (_progress.combo >= 3) {
      gain = (gain * 1.5).round();
    }

    final prevLevel = _progress.level;
    _progress.score += gain;
    if (_progress.score > _bestScore) _bestScore = _progress.score;
    widget.onScore(_progress.score);

    // 每 100 分升难度
    final newLevel = 1 + _progress.score ~/ _ptsPerLevel;
    if (newLevel > prevLevel) {
      _progress.level = newLevel;
      _progress.stars = (_progress.level - 1).clamp(0, 99);
      _levelFlash = 2.2;
      HapticFeedback.mediumImpact();
      _speakLevelUp();
      _floats.add(
        _FloatText(
          0.5,
          0.35,
          _progress.t('难度提升！下落更快', 'Harder! Faster falls'),
          const Color(0xFFFF8A00),
        ),
      );
    }

    _maybePraise();

    final label = d.bonus
        ? '+$gain ★'
        : (_progress.combo >= 3 ? 'x${_progress.combo} +$gain' : '+$gain');
    _floats.add(
      _FloatText(
        d.x,
        mouthY - 0.04,
        label,
        d.bonus ? const Color(0xFFFFB800) : const Color(0xFFFF6B9A),
      ),
    );
  }

  void _endRun() {
    if (_gameOver) return;
    _gameOver = true;
    _drops.clear();
    _spawnAcc = 0;
    final stars = _ratingStars;
    _progress.stars = stars;
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
    // 先置结束态打断当前帧逻辑，再重置，避免与 ticker 抢改同一列表
    _gameOver = true;
    _drops.clear();
    _sparks.clear();
    _floats.clear();
    if (!mounted) return;
    setState(() {
      _gameOver = false;
      _progress.score = 0;
      _progress.level = 1;
      _progress.lives = 3;
      _progress.combo = 0;
      _progress.stars = 0;
      _caughtTotal = 0;
      _lastPraiseAt = 0;
      _levelFlash = 0;
      _basketFruits.clear();
      _spawnAcc = 0;
      _basket = 0.5;
      _basketV = 0;
      _basketTilt = 0;
      _last = Duration.zero;
    });
    widget.onScore(0);
  }

  void _maybePraise() {
    const step = 50;
    if (_progress.score < step) return;
    final mark = (_progress.score ~/ step) * step;
    if (mark <= _lastPraiseAt) return;
    _lastPraiseAt = mark;
    final line = _praiseForScore(mark);
    unawaited(_progress.isEn ? Voice.sayEn(line.$2) : Voice.say(line.$1));
  }

  (String, String) _praiseForScore(int score) {
    if (score < 100) return ('起得很好，加油！', 'Nice start!');
    if (score < 150) return ('你太棒了！', "You're awesome!");
    if (score < 200) return ('接得真准！', 'Great catching!');
    if (score < 250) return ('继续努力！', 'Keep going!');
    if (score < 300) return ('小高手出现啦！', "You're a little pro!");
    if (score < 400) return ('越来越厉害了！', "You're getting better!");
    if (score < 500) return ('超级厉害！', 'Super amazing!');
    return ('冠军就是你！', "You're the champion!");
  }

  void _speakLevelUp() {
    unawaited(
      _progress.isEn
          ? Voice.sayEn('Level up! A bit faster!')
          : Voice.say('难度提升，水果更快啦！'),
    );
  }

  void _stashInBasket(String asset) {
    _basketFruits.add(
      _BasketFruit(
        asset,
        (_rng.nextDouble() - 0.5) * 0.55,
        -0.08 - _rng.nextDouble() * 0.22,
        0.28 + _rng.nextDouble() * 0.1,
        (_rng.nextDouble() - 0.5) * 0.6,
      ),
    );
    while (_basketFruits.length > 7) {
      _basketFruits.removeAt(0);
    }
  }

  void _spawnOne() {
    if (_gameOver) return;
    // 难度越高炸弹略多，但不会连续刷
    final bombChance = min(0.14, 0.03 + _progress.level * 0.012);
    final lastBomb = _drops.isNotEmpty && _drops.last.bomb;
    final bomb = !lastBomb && _rng.nextDouble() < bombChance;
    final bonus = !bomb && _rng.nextDouble() < 0.08;
    final size = bomb
        ? 40.0 + _rng.nextDouble() * 6
        : bonus
            ? 38.0 + _rng.nextDouble() * 6
            : 34.0 + _rng.nextDouble() * 12;
    _drops.add(
      _Drop(
        x: 0.08 + _rng.nextDouble() * 0.84,
        y: -0.12 - _rng.nextDouble() * 0.08,
        asset: bomb
            ? GameSprites.bomb
            : bonus
                ? GameSprites.star
                : GameSprites.fruits[_rng.nextInt(GameSprites.fruits.length)],
        bomb: bomb,
        bonus: bonus,
        speed: _fallBase * (0.8 + _rng.nextDouble() * 0.45),
        size: size,
        spin: _rng.nextDouble() * pi * 2,
        spinSpeed: (_rng.nextDouble() - 0.5) * 3.5,
        sway: 0.015 + _rng.nextDouble() * 0.035,
        swayPhase: _rng.nextDouble() * pi * 2,
      ),
    );
  }

  void _burst(double x, double y, bool bomb) {
    final base = bomb ? const Color(0xFFFF5A6A) : const Color(0xFFFFB4D0);
    for (var i = 0; i < (bomb ? 14 : 8); i++) {
      final a = _rng.nextDouble() * pi * 2;
      final sp = 0.25 + _rng.nextDouble() * 0.55;
      _sparks.add(
        _Spark(x, y, cos(a) * sp, sin(a) * sp - 0.2, Color.lerp(base, Colors.white, _rng.nextDouble() * 0.45)!),
      );
    }
  }

  void _moveBasket(double nx) {
    if (_gameOver) return;
    final next = nx.clamp(_basketHalf, 1 - _basketHalf);
    _basketV = (next - _basket) * 8;
    _basket = next;
  }

  @override
  void dispose() {
    unawaited(Voice.stop());
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final en = _progress.isEn;
    return Column(
      children: [
        _CatchHud(
          score: _progress.score,
          level: _progress.level,
          levelProgress: _levelProgress,
          combo: _progress.combo,
          lives: _progress.lives,
          isEn: en,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              _size = Size(c.maxWidth, c.maxHeight);
              final bw = c.maxWidth * _basketHalf * 2;
              final bh = max(42.0, bw * 0.62);
              return ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) {
                    setState(() => _moveBasket(_basket + d.delta.dx / c.maxWidth));
                  },
                  onTapDown: (d) {
                    setState(() => _moveBasket(d.localPosition.dx / c.maxWidth));
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _CatchScenePainter(cloudShift: _cloudShift, pulse: _groundPulse),
                        size: Size.infinite,
                      ),
                      for (final d in _drops.where((e) => !e.sinking))
                        Positioned(
                          left: d.x * c.maxWidth - d.size / 2,
                          top: d.y * c.maxHeight - d.size / 2,
                          child: Transform.rotate(
                            angle: d.spin,
                            child: Transform.scale(
                              scale: d.scale,
                              child: _FruitOrb(asset: d.asset, size: d.size, bomb: d.bomb, bonus: d.bonus),
                            ),
                          ),
                        ),
                      for (final s in _sparks)
                        Positioned(
                          left: s.x * c.maxWidth,
                          top: s.y * c.maxHeight,
                          child: Opacity(
                            opacity: s.life.clamp(0.0, 1.0),
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: s.color,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: s.color.withValues(alpha: 0.55), blurRadius: 6)],
                              ),
                            ),
                          ),
                        ),
                      for (final f in _floats)
                        Positioned(
                          left: f.x * c.maxWidth - 36,
                          top: f.y * c.maxHeight,
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
                      Positioned(
                        left: _basket * c.maxWidth - bw / 2,
                        bottom: c.maxHeight * 0.04,
                        child: Transform.rotate(
                          angle: _basketTilt.clamp(-0.25, 0.25),
                          child: _BasketView(width: bw, height: bh, fruits: _basketFruits),
                        ),
                      ),
                      for (final d in _drops.where((e) => e.sinking))
                        Positioned(
                          left: d.x * c.maxWidth - d.size * d.scale / 2,
                          top: d.y * c.maxHeight - d.size * d.scale / 2,
                          child: Transform.rotate(
                            angle: d.spin,
                            child: Opacity(
                              opacity: (1 - d.sinkT * 0.35).clamp(0.4, 1),
                              child: _FruitOrb(
                                asset: d.asset,
                                size: d.size * d.scale,
                                bomb: false,
                                bonus: d.bonus,
                              ),
                            ),
                          ),
                        ),
                      if (_levelFlash > 0)
                        Positioned(
                          top: c.maxHeight * 0.28,
                          left: 0,
                          right: 0,
                          child: Opacity(
                            opacity: (_levelFlash / 2.2).clamp(0.0, 1.0),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(color: CamiColors.rose.withValues(alpha: 0.3), blurRadius: 12),
                                  ],
                                ),
                                child: Text(
                                  en ? 'Difficulty ${_progress.level}' : '难度 ${_progress.level}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                    color: Color(0xFFFF6B00),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 12,
                        bottom: 10,
                        child: _TipChip(
                          text: en
                              ? 'Fruit +10 · Star +50 · Avoid bombs'
                              : '水果+10 · 星星+50 · 躲开炸弹',
                        ),
                      ),
                      if (_gameOver) _GameOverPanel(
                        score: _progress.score,
                        best: _bestScore,
                        stars: _ratingStars,
                        caught: _caughtTotal,
                        isEn: en,
                        onRetry: _restart,
                      ),
                    ],
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

class _CatchHud extends StatelessWidget {
  const _CatchHud({
    required this.score,
    required this.level,
    required this.levelProgress,
    required this.combo,
    required this.lives,
    required this.isEn,
  });

  final int score;
  final int level;
  final double levelProgress;
  final int combo;
  final int lives;
  final bool isEn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF7FA), Color(0xFFFFE8F1)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CamiColors.line),
      ),
      child: Row(
        children: [
          _pill(isEn ? 'Score' : '得分', '$score'),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn ? 'Difficulty $level  (faster falls)' : '难度 $level  （分数越高下落越快）',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: levelProgress.clamp(0.0, 1.0),
                    minHeight: 7,
                    color: const Color(0xFFFF8A00),
                    backgroundColor: CamiColors.blush,
                  ),
                ),
              ],
            ),
          ),
          if (combo > 1) ...[
            const SizedBox(width: 8),
            _pill(isEn ? 'Combo' : '连击', 'x$combo', hot: true),
          ],
          const SizedBox(width: 8),
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: hot ? Colors.white : CamiColors.ink,
        ),
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  const _TipChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _GameOverPanel extends StatelessWidget {
  const _GameOverPanel({
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
              BoxShadow(color: CamiColors.rose.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEn ? 'Round over' : '本局结束',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 12),
              Text(
                isEn ? 'Score $score' : '得分 $score',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFFF6B9A)),
              ),
              const SizedBox(height: 4),
              Text(
                isEn
                    ? 'Caught $caught · Best $best'
                    : '接住 $caught 个 · 最高 $best',
                style: TextStyle(color: CamiColors.ink.withValues(alpha: 0.65), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: CamiColors.roseDeep,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    isEn ? 'Play again' : '再玩一次',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FruitOrb extends StatelessWidget {
  const _FruitOrb({
    required this.asset,
    required this.size,
    required this.bomb,
    this.bonus = false,
  });
  final String asset;
  final double size;
  final bool bomb;
  final bool bonus;

  @override
  Widget build(BuildContext context) {
    final glow = bomb
        ? const Color(0xFFFF4D6D)
        : bonus
            ? const Color(0xFFFFB800)
            : CamiColors.rose;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(0, 4),
            child: Container(
              width: size * 0.7,
              height: size * 0.25,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(40),
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: glow.withValues(alpha: 0.35), blurRadius: bomb || bonus ? 14 : 8),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: bomb ? const Color(0xFF444444) : const Color(0xFFFFE4EF),
                ),
              ),
            ),
          ),
          Positioned(
            left: size * 0.18,
            top: size * 0.14,
            child: Container(
              width: size * 0.26,
              height: size * 0.16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.5),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BasketView extends StatelessWidget {
  const _BasketView({
    required this.width,
    required this.height,
    required this.fruits,
  });
  final double width;
  final double height;
  final List<_BasketFruit> fruits;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height * 1.35,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: width * 0.85,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF8FAB).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      GameSprites.basket,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFFFC4D8)),
                    ),
                    ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          height: height * 0.72,
                          width: width,
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              for (final f in fruits)
                                Positioned(
                                  left: width * (0.5 + f.ox * 0.5) - (width * f.size) / 2,
                                  top: height * (0.35 + f.oy),
                                  child: Transform.rotate(
                                    angle: f.spin,
                                    child: ClipOval(
                                      child: Image.asset(
                                        f.asset,
                                        width: width * f.size,
                                        height: width * f.size,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.22),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatchScenePainter extends CustomPainter {
  _CatchScenePainter({required this.cloudShift, required this.pulse});
  final double cloudShift;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        const [
          Color(0xFF9AD7FF),
          Color(0xFFE8F7FF),
          Color(0xFFFFF0F6),
          Color(0xFFFFD6E7),
        ],
        const [0.0, 0.35, 0.72, 1.0],
      );
    canvas.drawRect(Offset.zero & size, sky);

    final hill = Path()
      ..moveTo(0, size.height * 0.62)
      ..quadraticBezierTo(size.width * 0.22, size.height * 0.48, size.width * 0.42, size.height * 0.58)
      ..quadraticBezierTo(size.width * 0.62, size.height * 0.7, size.width * 0.82, size.height * 0.55)
      ..quadraticBezierTo(size.width * 0.92, size.height * 0.5, size.width, size.height * 0.58)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFFB8E8C8).withValues(alpha: 0.55));

    final grassTop = size.height * 0.78;
    final grass = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, grassTop),
        Offset(0, size.height),
        const [Color(0xFF7BC96F), Color(0xFF3D8B4A)],
        const [0.0, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, grassTop, size.width, size.height - grassTop), grass);

    final wave = Paint()..color = Colors.white.withValues(alpha: 0.12 + sin(pulse * 2) * 0.03);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.5, grassTop + 8), width: size.width * 1.1, height: 28),
      wave,
    );

    void cloud(double x, double y, double s, double a) {
      final p = Paint()..color = Colors.white.withValues(alpha: a);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 70 * s, height: 28 * s), p);
      canvas.drawOval(Rect.fromCenter(center: Offset(x - 22 * s, y + 4 * s), width: 44 * s, height: 22 * s), p);
      canvas.drawOval(Rect.fromCenter(center: Offset(x + 24 * s, y + 2 * s), width: 50 * s, height: 24 * s), p);
    }

    final w = size.width;
    cloud((cloudShift * 0.35) % (w + 120) - 60, size.height * 0.14, 1.1, 0.55);
    cloud((cloudShift * 0.22 + w * 0.45) % (w + 140) - 70, size.height * 0.22, 0.85, 0.4);
    cloud((cloudShift * 0.18 + w * 0.75) % (w + 100) - 50, size.height * 0.11, 0.7, 0.35);

    final sunC = Offset(size.width * 0.88, size.height * 0.16);
    canvas.drawCircle(
      sunC,
      34,
      Paint()
        ..shader = ui.Gradient.radial(
          sunC,
          34,
          [const Color(0xFFFFF3A0), const Color(0xFFFFC85A).withValues(alpha: 0.12)],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _CatchScenePainter oldDelegate) =>
      oldDelegate.cloudShift != cloudShift || oldDelegate.pulse != pulse;
}
