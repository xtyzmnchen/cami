import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'game_kit.dart';
import 'sprites.dart';

/// 消消乐：相邻交换三消、下落连锁、关卡目标与步数。
class Match3Game extends StatefulWidget {
  const Match3Game({super.key, required this.onScore});
  final ValueChanged<int> onScore;

  @override
  State<Match3Game> createState() => _Match3GameState();
}

class _Cell {
  _Cell(this.type, {this.special = 0}) : id = UniqueKey();
  int type;
  int special; // 0普通 1横消 2竖消 3爆炸
  Key id;
}

class _Match3GameState extends State<Match3Game> {
  static const _gems = [
    GameSprites.strawberry,
    GameSprites.apple,
    GameSprites.orange,
    GameSprites.grape,
    GameSprites.lemon,
    GameSprites.peach,
    GameSprites.kiwi,
    GameSprites.cherry,
  ];

  final _rng = Random();
  final _progress = GameProgress(lives: 3);
  late List<List<_Cell?>> _board;
  var _busy = false;
  var _movesLeft = 20;
  var _levelScore = 0;
  var _combo = 0;
  var _size = 6;
  var _types = 5;
  var _goal = 40;
  (int, int)? _selected;

  int _sizeForLevel(int level) => level >= 8 ? 8 : level >= 4 ? 7 : 6;
  int _typesForLevel(int level) => min(_gems.length, 5 + (level ~/ 3));
  int _goalForLevel(int level) => 40 + level * 35;
  int _movesForLevel(int level) => max(12, 24 - level);

