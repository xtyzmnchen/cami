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

/// 小公主跑酷 — 神庙逃亡 / 地铁跑酷式三赛道
/// · 左滑/右滑换道躲障碍 · 上滑跳跃 · 下滑滑铲
/// · 吃金币连击加分；撞障碍扣命；3 命结算再玩
/// · 透视赛道 + 视差背景，速度随路程加快
class RunnerGame extends StatefulWidget {
  const RunnerGame({super.key, required this.onScore});
  final ValueChanged<int> onScore;

  @override
  State<RunnerGame> createState() => _RunnerGameState();
}

enum _Kind { coin, box, tall, barrier }

class _Obj {
  _Obj({required this.lane, required this.z, required this.kind});
  int lane;
  double z;
  final _Kind kind;
  bool taken = false;
  /// 已判定过（躲开或撞上），避免同窗反复结算
  bool resolved = false;
}

class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.color);
  double x, y, vx, vy;
  final Color color;
  double life = 1;
}

class _Float {
  _Float(this.x, this.y, this.text, this.color);
  double x, y;
  final String text;
  final Color color;
  double life = 1;
}

class _RunnerGameState extends State<RunnerGame> with SingleTickerProviderStateMixin {
  static const _lanes = 3;
  static const _playerZ = 0.12;
  static const _farZ = 1.0;

  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  final _rng = Random();
  final _progress = GameProgress(lives: 3);
  final _objs = <_Obj>[];
  final _sparks = <_Spark>[];
  final _floats = <_Float>[];
  final _images = <String, ui.Image>{};

  /// 逻辑车道目标；显示用平滑插值
  var _lane = 1;
  var _laneX = 1.0;
  var _jumpY = 0.0;
  var _jumpVy = 0.0;
  /// 起跳后一段保护时间：滞空内一律可越过矮障
  var _jumpProtect = 0.0;
  var _sliding = false;
  var _slideT = 0.0;
  var _runPhase = 0.0;
  var _distance = 0.0;
  var _runTime = 0.0;
  var _coins = 0;
  var _best = 0;
  var _invuln = 0.0;
  var _hitFlash = 0.0;
  var _spawnZ = 1.15;
  var _distAcc = 0.0;
  var _gameOver = false;
  var _lastPraise = 0;
  var _booted = false;
  var _hudScore = 0;
  var _hudCoins = 0;
  var _hudLives = 3;
  var _hudLevel = 1;
  var _hudCombo = 0;
  var _lastReportedScore = -1;
  Offset? _panDelta;

  double get _speed => 0.42 + min(0.55, _distance * 0.0009) + _progress.level * 0.03;

  /// 0 开局轻松 → 1 后期更密：综合米数 / 得分 / 时间
  double get _difficulty {
    final byDist = (_distance / 800).clamp(0.0, 1.0);
    final byScore = (_progress.score / 350).clamp(0.0, 1.0);
    final byTime = (_runTime / 90).clamp(0.0, 1.0);
    return (byDist * 0.45 + byScore * 0.30 + byTime * 0.25).clamp(0.0, 1.0);
  }

  int get _ratingStars {
    if (_progress.score >= 400) return 3;
    if (_progress.score >= 200) return 2;
    if (_progress.score >= 80) return 1;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _seedCourse();
    _ticker = createTicker(_frame)..start();
    unawaited(_loadImages());
  }

  Future<void> _loadImages() async {
    const paths = [
      GameSprites.runnerHero,
      GameSprites.runnerHeroSlide,
      GameSprites.runnerCoin,
      GameSprites.runnerBox,
      GameSprites.runnerHedge,
      GameSprites.runnerBarrier,
    ];
    for (final path in paths) {
      try {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        _images[path] = frame.image;
      } catch (_) {}
    }
    if (mounted) _repaint.value++;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progress.isEn = Localizations.localeOf(context).languageCode == 'en';
    _booted = true;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    for (final img in _images.values) {
      img.dispose();
    }
    super.dispose();
  }

