import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'game_kit.dart';
import 'sprites.dart';

class CatchFruitGame extends StatefulWidget {
  const CatchFruitGame({super.key, required this.onScore});
  final ValueChanged<int> onScore;

  @override
  State<CatchFruitGame> createState() => _CatchFruitGameState();
}

class _Drop {
  _Drop(this.x, this.y, this.asset, this.bomb, this.speed);
  double x;
  double y;
  final String asset;
  final bool bomb;
  final double speed;
}

class _CatchFruitGameState extends State<CatchFruitGame> {
  final _rng = Random();
  final _progress = GameProgress(lives: 3);
  final _drops = <_Drop>[];
  var _basket = 0.5;
  var _caughtLevel = 0;
  Timer? _timer;
  Size _size = Size.zero;

  double get _fall => 0.008 + _progress.level * 0.0018;
  double get _spawnChance => min(0.12, 0.035 + _progress.level * 0.008);
  double get _basketHalf => max(0.08, 0.13 - _progress.level * 0.004);
  int get _need => 6 + _progress.level * 2;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progress.isEn = Localizations.localeOf(context).languageCode == 'en';
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 32), (_) => _tick());
  }

  void _tick() {
    if (_size == Size.zero || _progress.lives <= 0) return;
    setState(() {
      _progress.clearBannerIfNeeded();
      if (_rng.nextDouble() < _spawnChance) {
        final bomb = _rng.nextDouble() < min(0.22, 0.08 + _progress.level * 0.015);
        _drops.add(
          _Drop(
            0.1 + _rng.nextDouble() * 0.8,
            -0.05,
            bomb ? GameSprites.bomb : GameSprites.fruits[_rng.nextInt(GameSprites.fruits.length)],
            bomb,
            _fall * (0.85 + _rng.nextDouble() * 0.4),
          ),
        );
      }
      for (final d in _drops) {
        d.y += d.speed;
      }
      final left = _basket - _basketHalf;
      final right = _basket + _basketHalf;
      _drops.removeWhere((d) {
        if (d.y < 0.88) return false;
        final hit = d.x >= left && d.x <= right && d.y < 0.98;
        if (hit) {
          if (d.bomb) {
            unawaited(HapticFeedback.vibrate());
            _progress.loseLife(haptic: false);
            _progress.showBanner(_progress.t('接到炸弹啦！', 'Caught a bomb!'));
            _progress.breakCombo();
          } else {
            HapticFeedback.selectionClick();
            _progress.hitCombo();
            _progress.score += _progress.combo >= 4 ? 2 : 1;
            _caughtLevel++;
            widget.onScore(_progress.score);
            if (_caughtLevel >= _need) {
              _caughtLevel = 0;
              _progress.levelUp(onScore: widget.onScore, label: _progress.t('第 ${_progress.level} 关！落得更快了', 'Level ${_progress.level}! Falling faster'));
            }
          }
          return true;
        }
        if (d.y >= 1.05) {
          if (!d.bomb) {
            _progress.loseLife();
            _progress.showBanner(_progress.t('水果掉地上了', 'Fruit hit the ground'));
            if (_progress.lives <= 0) {
              _progress.lives = 3;
              _progress.level = max(1, _progress.level - 1);
              _caughtLevel = 0;
              _progress.showBanner(_progress.t('重新挑战第 ${_progress.level} 关', 'Retry level ${_progress.level}'));
            }
          }
          return true;
        }
        return false;
      });
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
      hint: _progress.t('左右拖动篮子 · 接水果避开炸弹', 'Drag the basket · catch fruit, avoid bombs'),
      child: LayoutBuilder(
        builder: (context, c) {
          _size = Size(c.maxWidth, c.maxHeight);
          final bw = c.maxWidth * _basketHalf * 2;
          return GameStage(
            colors: const [Color(0xFFE8FFF4), Color(0xFFFFF0F5)],
            child: GestureDetector(
              onHorizontalDragUpdate: (d) {
                setState(() {
                  _basket = (_basket + d.delta.dx / c.maxWidth).clamp(_basketHalf, 1 - _basketHalf);
                });
              },
              onTapDown: (d) {
                setState(() {
                  _basket = (d.localPosition.dx / c.maxWidth).clamp(_basketHalf, 1 - _basketHalf);
                });
              },
              child: Stack(
                children: [
                  Positioned(top: 24, left: 20, child: _cloud()),
                  Positioned(top: 48, right: 30, child: _cloud(w: 70)),
                  for (final d in _drops)
                    Positioned(
                      left: d.x * c.maxWidth - 22,
                      top: d.y * c.maxHeight,
                      child: GameSprites.img(d.asset, size: 44),
                    ),
                  Positioned(
                    left: _basket * c.maxWidth - bw / 2,
                    bottom: 12,
                    child: GameSprites.tile(GameSprites.basket, width: bw, height: 48, radius: 16),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 66,
                    child: Text(
                      '再接 ${_need - _caughtLevel} 个升级',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: CamiColors.roseDeep, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _cloud({double w = 56}) => Container(
        width: w,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
        ),
      );
}
