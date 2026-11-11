import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../theme.dart';

/// 当前登录手机号；Web 端按账号分 key 存。
String activeAccountPhone = '';

final memoryMedia = <String, Uint8List>{};

String _prefKey(String base) => activeAccountPhone.isEmpty ? base : '${base}_$activeAccountPhone';

Future<String> saveMediaBytes(String filename, List<int> bytes) async {
  final key = activeAccountPhone.isEmpty ? filename : '$activeAccountPhone/$filename';
  memoryMedia[key] = Uint8List.fromList(bytes);
  memoryMedia[filename] = memoryMedia[key]!;
  return key;
}

Future<List<int>?> readMediaBytes(String path) async =>
    memoryMedia[path] ?? memoryMedia[path.split('/').last];

Future<void> deleteMediaFile(String path, String storedName) async {
  memoryMedia.remove(path);
  memoryMedia.remove(storedName);
  if (activeAccountPhone.isNotEmpty) {
    memoryMedia.remove('$activeAccountPhone/$storedName');
  }
}

Future<void> pruneOrphanMedia(Set<String> keepNames) async {
  memoryMedia.removeWhere((key, _) {
    final name = key.contains('/') ? key.split('/').last : key;
    return !keepNames.contains(name) && !keepNames.contains(key);
  });
}

Future<String?> readState() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_prefKey('cami_state'));
}

Future<void> writeState(String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefKey('cami_state'), value);
}

String? _remoteUrl(String? serverUrl, String? token, String filename) {
  if ((serverUrl ?? '').isEmpty || filename.isEmpty) return null;
  final base = serverUrl!.replaceAll(RegExp(r'/+$'), '');
  return '$base/api/media/${Uri.encodeComponent(filename)}?token=${Uri.encodeQueryComponent(token ?? '')}';
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
  final bytes = memoryMedia[filename] ?? memoryMedia[path] ??
      (activeAccountPhone.isEmpty ? null : memoryMedia['$activeAccountPhone/$filename']);
  var remote = _remoteUrl(serverUrl, token, filename);
  if (remote != null && (session ?? '').isNotEmpty) {
    remote = '$remote&session=${Uri.encodeQueryComponent(session!)}';
  }

  if (kind == 'photo') {
    if (bytes != null) return Image.memory(bytes, fit: fit);
    if (remote != null) {
      return Image.network(
        remote,
        fit: fit,
        headers: {
          if ((token ?? '').isNotEmpty) 'x-cami-token': token!,
          if ((session ?? '').isNotEmpty) 'x-cami-session': session!,
        },
        errorBuilder: (_, __, ___) => const _MissingMedia(kind: '照片'),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
      );
    }
  }
  if (kind == 'video') {
    if (remote != null) return _WebVideo(url: remote, fit: fit);
    if (bytes != null) {
      return const Center(child: Text('视频已在本机缓存', style: TextStyle(color: CamiColors.muted)));
    }
  }
  if (kind == 'audio') {
    if (remote != null) return _WebAudio(url: remote);
    if (bytes != null) {
      return const Center(child: Icon(Icons.check_circle, color: Color(0xFF2F9A62)));
    }
  }
  return _MissingMedia(kind: kind == 'video' ? '视频' : kind == 'audio' ? '录音' : '附件');
}

class _MissingMedia extends StatelessWidget {
  const _MissingMedia({required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CamiColors.blush,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '$kind还没传到同步电脑\n请用拍过照的那台手机：家长设置 → 现在上传',
            textAlign: TextAlign.center,
            style: const TextStyle(color: CamiColors.roseDeep, fontWeight: FontWeight.w700, height: 1.4),
          ),
        ),
      ),
    );
  }
}

class _WebVideo extends StatefulWidget {
  const _WebVideo({required this.url, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;

  @override
  State<_WebVideo> createState() => _WebVideoState();
}

class _WebVideoState extends State<_WebVideo> {
  VideoPlayerController? _controller;
  var _ready = false;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = c;
    c.addListener(() {
      if (mounted) setState(() {});
    });
    c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const _MissingMedia(kind: '视频');
    if (!_ready || _controller == null) return const Center(child: CircularProgressIndicator());
    final playing = _controller!.value.isPlaying;
    final ratio = _controller!.value.aspectRatio == 0 ? 16 / 9 : _controller!.value.aspectRatio;
    final video = AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller!),
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
              _controller!,
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
      onTap: () => playing ? _controller!.pause() : _controller!.play(),
      child: widget.fit == BoxFit.contain
          ? Center(child: video)
          : FittedBox(fit: widget.fit, clipBehavior: Clip.hardEdge, child: video),
    );
  }
}

class _WebAudio extends StatelessWidget {
  const _WebAudio({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: () async {
          final player = AudioPlayer();
          try {
            await player.play(UrlSource(url));
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('录音还没传到同步电脑，请用手机重新上传')),
              );
            }
          }
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('听录音'),
      ),
    );
  }
}