  void _seedCourse() {
    _objs.clear();
    // 开局疏一点，留给反应时间
    var z = 0.55;
    for (var i = 0; i < 4; i++) {
      z += 0.22 + _rng.nextDouble() * 0.08;
      _spawnOne(z, forceEasy: true);
    }
    _spawnZ = z;
  }

  void _restart() {
    _progress.lives = 3;
    _progress.score = 0;
    _progress.combo = 0;
    _progress.level = 1;
    _progress.stars = 0;
    _distance = 0;
    _runTime = 0;
    _coins = 0;
    _lane = 1;
    _laneX = 1;
    _jumpY = 0;
    _jumpVy = 0;
    _jumpProtect = 0;
    _sliding = false;
    _slideT = 0;
    _invuln = 0;
    _hitFlash = 0;
    _distAcc = 0;
    _gameOver = false;
    _lastPraise = 0;
    _sparks.clear();
    _floats.clear();
    _seedCourse();
    widget.onScore(0);
  }

  void _frame(Duration elapsed) {
    if (!_booted) {
      _last = elapsed;
      return;
    }
    final rawMs = elapsed.inMilliseconds - _last.inMilliseconds;
    _last = elapsed;
    if (rawMs <= 0) return;
    // 真实帧间隔，上限防卡顿跳变；不强制量化，更丝滑
    final dt = (rawMs / 1000.0).clamp(0.001, 0.033);
    if (!mounted) return;
    if (_gameOver) {
      _repaint.value++;
      return;
    }

    final wasOver = _gameOver;
    _tick(dt);
    // 只重绘画布，不重建 Widget 树（避免 Image 布局抖动）
    _repaint.value++;

    final hudDirty = _progress.score != _hudScore ||
        _coins != _hudCoins ||
        _progress.lives != _hudLives ||
        _progress.level != _hudLevel ||
        _progress.combo != _hudCombo ||
        _gameOver != wasOver;
    if (hudDirty) {
      _hudScore = _progress.score;
      _hudCoins = _coins;
      _hudLives = _progress.lives;
      _hudLevel = _progress.level;
      _hudCombo = _progress.combo;
      setState(() {});
    }
    if (_progress.score != _lastReportedScore) {
      _lastReportedScore = _progress.score;
      widget.onScore(_progress.score);
    }
  }

  void _tick(double dt) {
    // 帧率无关的指数平滑变道（丝滑跟手）
    final t = 1 - exp(-16 * dt);
    _laneX += (_lane - _laneX) * t;

    // 跳跃：抬高、滞空更久，方便越过矮障
    if (_jumpY > 0 || _jumpVy != 0) {
      _jumpVy += 16 * dt;
      _jumpY -= _jumpVy * dt;
      if (_jumpY > 0.85) {
        _jumpY = 0.85;
        if (_jumpVy < 0) _jumpVy = 0;
      }
      if (_jumpY <= 0) {
        _jumpY = 0;
        _jumpVy = 0;
      }
    }
    if (_jumpProtect > 0) _jumpProtect = max(0, _jumpProtect - dt);

    // 滑铲
    if (_sliding) {
      _slideT -= dt;
      if (_slideT <= 0) {
        _sliding = false;
        _slideT = 0;
      }
    }

    if (_invuln > 0) _invuln = max(0, _invuln - dt);
    if (_hitFlash > 0) _hitFlash = max(0, _hitFlash - dt);

    _runPhase += dt * (8 + _speed * 6);
    _runTime += dt;
    _distance += _speed * 60 * dt;

    final level = 1 + (_distance / 280).floor();
    if (level > _progress.level) {
      _progress.level = level;
      _floats.add(_Float(0.5, 0.42, _progress.t('加速！', 'Faster!'), CamiColors.roseDeep));
      HapticFeedback.mediumImpact();
    }

    // 移动障碍/金币朝玩家
    final spd = _speed;
    for (final o in List<_Obj>.of(_objs)) {
      o.z -= spd * dt;
    }

    _resolveHits();
    _objs.removeWhere((o) => o.z < -0.08 || o.taken);
    _spawn();

    // 路程分：跑得越远分越高
    if (!_gameOver) {
      _distAcc += _speed * 60 * dt;
      while (_distAcc >= 10) {
        _distAcc -= 10;
        _progress.score += 1;
        if (_progress.score > _best) _best = _progress.score;
      }
    }

    for (final s in _sparks) {
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vy += 0.6 * dt;
      s.life -= dt * 1.8;
    }
    _sparks.removeWhere((s) => s.life <= 0);
    for (final f in _floats) {
      f.y -= dt * 0.25;
      f.life -= dt * 1.2;
    }
    _floats.removeWhere((f) => f.life <= 0);

    if (_coins - _lastPraise >= 15) {
      _lastPraise = _coins;
      unawaited(Voice.say(_progress.isEn ? 'Awesome!' : '真棒！'));
    }
  }

