import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// 碰到炸弹时的明显震动提醒（接住 / 切到 / 点到）。
Future<void> bombHitFeedback() async {
  for (var i = 0; i < 3; i++) {
    await HapticFeedback.vibrate();
    await HapticFeedback.heavyImpact();
    if (i < 2) await Future<void>.delayed(const Duration(milliseconds: 90));
  }
}

/// 小游戏通用进度：关卡、连击、星星、生命。
class GameProgress {
  GameProgress({this.lives = 3});

  int score = 0;
  int level = 1;
  int combo = 0;
  int bestCombo = 0;
  int stars = 0;
  int lives;
  int roundsCleared = 0;
  String? banner;
  DateTime? _bannerUntil;
  /// 与 App 语言同步；各游戏在 didChangeDependencies 里赋值。
  bool isEn = false;

  String t(String zh, String en) => isEn ? en : zh;

  /// 每关目标分（可被各游戏覆盖逻辑）。
  int get target => 4 + (level - 1) * 3;

  bool get bannerVisible =>
      banner != null && _bannerUntil != null && DateTime.now().isBefore(_bannerUntil!);

  void showBanner(String text, {Duration forDuration = const Duration(milliseconds: 1400)}) {
    // 游戏中不再弹出提示条，避免打断操作
  }

  void clearBannerIfNeeded() {
    if (banner != null && _bannerUntil != null && DateTime.now().isAfter(_bannerUntil!)) {
      banner = null;
    }
  }

  void hitCombo() {
    combo++;
    if (combo > bestCombo) bestCombo = combo;
  }

  void breakCombo() => combo = 0;

  /// 加分；若过关返回 true。
  bool gain(int points, {required ValueChanged<int> onScore, int? customTarget}) {
    score += points;
    onScore(score);
    final need = customTarget ?? target;
    if (roundsCleared + 1 >= need || score >= _scoreGate()) {
      // 用 roundsCleared 或 score 由各游戏决定；这里提供 score gate 默认
    }
    return false;
  }

  int _scoreGate() => level * 8;

  /// 完成一局/一轮后升级。
  void levelUp({required ValueChanged<int> onScore, String? label}) {
    roundsCleared = 0;
    level++;
    stars++;
    showBanner(label ?? t('第 $level 关！', 'Level $level!'));
    HapticFeedback.mediumImpact();
    onScore(score);
  }

  void loseLife({VoidCallback? onGameOver, bool haptic = true}) {
    lives = (lives - 1).clamp(0, 99);
    breakCombo();
    if (haptic) HapticFeedback.heavyImpact();
    if (lives <= 0) onGameOver?.call();
  }
}

class GameFrame extends StatelessWidget {
  const GameFrame({
    super.key,
    required this.progress,
    required this.child,
    this.hint,
    this.extra,
  });

  final GameProgress progress;
  final Widget child;
  final String? hint;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Hud(progress: progress),
        if (extra != null) extra!,
        const SizedBox(height: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.progress});
  final GameProgress progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7FA), Color(0xFFFFE8F1)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CamiColors.line),
      ),
      child: Row(
        children: [
          _chip(Localizations.localeOf(context).languageCode == 'en' ? 'Lv' : '关卡', '${progress.level}'),
          const SizedBox(width: 8),
          _chip(Localizations.localeOf(context).languageCode == 'en' ? 'Score' : '得分', '${progress.score}'),
          const SizedBox(width: 8),
          if (progress.combo > 1)
            _chip(Localizations.localeOf(context).languageCode == 'en' ? 'Combo' : '连击', 'x${progress.combo}', hot: true),
          const Spacer(),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Icon(
                i < progress.lives ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: i < progress.lives ? CamiColors.roseDeep : CamiColors.line,
              ),
            ),
          const SizedBox(width: 6),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: CamiColors.gold, size: 18),
              Text(' ${progress.stars}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, {bool hot = false}) {
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

/// 圆角游戏舞台背景。
class GameStage extends StatelessWidget {
  const GameStage({super.key, required this.child, this.colors});
  final Widget child;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors ?? const [Color(0xFFFFF8FB), Color(0xFFFFE4EF)],
          ),
        ),
        child: child,
      ),
    );
  }
}
