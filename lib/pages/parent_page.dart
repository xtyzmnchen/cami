import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/l10n.dart';
import '../logic.dart';
import '../models.dart';
import '../storage/files.dart';
import '../store.dart';
import '../sync_qr.dart';
import '../theme.dart';
import '../widgets.dart';
import 'server_scan_page.dart';

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
    final s = context.l10n;
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
          title: Text(s.parentTitle(name)),
          actions: [
            TextButton.icon(
              onPressed: () => store.setParentMode(false),
              icon: const Icon(Icons.child_care_outlined),
              label: Text(s.studentMode),
            ),
          ],
        ),
        body: SafeArea(child: pages[index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.fact_check_outlined), selectedIcon: const Icon(Icons.fact_check), label: s.navReview),
            NavigationDestination(icon: const Icon(Icons.checklist_outlined), selectedIcon: const Icon(Icons.checklist), label: s.navTasks),
            NavigationDestination(icon: const Icon(Icons.card_giftcard_outlined), selectedIcon: const Icon(Icons.card_giftcard), label: s.navRewards),
            NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: s.navSettings),
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

  String _line(BuildContext context, Store store, String date, TaskTemplate task) {
    final s = context.l10n;
    final row = store.progress(date, task.id);
    if (row == null) return s.notStarted(task.points);
    if (!row.done) {
      if (row.media.isEmpty) return s.noSubmit(task.points);
      return s.pendingReview(row.media.length);
    }
    return s.finishedPts(row.points, row.comment);
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
        ? context.l10n.neverSynced
        : context.l10n.lastSynced('${store.lastSync!.hour}:${store.lastSync!.minute.toString().padLeft(2, '0')}');

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
                      context.l10n.todayPtsWaiting(store.pointsOn(key), waiting),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    Text(
                      store.syncError ?? sync,
                      style: TextStyle(color: store.syncError != null ? CamiColors.red : CamiColors.muted, fontSize: 12),
                    ),
                    Text(
                      context.l10n.monthPtsOnly(monthPoints(store.data, DateTime.now().year, DateTime.now().month)),
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
                label: Text(store.syncing ? context.l10n.syncing : context.l10n.refresh),
              ),
            ],
          ),
        ),
        if (waiting > 0) ...[
          const SizedBox(height: 12),
          Text(context.l10n.priorityReview, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 6),
          for (final task in all.where((t) {
            final row = store.progress(key, t.id);
            return row != null && row.media.isNotEmpty && !row.done;
          }))
            Card(
              color: const Color(0xFFFFF3D6),
              child: ListTile(
                leading: RoseAvatar(
                  size: 36,
                  label: context.l10n.subject(task.subject).substring(0, 1),
                  pale: true,
                ),
                title: Text(
                  context.l10n.taskTitle(task.id, task.title),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${context.l10n.subject(task.subject)} · ${_line(context, store, key, task)}'),
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
                RoseAvatar(
                  size: 34,
                  label: context.l10n.subject(subject).substring(0, 1),
                  pale: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.subject(subject),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
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
                title: Text(
                  context.l10n.taskTitle(task.id, task.title),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(_line(context, store, key, task)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GradeTaskPage(task: task, date: key)),
                ),
              ),
            ),
          if (store.tasksFor(subject, key).isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text(context.l10n.noTasksTodaySubject, style: const TextStyle(color: CamiColors.muted)),
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
      appBar: AppBar(
        title: Text(
          '${context.l10n.subject(widget.task.subject)} · ${context.l10n.taskTitle(widget.task.id, widget.task.title)}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (row == null || row.media.isEmpty)
            Text(context.l10n.noMediaYet, style: const TextStyle(color: CamiColors.muted))
          else
            for (final media in row.media) ...[
              Text(
                media.label.isEmpty
                    ? (media.kind == 'photo'
                        ? context.l10n.photo
                        : media.kind == 'video'
                            ? context.l10n.video
                            : context.l10n.audio)
                    : context.l10n.mediaLabel(media.label),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
          Text(context.l10n.scoreThisTask, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var n = 1; n <= 5; n++)
                ChoiceChip(label: Text('$n'), selected: points == n, onSelected: (_) => setState(() => points = n)),
            ],
          ),
          TextField(controller: comment, decoration: InputDecoration(labelText: context.l10n.commentOptional)),
          const SizedBox(height: 12),
          RoseButton(
            label: context.l10n.saveScore,
            onPressed: () async {
              await store.setScore(widget.date, widget.task.id, points, comment.text.trim());
              if (context.mounted) {
                toast(context, context.l10n.scoreSaved);
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
              child: Text(context.l10n.schoolProxyCheck),
            ),
          TextButton(
            onPressed: () async {
              await store.sendBack(widget.date, widget.task.id, comment.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(context.l10n.sendBack),
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
        Text(context.l10n.manageTasksBySubject, style: const TextStyle(color: CamiColors.muted)),
        for (final subject in subjects) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
            child: Row(
              children: [
                RoseAvatar(
                  size: 34,
                  label: context.l10n.subject(subject).substring(0, 1),
                  pale: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.subject(subject),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  context.l10n.itemsCount(fixed.where((t) => t.subject == subject).length),
                  style: const TextStyle(color: CamiColors.roseDeep, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          for (final task in fixed.where((t) => t.subject == subject))
            Card(
              child: ListTile(
                title: Text(
                  context.l10n.taskTitle(task.id, task.title),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(taskMeta(task, context.l10n)),
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
                  title: context.l10n.isEn ? '新的一项' : context.l10n.newItem,
                  minutes: 10,
                  points: 3,
                );
                Navigator.push(context, MaterialPageRoute(builder: (_) => EditTaskPage(task: task, fresh: true)));
              },
              icon: const Icon(Icons.add),
              label: Text(context.l10n.addForSubject(context.l10n.subject(subject))),
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
  late final title = TextEditingController();
  late String subject = widget.task.subject;
  late int minutes = widget.task.minutes == 0 ? 10 : widget.task.minutes;
  late int points = widget.task.points;
  late bool school = widget.task.schoolOnly;
  late bool english = widget.task.englishSpecial;
  var _titleReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_titleReady) return;
    _titleReady = true;
    title.text = context.l10n.displayTaskTitle(widget.task.id, widget.task.title);
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(widget.fresh ? s.addTask : s.editTask)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: title, decoration: InputDecoration(labelText: s.taskName)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final name in subjects)
                ChoiceChip(
                  label: Text(s.subject(name)),
                  selected: subject == name,
                  onSelected: (_) => setState(() => subject = name),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.schoolOnlyToggle),
            value: school,
            onChanged: (v) => setState(() => school = v),
          ),
          if (!school) ...[
            Text(s.durationMinutes),
            Wrap(
              spacing: 8,
              children: [
                for (final n in minuteChoices)
                  ChoiceChip(label: Text('$n'), selected: minutes == n, onSelected: (_) => setState(() => minutes = n)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(s.pointsOnComplete),
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
              title: Text(s.englishSpecialToggle),
              value: english,
              onChanged: (v) => setState(() => english = v),
            ),
          const SizedBox(height: 12),
          RoseButton(
            label: s.save,
            onPressed: () async {
              widget.task
                ..title = s.canonicalTaskTitle(widget.task.id, title.text)
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
              child: Text(s.deleteThis),
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
        Text(context.l10n.balanceSpent(store.balance, store.spent), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        for (final reward in store.data.rewards)
          Card(
            child: ListTile(
              title: Text(context.l10n.rewardTitle(reward.id, reward.title), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(context.l10n.pts(reward.cost)),
              trailing: FilledButton(
                onPressed: () {
                  final error = store.redeem(reward.id);
                  toast(context, error ?? context.l10n.redeemedTitle(context.l10n.rewardTitle(reward.id, reward.title)));
                },
                child: Text(context.l10n.redeem),
              ),
              onLongPress: () => store.deleteReward(reward.id),
            ),
          ),
        RoseButton(
          label: context.l10n.addReward,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _NewRewardPage())),
        ),
        const SizedBox(height: 12),
        Text(context.l10n.redeemHistory, style: const TextStyle(fontWeight: FontWeight.w700)),
        for (final item in store.data.redemptions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.rewardTitle('', item.title)),
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
      appBar: AppBar(title: Text(context.l10n.newReward)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: title, decoration: InputDecoration(labelText: context.l10n.rewardName)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(context.l10n.needs),
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
                Text(context.l10n.pts(cost)),
              ],
            ),
            RoseButton(
              label: context.l10n.save,
              onPressed: () async {
                await context.read<Store>().saveReward(Reward(
                      id: context.read<Store>().newId(),
                      title: title.text.trim().isEmpty ? context.l10n.littleReward : title.text.trim(),
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
    final s = context.l10n;
    final hm = store.lastSync == null
        ? null
        : '${store.lastSync!.hour}:${store.lastSync!.minute.toString().padLeft(2, '0')}';
    final sync = hm == null ? s.neverSynced : s.lastSynced(hm);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(s.language, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 4),
        Text(s.languageHint, style: const TextStyle(color: CamiColors.muted, height: 1.4)),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'zh', label: Text(s.languageZh), icon: const Icon(Icons.translate)),
            ButtonSegment(value: 'en', label: Text(s.languageEn), icon: const Icon(Icons.language)),
          ],
          selected: {store.localeCode},
          onSelectionChanged: (set) {
            final code = set.first;
            store.setLocaleCode(code);
          },
        ),
        const Divider(height: 32),
        RoseButton(
          label: s.switchToStudent,
          onPressed: () => store.setParentMode(false),
        ),
        const Divider(height: 32),
        if (store.profile != null) ...[
          Text(s.currentAccount(store.profile!.phone), style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
            '${store.profile!.name} · ${store.profile!.age}${s.tr('岁', 'y')} · ${s.gradeName(store.profile!.grade)}'
            '${store.profile!.interests.isEmpty ? '' : ' · ${s.interestsLine(store.profile!.interests)}'}',
            style: const TextStyle(color: CamiColors.muted),
          ),
          const SizedBox(height: 8),
          RoseButton(
            label: s.logout,
            filled: false,
            onPressed: () async {
              await store.logout();
              if (context.mounted) toast(context, s.loggedOut);
            },
          ),
          const Divider(height: 32),
        ],
        TextField(controller: name, decoration: InputDecoration(labelText: s.childName)),
        const SizedBox(height: 8),
        RoseButton(label: s.saveName, onPressed: () => store.setChildName(name.text)),
        const Divider(height: 32),
        Text(s.syncComputer, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(s.syncHint, style: const TextStyle(color: CamiColors.muted, height: 1.45)),
        const SizedBox(height: 8),
        TextField(
          controller: url,
          decoration: InputDecoration(
            labelText: s.syncUrl,
            hintText: s.syncUrlHint,
            suffixIcon: IconButton(
              tooltip: s.scanQr,
              onPressed: () async {
                final endpoint = await Navigator.of(context).push<SyncEndpoint>(
                  MaterialPageRoute(builder: (_) => const ServerScanPage()),
                );
                if (!context.mounted || endpoint == null) return;
                setState(() {
                  url.text = endpoint.url;
                  token.text = endpoint.token;
                });
              },
              icon: const Icon(Icons.qr_code_scanner, color: CamiColors.roseDeep),
            ),
          ),
        ),
        TextField(controller: token, decoration: InputDecoration(labelText: s.syncToken)),
        const SizedBox(height: 8),
        RoseButton(
          label: s.saveUrl,
          onPressed: () async {
            await store.setServer(url.text, token.text);
            if (context.mounted) toast(context, s.urlSaved);
          },
        ),
        const SizedBox(height: 8),
        RoseButton(
          label: s.showSyncQr,
          filled: false,
          onPressed: () {
            final parsed = SyncEndpoint.tryParse(url.text);
            if (parsed == null) {
              toast(context, s.needValidUrl);
              return;
            }
            final tok = token.text.trim();
            final endpoint = SyncEndpoint(
              url: parsed.url,
              token: tok.isEmpty ? parsed.token : tok,
            );
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(s.syncQrTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.syncQrHint, style: const TextStyle(color: CamiColors.muted)),
                    const SizedBox(height: 16),
                    QrImageView(
                      data: endpoint.encode(),
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(endpoint.url, style: const TextStyle(fontSize: 12)),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close)),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        RoseButton(
          label: store.syncing ? s.syncing : s.uploadNow,
          onPressed: store.syncing
              ? null
              : () async {
                  await store.syncPush();
                  if (!context.mounted) return;
                  final err = context.read<Store>().syncError;
                  toast(context, err ?? s.uploaded);
                },
        ),
        const SizedBox(height: 8),
        RoseButton(
          label: s.pullNow,
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
          decoration: InputDecoration(labelText: s.newPin),
        ),
        RoseButton(
          label: s.changePin,
          onPressed: () async {
            if (pin.text.length != 4) {
              toast(context, s.pinNeedFour);
              return;
            }
            await store.setPin(pin.text);
            if (context.mounted) toast(context, s.pinChanged);
          },
        ),
      ],
    );
  }
}