  void _resolveHits() {
    for (final o in _objs) {
      if (o.taken || o.resolved) continue;
      // 接近玩家深度才判定
      if (o.z > _playerZ + 0.07 || o.z < _playerZ - 0.06) continue;
      final sameLane = (o.lane - _laneX).abs() < 0.45;
      if (!sameLane) continue;

      if (o.kind == _Kind.coin) {
        o.taken = true;
        o.resolved = true;
        _coins++;
        _progress.hitCombo();
        final bonus = 8 + min<int>(20, _progress.combo * 2);
        _progress.score += bonus;
        if (_progress.score > _best) _best = _progress.score;
        HapticFeedback.selectionClick();
        final p = _project(o.lane.toDouble(), o.z, jump: 0.08);
        _burst(p.$1, p.$2, CamiColors.gold);
        _floats.add(_Float(p.$1, p.$2 - 0.05, '+$bonus', CamiColors.amber));
        continue;
      }

      if (_invuln > 0) continue;

      // 起跳保护期内 / 滞空中：矮箱和石障都能跳过
      final jumping = _jumpProtect > 0 || _jumpY > 0.03 || _jumpVy < -0.2;
      final ducked = _sliding;

      var hit = false;
      if (o.kind == _Kind.box || o.kind == _Kind.barrier) {
        // 矮障：跳过 或 换道
        hit = !jumping;
      } else if (o.kind == _Kind.tall) {
        // 高篱：必须滑铲（或换道）
        hit = !ducked;
      }

      if (!hit) {
        // 成功躲过：障碍仍显示飞过，只结算一次
        o.resolved = true;
        _progress.score += 3;
        continue;
      }

      o.resolved = true;
      o.taken = true;
      _progress.loseLife();
      _progress.breakCombo();
      _invuln = 1.25;
      _hitFlash = 0.35;
      HapticFeedback.heavyImpact();
      final p = _project(_laneX, _playerZ, jump: _jumpY);
      _burst(p.$1, p.$2, CamiColors.roseDeep);
      _floats.add(
        _Float(
          p.$1,
          p.$2 - 0.08,
          o.kind == _Kind.tall
              ? _progress.t('下滑躲避！', 'Slide!')
              : _progress.t('跳起来！', 'Jump!'),
          CamiColors.roseDeep,
        ),
      );
      if (_progress.lives <= 0) {
        _gameOver = true;
        _progress.stars = _ratingStars;
      }
    }
  }

  /// 前方始终补到约 1.3 深度；密度随难度升高
  void _spawn() {
    var farthest = _objs.isEmpty ? 0.0 : _objs.map((o) => o.z).fold<double>(0, max);
    var guard = 0;
    while (farthest < 1.3 && guard++ < 12) {
      final z = farthest + _nextGap();
      _spawnOne(z);
      farthest = _objs.isEmpty ? z : _objs.map((o) => o.z).fold<double>(0, max);
      // 若本段是空档，也要把“游标”推过这段，否则会死循环卡在 farthest
      farthest = max(farthest, z);
      _spawnZ = farthest;
    }
  }