  var _booted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progress.isEn = Localizations.localeOf(context).languageCode == 'en';
    if (_booted) return;
    _booted = true;
    _newLevel(resetMoves: true);
  }

  void _newLevel({bool resetMoves = false}) {
    // 本关尺寸/色种锁定，避免过关瞬间 getter 变大而棋盘未重建导致越界
    _size = _sizeForLevel(_progress.level);
    _types = _typesForLevel(_progress.level);
    _goal = _goalForLevel(_progress.level);
    _board = List.generate(_size, (_) => List<_Cell?>.filled(_size, null));
    _fillBoard(avoidMatches: true);
    _levelScore = 0;
    _combo = 0;
    _selected = null;
    if (resetMoves) _movesLeft = _movesForLevel(_progress.level);
    _progress.showBanner(_progress.t('第 ${_progress.level} 关 · 目标 $_goal 分', 'Level ${_progress.level} · goal $_goal pts'));
  }

  _Cell _randCell() => _Cell(_rng.nextInt(_types));

  void _fillBoard({required bool avoidMatches}) {
    for (var r = 0; r < _size; r++) {
      for (var c = 0; c < _size; c++) {
        if (_board[r][c] != null) continue;
        var tries = 0;
        late _Cell cell;
        do {
          cell = _randCell();
          tries++;
        } while (avoidMatches && tries < 20 && _wouldMatchAt(r, c, cell.type));
        _board[r][c] = cell;
      }
    }
  }

  bool _wouldMatchAt(int r, int c, int type) {
    if (c >= 2 &&
        _board[r][c - 1]?.type == type &&
        _board[r][c - 2]?.type == type) {
      return true;
    }
    if (r >= 2 &&
        _board[r - 1][c]?.type == type &&
        _board[r - 2][c]?.type == type) {
      return true;
    }
    return false;
  }

  bool _in(int r, int c) => r >= 0 && c >= 0 && r < _size && c < _size;

  Set<(int, int)> _findMatches() {
    final matched = <(int, int)>{};
    for (var r = 0; r < _size; r++) {
      var run = 1;
      for (var c = 1; c <= _size; c++) {
        final same = c < _size &&
            _board[r][c] != null &&
            _board[r][c - 1] != null &&
            _board[r][c]!.type == _board[r][c - 1]!.type;
        if (same) {
          run++;
        } else {
          if (run >= 3) {
            for (var k = 0; k < run; k++) {
              matched.add((r, c - 1 - k));
            }
          }
          run = 1;
        }
      }
    }
    for (var c = 0; c < _size; c++) {
      var run = 1;
      for (var r = 1; r <= _size; r++) {
        final same = r < _size &&
            _board[r][c] != null &&
            _board[r - 1][c] != null &&
            _board[r][c]!.type == _board[r - 1][c]!.type;
        if (same) {
          run++;
        } else {
          if (run >= 3) {
            for (var k = 0; k < run; k++) {
              matched.add((r - 1 - k, c));
            }
          }
          run = 1;
        }
      }
    }
    return matched;
  }

  /// 检测一行/列 run 长度，用于生成特殊块。
  List<List<(int, int)>> _runs() {
    final runs = <List<(int, int)>>[];
    for (var r = 0; r < _size; r++) {
      var start = 0;
      for (var c = 1; c <= _size; c++) {
        final same = c < _size &&
            _board[r][c] != null &&
            _board[r][c - 1] != null &&
            _board[r][c]!.type == _board[r][c - 1]!.type;
        if (!same) {
          if (c - start >= 3) {
            runs.add([for (var k = start; k < c; k++) (r, k)]);
          }
          start = c;
        }
      }
    }
    for (var c = 0; c < _size; c++) {
      var start = 0;
      for (var r = 1; r <= _size; r++) {
        final same = r < _size &&
            _board[r][c] != null &&
            _board[r - 1][c] != null &&
            _board[r][c]!.type == _board[r - 1][c]!.type;
        if (!same) {
          if (r - start >= 3) {
            runs.add([for (var k = start; k < r; k++) (k, c)]);
          }
          start = r;
        }
      }
    }
    return runs;
  }

  Future<void> _resolve({(int, int)? swapA, (int, int)? swapB}) async {
    _combo = 0;
    while (mounted) {
      final matched = _findMatches();
      if (matched.isEmpty) break;
      _combo++;
      HapticFeedback.selectionClick();

      // 特殊块生成：在交换点或 run 中心
      final specials = <(int, int), int>{};
      for (final run in _runs()) {
        if (run.length >= 5) {
          final mid = run[run.length ~/ 2];
          specials[mid] = 3;
        } else if (run.length == 4) {
          final mid = run[run.length ~/ 2];
          final horizontal = run.first.$1 == run.last.$1;
          specials[mid] = horizontal ? 1 : 2;
        }
      }
      // L/T 交叉：同属两个 run
      final count = <(int, int), int>{};
      for (final run in _runs()) {
        for (final p in run) {
          count[p] = (count[p] ?? 0) + 1;
        }
      }
      for (final e in count.entries) {
        if (e.value >= 2) specials[e.key] = 3;
      }

      // 触发已有特殊块连锁
      final toClear = {...matched};
      final queue = matched.toList();
      while (queue.isNotEmpty) {
        final (r, c) = queue.removeLast();
        final cell = _board[r][c];
        if (cell == null) continue;
        if (cell.special == 1) {
          for (var cc = 0; cc < _size; cc++) {
            if (toClear.add((r, cc))) queue.add((r, cc));
          }
        } else if (cell.special == 2) {
          for (var rr = 0; rr < _size; rr++) {
            if (toClear.add((rr, c))) queue.add((rr, c));
          }
        } else if (cell.special == 3) {
          for (var rr = r - 1; rr <= r + 1; rr++) {
            for (var cc = c - 1; cc <= c + 1; cc++) {
              if (_in(rr, cc) && toClear.add((rr, cc))) queue.add((rr, cc));
            }
          }
        }
      }

      final gained = toClear.length * (10 + _combo * 4) + (_combo >= 3 ? 20 : 0);
      _levelScore += gained;
      _progress.score += gained;
      _progress.hitCombo();
      widget.onScore(_progress.score);

      setState(() {
        final spawn = <(int, int), (int type, int special)>{};
        for (final e in specials.entries) {
          if (!toClear.contains(e.key)) continue;
          final (r, c) = e.key;
          spawn[e.key] = (_board[r][c]?.type ?? _rng.nextInt(_types), e.value);
        }
        for (final (r, c) in toClear) {
          _board[r][c] = null;
        }
        for (final e in spawn.entries) {
          final (r, c) = e.key;
          _board[r][c] = _Cell(e.value.$1, special: e.value.$2);
        }
      });
      await Future<void>.delayed(const Duration(milliseconds: 160));
      if (!mounted) return;

      setState(_gravity);
      await Future<void>.delayed(const Duration(milliseconds: 140));
      if (!mounted) return;

      setState(() => _fillBoard(avoidMatches: false));
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    if (_levelScore >= _goal) {
      _progress.levelUp(
        onScore: widget.onScore,
        label: _progress.t('过关！第 ${_progress.level} 关 · 目标更高', 'Cleared! Level ${_progress.level} · higher goal'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() => _newLevel(resetMoves: true));
    } else if (_movesLeft <= 0) {
      _progress.loseLife();
      _progress.breakCombo();
      if (_progress.lives <= 0) {
        _progress.lives = 3;
        _progress.showBanner(_progress.t('步数用完 · 仍是第 ${_progress.level} 关', 'No moves · still Lv ${_progress.level}'));
      } else {
        _progress.showBanner(_progress.t('步数用完，再试一次', 'No moves — try again'));
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _newLevel(resetMoves: true));
    }
  }

  void _gravity() {
    for (var c = 0; c < _size; c++) {
      var write = _size - 1;
      for (var r = _size - 1; r >= 0; r--) {
        final cell = _board[r][c];
        if (cell == null) continue;
        _board[r][c] = null;
        _board[write][c] = cell;
        write--;
      }
    }
  }

  bool _hasAnyMove() {
    for (var r = 0; r < _size; r++) {
      for (var c = 0; c < _size; c++) {
        for (final d in const [(0, 1), (1, 0)]) {
          final nr = r + d.$1;
          final nc = c + d.$2;
          if (!_in(nr, nc)) continue;
          _swapCells(r, c, nr, nc);
          final ok = _findMatches().isNotEmpty;
          _swapCells(r, c, nr, nc);
          if (ok) return true;
        }
      }
    }
    return false;
  }

  void _swapCells(int r1, int c1, int r2, int c2) {
    final t = _board[r1][c1];
    _board[r1][c1] = _board[r2][c2];
    _board[r2][c2] = t;
  }

  Future<void> _trySwap(int r1, int c1, int r2, int c2) async {
    if (_busy || !_in(r2, c2)) return;
    if ((r1 - r2).abs() + (c1 - c2).abs() != 1) return;
    _busy = true;
    setState(() {
      _swapCells(r1, c1, r2, c2);
      _selected = null;
    });
    final matched = _findMatches();
    if (matched.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      setState(() => _swapCells(r1, c1, r2, c2));
      HapticFeedback.lightImpact();
      _busy = false;
      return;
    }
    setState(() => _movesLeft--);
    HapticFeedback.mediumImpact();
    await _resolve(swapA: (r1, c1), swapB: (r2, c2));
    if (mounted && !_hasAnyMove()) {
      setState(() {
        _board = List.generate(_size, (_) => List<_Cell?>.filled(_size, null));
        _fillBoard(avoidMatches: true);
        _progress.showBanner(_progress.t('没有可消的了，已重排', 'No moves left — reshuffled'));
      });
    }
    _busy = false;
  }

  void _onTapCell(int r, int c) {
    if (_busy) return;
    final sel = _selected;
    if (sel == null) {
      setState(() => _selected = (r, c));
      return;
    }
    if (sel == (r, c)) {
      setState(() => _selected = null);
      return;
    }
    if ((sel.$1 - r).abs() + (sel.$2 - c).abs() == 1) {
      _trySwap(sel.$1, sel.$2, r, c);
    } else {
      setState(() => _selected = (r, c));
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = (_goal - _levelScore).clamp(0, _goal);
    return GameFrame(
      progress: _progress,
      hint: _progress.t('点两颗相邻宝石交换 · 三消下落 · 四消有条纹 · 五消会爆炸', 'Swap neighbors · match 3 · 4 makes stripes · 5 explodes'),
      child: GameStage(
        colors: const [Color(0xFFFFF7FB), Color(0xFFE8F4FF)],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: _meter(
                      label: _progress.t('目标', 'Goal'),
                      value: '$_levelScore / $_goal',
                      progress: (_levelScore / _goal).clamp(0.0, 1.0),
                      color: CamiColors.roseDeep,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _pill(_progress.t('步数 $_movesLeft', 'Moves $_movesLeft')),
                  const SizedBox(width: 6),
                  _pill('$_size×$_size'),
                ],
              ),
            ),
            if (left > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _progress.t('还差 $left 分过关', '$left pts to clear'),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: CamiColors.muted, fontSize: 12),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final cell = box.maxWidth / _size;
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: CamiColors.line),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _size * _size,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _size,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                          ),
                          itemBuilder: (_, i) {
                            final r = i ~/ _size;
                            final c = i % _size;
                            final cellData = _board[r][c];
                            final selected = _selected == (r, c);
                            return GestureDetector(
                              onTap: () => _onTapCell(r, c),
                              onPanUpdate: (d) {
                                if (_selected == null) {
                                  _selected = (r, c);
                                }
                                final sel = _selected!;
                                final dx = d.localPosition.dx;
                                final dy = d.localPosition.dy;
                                // rough: if dragged far, swap toward direction from this cell
                                if (dx > cell * 0.65) {
                                  _trySwap(sel.$1, sel.$2, sel.$1, sel.$2 + 1);
                                } else if (dx < cell * 0.35 && d.delta.dx < -2) {
                                  _trySwap(sel.$1, sel.$2, sel.$1, sel.$2 - 1);
                                } else if (dy > cell * 0.65) {
                                  _trySwap(sel.$1, sel.$2, sel.$1 + 1, sel.$2);
                                } else if (dy < cell * 0.35 && d.delta.dy < -2) {
                                  _trySwap(sel.$1, sel.$2, sel.$1 - 1, sel.$2);
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected ? CamiColors.roseDeep : Colors.white70,
                                    width: selected ? 2.4 : 1,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: CamiColors.roseDeep.withValues(alpha: 0.35),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: cellData == null
                                    ? const ColoredBox(color: Color(0x22FFFFFF))
                                    : Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          GameSprites.tile(_gems[cellData.type % _gems.length], radius: 0),
                                          if (cellData.special != 0)
                                            Positioned(
                                              right: 2,
                                              top: 2,
                                              child: Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.9),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Icon(
                                                  cellData.special == 3
                                                      ? Icons.flash_on
                                                      : cellData.special == 1
                                                          ? Icons.swap_horiz
                                                          : Icons.swap_vert,
                                                  size: 12,
                                                  color: CamiColors.roseDeep,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: CamiColors.line),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
      );

  Widget _meter({
    required String label,
    required String value,
    required double progress,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: CamiColors.muted)),
            const Spacer(),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: color,
            backgroundColor: CamiColors.blush,
          ),
        ),
      ],
    );
  }
}
