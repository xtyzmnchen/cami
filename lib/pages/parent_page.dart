import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic.dart';
import '../models.dart';
import '../storage/files.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';


class ParentPage extends StatelessWidget {
  const ParentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: RoseBackdrop(
        intensity: 0.28,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('家长'),
            bottom: const TabBar(
              tabs: [
                Tab(text: '批改'),
                Tab(text: '任务'),
                Tab(text: '兑换'),
                Tab(text: '设置'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              _ReviewTab(),
              _TasksTab(),
              _RewardsTab(),
              _SettingsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewTab extends StatefulWidget {
  const _ReviewTab();

  @override
  State<_ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<_ReviewTab> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<Store>().syncPull();
    });
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      context.read<Store>().syncPull();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final key = store.todayKey;
    final tasks = tasksOn(store.data, key);
    final waiting = tasks.where((t) {
      final row = store.progress(key, t.id);
      return row != null && row.media.isNotEmpty && !row.done;
    }).length;
    final sync = store.lastSync == null
        ? '还没同步'
        : '上次同步 ${store.lastSync!.hour}:${store.lastSync!.minute.toString().padLeft(2, '0')}';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('今天 ${store.pointsOn(key)} 分 · 待看 $waiting 件', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    store.syncError ?? sync,
                    style: TextStyle(color: store.syncError != null ? CamiColors.red : CamiColors.muted),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: store.syncing ? null : () => store.syncPull(),
              icon: store.syncing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: Text(store.syncing ? '同步中' : '刷新'),
            ),
          ],
        ),
        Text('本月 ${monthPoints(store.data, DateTime.now().year, DateTime.now().month)} 分', style: const TextStyle(color: CamiColors.muted)),
        const SizedBox(height: 8),
        for (final task in tasks)
          Card(
            child: ListTile(
              title: Text(task.title),
              subtitle: Text(_line(store, key, task)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _GradePage(task: task, date: key))),
            ),
          ),
      ],
    );
  }

  String _line(Store store, String date, TaskTemplate task) {
    final row = store.progress(date, task.id);
    if (row == null) return '还没开始 · 预设 ${task.points} 分';
    if (!row.done) {
      if (row.media.isEmpty) return '还没交内容 · 预设 ${task.points} 分';
      return '有内容，还没算完成 · ${row.media.length} 个文件';
    }
    return '已完成 ${row.points} 分${row.comment.isEmpty ? '' : ' · ${row.comment}'}';
  }
}

class _GradePage extends StatefulWidget {
  const _GradePage({required this.task, required this.date});
  final TaskTemplate task;
  final String date;

  @override
  State<_GradePage> createState() => _GradePageState();
}

class _GradePageState extends State<_GradePage> {
  late int points;
  late final TextEditingController comment;

