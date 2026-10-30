import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'storage/files.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// 按语数英其他分组，作业下可展开看照片/视频/录音。
class TaskDaySections extends StatelessWidget {
  const TaskDaySections({super.key, required this.date});
  final String date;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final subject in subjects) ...[
          SubjectProgressHeader(subject: subject, date: date),
          for (final task in store.tasksFor(subject, date))
            TaskExpandTile(task: task, date: date),
          if (store.tasksFor(subject, date).isNotEmpty) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class SubjectProgressHeader extends StatelessWidget {
  const SubjectProgressHeader({super.key, required this.subject, required this.date});
  final String subject;
  final String date;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final tasks = store.tasksFor(subject, date);
    if (tasks.isEmpty) return const SizedBox.shrink();
    final done = tasks.where((t) => store.done(date, t.id)).length;
    final points = tasks.fold<int>(0, (sum, t) {
      if (!store.done(date, t.id)) return sum;
      return sum + (store.progress(date, t.id)?.points ?? 0);
    });
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
      child: Row(
        children: [
          RoseAvatar(size: 36, label: subject.substring(0, 1), pale: true),
          const SizedBox(width: 10),
          Expanded(
            child: Text(subject, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ),
          Text(
            '$done/${tasks.length} · $points 分',
            style: const TextStyle(color: CamiColors.roseDeep, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class TaskExpandTile extends StatelessWidget {
  const TaskExpandTile({super.key, required this.task, required this.date});
  final TaskTemplate task;
  final String date;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final row = store.progress(date, task.id);
    final media = row?.media ?? const [];
    final done = store.done(date, task.id);
    final points = done ? '${row?.points ?? 0} 分' : '未完成';
    final kindHint = media.isEmpty
        ? (done ? '没有附件' : '还没开始')
        : '${media.length} 个附件，点箭头查看';

    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 2, 10, 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          enabled: media.isNotEmpty,
          leading: done
              ? Image.asset(CamiAssets.rosePale, width: 28, height: 28)
              : const Icon(Icons.circle_outlined, color: CamiColors.line),
          title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(kindHint, style: const TextStyle(fontSize: 12, color: CamiColors.muted)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(points, style: TextStyle(color: done ? CamiColors.roseDeep : CamiColors.muted, fontWeight: FontWeight.w700)),
              if (media.isNotEmpty) ...[
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, color: CamiColors.roseDeep),
              ],
            ],
          ),
          children: [
            for (final item in media)
              _MediaPreview(
                item: item,
                date: date,
                taskId: task.id,
                serverUrl: store.serverUrl,
                token: store.serverToken,
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({
    required this.item,
    required this.date,
    required this.taskId,
    required this.serverUrl,
    required this.token,
  });

  final MediaItem item;
  final String date;
  final String taskId;
  final String serverUrl;
  final String token;

  String get _kindLabel =>
      item.kind == 'photo' ? '照片' : item.kind == 'video' ? '视频' : '录音';

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除$_kindLabel？'),
        content: Text(item.label.isEmpty ? '删掉后不能恢复。' : '删掉「${item.label}」后不能恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: CamiColors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<Store>().deleteMedia(date: date, taskId: taskId, mediaId: item.id);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label.isEmpty ? _kindLabel : item.label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              IconButton(
                tooltip: '删除',
                visualDensity: VisualDensity.compact,
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline, color: CamiColors.red),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: CamiColors.blush,
              child: SizedBox(
                width: double.infinity,
                height: item.kind == 'audio' ? 96 : 180,
                child: mediaView(
                  kind: item.kind,
                  path: item.path,
                  filename: item.storedName,
                  serverUrl: serverUrl,
                  token: token,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
