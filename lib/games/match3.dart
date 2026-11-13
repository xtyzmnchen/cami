import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'game_kit.dart';
import 'sprites.dart';

/// 消消乐（Candy Crush 系成熟玩法 · 横屏铺满）
/// · 滑动 / 点选相邻交换；无效交换弹回
/// · 三消下落连锁；四消=条纹（清行/列）；五消或 L/T=爆炸
/// · 每关有目标分 + 有限步数；过关升难度；步数用完扣命
/// · 棋盘按可用区域最大正方形铺满，不再挤在中间一小块
class Match3Game extends StatefulWidget {
  const Match3Game({super.key, required this.onScore});
  final ValueChanged<int> onScore;

  @override
  State<Match3Game> createState() => _Match3GameState();
}

class _Cell {
  _Cell(this.type, {this.special = 0}) : id = UniqueKey();
  int type;
  /// 0 普通 · 1 横条 · 2 竖条 · 3 爆炸
  int special;
  final Key id;
}

class _Float {
  _Float(this.r, this.c, this.text, this.color);
  final int r, c;
  final String text;
  final Color color;
  double life = 1;
}

class _Match3GameState extends State<Match3Game> with SingleTickerProviderStateMixin {
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

  static const _tint = [
    Color(0xFFFF6B9A),
    Color(0xFFFF5A5A),
    Color(0xFFFFA64D),
    Color(0xFF9B6BFF),
    Color(0xFFFFE14D),
    Color(0xFFFF9EC8),
    Color(0xFF6BCB77),
    Color(0xFFFF4D6D),
  ];

  final _rng = Random();
  final _progress = GameProgress(lives: 3);
  late List<List<_Cell?>> _board;
  final _floats = <_Float>[];
  final _clearing = <(int, int)>{};
  var _busy = false;
  var _movesLeft = 22;
  var _levelScore = 0;
  var _combo = 0;
  /// 横屏铺满：宽棋盘，不再用正方形挤在中间
  var _cols = 8;
  var _rows = 6;
  var _types = 5;
  var _goal = 500;
  var _best = 0;
  var _gameOver = false;
  var _levelClear = false;
  (int, int)? _selected;
  var _booted = false;
  late final AnimationController _pulse;

  (int, int) _gridForLevel(int level) {
    if (level >= 8) return (9, 7);
    if (level >= 4) return (9, 6);
    return (8, 6);
  }

  int _typesForLevel(int level) => min(_gems.length, 5 + (level ~/ 3));
  int _goalForLevel(int level) => 400 + level * 180;
  int _movesForLevel(int level) => max(14, 26 - level);

  int get _ratingStars {
    if (_levelScore >= _goal * 1.6) return 3;
    if (_levelScore >= _goal * 1.2) return 2;
    if (_levelScore >= _goal) return 1;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _board = List.generate(_rows, (_) => List<_Cell?>.filled(_cols, null));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progress.isEn = Localizations.localeOf(context).languageCode == 'en';
    if (_booted) return;
    _booted = true;
    _newLevel(resetMoves: true);
  }

  void _newLevel({bool resetMoves = false}) {
    final grid = _gridForLevel(_progress.level);
    _cols = grid.$1;
    _rows = grid.$2;
    _types = _typesForLevel(_progress.level);
    _goal = _goalForLevel(_progress.level);
    _board = List.generate(_rows, (_) => List<_Cell?>.filled(_cols, null));
    _fillBoard(avoidMatches: true);
    _levelScore = 0;
    _combo = 0;
    _selected = null;
    _clearing.clear();
    _floats.clear();
    _levelClear = false;
    _gameOver = false;
    if (resetMoves) _movesLeft = _movesForLevel(_progress.level);
  }

  _Cell _randCell() => _Cell(_rng.nextInt(_types));