  double _nextGap() {
    final d = _difficulty;
    // 开局间距大（疏），后期逐渐加密
    final base = ui.lerpDouble(0.32, 0.12, d)!;
    final jitter = ui.lerpDouble(0.10, 0.04, d)!;
    return base + _rng.nextDouble() * jitter;
  }

  void _spawnOne(double z, {bool forceEasy = false}) {
    final d = forceEasy ? 0.0 : _difficulty;
    final lane = _rng.nextInt(_lanes);

    // 开局多留空档喘气；后期几乎每段都有内容
    final emptyChance = ui.lerpDouble(0.32, 0.05, d)!;
    if (!forceEasy && _rng.nextDouble() < emptyChance) return;

    final roll = _rng.nextDouble();
    // 开局偏金币，后期障碍占比升高
    final coinChance = ui.lerpDouble(0.58, 0.26, d)!;
    final boxChance = coinChance + ui.lerpDouble(0.18, 0.28, d)!;
    final tallChance = boxChance + ui.lerpDouble(0.12, 0.22, d)!;
    final barrierChance = tallChance + ui.lerpDouble(0.08, 0.16, d)!;

    if (roll < coinChance) {
      _objs.add(_Obj(lane: lane, z: z, kind: _Kind.coin));
      // 金币串也随难度增多
      final trail = ui.lerpDouble(0.15, 0.5, d)!;
      if (_rng.nextDouble() < trail) {
        _objs.add(_Obj(lane: lane, z: z + 0.06, kind: _Kind.coin));
      }
      if (_rng.nextDouble() < trail * 0.45) {
        _objs.add(_Obj(lane: lane, z: z + 0.12, kind: _Kind.coin));
      }
    } else if (roll < boxChance) {
      _objs.add(_Obj(lane: lane, z: z, kind: _Kind.box));
    } else if (roll < tallChance) {
      _objs.add(_Obj(lane: lane, z: z, kind: _Kind.tall));
    } else if (roll < barrierChance) {
      _objs.add(_Obj(lane: lane, z: z, kind: _Kind.barrier));
    } else {
      // 后期才更常见的双道错开障碍
      if (d < 0.35) {
        _objs.add(_Obj(lane: lane, z: z, kind: _Kind.box));
        return;
      }
      final other = (lane + 1 + _rng.nextInt(2)) % _lanes;
      _objs.add(_Obj(lane: lane, z: z, kind: _Kind.box));
      _objs.add(_Obj(lane: other, z: z + 0.1, kind: _rng.nextBool() ? _Kind.barrier : _Kind.tall));
    }
  }

  void _burst(double x, double y, Color c) {
    for (var i = 0; i < 8; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final sp = 0.3 + _rng.nextDouble() * 0.5;
      _sparks.add(_Spark(x, y, cos(a) * sp, sin(a) * sp - 0.2, c));
    }
  }

  /// 返回归一化屏幕坐标 (x,y) 与缩放。
  /// 镜头锁定在当前车道：角色永远在画面正中，换道时整条赛道横向滑动。
  (double, double, double) _project(double laneF, double z, {double jump = 0, double? cam}) {
    final camLane = cam ?? _laneX;
    final t = (z / _farZ).clamp(0.0, 1.0);
    final ease = t * t; // 远处更挤
    final scale = ui.lerpDouble(1.15, 0.18, ease)!;
    // 跳跃视觉抬升加大，近处几乎按完整 jump 抬高
    final y = ui.lerpDouble(0.78, 0.28, ease)! - jump.clamp(0.0, 0.9) * (1 - ease) * 0.62;
    final spread = ui.lerpDouble(0.30, 0.055, ease)!;
    final x = 0.5 + (laneF - camLane) * spread;
    return (x, y, scale);
  }

