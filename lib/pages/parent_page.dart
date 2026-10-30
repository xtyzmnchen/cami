import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic.dart';
import '../models.dart';
import '../storage/files.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// 家长端主壳：底部直接放批改 / 任务 / 兑换 / 设置。
class ParentShell extends StatefulWidget {
  const ParentShell({super.key});

  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  var index = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final name = store.profile?.name ?? store.data.childName;
    final pages = [
      const ParentReviewPage(),
      const ParentTasksPage(),
      const ParentRewardsPage(),
      const ParentSettingsPage(),
    ];
    return RoseBackdrop(
      intensity: 0.28,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text('家长端 · $name'),
          actions: [
            TextButton.icon(
              onPressed: () => store.setParentMode(false),
              icon: const Icon(Icons.child_care_outlined),
              label: const Text('学生端'),
            ),
          ],
        ),
        body: SafeArea(child: pages[index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: '批改'),
            NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: '任务'),
            NavigationDestination(icon: Icon(Icons.card_giftcard_outlined), selectedIcon: Icon(Icons.card_giftcard), label: '兑换'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
          ],
        ),
      ),
    );
  }
}

@Deprecated('Use ParentShell')
class ParentPage extends StatelessWidget {
  const ParentPage({super.key});

  @override
  Widget build(BuildContext context) => const ParentShell();
}

class ParentReviewPage extends StatefulWidget {
  const ParentReviewPage({super.key});

  @override
  State<ParentReviewPage> createState() => _ParentReviewPageState();
}

class _ParentReviewPageState extends State<ParentReviewPage> {
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

  String _line(Store store, String date, TaskTemplate task) {
    final row = store.progress(date, task.id);
    if (row == null) return '还没开始 · 预设 ${task.points} 分';
    if (!row.done) {
      if (row.media.isEmpty) return '还没交内容 · 预设 ${task.points} 分';
      return '待批改 · ${row.media.length} 个附件';
    }
    return '已完成 ${row.points} 分${row.comment.isEmpty ? '' : ' · ${row.comment}'}';
  }

  Color? _tileColor(Store store, String date, TaskTemplate task) {
    final row = store.progress(date, task.id);
    if (row == null) return null;
    if (!row.done && row.media.isNotEmpty) return const Color(0xFFFFF3D6);
    if (row.done) return CamiColors.greenBg;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final key = store.todayKey;
    final all = tasksOn(store.data, key);
    final waiting = all.where((t) {
      final row = store.progress(key, t.id);
      return row != null && row.media.isNotEmpty && !row.done;
    }).length;
    final sync = store.lastSync == null
        ? '还没同步'
        : '上次同步 ${store.lastSync!.hour}:${store.lastSync!.minute.toString().padLeft(2, '0')}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        GlassPanel(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今天 ${store.pointsOn(key)} 分 · 待批改 $waiting 件',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    Text(
                      store.syncError ?? sync,
                      style: TextStyle(color: store.syncError != null ? CamiColors.red : CamiColors.muted, fontSize: 12),
                    ),
                    Text(
                      '本月 ${monthPoints(store.data, DateTime.now().year, DateTime.now().month)} 分',
                      style: const TextStyle(color: CamiColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: store.syncing ? null : () => store.syncPull(),
                icon: store.syncing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: Text(store.syncing ? '同步中' : '刷新'),
              ),
            ],
          ),
        ),
        if (waiting > 0) ...[
          const SizedBox(height: 12),
          const Text('优先待批改', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 6),
          for (final task in all.where((t) {
            final row = store.progress(key, t.id);
            return row != null && row.media.isNotEmpty && !row.done;
          }))
            Card(
              color: const Color(0xFFFFF3D6),
              child: ListTile(
                leading: RoseAvatar(size: 36, label: task.subject.substring(0, 1), pale: true),
                title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${task.subject} · ${_line(store, key, task)}'),
                trailing: const Icon(Icons.rate_review_outlined, color: CamiColors.roseDeep),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GradeTaskPage(task: task, date: key)),
                ),
              ),
            ),
        ],
        for (final subject in subjects) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
            child: Row(
              children: [
                RoseAvatar(size: 34, label: subject.substring(0, 1), pale: true),
                const SizedBox(width: 10),
                Expanded(child: Text(subject, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                Builder(
                  builder: (context) {
                    final list = store.tasksFor(subject, key);
                    final done = list.where((t) => store.done(key, t.id)).length;
                    return Text('$done/${list.length}', style: const TextStyle(color: CamiColors.roseDeep, fontWeight: FontWeight.w700));
                  },
                ),
              ],
            ),
          ),
          for (final task in store.tasksFor(subject, key))
            Card(
              color: _tileColor(store, key, task),
              child: ListTile(
                title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(_line(store, key, task)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GradeTaskPage(task: task, date: key)),
                ),
              ),
            ),
          if (store.tasksFor(subject, key).isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 8),
              child: Text('这科今天没有任务', style: TextStyle(color: CamiColors.muted)),
            ),
        ],
      ],
    );
  }
}

