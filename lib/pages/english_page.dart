import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic.dart';
import '../models.dart';
import '../services/capture.dart';
import '../services/translate.dart';
import '../services/voice.dart';
import '../storage/files.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'task_page.dart';

class EnglishPage extends StatelessWidget {
  const EnglishPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final date = store.todayKey;
    final checkIn = store.englishCheckIn(date);
    final rest = store.tasksFor('英语', date).where((t) => t.id != checkIn?.id).toList();
    final recordings = checkIn == null
        ? const <MediaItem>[]
        : (store.progress(date, checkIn.id)?.media ?? const <MediaItem>[]);
    final allTypesRecorded = englishTypes.every(
      (type) => recordings.any((m) => m.englishType == type),
    );
    final specialDone = checkIn != null && store.done(date, checkIn.id);
    final missing = englishTypes.where((type) => recordings.every((m) => m.englishType != type)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('英语打卡')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            checkIn == null
                ? '还没有英语打卡这项，去家长端加一下'
                : specialDone
                    ? '今天英语打卡已完成，下面还能听回录音'
                    : allTypesRecorded
                        ? '四条都录好了，可以打勾'
                        : '选一个类型，四条都录完才能打勾',
            style: const TextStyle(color: CamiColors.muted),
          ),
          if (checkIn != null && !specialDone && missing.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('还没录：${missing.join('、')}', style: const TextStyle(color: CamiColors.roseDeep, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          for (final type in englishTypes)
            _typeRow(context, store, checkIn, type, recordings, locked: specialDone),
          if (checkIn != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: RoseButton(
                label: specialDone ? '今天已打卡' : '这几条都录好了',
                onPressed: specialDone || !allTypesRecorded
                    ? null
                    : () async {
                        final error = await store.complete(date, checkIn.id);
                        if (!context.mounted) return;
                        toast(context, error ?? '英语打卡已记下');
                      },
              ),
            ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: CamiColors.line),
            ),
            title: const Text('去微信小程序打卡'),
            subtitle: const Text('还没绑定指定页时，会先打开微信'),
            trailing: const Text('打开', style: TextStyle(color: CamiColors.roseDeep, fontWeight: FontWeight.w700)),
            onTap: () => launchUrl(Uri.parse('weixin://'), mode: LaunchMode.externalApplication),
          ),
          const SizedBox(height: 16),
          const Text('今天还有', style: TextStyle(color: CamiColors.muted, fontWeight: FontWeight.w700)),
          if (rest.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('没有其他英语任务', style: TextStyle(color: CamiColors.muted)),
            ),
          for (final task in rest) _plain(context, store, task),
        ],
      ),
    );
  }

  Widget _typeRow(
    BuildContext context,
    Store store,
    TaskTemplate? task,
    String type,
    List<MediaItem> recordings, {
    bool locked = false,
  }) {
    final mine = recordings.where((m) => m.englishType == type).toList();
    final done = mine.isNotEmpty;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(done ? Icons.check_circle : Icons.circle_outlined, color: done ? CamiColors.green : CamiColors.line),
            title: Text(type),
            subtitle: Text(done ? mine.first.label : '还没有录音'),
            trailing: done
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '听录音',
                        icon: const Icon(Icons.play_circle_outline, color: CamiColors.roseDeep),
                        onPressed: () => _play(context, store, mine.first),
                      ),
                      IconButton(
                        tooltip: '分享',
                        icon: const Icon(Icons.share),
                        onPressed: () {
                          final path = mine.first.path;
                          if (path.isEmpty) return;
                          SharePlus.instance.share(ShareParams(files: [XFile(path)], text: mine.first.label));
                        },
                      ),
                      if (!locked)
                        TextButton(
                          onPressed: task == null
                              ? null
                              : () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecordPage(task: task, type: type))),
                          child: const Text('重录'),
                        ),
                    ],
                  )
                : FilledButton(
                    onPressed: task == null || locked
                        ? null
                        : () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecordPage(task: task, type: type))),
                    child: const Text('去录'),
                  ),
          ),
          if (done)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ColoredBox(
                  color: CamiColors.blush,
                  child: SizedBox(
                    height: 96,
                    width: double.infinity,
                    child: mediaView(
                      kind: mine.first.kind,
                      path: mine.first.path,
                      filename: mine.first.storedName,
                      serverUrl: store.serverUrl,
                      token: store.serverToken,
                      session: store.sessionId,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _play(BuildContext context, Store store, MediaItem item) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SizedBox(
            height: 96,
            child: mediaView(
              kind: item.kind,
              path: item.path,
              filename: item.storedName,
              serverUrl: store.serverUrl,
              token: store.serverToken,
              session: store.sessionId,
            ),
          ),
        ),
      ),
    );
  }

  Widget _plain(BuildContext context, Store store, TaskTemplate task) {
    final done = store.done(store.todayKey, task.id);
    return Card(
      child: ListTile(
        leading: Icon(done ? Icons.check_circle : Icons.circle_outlined, color: done ? CamiColors.green : CamiColors.line),
        title: Text(task.title),
        subtitle: Text(done ? '已完成 · ${taskMeta(task)}' : taskMeta(task)),
        trailing: done
            ? TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskPage(task: task))),
                child: const Text('查看'),
              )
            : FilledButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskPage(task: task))),
                child: const Text('开始'),
              ),
      ),
    );
  }
}

