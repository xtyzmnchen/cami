import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/notify.dart';
import '../services/voice.dart';
import '../store.dart';
import '../task_day_view.dart';
import '../theme.dart';
import '../widgets.dart';
import 'task_page.dart';


class FocusPage extends StatefulWidget {
  const FocusPage({super.key});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  var minutes = 25;
  int? left;
  Timer? timer;

  @override
  void dispose() {
    timer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  bool get _focusing => left != null && left! > 0;

  Future<void> _start() async {
    final seconds = minutes * 60;
    setState(() => left = seconds);
    await WakelockPlus.enable();
    await Alerts.schedule(
      id: 88025,
      when: DateTime.now().add(Duration(seconds: seconds)),
      title: '时间到了',
      body: '专注了 $minutes 分钟',
    );
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || left == null) return;
      if (left! <= 1) {
        timer?.cancel();
        setState(() => left = 0);
        await WakelockPlus.disable();
        SystemSound.play(SystemSoundType.alert);
        await Voice.say('时间到了');
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AlarmPage(title: '时间到了', subtitle: '番茄钟结束了')),
          );
        }
        return;
      }
      setState(() => left = left! - 1);
    });
  }

  Future<void> _stopFocus() async {
    timer?.cancel();
    await Alerts.cancel(88025);
    await WakelockPlus.disable();
    if (!mounted) return;
    setState(() => left = null);
  }

  Future<bool> _confirmLeave() async {
    if (!_focusing) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('确定退出吗？'),
        content: const Text('番茄钟还在走，退出后这轮计时会停掉。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('继续专注')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: CamiColors.roseDeep),
            child: const Text('确定退出'),
          ),
        ],
      ),
    );
    if (ok == true) await _stopFocus();
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final total = minutes * 60;
    final clock = left == null
        ? '${minutes.toString().padLeft(2, '0')}:00'
        : '${(left! ~/ 60).toString().padLeft(2, '0')}:${(left! % 60).toString().padLeft(2, '0')}';
    final ringProgress = left == null ? 1.0 : left! / total;
    return PopScope(
      canPop: !_focusing,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_focusing) return;
        if (await _confirmLeave() && mounted) {
          Navigator.pop(context);
        }
      },
      child: RoseBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('番茄钟'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                if (await _confirmLeave() && mounted) Navigator.pop(context);
              },
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Spacer(),
                CountdownRing(label: clock, progress: ringProgress, size: 240, fontSize: 56),
                const SizedBox(height: 12),
                const Text('然后休息 5 分钟', style: TextStyle(color: CamiColors.muted)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final n in [10, 15, 20, 25, 30])
                      ChoiceChip(
                        label: Text('$n'),
                        selected: minutes == n,
                        onSelected: left == null ? (_) => setState(() => minutes = n) : null,
                      ),
                  ],
                ),
                const Spacer(),
                const Text('到点会叫你。按住小皇冠就能停下。', style: TextStyle(color: CamiColors.muted)),
                const SizedBox(height: 12),
                RoseButton(label: left == null ? '开始专注' : '正在专注', onPressed: left == null ? _start : null),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SummaryPage extends StatelessWidget {
  const SummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final key = store.todayKey;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        RoseHeroBanner(title: '今天 ${store.pointsOn(key)} 分', subtitle: '一日千里', height: 130),
        const SizedBox(height: 8),
        TaskDaySections(date: key),
      ],
    );
  }
}
