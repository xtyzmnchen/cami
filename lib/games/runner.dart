import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'game_kit.dart';
import 'sprites.dart';

class RunnerGame extends StatefulWidget {
  const RunnerGame({super.key, required this.onScore});
  final ValueChanged<int> onScore;

  @override
  State<RunnerGame> createState() => _RunnerGameState();
}

enum _Kind { box, tall, coin }

class _Obj {
  _Obj(this.x, this.kind);
  double x;
  final _Kind kind;
  bool taken = false;
}

class _RunnerGameState extends State<RunnerGame> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final _rng = Random();
  final _progress = GameProgress(lives: 3);
  final _objs = <_Obj>[];
  var _y = 0.0;
  var _vy = 0.0;
  var _distance = 0.0;
  var _ducking = false;
  var _groundY = 0.0;
  var _nextSpawn = 280.0;
  var _cleared = 0;

  double get _speed => 4.4 + _progress.level * 0.55;
  int get _need => 8 + _progress.level * 3;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progress.isEn = Localizations.localeOf(context).languageCode == 'en';
  }

  @override
  void initState() {
    super.initState();
    _objs.addAll([_Obj(420, _Kind.box), _Obj(620, _Kind.coin), _Obj(780, _Kind.tall)]);
    _ticker = createTicker(_frame)..start();
  }

  void _frame(Duration elapsed) {
    final raw = elapsed.inMilliseconds - _last.inMilliseconds;
    _last = elapsed;
    final dt = (_last == Duration.zero || raw <= 0 ? 16 : raw.clamp(8, 34)) / 16.0;
    if (!mounted || _progress.lives <= 0) return;
    setState(() {
      _progress.clearBannerIfNeeded();
      _vy += 0.85 * dt;
      _y = min(0, _y + _vy * dt);
      if (_y >= -0.5) {
        _y = 0;
        _vy = 0;
      }
      _distance += _speed * dt;
      _groundY = sin(_distance / 40) * 1.5;

      var resetCourse = false;
      // 先拷贝再遍历，避免中途 clear/remove 触发 ConcurrentModificationError
      for (final o in List<_Obj>.of(_objs)) {
        o.x -= _speed * dt;
        const playerX = 64.0;
        const playerW = 36.0;
        final playerBottom = 28 - _y;
        final playerTop = playerBottom + (_ducking ? 22 : 36);
        if (o.kind == _Kind.coin) {
          const coinBottom = 58.0;
          const coinTop = coinBottom + 24;
          final overlapX = o.x < playerX + playerW && o.x + 22 > playerX;
          final overlapY = playerTop > coinBottom && playerBottom < coinTop;
          if (!o.taken && overlapX && overlapY) {
            o.taken = true;
            _progress.hitCombo();
            _progress.score += 2;
            widget.onScore(_progress.score);
            HapticFeedback.selectionClick();
          }
        } else {
          // tall: must duck; box: must jump
          final realHit = o.kind == _Kind.box
              ? (o.x < playerX + playerW - 6 && o.x + 22 > playerX + 6 && _y > -26)
              : (o.x < playerX + playerW - 6 && o.x + 22 > playerX + 6 && !_ducking && _y > -40);
          if (realHit && !o.taken) {
            o.taken = true;
            o.x = -80;
            _progress.loseLife();
            _progress.showBanner(o.kind == _Kind.tall ? _progress.t('要低头躲！', 'Duck!') : _progress.t('要跳起来！', 'Jump!'));
            if (_progress.lives <= 0) {
              _progress.lives = 3;
              _progress.level = max(1, _progress.level - 1);
              _cleared = 0;
              resetCourse = true;
              _nextSpawn = 300;
            }
          } else if (!o.taken && o.x < playerX - 10) {
            o.taken = true;
            _cleared++;
            _progress.score++;
            widget.onScore(_progress.score);
            if (_cleared >= _need) {
              _cleared = 0;
              _progress.levelUp(onScore: widget.onScore, label: _progress.t('第 ${_progress.level} 关！跑更快了', 'Level ${_progress.level}! Run faster'));
            }
          }
        }
      }
      if (resetCourse) {
        _objs
          ..clear()
          ..addAll([_Obj(420, _Kind.box), _Obj(620, _Kind.coin), _Obj(780, _Kind.tall)]);
      } else {
        _objs.removeWhere((o) => o.x < -40 || (o.kind == _Kind.coin && o.taken));
        if (_objs.isEmpty || _objs.last.x < _nextSpawn) {
          final gap = 160 + _rng.nextDouble() * (140 - min(60, _progress.level * 8));
          final roll = _rng.nextDouble();
          final kind = roll < 0.28
              ? _Kind.coin
              : roll < 0.62
                  ? _Kind.box
                  : _Kind.tall;
          _objs.add(_Obj((_objs.isEmpty ? 360.0 : _objs.last.x) + gap, kind));
          _nextSpawn = 220 + _rng.nextDouble() * 80;
        }
      }
    });
  }

  void _jump() {
    if (_y == 0 && !_ducking) {
      _vy = -13.2 - min(2.0, _progress.level * 0.1);
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      progress: _progress,
      hint: _progress.t('点按跳跃 · 按住低头躲高障碍 · 接星星加分', 'Tap jump · hold to duck · grab stars'),
      child: GameStage(
        colors: const [Color(0xFFDFF6FF), Color(0xFFFFE8F1)],
        child: Listener(
          onPointerDown: (_) => _jump(),
          onPointerMove: (e) {
            // hold near bottom to duck
            if (e.localPosition.dy > 120) setState(() => _ducking = true);
          },
          onPointerUp: (_) => setState(() => _ducking = false),
          child: LayoutBuilder(
            builder: (context, box) {
              return Stack(
                children: [
                  // hills
                  Positioned(
                    left: -((_distance * 0.3) % 200),
                    bottom: 70,
                    child: Row(
                      children: List.generate(
                        8,
                        (i) => Container(
                          width: 120,
                          height: 40 + (i % 3) * 10,
                          margin: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: CamiColors.blush.withValues(alpha: 0.7),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(80)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 24 + _groundY,
                    child: Container(height: 6, color: CamiColors.rose.withValues(alpha: 0.45)),
                  ),
                  Positioned(
                    left: 40,
                    bottom: 22 - _y + _groundY,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      width: _ducking ? 44 : 48,
                      height: _ducking ? 28 : 48,
                      child: GameSprites.tile(GameSprites.runnerHero, width: _ducking ? 44 : 48, height: _ducking ? 28 : 48, radius: 12),
                    ),
                  ),
                  for (final o in _objs)
                    if (!(o.kind == _Kind.coin && o.taken))
                      Positioned(
                        left: o.x,
                        bottom: o.kind == _Kind.coin ? 58 + _groundY : 28 + _groundY,
                        child: o.kind == _Kind.coin
                            ? GameSprites.img(GameSprites.star, size: 28)
                            : GameSprites.tile(
                                o.kind == _Kind.tall ? GameSprites.runnerHedge : GameSprites.runnerBox,
                                width: o.kind == _Kind.tall ? 28 : 26,
                                height: o.kind == _Kind.tall ? 54 : 32,
                                radius: 8,
                              ),
                      ),
                  Positioned(
                    left: 12,
                    top: 10,
                    child: Text(
                      '再躲 ${_need - _cleared} 个升级',
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
