import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
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
import 'vocab_page.dart';
import '../vocab/schedule.dart';

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
      appBar: AppBar(title: Text(context.l10n.englishCheckIn)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            checkIn == null
                ? context.l10n.noEnglishCheckIn
                : specialDone
                    ? context.l10n.englishDoneListen
                    : allTypesRecorded
                        ? context.l10n.englishReadyToCheck
                        : context.l10n.englishPickTypes,
            style: const TextStyle(color: CamiColors.muted),
          ),
          if (checkIn != null && !specialDone && missing.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(context.l10n.stillMissing(missing.map(context.l10n.englishType).join(context.l10n.isEn ? ', ' : '、')), style: const TextStyle(color: CamiColors.roseDeep, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          for (final type in englishTypes)
            _typeRow(context, store, checkIn, type, recordings, locked: specialDone),
          if (checkIn != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: RoseButton(
                label: specialDone ? context.l10n.englishCheckedToday : context.l10n.englishAllRecorded,
                onPressed: specialDone || !allTypesRecorded
                    ? null
                    : () async {
                        final error = await store.complete(date, checkIn.id);
                        if (!context.mounted) return;
                        toast(context, error ?? context.l10n.englishSaved);
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
            title: Text(context.l10n.openWechatMini),
            subtitle: Text(context.l10n.wechatBindHint),
            trailing: Text(context.l10n.open, style: const TextStyle(color: CamiColors.roseDeep, fontWeight: FontWeight.w700)),
            onTap: () => launchUrl(Uri.parse('weixin://'), mode: LaunchMode.externalApplication),
          ),
          const SizedBox(height: 16),
          Text(context.l10n.englishMoreToday, style: const TextStyle(color: CamiColors.muted, fontWeight: FontWeight.w700)),
          if (rest.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(context.l10n.noOtherEnglish, style: const TextStyle(color: CamiColors.muted)),
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
            title: Text(context.l10n.englishType(type)),
            subtitle: Text(
              done ? context.l10n.mediaLabel(mine.first.label) : context.l10n.noRecordingYet,
            ),
            trailing: done
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: context.l10n.listenRecording,
                        icon: const Icon(Icons.play_circle_outline, color: CamiColors.roseDeep),
                        onPressed: () => _play(context, store, mine.first),
                      ),
                      IconButton(
                        tooltip: context.l10n.share,
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
                          child: Text(context.l10n.reRecord),
                        ),
                    ],
                  )
                : FilledButton(
                    onPressed: task == null || locked
                        ? null
                        : () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecordPage(task: task, type: type))),
                    child: Text(context.l10n.goRecord),
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
    final isVocab = task.id == vocabTaskId || task.title.contains('单词');
    void open() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => isVocab ? const VocabPage() : TaskPage(task: task)),
      );
    }

    return Card(
      child: ListTile(
        leading: Icon(done ? Icons.check_circle : Icons.circle_outlined, color: done ? CamiColors.green : CamiColors.line),
        title: Text(context.l10n.taskTitle(task.id, task.title)),
        subtitle: Text(
          isVocab
              ? (done
                  ? '${context.l10n.tr('已完成', 'Done')} · ${store.vocabTodayBadge()}'
                  : store.vocabTodayBadge())
              : (done
                  ? '${context.l10n.tr('已完成', 'Done')} · ${taskMeta(task, context.l10n)}'
                  : taskMeta(task, context.l10n)),
        ),
        trailing: done
            ? TextButton(onPressed: open, child: Text(context.l10n.view))
            : FilledButton(onPressed: open, child: Text(context.l10n.start)),
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
      toast(context, context.l10n.needMic);
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
    if (_recordSeconds < 10) {
      toast(context, context.l10n.recordTooShort);
      return;
    }
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
      toast(context, context.l10n.noSound);
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
    toast(context, context.l10n.recordSaved);
  }

  Future<void> _speakNote() async {
    if (_recording) return;
    setState(() => _listening = true);
    final text = await Voice.listen();
    if (!mounted) return;
    final zh = text == null ? '' : await toChinese(text);
    setState(() {
      _listening = false;
      _heard = text ?? context.l10n.didntCatch;
      _zh = zh;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.englishType(_type))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            context.l10n.englishType(_type),
            style: const TextStyle(color: CamiColors.muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in englishTypes)
                ChoiceChip(
                  label: Text(context.l10n.englishType(type)),
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
                    _saving ? context.l10n.saving : context.l10n.recordingClock(_recordClock),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _recordSeconds < 10 ? context.l10n.recordNeedMore(10 - _recordSeconds) : context.l10n.stopWhenDone,
                    style: TextStyle(
                      color: _recordSeconds < 10 ? CamiColors.roseDeep : CamiColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _saving ? null : _stopAndSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: CamiColors.roseDeep,
                      minimumSize: const Size(160, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_saving ? context.l10n.pleaseWait : context.l10n.stopAndSave),
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
                  Text(context.l10n.mediaLabel(_saved!.label), style: const TextStyle(fontWeight: FontWeight.w800)),
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
              label: context.l10n.recordedBack,
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
              child: Text(context.l10n.recordAnother),
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
                  Text(context.l10n.readyThenStart, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 14),
                  RoseButton(label: context.l10n.startRecord, onPressed: _startRecord),
                ],
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: (_recording || _listening) ? null : _speakNote,
            child: Text(_listening ? context.l10n.listeningNote : context.l10n.speakNoteOptional),
          ),
          if (_heard.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(context.l10n.justSaid(_heard)),
            const SizedBox(height: 8),
            Text(context.l10n.zhNote(_zh), style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}
