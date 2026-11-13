import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../logic.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'english_page.dart';
import 'focus_page.dart';
import 'play.dart';
import 'task_page.dart';
import 'poem_page.dart';
import 'vocab_page.dart';
import '../poems/poems.dart';
import '../vocab/schedule.dart';

/// 临时：首页列出全部小游戏方便测试。测完改回 false。
const kListAllGamesForTest = false;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final s = context.l10n;
    final today = DateTime.now();
    final key = store.todayKey;
    final all = tasksOn(store.data, key);
    final doneCount = all.where((t) => store.done(key, t.id)).length;
    final progress = all.isEmpty ? 0.0 : doneCount / all.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.dateLabel(today), style: const TextStyle(color: CamiColors.muted)),
                  Text('${s.hello(today)}, ${store.data.childName}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            IconButton(
              onPressed: store.syncing ? null : () => store.syncPull(),
              icon: store.syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: CamiColors.roseDeep),
                    )
                  : const Icon(Icons.refresh, color: CamiColors.roseDeep),
              tooltip: s.refresh,
            ),
            IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusPage())),
              icon: const Icon(Icons.timer_outlined, color: CamiColors.roseDeep),
              tooltip: s.pomodoro,
            ),
            FilledButton.tonal(
              onPressed: () async {
                final store = context.read<Store>();
                // 应急最高权限账号免 PIN；普通账号仍需密码
                if (store.isMasterUser) {
                  await store.setParentMode(true);
                  return;
                }
                if (await askPin(context) && context.mounted) {
                  await store.setParentMode(true);
                } else if (context.mounted) {
                  toast(context, s.wrongPin);
                }
              },
              child: Text(s.parentMode),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RoseHeroBanner(
          title: doneCount == all.length ? s.allDoneToday : s.remainingTasks(all.length - doneCount),
          subtitle: s.gameUnlockHint(all.length),
          height: 132,
        ),
        const SizedBox(height: 12),
        GlassPanel(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('$doneCount / ${all.length}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  const Spacer(),
                  Text('${(progress * 100).round()}%', style: const TextStyle(color: CamiColors.roseDeep, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  color: CamiColors.roseDeep,
                  backgroundColor: CamiColors.blush,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final subject in subjects) _card(context, store, subject),
        const SizedBox(height: 4),
        _game(context, store),
      ],
    );
  }

  Widget _card(BuildContext context, Store store, String subject) {
    final s = context.l10n;
    final tasks = store.tasksFor(subject, store.todayKey);
    final done = tasks.where((t) => store.done(store.todayKey, t.id)).length;
    final pending = tasks.where((t) => !store.done(store.todayKey, t.id)).toList();
    final current = pending.isEmpty ? null : pending.first;
    final label = s.subject(subject);
    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      onTap: () {
        if (subject == '英语') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const EnglishPage()));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectPage(subject: subject)));
        }
      },
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        leading: RoseAvatar(size: 52, label: label.substring(0, 1), pale: true),
        title: Text(
          label,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.1),
        ),
        subtitle: Text(
          current == null
              ? s.allFinishedCount(done, tasks.length)
              : s.nextTask(s.taskTitle(current.id, current.title), done, tasks.length),
          style: const TextStyle(fontSize: 13),
        ),
        trailing: current == null
            ? Image.asset(CamiAssets.rosePale, width: 28, height: 28)
            : FilledButton(
                onPressed: () => _open(context, current),
                child: Text(s.start),
              ),
      ),
    );
  }

  void _open(BuildContext context, dynamic task) {
    if (task.englishSpecial == true) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const EnglishPage()));
      return;
    }
    _openTask(context, task as TaskTemplate);
  }

  Widget _game(BuildContext context, Store store) {
    final s = context.l10n;
    if (kListAllGamesForTest) {
      return GlassPanel(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.gameTestTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 4),
            Text(s.gameTestHint, style: const TextStyle(color: CamiColors.muted, fontSize: 12)),
            const SizedBox(height: 12),
            for (final kind in GameKind.values) ...[
              RoseButton(
                label: s.gameName(kind),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PlayPage(kind: kind, testing: true)),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      );
    }

    final key = store.todayKey;
    final game = s.gameName(store.todayGame());
    if (store.playable(key)) {
      final remain = store.playSecondsLeftToday(key);
      final mins = remain ~/ 60;
      final secs = remain % 60;
      final clock = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
      final remainText = remain >= playBudgetSeconds ? s.playTenMinutes : s.playRemain(clock);
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 190,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(CamiAssets.roseBg, fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      CamiColors.roseDeep.withValues(alpha: 0.88),
                      CamiColors.rose.withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: -16,
                bottom: -24,
                child: Image.asset(CamiAssets.roseFlower, width: 150, height: 150),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.todaysPick, style: const TextStyle(color: Colors.white)),
                    Text(game, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                    Text(remainText, style: const TextStyle(color: Colors.white)),
                    const Spacer(),
                    RoseButton(
                      label: remain >= playBudgetSeconds ? s.playStart : s.playContinue,
                      filled: false,
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PlayPage(kind: store.todayGame())),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    final exhausted = store.playExhausted(key);
    return GlassPanel(
      child: Row(
        children: [
          Image.asset(CamiAssets.roseBadge, width: 72, height: 72, fit: BoxFit.cover),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exhausted ? s.playTimeUsedUp : s.gameLocked,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  exhausted ? s.playTomorrow : s.gameUnlockNeed,
                  style: const TextStyle(color: CamiColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _openTask(BuildContext context, TaskTemplate task) {
  final isVocab = task.id == vocabTaskId || task.title.contains('单词');
  final isPoem = isPoemTaskIdTitle(task.id, task.title);
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) {
        if (isVocab) return const VocabPage();
        if (isPoem) return PoemPage(task: task);
        return TaskPage(task: task);
      },
    ),
  );
}

class SubjectPage extends StatelessWidget {
  const SubjectPage({super.key, required this.subject});
  final String subject;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final s = context.l10n;
    final label = s.subject(subject);
    final tasks = store.tasksFor(subject, store.todayKey);
    final done = tasks.where((t) => store.done(store.todayKey, t.id)).length;
    return RoseBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, title: Text(label)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            RoseHeroBanner(title: label, subtitle: s.subjectProgress(done, tasks.length), height: 120),
            const SizedBox(height: 12),
            for (final task in tasks)
              GlassPanel(
                margin: const EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: store.done(store.todayKey, task.id)
                      ? Image.asset(CamiAssets.rosePale, width: 28, height: 28)
                      : const Icon(Icons.circle_outlined, color: CamiColors.line),
                  title: Text(s.taskTitle(task.id, task.title)),
                  subtitle: Text(
                    (task.id == vocabTaskId || task.title.contains('单词'))
                        ? store.vocabTodayBadge()
                        : (isPoemTaskIdTitle(task.id, task.title)
                            ? store.poemTodayBadge()
                            : taskMeta(task, s)),
                  ),
                  trailing: store.done(store.todayKey, task.id)
                      ? TextButton(
                          onPressed: () => _openTask(context, task),
                          child: Text(s.view),
                        )
                      : FilledButton(
                          onPressed: () => _openTask(context, task),
                          child: Text(task.schoolOnly ? s.checkOff : s.start),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