  @override
  void initState() {
    super.initState();
    final store = context.read<Store>();
    final row = store.progress(widget.date, widget.task.id);
    points = row?.points == 0 ? widget.task.points : (row?.points ?? widget.task.points);
    comment = TextEditingController(text: row?.comment ?? '');
  }

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final row = store.progress(widget.date, widget.task.id);
    return Scaffold(
      appBar: AppBar(title: Text(widget.task.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (row == null || row.media.isEmpty)
            const Text('还没有照片、视频或录音', style: TextStyle(color: CamiColors.muted))
          else
            for (final media in row.media) ...[
              Text(media.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (media.noteZh.isNotEmpty) Text(media.noteZh),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 220,
                  child: mediaView(
                    kind: media.kind,
                    path: media.path,
                    filename: media.storedName,
                    serverUrl: store.serverUrl,
                    token: store.serverToken,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          const Text('给这件打几分'),
          Wrap(
            spacing: 8,
            children: [
              for (var n = 1; n <= 5; n++)
                ChoiceChip(label: Text('$n'), selected: points == n, onSelected: (_) => setState(() => points = n)),
            ],
          ),
          TextField(controller: comment, decoration: const InputDecoration(labelText: '评语，可以空着')),
          const SizedBox(height: 12),
          RoseButton(
            label: '记下分数',
            onPressed: () async {
              await store.setScore(widget.date, widget.task.id, points, comment.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
          ),
          if (widget.task.schoolOnly)
            TextButton(
              onPressed: () async {
                await store.parentConfirmSchool(widget.date, widget.task.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('人在学校，家长代勾'),
            ),
          TextButton(
            onPressed: () async {
              await store.sendBack(widget.date, widget.task.id, comment.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('退回，让她再做一次'),
          ),
        ],
      ),
    );
  }
}

class _TasksTab extends StatelessWidget {
  const _TasksTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final fixed = store.data.tasks.where((t) => !t.bonus).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('保存之后，就是每天要做的全部', style: TextStyle(color: CamiColors.muted)),
        for (final task in fixed)
          ListTile(
            title: Text(task.title),
            subtitle: Text('${task.subject} · ${taskMeta(task)}'),
            trailing: const Icon(Icons.edit),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _EditTaskPage(task: task))),
          ),
        RoseButton(
          label: '添加一项',
          onPressed: () {
            final task = TaskTemplate(
              id: store.newId(),
              subject: '语文',
              title: '新的一项',
              minutes: 10,
              points: 3,
            );
            Navigator.push(context, MaterialPageRoute(builder: (_) => _EditTaskPage(task: task, fresh: true)));
          },
        ),
      ],
    );
  }
}

class _EditTaskPage extends StatefulWidget {
  const _EditTaskPage({required this.task, this.fresh = false});
  final TaskTemplate task;
  final bool fresh;

  @override
  State<_EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<_EditTaskPage> {
  late final title = TextEditingController(text: widget.task.title);
  late String subject = widget.task.subject;
  late int minutes = widget.task.minutes == 0 ? 10 : widget.task.minutes;
  late int points = widget.task.points;
  late bool school = widget.task.schoolOnly;
  late bool english = widget.task.englishSpecial;

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑任务')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: '名称')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final name in subjects)
                ChoiceChip(label: Text(name), selected: subject == name, onSelected: (_) => setState(() => subject = name)),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('在学校完成，只打勾'),
            value: school,
            onChanged: (v) => setState(() => school = v),
          ),
          if (!school) ...[
            const Text('时长（分钟）'),
            Wrap(
              spacing: 8,
              children: [
                for (final n in minuteChoices)
                  ChoiceChip(label: Text('$n'), selected: minutes == n, onSelected: (_) => setState(() => minutes = n)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Text('完成可得几分'),
          Wrap(
            spacing: 8,
            children: [
              for (var n = 1; n <= 5; n++)
                ChoiceChip(label: Text('$n'), selected: points == n, onSelected: (_) => setState(() => points = n)),
            ],
          ),
          if (subject == '英语')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('这是英语打卡，要选类型并录音'),
              value: english,
              onChanged: (v) => setState(() => english = v),
            ),
          const SizedBox(height: 12),
          RoseButton(
            label: '保存',
            onPressed: () async {
              widget.task
                ..title = title.text.trim().isEmpty ? '未命名' : title.text.trim()
                ..subject = subject
                ..minutes = school ? 0 : minutes
                ..points = points
                ..schoolOnly = school
                ..englishSpecial = subject == '英语' && english;
              await context.read<Store>().saveTask(widget.task);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          if (!widget.fresh)
            TextButton(
              onPressed: () async {
                await context.read<Store>().deleteTask(widget.task.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('删除这件'),
            ),
        ],
      ),
    );
  }
}

class _RewardsTab extends StatelessWidget {
  const _RewardsTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('可用 ${store.balance} 分 · 已兑换 ${store.spent} 分', style: const TextStyle(fontWeight: FontWeight.w700)),
        for (final reward in store.data.rewards)
          ListTile(
            title: Text(reward.title),
            subtitle: Text('${reward.cost} 分'),
            trailing: FilledButton(
              onPressed: () {
                final error = store.redeem(reward.id);
                toast(context, error ?? '已兑换 ${reward.title}');
              },
              child: const Text('兑换'),
            ),
            onLongPress: () => store.deleteReward(reward.id),
          ),
        RoseButton(
          label: '添加一个奖励',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _NewRewardPage())),
        ),
        const SizedBox(height: 12),
        const Text('兑换记录', style: TextStyle(fontWeight: FontWeight.w700)),
        for (final item in store.data.redemptions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.title),
            trailing: Text('-${item.cost}'),
          ),
      ],
    );
  }
}