  void _jump() {
    if (_gameOver) return;
    if (_jumpY > 0.05) return;
    if (_sliding) {
      _sliding = false;
      _slideT = 0;
    }
    // 高跳 + 保护窗：同帧起跳就能越过矮障，滞空更明显
    _jumpVy = -11.0;
    _jumpY = 0.2;
    _jumpProtect = 0.75;
    HapticFeedback.lightImpact();
  }

  void _slide() {
    if (_gameOver) return;
    if (_jumpY > 0.1) return;
    _sliding = true;
    _slideT = 0.55;
    HapticFeedback.selectionClick();
  }

  void _moveLane(int dir) {
    if (_gameOver) return;
    final next = (_lane + dir).clamp(0, _lanes - 1);
    if (next == _lane) {
      HapticFeedback.lightImpact();
      return;
    }
    _lane = next;
    HapticFeedback.selectionClick();
  }

  void _onPanStart(DragStartDetails d) {
    _panDelta = Offset.zero;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _panDelta = (_panDelta ?? Offset.zero) + d.delta;
  }

  void _onPanEnd(DragEndDetails d) {
    final delta = _panDelta ?? Offset.zero;
    final v = d.velocity.pixelsPerSecond;
    // 优先用位移，辅以速度（更跟手）
    final dx = delta.dx.abs() > 18 ? delta.dx : v.dx * 0.08;
    final dy = delta.dy.abs() > 18 ? delta.dy : v.dy * 0.08;
    _panDelta = null;

    if (dx.abs() < 14 && dy.abs() < 14) {
      // 轻点 = 跳
      _jump();
      return;
    }
    // 明显上滑优先当跳跃（避免被轻微左右晃成换道）
    if (dy < -22 && dy.abs() >= dx.abs() * 0.85) {
      _jump();
      return;
    }
    if (dx.abs() > dy.abs()) {
      _moveLane(dx > 0 ? 1 : -1);
    } else if (dy < 0) {
      _jump();
    } else {
      _slide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final en = _progress.isEn;
    final inset = MediaQuery.paddingOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        inset.left + 8,
        inset.top + 64,
        inset.right + 8,
        inset.bottom + 4,
      ),
      child: Column(
        children: [
          _RunHud(
            score: _hudScore,
            coins: _hudCoins,
            distance: _distance,
            lives: _hudLives,
            level: _hudLevel,
            combo: _hudCombo,
            isEn: en,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 单层画布：每帧只 paint，不重建图片 Widget
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: _GamePainter(
                          repaint: _repaint,
                          images: _images,
                          objs: _objs,
                          sparks: _sparks,
                          floats: _floats,
                          laneX: () => _laneX,
                          lane: () => _lane,
                          jumpY: () => _jumpY,
                          sliding: () => _sliding,
                          runPhase: () => _runPhase,
                          distance: () => _distance,
                          hitFlash: () => _hitFlash,
                          invuln: () => _invuln,
                          playerZ: _playerZ,
                          farZ: _farZ,
                          project: _project,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: 8,
                      child: _Tip(
                        text: en
                            ? 'Swipe ←→ lane · ↑ jump · ↓ slide'
                            : '滑动：左右换道 · 上跳 · 下滑铲',
                      ),
                    ),
                    if (_gameOver)
                      _OverPanel(
                        score: _progress.score,
                        best: _best,
                        coins: _coins,
                        distance: _distance,
                        stars: _ratingStars,
                        isEn: en,
                        onRetry: () {
                          _restart();
                          _hudScore = 0;
                          _hudCoins = 0;
                          _hudLives = 3;
                          _hudLevel = 1;
                          _hudCombo = 0;
                          _lastReportedScore = -1;
                          setState(() {});
                          _repaint.value++;
                        },
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

/// 整局场景一笔画完，避免每帧 Positioned+Image 布局抖动。
class _GamePainter extends CustomPainter {
  _GamePainter({
    required Listenable repaint,
    required this.images,
    required this.objs,
    required this.sparks,
    required this.floats,
    required this.laneX,
    required this.lane,
    required this.jumpY,
    required this.sliding,
    required this.runPhase,
    required this.distance,
    required this.hitFlash,
    required this.invuln,
    required this.playerZ,
    required this.farZ,
    required this.project,
  }) : super(repaint: repaint);

  final Map<String, ui.Image> images;
  final List<_Obj> objs;
  final List<_Spark> sparks;
  final List<_Float> floats;
  final double Function() laneX;
  final int Function() lane;
  final double Function() jumpY;
  final bool Function() sliding;
  final double Function() runPhase;
  final double Function() distance;
  final double Function() hitFlash;
  final double Function() invuln;
  final double playerZ;
  final double farZ;
  final (double, double, double) Function(double laneF, double z, {double jump, double? cam}) project;

  final _imgPaint = Paint()..filterQuality = FilterQuality.medium;
  final _sparkPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final dist = distance();
    final phase = runPhase();
    final jy = jumpY();
    final duck = sliding();
    final lx = laneX();
    final cam = lx; // 镜头跟角色，角色始终在正中

    _paintTrack(canvas, size, dist, cam);

    final sorted = objs.where((o) => !o.taken && o.z > -0.05 && o.z < 1.2).toList()
      ..sort((a, b) => b.z.compareTo(a.z));

    for (final o in sorted) {
      final p = project(o.lane.toDouble(), o.z, jump: o.kind == _Kind.coin ? 0.08 : 0, cam: cam);
      final scale = p.$3;
      final bw = switch (o.kind) {
        _Kind.coin => 38.0 * scale,
        _Kind.box => 48.0 * scale,
        _Kind.tall => 52.0 * scale,
        _Kind.barrier => 56.0 * scale,
      };
      final bh = switch (o.kind) {
        _Kind.coin => bw,
        _Kind.box => 48.0 * scale,
        _Kind.tall => 78.0 * scale,
        _Kind.barrier => 40.0 * scale,
      };
      var cy = p.$2 * h - bh * (o.kind == _Kind.coin ? 0.55 : 0.88);
      if (o.kind == _Kind.coin) {
        cy += sin(phase * 2.2 + o.z * 8) * 2.5 * scale;
      }
      final cx = p.$1 * w - bw / 2;
      final asset = switch (o.kind) {
        _Kind.coin => GameSprites.runnerCoin,
        _Kind.box => GameSprites.runnerBox,
        _Kind.tall => GameSprites.runnerHedge,
        _Kind.barrier => GameSprites.runnerBarrier,
      };
      _drawSprite(canvas, asset, Rect.fromLTWH(cx, cy, bw, bh));
    }

    // 玩家永远画在画面正中（镜头已锁定）
    final pp = project(lx, playerZ, jump: jy, cam: cam);
    final bob = jy > 0 ? 0.0 : sin(phase) * 1.6;
    final pw = duck ? 64.0 : 58.0;
    final ph = duck ? 48.0 : 72.0;
    final px = pp.$1 * w - pw / 2;
    final py = pp.$2 * h - ph * 0.95 + bob;
    final blink = invuln() > 0 && (invuln() * 10).floor().isEven;

    // 影子贴地（不跟跳跃飞起来）
    final ground = project(lx, playerZ, jump: 0, cam: cam);
    final shadow = Paint()..color = Colors.black.withValues(alpha: blink ? 0.06 : 0.2);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(ground.$1 * w, ground.$2 * h + 4),
        width: pw * (0.55 + jy * 0.15),
        height: 10,
      ),
      shadow,
    );

    // 换道时轻微侧倾，表达惯性
    final lean = (lx - lane()) * 0.14;
    canvas.save();
    if (blink) {
      canvas.saveLayer(Rect.fromLTWH(px - 4, py - 4, pw + 8, ph + 8), Paint()..color = const Color(0x55FFFFFF));
    }
    canvas.translate(px + pw / 2, py + ph);
    canvas.rotate(lean);
    canvas.translate(-pw / 2, -ph);
    _drawSprite(
      canvas,
      duck ? GameSprites.runnerHeroSlide : GameSprites.runnerHero,
      Rect.fromLTWH(0, 0, pw, ph),
    );
    if (blink) canvas.restore();
    canvas.restore();

    for (final s in sparks) {
      if (s.life <= 0) continue;
      _sparkPaint.color = s.color.withValues(alpha: s.life.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(s.x * w, s.y * h), 3.5, _sparkPaint);
    }

    for (final f in floats) {
      if (f.life <= 0) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: f.text,
          style: TextStyle(
            color: f.color.withValues(alpha: f.life.clamp(0.0, 1.0)),
            fontWeight: FontWeight.w900,
            fontSize: 16,
            shadows: const [Shadow(color: Colors.white, blurRadius: 6)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(f.x * w - tp.width / 2, f.y * h));
    }

    final flash = hitFlash();
    if (flash > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = CamiColors.roseDeep.withValues(alpha: flash * 0.3));
    }
  }

  void _drawSprite(Canvas canvas, String asset, Rect dst) {
    final img = images[asset];
    if (img == null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(dst, const Radius.circular(8)),
        Paint()..color = const Color(0x55FFB7D5),
      );
      return;
    }
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    // contain
    final scale = min(dst.width / src.width, dst.height / src.height);
    final dw = src.width * scale;
    final dh = src.height * scale;
    final dx = dst.left + (dst.width - dw) / 2;
    final dy = dst.top + (dst.height - dh) / 2;
    canvas.drawImageRect(img, src, Rect.fromLTWH(dx, dy, dw, dh), _imgPaint);
  }

  void _paintTrack(Canvas canvas, Size size, double dist, double cam) {
    final w = size.width;
    final h = size.height;

    final sky = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, h * 0.55),
        const [Color(0xFF7EC8FF), Color(0xFFFFE6F2), Color(0xFFFFF5E8)],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(Offset.zero & size, sky);

    // 背景随镜头轻微平移
    final camShift = (1 - cam) * w * 0.06;
    final scroll = (dist * 0.12) % (w * 0.8);
    final hill = Paint()..color = const Color(0xFFFFB7D5).withValues(alpha: 0.55);
    for (var i = -1; i < 4; i++) {
      final x = i * w * 0.55 - scroll + camShift;
      final path = Path()
        ..moveTo(x, h * 0.42)
        ..quadraticBezierTo(x + w * 0.2, h * 0.22, x + w * 0.45, h * 0.42)
        ..lineTo(x, h * 0.42);
      canvas.drawPath(path, hill);
    }

    final castle = Paint()..color = const Color(0xFFD48BB0).withValues(alpha: 0.35);
    final cx = w * 0.72 - (dist * 0.035) % 40 + camShift;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx, h * 0.2, 36, 70), const Radius.circular(4)), castle);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx + 40, h * 0.26, 28, 58), const Radius.circular(4)), castle);
    canvas.drawCircle(Offset(cx + 18, h * 0.2), 14, castle);

    // 赛道随镜头横移：当前车道始终对准画面中线
    final horizon = Offset(w * 0.5, h * 0.28);
    const nearSpread = 0.30;
    const farSpread = 0.055;
    // 跑道左右缘在车道坐标 -0.5 ~ 2.5
    final bl = Offset(w * (0.5 + (-0.5 - cam) * nearSpread), h * 0.98);
    final br = Offset(w * (0.5 + (2.5 - cam) * nearSpread), h * 0.98);
    final fl = Offset(w * (0.5 + (-0.5 - cam) * farSpread), horizon.dy);
    final fr = Offset(w * (0.5 + (2.5 - cam) * farSpread), horizon.dy);
    final road = Path()
      ..moveTo(fl.dx, fl.dy)
      ..lineTo(fr.dx, fr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();
    canvas.drawPath(
      road,
      Paint()
        ..shader = ui.Gradient.linear(
          horizon,
          Offset(w * 0.5, h),
          const [Color(0xFFE8C4A8), Color(0xFFD4A574), Color(0xFFC48B5A)],
          const [0.0, 0.45, 1.0],
        ),
    );

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dashShift = (dist * 0.045) % 1.0;
    // 车道分隔线在 0.5 与 1.5
    for (final laneT in [0.5, 1.5]) {
      final nearX = w * (0.5 + (laneT - cam) * nearSpread);
      final farX = w * (0.5 + (laneT - cam) * farSpread);
      const dashN = 16;
      for (var i = 0; i < dashN; i++) {
        final a = (i + dashShift) / dashN;
        final b = (i + 0.4 + dashShift) / dashN;
        if (a >= 1) continue;
        final bClamped = b.clamp(0.0, 1.0);
        final p0 = Offset(ui.lerpDouble(farX, nearX, a)!, ui.lerpDouble(horizon.dy, h * 0.96, a)!);
        final p1 = Offset(ui.lerpDouble(farX, nearX, bClamped)!, ui.lerpDouble(horizon.dy, h * 0.96, bClamped)!);
        canvas.drawLine(p0, p1, linePaint);
      }
    }

    final grass = Paint()..color = const Color(0xFF6BB86A).withValues(alpha: 0.85);
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.55)
        ..lineTo(bl.dx, bl.dy)
        ..lineTo(0, h)
        ..close(),
      grass,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w, h * 0.55)
        ..lineTo(br.dx, br.dy)
        ..lineTo(w, h)
        ..close(),
      grass,
    );
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => false;
}

