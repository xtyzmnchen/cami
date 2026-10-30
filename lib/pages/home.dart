import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic.dart';
import '../models.dart';
import '../services/voice.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'english_page.dart';
import 'focus_page.dart';
import 'parent_page.dart';
import 'play.dart';
import 'task_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  String _hello(DateTime now) {
    final hour = now.hour;
    if (hour < 5) return '夜深了';
    if (hour < 11) return '早安';
    if (hour < 13) return '中午好';
    if (hour < 18) return '下午好';
    if (hour < 22) return '晚上好';
    return '夜深了';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
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
                  Text('${today.month}月${today.day}日', style: const TextStyle(color: CamiColors.muted)),
                  Text('${_hello(today)}，${store.data.childName}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusPage())),
              icon: const Icon(Icons.timer_outlined, color: CamiColors.roseDeep),
              tooltip: '番茄钟',
            ),
            Material(
              color: Colors.white.withValues(alpha: 0.75),
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: () async {
                  if (await askPin(context) && context.mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ParentPage()));
                  } else if (context.mounted) {
                    toast(context, '密码不对');
                  }
                },
                icon: const Icon(Icons.lock_outline, color: CamiColors.roseDeep),
                tooltip: '家长',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RoseHeroBanner(
          title: doneCount == all.length ? '今天都做完了' : '还差 ${all.length - doneCount} 件',
          subtitle: '做完今天这 ${all.length} 件，小游戏才会亮',
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
    final tasks = store.tasksFor(subject, store.todayKey);
    final done = tasks.where((t) => store.done(store.todayKey, t.id)).length;
    final pending = tasks.where((t) => !store.done(store.todayKey, t.id)).toList();
    final current = pending.isEmpty ? null : pending.first;
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
        leading: RoseAvatar(size: 52, label: subject.substring(0, 1), pale: true),
        title: Text(
          subject,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.1),
        ),
        subtitle: Text(
          current == null ? '都完成了 · $done/${tasks.length}' : '下一件 · ${current.title} · $done/${tasks.length}',
          style: const TextStyle(fontSize: 13),
        ),
        trailing: current == null
            ? Image.asset(CamiAssets.rosePale, width: 28, height: 28)
            : FilledButton(
                onPressed: () => _open(context, current),
                child: const Text('开始'),
              ),
      ),
    );
  }

  void _open(BuildContext context, dynamic task) {
    if (task.englishSpecial == true) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const EnglishPage()));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => TaskPage(task: task)));
  }

  Widget _game(BuildContext context, Store store) {
    final key = store.todayKey;
    final game = gameTitles[store.todayGame()]!;
    if (store.playable(key)) {
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
                    const Text('今天抽到', style: TextStyle(color: Colors.white)),
                    Text(game, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                    const Text('可以玩 10 分钟', style: TextStyle(color: Colors.white)),
                    const Spacer(),
                    RoseButton(
                      label: '开始玩',
                      filled: false,
                      onPressed: () async {
                        final played = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => PlayPage(kind: store.todayGame())),
                        );
                        if (played == true && context.mounted) {
                          await _askBonus(context);
                        }
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
    final hint = store.addableBonus(key)
        ? '再做完一件新任务，可以再玩 10 分钟'
        : '14 件都做完，这里才会亮';
    return GlassPanel(
      child: Row(
        children: [
          Image.asset(CamiAssets.roseBadge, width: 72, height: 72, fit: BoxFit.cover),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.addableBonus(key) ? '这轮已经玩过了' : '小游戏还没亮', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(hint, style: const TextStyle(color: CamiColors.muted)),
                if (store.addableBonus(key))
                  TextButton(onPressed: () => _askBonus(context), child: const Text('接受新任务')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _askBonus(BuildContext context) async {
    final store = context.read<Store>();
    await Voice.say('要不要接受一件新任务？');
    if (!context.mounted) return;
    final accept = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('要不要接受一件新任务？'),
        content: const Text('接受后说出来就行，不用打字。做完这件，小游戏可以再开一次。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('今天就到这里')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('接受')),
        ],
      ),
    );
    if (accept != true || !context.mounted) return;
    final heard = await Voice.listen();
    if (!context.mounted) return;
    if (heard == null) {
      toast(context, '没听清，再说一次');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('听到的是'),
        content: Text(heard),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('再说一次')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('就这件')),
        ],
      ),
    );
    if (ok == true) {
      await store.addBonus(store.todayKey, heard);
      if (context.mounted) toast(context, '已加到其他。做完就能再玩游戏');
    }
  }
}

class SubjectPage extends StatelessWidget {
  const SubjectPage({super.key, required this.subject});
  final String subject;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final tasks = store.tasksFor(subject, store.todayKey);
    final done = tasks.where((t) => store.done(store.todayKey, t.id)).length;
    return RoseBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, title: Text(subject)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            RoseHeroBanner(title: subject, subtitle: '$done / ${tasks.length} 已完成', height: 120),
            const SizedBox(height: 12),
            for (final task in tasks)
              GlassPanel(
                margin: const EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: store.done(store.todayKey, task.id)
                      ? Image.asset(CamiAssets.rosePale, width: 28, height: 28)
                      : const Icon(Icons.circle_outlined, color: CamiColors.line),
                  title: Text(task.title),
                  subtitle: Text(taskMeta(task)),
                  trailing: store.done(store.todayKey, task.id)
                      ? null
                      : FilledButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskPage(task: task))),
                          child: Text(task.schoolOnly ? '打勾' : '开始'),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
