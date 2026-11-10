import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'game_kit.dart';
import 'sprites.dart';

/// 打地鼠：洞里冒出鼹鼠，点中得分；关卡越高出得越快越多。
class WhackMoleGame extends StatefulWidget {
  const WhackMoleGame({super.key, required this.onScore});
  final ValueChanged<int> onScore;

  @override
  State<WhackMoleGame> createState() => _WhackMoleGameState();
}

class _Hole {
  var up = false;
  var bomb = false;
  var hit = false;
  var life = 0.0;
  var maxLife = 0.9;
}

class _WhackMoleGameState extends State<WhackMoleGame> {
  final _rng = Random();
  final _progress = GameProgress(lives: 3);
  late List<_Hole> _holes;
  var _hitsLevel = 0;
  var _spawnCool = 0.0;
  Timer? _timer;
  var _bonkIndex = -1;
  var _bonkT = 0.0;

  /// 洞位随关卡变多：2×2 → 3×2 → 3×3 → 4×3 → 4×4
  int get _cols => _progress.level >= 4 ? 4 : _progress.level >= 2 ? 3 : 2;
  int get _rows => _progress.level >= 10 ? 4 : _progress.level >= 3 ? 3 : 2;
  int get _count => _cols * _rows;
  int get _need => 6 + _progress.level * 4;
  /// 露头时间越来越短（最低约 0.28 秒）
  double get _upTime => max(0.28, 1.15 - _progress.level * 0.09);
  /// 出洞间隔越来越短
  double get _spawnGap => max(0.12, 0.62 - _progress.level * 0.045);
  /// 炸弹越来越多
  double get _bombChance => min(0.38, 0.06 + _progress.level * 0.028);
  /// 同时冒出的地鼠数
  int get _maxActive => min(_count - 1, 1 + (_progress.level + 1) ~/ 2);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progress.isEn = Localizations.localeOf(context).languageCode == 'en';
  }

  @override
  void initState() {
    super.initState();
    _holes = List.generate(_count, (_) => _Hole());
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick(0.016));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _ensureHoles() {
    if (_holes.length == _count) return;
    _holes = List.generate(_count, (i) => i < _holes.length ? _holes[i] : _Hole());
  }

  void _tick(double dt) {
    setState(() {
      _progress.clearBannerIfNeeded();
      _ensureHoles();
      if (_bonkT > 0) _bonkT = max(0, _bonkT - dt);

      _spawnCool -= dt;
      var active = _holes.where((h) => h.up && !h.hit).length;
      if (_spawnCool <= 0 && active < _maxActive) {
        // 高关卡偶尔连着冒 2～3 只
        final burst = 1 + (_progress.level >= 5 && _rng.nextDouble() < 0.45 ? 1 : 0) + (_progress.level >= 9 && _rng.nextDouble() < 0.35 ? 1 : 0);
        for (var n = 0; n < burst; n++) {
          active = _holes.where((h) => h.up && !h.hit).length;
          if (active >= _maxActive) break;
          final free = <int>[];
          for (var i = 0; i < _holes.length; i++) {
            if (!_holes[i].up) free.add(i);
          }
          if (free.isEmpty) break;
          final i = free[_rng.nextInt(free.length)];
          final h = _holes[i];
          h.up = true;
          h.hit = false;
          h.bomb = _rng.nextDouble() < _bombChance;
          h.maxLife = _upTime * (0.8 + _rng.nextDouble() * 0.35);
          h.life = h.maxLife;
        }
        _spawnCool = _spawnGap * (0.55 + _rng.nextDouble() * 0.55);
      }

      for (final h in _holes) {
        if (!h.up) continue;
        h.life -= dt;
        if (h.life <= 0) {
          if (!h.hit && !h.bomb) {
            _progress.loseLife();
            _progress.breakCombo();
            _progress.showBanner(_progress.t('地鼠跑掉了', 'Mole got away'));
            // 失败不降关：难度继续往上，只扣心重开本关计数
            if (_progress.lives <= 0) {
              _progress.lives = 3;
              _hitsLevel = 0;
              _progress.showBanner(_progress.t('心没了 · 仍是第 ${_progress.level} 关，继续加快', 'No hearts · still Lv ${_progress.level}, speeding up'));
            }
          }
          h.up = false;
          h.hit = false;
        }
      }
    });
  }

  void _tap(int index) {
    final h = _holes[index];
    if (!h.up || h.hit) return;
    h.hit = true;
    h.life = min(h.life, 0.18);
    setState(() {
      _bonkIndex = index;
      _bonkT = 0.22;
    });

    if (h.bomb) {
      unawaited(HapticFeedback.vibrate());
      _progress.loseLife(haptic: false);
      _progress.breakCombo();
      _progress.score = max(0, _progress.score - (2 + _progress.level));
      widget.onScore(_progress.score);
      _progress.showBanner(_progress.t('打到炸弹了！', 'Hit a bomb!'));
      if (_progress.lives <= 0) {
        _progress.lives = 3;
        _hitsLevel = 0;
        _progress.showBanner(_progress.t('心没了，本关重来', 'No hearts — retry this level'));
      }
      return;
    }

    HapticFeedback.mediumImpact();
    _progress.hitCombo();
    _progress.score += 1 + (_progress.combo >= 5 ? 2 : (_progress.combo >= 3 ? 1 : 0));
    _hitsLevel++;
    widget.onScore(_progress.score);
    if (_hitsLevel >= _need) {
      _hitsLevel = 0;
      _progress.levelUp(
        onScore: widget.onScore,
        label: _progress.t('第 ${_progress.level} 关！${_cols}×$_rows 洞 · 同时$_maxActive只', 'Level ${_progress.level}! ${_cols}×$_rows holes · $_maxActive at once'),
      );
      setState(_ensureHoles);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      progress: _progress,
      hint: _progress.t('地鼠冒出来就点 · 别打炸弹 · 关卡越高越快越多', 'Tap moles · avoid bombs · faster each level'),
      child: GameStage(
        colors: const [Color(0xFFE8F8EF), Color(0xFFFFF0F5)],
        child: LayoutBuilder(
          builder: (context, box) {
            return Stack(
              children: [
                Positioned(
                  left: 12,
                  top: 8,
                  right: 12,
                  child: Text(
                    '再打 ${_need - _hitsLevel} 只升级 · ${_cols}×$_rows · 露头 ${_upTime.toStringAsFixed(1)}s',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: CamiColors.roseDeep, fontSize: 12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 36, 12, 12),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _count,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _cols,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemBuilder: (context, i) {
                      final h = _holes[i];
                      final pop = h.up ? (h.hit ? 0.35 : (h.life / h.maxLife).clamp(0.0, 1.0)) : 0.0;
                      return GestureDetector(
                        onTap: () => _tap(i),
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: GameSprites.tile(GameSprites.whackHole, width: 88, height: 54, radius: 20),
                            ),
                            if (h.up)
                              Positioned(
                                bottom: 18 + pop * 28,
                                child: Opacity(
                                  opacity: h.hit ? 0.45 : 1,
                                  child: Transform.scale(
                                    scale: 0.75 + pop * 0.35,
                                    child: GameSprites.img(
                                      h.bomb ? GameSprites.bomb : GameSprites.whackMole,
                                      size: 64,
                                    ),
                                  ),
                                ),
                              ),
                            if (_bonkT > 0 && _bonkIndex == i)
                              Positioned(
                                top: 0,
                                right: 4,
                                child: Opacity(
                                  opacity: (_bonkT / 0.22).clamp(0.0, 1.0),
                                  child: Transform.rotate(
                                    angle: -0.4 + (1 - _bonkT / 0.22) * 0.9,
                                    child: GameSprites.img(GameSprites.whackHammer, size: 48),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
