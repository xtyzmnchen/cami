import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models.dart';
import '../services/capture.dart';
import '../services/notify.dart';
import '../services/voice.dart';
import '../storage/files.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key, required this.task});
  final TaskTemplate task;

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  Timer? _timer;
  int? _left;
  var _running = false;
  var _finishedRound = false;
  final _recorder = ClipRecorder();
  Timer? _recordTimer;
  var _recording = false;
  var _recordSeconds = 0;
  var _savingAudio = false;
  var _alarmShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreTimer());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  int _secondsLeft(DateTime endsAt) {
    final left = endsAt.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }

  Future<void> _restoreTimer() async {
    if (!mounted || widget.task.minutes <= 0) return;
    final store = context.read<Store>();
    final endsAt = store.timerEndsAt(store.todayKey, widget.task.id);
    if (endsAt == null) return;
    final left = _secondsLeft(endsAt);
    if (left <= 0) {
      setState(() {
        _left = 0;
        _running = false;
        _finishedRound = true;
      });
      await store.stopTimer(store.todayKey, widget.task.id);
      return;
    }
    setState(() {
      _left = left;
      _running = true;
      _finishedRound = false;
    });
    await WakelockPlus.enable();
    _tickFrom(endsAt, announce: false);
  }

  Future<void> _start() async {
    if (_running) return;
    final store = context.read<Store>();
    final seconds = widget.task.minutes * 60;
    final endsAt = DateTime.now().add(Duration(seconds: seconds));
    await store.startTimer(store.todayKey, widget.task.id, widget.task.minutes);
    if (!mounted) return;
    setState(() {
      _left = seconds;
      _running = true;
      _finishedRound = false;
      _alarmShown = false;
    });
    await WakelockPlus.enable();
    await Alerts.schedule(
      id: widget.task.id.hashCode,
      when: endsAt,
      title: '时间到了',
      body: '${widget.task.title}，${widget.task.minutes} 分钟到了',
    );
    _tickFrom(endsAt, announce: true);
  }

  void _tickFrom(DateTime endsAt, {required bool announce}) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      final left = _secondsLeft(endsAt);
      if (left <= 0) {
        _timer?.cancel();
        setState(() {
          _left = 0;
          _running = false;
          _finishedRound = true;
        });
        final store = context.read<Store>();
        await store.stopTimer(store.todayKey, widget.task.id);
        await WakelockPlus.disable();
        await Alerts.cancel(widget.task.id.hashCode);
        if (!announce || _alarmShown || !mounted) return;
        _alarmShown = true;
        SystemSound.play(SystemSoundType.alert);
        await Voice.say('时间到了。${widget.task.title}，这${widget.task.minutes}分钟到了。');
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const _AlarmPage(
                title: '时间到了',
                subtitle: '这件作业的时间到了',
              ),
            ),
          );
        }
        return;
      }
      setState(() => _left = left);
    });
  }

  Future<void> _stopChallenge() async {
    _timer?.cancel();
    final store = context.read<Store>();
    await store.stopTimer(store.todayKey, widget.task.id);
    await Alerts.cancel(widget.task.id.hashCode);
    await WakelockPlus.disable();
    if (!mounted) return;
    setState(() {
      _left = null;
      _running = false;
      _finishedRound = false;
      _alarmShown = false;
    });
    if (!mounted) return;
    toast(context, '已结束这轮计时');
  }

  Future<void> _add(String kind) async {
    if (kind == 'audio') {
      await _toggleRecord();
      return;
    }
    final store = context.read<Store>();
    final bytes = kind == 'photo' ? await capturePhoto() : await captureVideo();
    if (bytes == null || !mounted) return;
    await store.addMedia(
      date: store.todayKey,
      taskId: widget.task.id,
      kind: kind,
      label: widget.task.title,
      bytes: bytes,
    );
  }

  Future<void> _toggleRecord() async {
    if (_savingAudio) return;
    if (!_recording) {
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
      return;
    }
    setState(() => _savingAudio = true);
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
      _savingAudio = false;
      _recordSeconds = 0;
    });
    if (bytes == null || bytes.isEmpty) {
      toast(context, '没有录到声音，再试一次');
      return;
    }
    final store = context.read<Store>();
    await store.addMedia(
      date: store.todayKey,
      taskId: widget.task.id,
      kind: 'audio',
      label: widget.task.title,
      bytes: bytes,
    );
    if (mounted) toast(context, '录音已保存');
  }

  String get _recordClock {
    final m = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recordSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _finish() async {
    _timer?.cancel();
    final store = context.read<Store>();
    await Alerts.cancel(widget.task.id.hashCode);
    await WakelockPlus.disable();
    final message = await store.complete(store.todayKey, widget.task.id);
    if (!mounted) return;
    if (message != null) {
      await Voice.say(message);
      if (!mounted) return;
      toast(context, message);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final row = store.progress(store.todayKey, widget.task.id);
    final total = widget.task.minutes * 60;
    final clock = _left == null
        ? '${widget.task.minutes.toString().padLeft(2, '0')}:00'
        : '${(_left! ~/ 60).toString().padLeft(2, '0')}:${(_left! % 60).toString().padLeft(2, '0')}';
    final ringProgress = _left == null || total <= 0 ? 1.0 : _left! / total;
    return Scaffold(
      appBar: AppBar(title: Text(widget.task.subject)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(widget.task.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${widget.task.minutes} 分钟 · ${widget.task.points} 分', style: const TextStyle(color: CamiColors.roseDeep, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Center(child: CountdownRing(label: clock, progress: ringProgress, size: 220, fontSize: 52)),
          const SizedBox(height: 8),
          Text(
            _running
                ? '进行中'
                : _finishedRound
                    ? '这轮时间到了'
                    : '还没开始',
            textAlign: TextAlign.center,
            style: const TextStyle(color: CamiColors.muted),
          ),
          const SizedBox(height: 12),
          if (widget.task.minutes > 0 && !_running)
            RoseButton(
              label: _finishedRound ? '再来一轮' : '接受挑战',
              onPressed: _start,
            ),
          if (widget.task.minutes > 0 && _running) ...[
            RoseButton(label: '结束计时', onPressed: _stopChallenge),
            const SizedBox(height: 8),
            const Text('离开页面后，倒计时会继续，再进来接着走。', textAlign: TextAlign.center, style: TextStyle(color: CamiColors.muted, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          if (_recording || _savingAudio) ...[
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
                    _savingAudio ? '正在保存…' : '正在录音 $_recordClock',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text('说完再点一下停止', style: TextStyle(color: CamiColors.muted)),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _savingAudio ? null : _toggleRecord,
                    style: FilledButton.styleFrom(
                      backgroundColor: CamiColors.roseDeep,
                      minimumSize: const Size(160, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_savingAudio ? '请稍等' : '停止并保存'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _cap(Icons.photo_camera, '拍照', () => _add('photo')),
                _cap(Icons.videocam, '录像', () => _add('video')),
                _cap(Icons.mic, '录音', () => _add('audio')),
              ],
            ),
          if (!_recording) const SizedBox(height: 16),
          if (row == null || row.media.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CamiColors.line),
              ),
              child: const Text('还没有照片、视频或录音', style: TextStyle(color: CamiColors.muted)),
            )
          else
            ...row.media.map((item) => _mediaTile(context, store, item)),
          const SizedBox(height: 16),
          RoseButton(
            label: '我完成了',
            filled: row != null && row.media.isNotEmpty,
            onPressed: _finish,
          ),
        ],
      ),
    );
  }

  Widget _cap(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(radius: 30, backgroundColor: CamiColors.blush, child: Icon(icon, color: CamiColors.roseDeep)),
          const SizedBox(height: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _AlarmPage extends StatelessWidget {
  const _AlarmPage({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CamiColors.night,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 28),
                const _HoldStop(),
                const SizedBox(height: 16),
                const Text('按住两秒就会停下\n妈妈输入密码可以马上关', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HoldStop extends StatefulWidget {
  const _HoldStop();

  @override
  State<_HoldStop> createState() => _HoldStopState();
}

class _HoldStopState extends State<_HoldStop> {
  var _progress = 0.0;
  Timer? _timer;

  void _begin() {
    _timer?.cancel();
    final started = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final p = DateTime.now().difference(started).inMilliseconds / 2000;
      if (p >= 1) {
        _timer?.cancel();
        Voice.say('闹钟停下了');
        if (mounted) Navigator.pop(context);
        return;
      }
      setState(() => _progress = p);
    });
  }

  void _end() {
    _timer?.cancel();
    setState(() => _progress = 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _begin(),
      onTapUp: (_) => _end(),
      onTapCancel: _end,
      child: Container(
        width: 168,
        height: 168,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFD6E8),
          border: Border.all(color: Colors.white24, width: 10),
        ),
        child: Text(_progress == 0 ? '按住小皇冠' : '${(_progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

Widget _mediaTile(BuildContext context, Store store, MediaItem item) {
  return Card(
    child: ListTile(
      title: Text(item.label.isEmpty ? item.storedName : item.label),
      subtitle: Text(item.kind == 'photo' ? '照片' : item.kind == 'video' ? '视频' : '录音'),
      trailing: IconButton(
        icon: const Icon(Icons.share),
        onPressed: () {
          if (item.path.isEmpty) return;
          SharePlus.instance.share(ShareParams(files: [XFile(item.path)], text: item.label));
        },
      ),
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            child: SizedBox(
              height: 280,
              child: mediaView(
                kind: item.kind,
                path: item.path,
                filename: item.storedName,
                serverUrl: store.serverUrl,
                token: store.serverToken,
              ),
            ),
          ),
        );
      },
    ),
  );
}

class AlarmPage extends StatelessWidget {
  const AlarmPage({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => _AlarmPage(title: title, subtitle: subtitle);
}