class _RunHud extends StatelessWidget {
  const _RunHud({
    required this.score,
    required this.coins,
    required this.distance,
    required this.lives,
    required this.level,
    required this.combo,
    required this.isEn,
  });

  final int score;
  final int coins;
  final double distance;
  final int lives;
  final int level;
  final int combo;
  final bool isEn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF7FB), Color(0xFFE8F4FF)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CamiColors.line),
      ),
      child: Row(
        children: [
          _chip(isEn ? 'Lv$level' : '第$level关'),
          const SizedBox(width: 6),
          _chip(isEn ? 'Score $score' : '得分 $score'),
          const SizedBox(width: 6),
          Icon(Icons.star_rounded, size: 16, color: CamiColors.gold),
          Text(' $coins', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(width: 8),
          Text(
            isEn ? '${distance.toInt()}m' : '${distance.toInt()} 米',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: CamiColors.muted),
          ),
          const Spacer(),
          if (combo > 2) ...[
            _chip('x$combo', hot: true),
            const SizedBox(width: 6),
          ],
          for (var i = 0; i < 3; i++)
            Icon(
              i < lives ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: i < lives ? CamiColors.roseDeep : CamiColors.line,
            ),
        ],
      ),
    );
  }

  Widget _chip(String text, {bool hot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hot ? CamiColors.roseDeep : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: hot ? CamiColors.roseDeep : CamiColors.line),
      ),
      child: Text(
        text,
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
    required this.coins,
    required this.distance,
    required this.stars,
    required this.isEn,
    required this.onRetry,
  });

  final int score;
  final int best;
  final int coins;
  final double distance;
  final int stars;
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
              Text(isEn ? 'Run over!' : '跑完啦！', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
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
              const SizedBox(height: 8),
              Text(
                isEn ? 'Score $score · Best $best' : '得分 $score · 最佳 $best',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                isEn
                    ? 'Coins $coins · ${distance.toInt()}m'
                    : '金币 $coins · ${distance.toInt()} 米',
                style: const TextStyle(fontWeight: FontWeight.w700, color: CamiColors.muted),
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
                  child: Text(isEn ? 'Run again' : '再跑一次', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
