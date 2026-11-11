import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../theme.dart';

/// 当前登录手机号；本地状态/附件按账号分开存，互不混淆。
String activeAccountPhone = '';

Future<Directory> _accountDir() async {
  final root = await getApplicationDocumentsDirectory();
  if (activeAccountPhone.isEmpty) return Directory(root.path);
  final dir = Directory('${root.path}/accounts/$activeAccountPhone');
  await dir.create(recursive: true);
  return dir;
}

Future<String> saveMediaBytes(String filename, List<int> bytes) async {
  final root = await _accountDir();
  final dir = Directory('${root.path}/media');
  await dir.create(recursive: true);
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<List<int>?> readMediaBytes(String path) async {
  if (path.isEmpty) return null;
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<void> deleteMediaFile(String path, String storedName) async {
  try {
    if (path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } else if (storedName.isNotEmpty) {
      final root = await _accountDir();
      final file = File('${root.path}/media/$storedName');
      if (await file.exists()) await file.delete();
    }
  } catch (_) {}
}

/// 删掉本地 media 目录里、状态里已经不存在的文件。
Future<void> pruneOrphanMedia(Set<String> keepNames) async {
  try {
    final root = await _accountDir();
    final dir = Directory('${root.path}/media');
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isEmpty ? '' : entity.uri.pathSegments.last;
      if (name.isEmpty || keepNames.contains(name)) continue;
      try {
        await entity.delete();
      } catch (_) {}
    }
  } catch (_) {}
}

Future<String?> readState() async {
  final root = await _accountDir();
  final file = File('${root.path}/cami-state.json');
  if (!await file.exists()) return null;
  return file.readAsString();
}

Future<void> writeState(String value) async {
  final root = await _accountDir();
  final file = File('${root.path}/cami-state.json');
  await file.writeAsString(value);
}

Widget mediaView({
  required String kind,
  required String path,
  required String filename,
  String? serverUrl,
  String? token,
  String? session,
  BoxFit fit = BoxFit.cover,
}) {
  final local = path.isNotEmpty && File(path).existsSync();
  var remote = (serverUrl ?? '').isNotEmpty
      ? '${serverUrl!.replaceAll(RegExp(r'/+$'), '')}/api/media/${Uri.encodeComponent(filename)}?token=${Uri.encodeQueryComponent(token ?? '')}'
      : null;
  if (remote != null && (session ?? '').isNotEmpty) {
    remote = '$remote&session=${Uri.encodeQueryComponent(session!)}';
  }
  if (kind == 'photo') {
    if (local) return Image.file(File(path), fit: fit);
    if (remote != null) return Image.network(remote, fit: fit);
  }
  if (kind == 'video') {
    if (local) return _Video(filePath: path, fit: fit);
    if (remote != null) return _Video(url: remote, fit: fit);
  }
  if (kind == 'audio') {
    if (local) return _Audio(filePath: path);
    if (remote != null) return _Audio(url: remote);
  }
  return const ColoredBox(
    color: Color(0xFFFFE0EC),
    child: Center(child: Icon(Icons.image_outlined)),
  );
}

class _Video extends StatefulWidget {
  const _Video({this.filePath, this.url, this.fit = BoxFit.cover});
  final String? filePath;
  final String? url;
  final BoxFit fit;

  @override
  State<_Video> createState() => _VideoState();
}

class _VideoState extends State<_Video> {
  late final VideoPlayerController _controller;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.filePath != null
        ? VideoPlayerController.file(File(widget.filePath!))
        : VideoPlayerController.networkUrl(Uri.parse(widget.url!));
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _controller.initialize().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Center(child: CircularProgressIndicator());
    final playing = _controller.value.isPlaying;
    final ratio = _controller.value.aspectRatio == 0 ? 16 / 9 : _controller.value.aspectRatio;
    final video = AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller),
          if (!playing)
            Container(
              decoration: const BoxDecoration(
                color: Color(0x66000000),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: CamiColors.roseDeep,
                bufferedColor: Colors.white54,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
    return GestureDetector(
      onTap: () => playing ? _controller.pause() : _controller.play(),
      child: widget.fit == BoxFit.contain
          ? Center(child: video)
          : FittedBox(fit: widget.fit, clipBehavior: Clip.hardEdge, child: video),
    );
  }
}

class _Audio extends StatefulWidget {
  const _Audio({this.filePath, this.url});
  final String? filePath;
  final String? url;

  @override
  State<_Audio> createState() => _AudioState();
}

class _AudioState extends State<_Audio> {
  late final AudioPlayer _player;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  var _playing = false;
  var _ready = false;

  Source get _source =>
      widget.filePath != null ? DeviceFileSource(widget.filePath!) : UrlSource(widget.url!);

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.setReleaseMode(ReleaseMode.stop);
    _durationSub = _player.onDurationChanged.listen((d) {
      if (!mounted || d <= Duration.zero) return;
      setState(() {
        _duration = d;
        _ready = true;
      });
    });
    _positionSub = _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s == PlayerState.playing);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _position = Duration.zero;
      });
    });
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await _player.setSource(_source);
      final d = await _player.getDuration();
      if (!mounted) return;
      if (d != null && d > Duration.zero) {
        setState(() {
          _duration = d;
          _ready = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    if (_position > Duration.zero && _position < _duration) {
      await _player.resume();
      return;
    }
    await _player.play(_source);
  }

  String _fmt(Duration d) {
    final total = d.inMilliseconds < 0 ? 0 : d.inMilliseconds;
    final secs = (total / 1000).ceil().clamp(0, 9999);
    if (secs >= 60) {
      final m = secs ~/ 60;
      final s = secs % 60;
      return '$m分${s.toString().padLeft(2, '0')}秒';
    }
    return '$secs秒';
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration > Duration.zero ? _duration : Duration.zero;
    var left = Duration.zero;
    if (total > Duration.zero) {
      final remain = total - _position;
      left = remain.isNegative ? Duration.zero : (remain > total ? total : remain);
    }
    final progress = total.inMilliseconds <= 0
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final status = !_ready
        ? '准备中…'
        : _playing
            ? '播放中 · 还剩 ${_fmt(left)}'
            : total > Duration.zero
                ? '听录音 · 共 ${_fmt(total)}'
                : '听录音';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(52, 52),
                    painter: _RingPainter(
                      progress: _playing || _position > Duration.zero ? progress : 0,
                      track: CamiColors.line,
                      fill: CamiColors.roseDeep,
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _playing ? CamiColors.roseDeep : CamiColors.rose,
                      boxShadow: _playing
                          ? [
                              BoxShadow(
                                color: CamiColors.roseDeep.withValues(alpha: 0.35),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: _playing ? CamiColors.roseDeep : CamiColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: !_ready ? null : (total > Duration.zero ? progress : 0),
                    minHeight: 6,
                    backgroundColor: CamiColors.line,
                    color: CamiColors.roseDeep,
                  ),
                ),
                if (total > Duration.zero) ...[
                  const SizedBox(height: 4),
                  Text(
                    _playing ? '已播 ${_fmt(_position)} / ${_fmt(total)}' : '时长 ${_fmt(total)}',
                    style: const TextStyle(fontSize: 11, color: CamiColors.muted, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.track, required this.fill});
  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.fill != fill;
}