  void _fillBoard({required bool avoidMatches}) {
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        if (_board[r][c] != null) continue;
        var tries = 0;
        late _Cell cell;
        do {
          cell = _randCell();
          tries++;
        } while (avoidMatches && tries < 24 && _wouldMatchAt(r, c, cell.type));
        _board[r][c] = cell;
      }
    }
  }

  bool _wouldMatchAt(int r, int c, int type) {
    if (c >= 2 && _board[r][c - 1]?.type == type && _board[r][c - 2]?.type == type) return true;
    if (r >= 2 && _board[r - 1][c]?.type == type && _board[r - 2][c]?.type == type) return true;
    return false;
  }

  bool _in(int r, int c) => r >= 0 && c >= 0 && r < _rows && c < _cols;

  Set<(int, int)> _findMatches() {
    final matched = <(int, int)>{};
    for (var r = 0; r < _rows; r++) {
      var run = 1;
      for (var c = 1; c <= _cols; c++) {
        final same = c < _cols &&
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
    for (var c = 0; c < _cols; c++) {
      var run = 1;
      for (var r = 1; r <= _rows; r++) {
        final same = r < _rows &&
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

  List<List<(int, int)>> _runs() {
    final runs = <List<(int, int)>>[];
    for (var r = 0; r < _rows; r++) {
      var start = 0;
      for (var c = 1; c <= _cols; c++) {
        final same = c < _cols &&
            _board[r][c] != null &&
            _board[r][c - 1] != null &&
            _board[r][c]!.type == _board[r][c - 1]!.type;
        if (!same) {
          if (c - start >= 3) runs.add([for (var k = start; k < c; k++) (r, k)]);
          start = c;
        }
      }
    }
    for (var c = 0; c < _cols; c++) {
      var start = 0;
      for (var r = 1; r <= _rows; r++) {
        final same = r < _rows &&
            _board[r][c] != null &&
            _board[r - 1][c] != null &&
            _board[r][c]!.type == _board[r - 1][c]!.type;
        if (!same) {
          if (r - start >= 3) runs.add([for (var k = start; k < r; k++) (k, c)]);
          start = r;
        }
      }
    }
    return runs;
  }

  Future<void> _resolve() async {
    _combo = 0;
    while (mounted && !_gameOver) {
      final matched = _findMatches();
      if (matched.isEmpty) break;
      _combo++;
      HapticFeedback.selectionClick();

      final specials = <(int, int), int>{};
      final runList = _runs();
      for (final run in runList) {
        if (run.length >= 5) {
          specials[run[run.length ~/ 2]] = 3;
        } else if (run.length == 4) {
          final mid = run[run.length ~/ 2];
          final horizontal = run.first.$1 == run.last.$1;
          specials[mid] = horizontal ? 1 : 2;
        }
      }
      final count = <(int, int), int>{};
      for (final run in runList) {
        for (final p in run) {
          count[p] = (count[p] ?? 0) + 1;
        }
      }
      for (final e in count.entries) {
        if (e.value >= 2) specials[e.key] = 3;
      }

      final toClear = {...matched};
      final queue = matched.toList();
      while (queue.isNotEmpty) {
        final (r, c) = queue.removeLast();
        final cell = _board[r][c];
        if (cell == null) continue;
        if (cell.special == 1) {
          for (var cc = 0; cc < _cols; cc++) {
            if (toClear.add((r, cc))) queue.add((r, cc));
          }
        } else if (cell.special == 2) {
          for (var rr = 0; rr < _rows; rr++) {
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

      final gained = toClear.length * (12 + _combo * 6) + (_combo >= 3 ? 40 : 0);
      _levelScore += gained;
      _progress.score += gained;
      if (_progress.score > _best) _best = _progress.score;
      _progress.hitCombo();
      widget.onScore(_progress.score);

      final mid = toClear.elementAt(toClear.length ~/ 2);
      _floats.add(
        _Float(
          mid.$1,
          mid.$2,
          _combo >= 2 ? 'x$_combo +$gained' : '+$gained',
          _combo >= 3 ? const Color(0xFFFF8A00) : CamiColors.roseDeep,
        ),
      );

      setState(() {
        _clearing
          ..clear()
          ..addAll(toClear);
      });
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;

      setState(() {
        final spawn = <(int, int), (int, int)>{};
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
        _clearing.clear();
      });
      await Future<void>.delayed(const Duration(milliseconds: 70));
      if (!mounted) return;

      setState(_gravity);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;

      setState(() => _fillBoard(avoidMatches: false));
      await Future<void>.delayed(const Duration(milliseconds: 110));
      _tickFloats();
    }

    if (!mounted || _gameOver) return;

    if (_levelScore >= _goal) {
      _levelClear = true;
      _progress.stars = _ratingStars;
      _progress.levelUp(onScore: widget.onScore);
      HapticFeedback.mediumImpact();
      setState(() {});
      return;
    }

    if (_movesLeft <= 0) {
      _progress.loseLife();
      _progress.breakCombo();
      if (_progress.lives <= 0) {
        _gameOver = true;
        _progress.stars = _ratingStars;
      } else {
        // 还有命：本关重来
        setState(() => _newLevel(resetMoves: true));
      }
      setState(() {});
    }
  }

  void _tickFloats() {
    for (final f in _floats) {
      f.life -= 0.35;
    }
    _floats.removeWhere((f) => f.life <= 0);
  }

  void _gravity() {
    for (var c = 0; c < _cols; c++) {
      var write = _rows - 1;
      for (var r = _rows - 1; r >= 0; r--) {
        final cell = _board[r][c];
        if (cell == null) continue;
        _board[r][c] = null;
        _board[write][c] = cell;
        write--;
      }
    }
  }

  bool _hasAnyMove() {
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
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
    if (_busy || _gameOver || _levelClear || !_in(r2, c2)) return;
    if ((r1 - r2).abs() + (c1 - c2).abs() != 1) return;
    if (_board[r1][c1] == null || _board[r2][c2] == null) return;
    _busy = true;
    setState(() {
      _swapCells(r1, c1, r2, c2);
      _selected = null;
    });
    final matched = _findMatches();
    if (matched.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 160));
      if (!mounted) return;
      setState(() => _swapCells(r1, c1, r2, c2));
      HapticFeedback.lightImpact();
      _busy = false;
      return;
    }
    setState(() => _movesLeft--);
    HapticFeedback.mediumImpact();
    await _resolve();
    if (mounted && !_gameOver && !_levelClear && !_hasAnyMove()) {
      setState(() {
        _board = List.generate(_rows, (_) => List<_Cell?>.filled(_cols, null));
        _fillBoard(avoidMatches: true);
      });
    }
    _busy = false;
    if (mounted) setState(() {});
  }

  void _onTapCell(int r, int c) {
    if (_busy || _gameOver || _levelClear) return;
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

  void _onSwipe(int r, int c, DragEndDetails d) {
    if (_busy || _gameOver || _levelClear) return;
    final v = d.velocity.pixelsPerSecond;
    const th = 180.0;
    if (v.dx.abs() > v.dy.abs()) {
      if (v.dx > th) {
        _trySwap(r, c, r, c + 1);
      } else if (v.dx < -th) {
        _trySwap(r, c, r, c - 1);
      }
    } else {
      if (v.dy > th) {
        _trySwap(r, c, r + 1, c);
      } else if (v.dy < -th) {
        _trySwap(r, c, r - 1, c);
      }
    }
  }

  void _continueAfterClear() {
    setState(() {
      _levelClear = false;
      _newLevel(resetMoves: true);
    });
  }

  void _retryAfterFail() {
    setState(() {
      _gameOver = false;
      _progress.lives = 3;
      _progress.combo = 0;
      // 失败不降关，本关重开
      _newLevel(resetMoves: true);
      widget.onScore(_progress.score);
    });
  }

  @override
  Widget build(BuildContext context) {
    final en = _progress.isEn;
    final goalP = (_levelScore / _goal).clamp(0.0, 1.0);
    final inset = MediaQuery.paddingOf(context);

    // 避开 PlayPage 顶部关闭/计时条，把棋盘留给下方大片区域
    return Padding(
      padding: EdgeInsets.fromLTRB(
        inset.left + 10,
        inset.top + 66,
        inset.right + 10,
        inset.bottom + 6,
      ),
      child: Column(
      children: [
        _MatchHud(
          score: _progress.score,
          level: _progress.level,
          levelScore: _levelScore,
          goal: _goal,
          goalProgress: goalP,
          moves: _movesLeft,
          lives: _progress.lives,
          combo: _combo,
          isEn: en,
        ),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              // 横屏：格子尽量铺满宽高，矩形棋盘不再缩成中间一小块
              final pad = 4.0;
              final usableW = c.maxWidth - pad * 2;
              final usableH = c.maxHeight - pad * 2;
              final gap = min(usableW, usableH) * 0.01;
              final cell = min(
                (usableW - gap * (_cols + 1)) / _cols,
                (usableH - gap * (_rows + 1)) / _rows,
              );
              final boardW = gap * (_cols + 1) + cell * _cols;
              final boardH = gap * (_rows + 1) + cell * _rows;
              final left = (c.maxWidth - boardW) / 2;
              final top = (c.maxHeight - boardH) / 2;

              return ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _CandyBgPainter(), size: Size.infinite),
                    Positioned(
                      left: left,
                      top: top,
                      width: boardW,
                      height: boardH,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFF5FA), Color(0xFFE8F4FF)],
                          ),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: CamiColors.rose.withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            for (var r = 0; r < _rows; r++)
                              for (var cIdx = 0; cIdx < _cols; cIdx++)
                                _buildCell(r, cIdx, cell, gap),
                            for (final f in _floats)
                              Positioned(
                                left: gap + f.c * (cell + gap) + cell * 0.1,
                                top: gap + f.r * (cell + gap) + cell * 0.2 * (1 - f.life),
                                child: Opacity(
                                  opacity: f.life.clamp(0.0, 1.0),
                                  child: Text(
                                    f.text,
                                    style: TextStyle(
                                      color: f.color,
                                      fontWeight: FontWeight.w900,
                                      fontSize: cell * 0.28,
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
                      left: 10,
                      bottom: 6,
                      child: _Tip(
                        text: en
                            ? 'Swipe to swap · 4=stripe · 5=blast'
                            : '滑动交换 · 四消条纹 · 五消爆炸',
                      ),
                    ),
                    if (_levelClear)
                      _Panel(
                        title: en ? 'Level cleared!' : '过关啦！',
                        scoreLabel: en ? 'Level score $_levelScore' : '本关得分 $_levelScore',
                        stars: _ratingStars,
                        button: en ? 'Next level' : '下一关',
                        onPressed: _continueAfterClear,
                      ),
                    if (_gameOver)
                      _Panel(
                        title: en ? 'Out of moves' : '步数用完了',
                        scoreLabel: en ? 'Score ${_progress.score}' : '总分 ${_progress.score}',
                        stars: _ratingStars,
                        button: en ? 'Try again' : '再试一次',
                        onPressed: _retryAfterFail,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildCell(int r, int c, double cell, double gap) {
    final data = _board[r][c];
    final selected = _selected == (r, c);
    final clearing = _clearing.contains((r, c));

    return Positioned(
      left: gap + c * (cell + gap),
      top: gap + r * (cell + gap),
      width: cell,
      height: cell,
      child: GestureDetector(
        onTap: () => _onTapCell(r, c),
        onHorizontalDragEnd: (d) => _onSwipe(r, c, d),
        onVerticalDragEnd: (d) => _onSwipe(r, c, d),
        child: AnimatedScale(
          scale: clearing ? 0.2 : (selected ? 1.08 : 1),
          duration: const Duration(milliseconds: 140),
          child: AnimatedOpacity(
            opacity: clearing ? 0 : 1,
            duration: const Duration(milliseconds: 140),
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final glow = selected ? 0.25 + _pulse.value * 0.2 : 0.0;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(cell * 0.22),
                    color: Colors.white.withValues(alpha: 0.55),
                    border: Border.all(
                      color: selected ? CamiColors.roseDeep : Colors.white.withValues(alpha: 0.8),
                      width: selected ? 2.5 : 1,
                    ),
                    boxShadow: [
                      if (selected)
                        BoxShadow(
                          color: CamiColors.roseDeep.withValues(alpha: glow),
                          blurRadius: 10,
                        ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: child,
                );
              },
              child: data == null
                  ? const SizedBox.expand()
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: _tint[data.type % _tint.length].withValues(alpha: 0.2)),
                        Padding(
                          padding: EdgeInsets.all(cell * 0.08),
                          child: GameSprites.tile(
                            _gems[data.type % _gems.length],
                            radius: cell * 0.18,
                          ),
                        ),
                        if (data.special != 0)
                          Positioned(
                            right: 2,
                            top: 2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4),
                                ],
                              ),
                              child: Icon(
                                data.special == 3
                                    ? Icons.auto_awesome
                                    : data.special == 1
                                        ? Icons.swipe
                                        : Icons.swap_vert,
                                size: cell * 0.22,
                                color: data.special == 3 ? const Color(0xFFFF8A00) : CamiColors.roseDeep,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchHud extends StatelessWidget {
  const _MatchHud({
    required this.score,
    required this.level,
    required this.levelScore,
    required this.goal,
    required this.goalProgress,
    required this.moves,
    required this.lives,
    required this.combo,
    required this.isEn,
  });

  final int score;
  final int level;
  final int levelScore;
  final int goal;
  final double goalProgress;
  final int moves;
  final int lives;
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
          _chip(isEn ? 'Score $score' : '总分 $score'),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn ? 'Goal $levelScore / $goal' : '本关 $levelScore / $goal',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: goalProgress,
                    minHeight: 7,
                    color: CamiColors.roseDeep,
                    backgroundColor: CamiColors.blush,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _chip(isEn ? 'Moves $moves' : '步数 $moves', hot: moves <= 5),
          if (combo > 1) ...[
            const SizedBox(width: 6),
            _chip('x$combo', hot: true),
          ],
          const SizedBox(width: 6),
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

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.scoreLabel,
    required this.stars,
    required this.button,
    required this.onPressed,
  });

  final String title;
  final String scoreLabel;
  final int stars;
  final String button;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.42),
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
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
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
              Text(scoreLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: CamiColors.roseDeep,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(button, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandyBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        const [Color(0xFFFFE4F0), Color(0xFFE3F2FF), Color(0xFFFFF0D6)],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(Offset.zero & size, bg);

    final blob = Paint()..color = const Color(0xFFFF9EC8).withValues(alpha: 0.18);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.2), 60, blob);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.7), 80, blob..color = const Color(0xFF9AD7FF).withValues(alpha: 0.2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