class _NewRewardPage extends StatefulWidget {
  const _NewRewardPage();

  @override
  State<_NewRewardPage> createState() => _NewRewardPageState();
}

class _NewRewardPageState extends State<_NewRewardPage> {
  final title = TextEditingController();
  var cost = 10;

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新奖励')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: '奖励名称')),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('需要'),
                Expanded(
                  child: Slider(
                    value: cost.toDouble(),
                    min: 1,
                    max: 100,
                    divisions: 99,
                    label: '$cost',
                    onChanged: (v) => setState(() => cost = v.round()),
                  ),
                ),
                Text('$cost 分'),
              ],
            ),
            RoseButton(
              label: '保存',
              onPressed: () async {
                await context.read<Store>().saveReward(Reward(
                      id: context.read<Store>().newId(),
                      title: title.text.trim().isEmpty ? '小奖励' : title.text.trim(),
                      cost: cost,
                    ));
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTab extends StatefulWidget {
  const _SettingsTab();

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late final name = TextEditingController();
  late final url = TextEditingController();
  late final token = TextEditingController();
  late final pin = TextEditingController();

  @override
  void initState() {
    super.initState();
    final store = context.read<Store>();
    name.text = store.data.childName;
    url.text = store.serverUrl;
    token.text = store.serverToken;
  }

  @override
  void dispose() {
    name.dispose();
    url.dispose();
    token.dispose();
    pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final sync = store.lastSync == null ? '还没同步' : '上次同步 ${store.lastSync!.hour}:${store.lastSync!.minute.toString().padLeft(2, '0')}';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: '孩子的名字')),
        const SizedBox(height: 8),
        RoseButton(label: '保存名字', onPressed: () => store.setChildName(name.text)),
        const Divider(height: 32),
        const Text('同步电脑（家里或公司都行）', style: TextStyle(fontWeight: FontWeight.w700)),
        const Text(
          '1. 在这台电脑项目目录运行：dart run tool/server.dart\n'
          '2. 用 cpolar 把本机 8787 端口映射成公网地址\n'
          '3. 小孩手机和家长手机都填同一个地址与口令\n'
          '4. 小孩点「完成」后会自动上传；家长打开批改页会自动刷新',
          style: TextStyle(color: CamiColors.muted, height: 1.45),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: url,
          decoration: const InputDecoration(
            labelText: '同步地址',
            hintText: '例如 https://xxxx.cpolar.cn',
          ),
        ),
        TextField(controller: token, decoration: const InputDecoration(labelText: '口令（默认 cami-home）')),
        const SizedBox(height: 8),
        RoseButton(
          label: '保存地址',
          onPressed: () async {
            await store.setServer(url.text, token.text);
            if (context.mounted) toast(context, '地址已保存');
          },
        ),
        const SizedBox(height: 8),
        RoseButton(
          label: store.syncing ? '正在同步' : '现在上传到同步电脑',
          onPressed: store.syncing ? null : () => store.syncPush(),
        ),
        const SizedBox(height: 8),
        RoseButton(
          label: '从同步电脑拉取',
          filled: false,
          onPressed: store.syncing ? null : () => store.syncPull(),
        ),
        Text(store.syncError ?? sync, style: TextStyle(color: store.syncError != null ? CamiColors.red : CamiColors.muted)),
        const Divider(height: 32),
        TextField(controller: pin, keyboardType: TextInputType.number, maxLength: 4, obscureText: true, decoration: const InputDecoration(labelText: '新的四位密码')),
        RoseButton(
          label: '修改密码',
          onPressed: () async {
            if (pin.text.length != 4) {
              toast(context, '请输入四位数字');
              return;
            }
            await store.setPin(pin.text);
            if (context.mounted) toast(context, '密码已改');
          },
        ),
      ],
    );
  }
}