class GradeTaskPage extends StatefulWidget {
  const GradeTaskPage({super.key, required this.task, required this.date});
  final TaskTemplate task;
  final String date;

  @override
  State<GradeTaskPage> createState() => _GradeTaskPageState();
}

class _GradeTaskPageState extends State<GradeTaskPage> {
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
      appBar: AppBar(title: Text('${widget.task.subject} · ${widget.task.title}')),
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
                    session: store.sessionId,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          const Text('给这件打几分', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
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
              if (context.mounted) {
                toast(context, '已记下');
                Navigator.pop(context);
              }
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

class ParentTasksPage extends StatelessWidget {
  const ParentTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final fixed = store.data.tasks.where((t) => !t.bonus).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text('按学科管理每天要做的任务', style: TextStyle(color: CamiColors.muted)),
        for (final subject in subjects) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
            child: Row(
              children: [
                RoseAvatar(size: 34, label: subject.substring(0, 1), pale: true),
                const SizedBox(width: 10),
                Expanded(child: Text(subject, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                Text(
                  '${fixed.where((t) => t.subject == subject).length} 项',
                  style: const TextStyle(color: CamiColors.roseDeep, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          for (final task in fixed.where((t) => t.subject == subject))
            Card(
              child: ListTile(
                title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(taskMeta(task)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditTaskPage(task: task))),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                final task = TaskTemplate(
                  id: store.newId(),
                  subject: subject,
                  title: '新的一项',
                  minutes: 10,
                  points: 3,
                );
                Navigator.push(context, MaterialPageRoute(builder: (_) => EditTaskPage(task: task, fresh: true)));
              },
              icon: const Icon(Icons.add),
              label: Text('给$subject加一项'),
            ),
          ),
        ],
      ],
    );
  }
}

class EditTaskPage extends StatefulWidget {
  const EditTaskPage({super.key, required this.task, this.fresh = false});
  final TaskTemplate task;
  final bool fresh;

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
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
      appBar: AppBar(title: Text(widget.fresh ? '添加任务' : '编辑任务')),
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

class ParentRewardsPage extends StatelessWidget {
  const ParentRewardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('可用 ${store.balance} 分 · 已兑换 ${store.spent} 分', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        for (final reward in store.data.rewards)
          Card(
            child: ListTile(
              title: Text(reward.title, style: const TextStyle(fontWeight: FontWeight.w700)),
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

class ParentSettingsPage extends StatefulWidget {
  const ParentSettingsPage({super.key});

  @override
  State<ParentSettingsPage> createState() => _ParentSettingsPageState();
}

class _ParentSettingsPageState extends State<ParentSettingsPage> {
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
        RoseButton(
          label: '切回学生端',
          onPressed: () => store.setParentMode(false),
        ),
        const Divider(height: 32),
        if (store.profile != null) ...[
          Text('当前账号 ${store.profile!.phone}', style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
            '${store.profile!.name} · ${store.profile!.age}岁 · ${store.profile!.grade}'
            '${store.profile!.interests.isEmpty ? '' : ' · ${store.profile!.interests}'}',
            style: const TextStyle(color: CamiColors.muted),
          ),
          const SizedBox(height: 8),
          RoseButton(
            label: '退出登录',
            filled: false,
            onPressed: () async {
              await store.logout();
              if (context.mounted) toast(context, '已退出');
            },
          ),
          const Divider(height: 32),
        ],
        TextField(controller: name, decoration: const InputDecoration(labelText: '孩子的名字')),
        const SizedBox(height: 8),
        RoseButton(label: '保存名字', onPressed: () => store.setChildName(name.text)),
        const Divider(height: 32),
        const Text('同步电脑', style: TextStyle(fontWeight: FontWeight.w700)),
        const Text(
          '每个手机号的数据单独存放。批改前可点刷新拉取最新作业。',
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
          onPressed: store.syncing
              ? null
              : () async {
                  await store.syncPush();
                  if (!context.mounted) return;
                  final err = context.read<Store>().syncError;
                  toast(context, err ?? '已上传到同步电脑');
                },
        ),
        const SizedBox(height: 8),
        RoseButton(
          label: '从同步电脑拉取',
          filled: false,
          onPressed: store.syncing ? null : () => store.syncPull(),
        ),
        Text(store.syncError ?? sync, style: TextStyle(color: store.syncError != null ? CamiColors.red : CamiColors.muted)),
        const Divider(height: 32),
        TextField(
          controller: pin,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(labelText: '新的四位家长密码'),
        ),
        RoseButton(
          label: '修改家长密码',
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