class RecordPage extends StatefulWidget {
  const RecordPage({super.key, required this.task, required this.type});
  final TaskTemplate task;
  final String type;

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  late String _type = widget.type;
  String _heard = '';
  String _zh = '';
  var _listening = false;
  var _recording = false;
  var _saving = false;
  var _recordSeconds = 0;
  MediaItem? _saved;
  Timer? _recordTimer;
  final _recorder = ClipRecorder();

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  String get _recordClock {
    final m = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recordSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecord() async {
    if (_recording || _saving || _saved != null) return;
    final ok = await _recorder.start();
    if (!mounted) return;
    if (!ok) {
      toast(context, '要用麦克风才能录音');
      return;
    }
    _recordTimer?.cancel();
    setState(() {
      _recording = true;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopAndSave() async {
    if (!_recording || _saving) return;
    setState(() => _saving = true);
    _recordTimer?.cancel();
    List<int>? bytes;
    try {
      bytes = await _recorder.stop();
    } catch (_) {
      bytes = null;
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _saving = false;
    });
    if (bytes == null || bytes.isEmpty) {
      toast(context, '没有录到声音，再试一次');
      return;
    }
    final store = context.read<Store>();
    final item = await store.addMedia(
      date: store.todayKey,
      taskId: widget.task.id,
      kind: 'audio',
      label: englishFileLabel(DateTime.now(), _type),
      bytes: bytes,
      englishType: _type,
      note: _heard,
      noteZh: _zh,
    );
    if (!mounted) return;
    setState(() => _saved = item);
    toast(context, '录音已保存');
  }

  Future<void> _speakNote() async {
    if (_recording) return;
    setState(() => _listening = true);
    final text = await Voice.listen();
    if (!mounted) return;
    final zh = text == null ? '' : await toChinese(text);
    setState(() {
      _listening = false;
      _heard = text ?? '没听清，再说一次';
      _zh = zh;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final label = englishFileLabel(DateTime.now(), _type);
    return Scaffold(
      appBar: AppBar(title: Text(_type)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(label, style: const TextStyle(color: CamiColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in englishTypes)
                ChoiceChip(
                  label: Text(type),
                  selected: _type == type,
                  onSelected: (_recording || _saving || _saved != null)
                      ? null
                      : (_) => setState(() => _type = type),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recording || _saving)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              decoration: BoxDecoration(
                color: CamiColors.blush,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: CamiColors.line),
              ),
              child: Column(
                children: [
                  const Icon(Icons.mic, color: CamiColors.roseDeep, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    _saving ? '正在保存…' : '正在录音 $_recordClock',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text('说完再点一下停止', style: TextStyle(color: CamiColors.muted)),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _saving ? null : _stopAndSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: CamiColors.roseDeep,
                      minimumSize: const Size(160, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_saving ? '请稍等' : '停止并保存'),
                  ),
                ],
              ),
            )
          else if (_saved != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: CamiColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_saved!.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 96,
                    width: double.infinity,
                    child: mediaView(
                      kind: _saved!.kind,
                      path: _saved!.path,
                      filename: _saved!.storedName,
                      serverUrl: store.serverUrl,
                      token: store.serverToken,
                      session: store.sessionId,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RoseButton(
              label: '录好了，返回',
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _saved = null;
                  _recordSeconds = 0;
                });
                _startRecord();
              },
              child: const Text('再录一条'),
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
              decoration: BoxDecoration(
                color: CamiColors.blush,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: CamiColors.line),
              ),
              child: Column(
                children: [
                  const Icon(Icons.mic_none, color: CamiColors.roseDeep, size: 40),
                  const SizedBox(height: 8),
                  const Text('准备好了再点开始', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 14),
                  RoseButton(label: '开始录音', onPressed: _startRecord),
                ],
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: (_recording || _listening) ? null : _speakNote,
            child: Text(_listening ? '正在听备注…' : '说出备注，译成中文（可选）'),
          ),
          if (_heard.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('刚才说到\n$_heard'),
            const SizedBox(height: 8),
            Text('中文备注\n$_zh', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}
