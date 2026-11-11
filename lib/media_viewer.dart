import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import 'l10n/l10n.dart';
import 'models.dart';
import 'storage/files.dart';
import 'theme.dart';
import 'widgets.dart';

String mediaRemoteUrl({
  required String filename,
  String? serverUrl,
  String? token,
  String? session,
}) {
  if ((serverUrl ?? '').isEmpty || filename.isEmpty) return '';
  final base = serverUrl!.replaceAll(RegExp(r'/+$'), '');
  var url =
      '$base/api/media/${Uri.encodeComponent(filename)}?token=${Uri.encodeQueryComponent(token ?? '')}';
  if ((session ?? '').isNotEmpty) {
    url = '$url&session=${Uri.encodeQueryComponent(session!)}';
  }
  return url;
}

String _mimeFor(MediaItem item) {
  final name = item.storedName.toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.gif')) return 'image/gif';
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  if (name.endsWith('.mp4') || name.endsWith('.mov') || name.endsWith('.m4v')) {
    return 'video/mp4';
  }
  if (name.endsWith('.webm')) return 'video/webm';
  if (name.endsWith('.m4a') || name.endsWith('.aac')) return 'audio/mp4';
  if (name.endsWith('.mp3')) return 'audio/mpeg';
  if (name.endsWith('.wav')) return 'audio/wav';
  return switch (item.kind) {
    'photo' => 'image/jpeg',
    'video' => 'video/mp4',
    'audio' => 'audio/mp4',
    _ => 'application/octet-stream',
  };
}

Future<XFile?> resolveMediaXFile(
  MediaItem item, {
  String? serverUrl,
  String? token,
  String? session,
}) async {
  if (item.path.isNotEmpty) {
    return XFile(item.path, name: item.storedName.isEmpty ? null : item.storedName);
  }

  List<int>? bytes = await readMediaBytes(item.storedName);
  bytes ??= item.path.isEmpty ? null : await readMediaBytes(item.path);

  if (bytes == null) {
    final remote = mediaRemoteUrl(
      filename: item.storedName,
      serverUrl: serverUrl,
      token: token,
      session: session,
    );
    if (remote.isNotEmpty) {
      final resp = await http.get(
        Uri.parse(remote),
        headers: {
          if ((token ?? '').isNotEmpty) 'x-cami-token': token!,
          if ((session ?? '').isNotEmpty) 'x-cami-session': session!,
        },
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        bytes = resp.bodyBytes;
      }
    }
  }

  if (bytes == null || bytes.isEmpty) return null;
  final name = item.storedName.isEmpty ? 'cami-${item.kind}' : item.storedName;
  return XFile.fromData(
    Uint8List.fromList(bytes),
    name: name,
    mimeType: _mimeFor(item),
  );
}

Future<void> shareMediaItem(
  BuildContext context,
  MediaItem item, {
  String? serverUrl,
  String? token,
  String? session,
}) async {
  final s = context.l10n;
  toast(context, s.preparingShare);
  try {
    final file = await resolveMediaXFile(
      item,
      serverUrl: serverUrl,
      token: token,
      session: session,
    );
    if (!context.mounted) return;
    if (file == null) {
      toast(context, s.shareUnavailable);
      return;
    }
    final text = item.label.isEmpty
        ? (item.kind == 'photo'
            ? s.photo
            : item.kind == 'video'
                ? s.video
                : s.audio)
        : s.mediaLabel(item.label);
    await SharePlus.instance.share(ShareParams(files: [file], text: text));
  } catch (_) {
    if (context.mounted) toast(context, s.shareFailed);
  }
}

Future<void> openMediaViewer(
  BuildContext context, {
  required MediaItem item,
  String? serverUrl,
  String? token,
  String? session,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => MediaViewerPage(
        item: item,
        serverUrl: serverUrl,
        token: token,
        session: session,
      ),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class MediaViewerPage extends StatelessWidget {
  const MediaViewerPage({
    super.key,
    required this.item,
    this.serverUrl,
    this.token,
    this.session,
  });

  final MediaItem item;
  final String? serverUrl;
  final String? token;
  final String? session;

  String _title(AppL10n s) {
    if (item.label.isNotEmpty) return s.mediaLabel(item.label);
    return item.kind == 'photo'
        ? s.photo
        : item.kind == 'video'
            ? s.video
            : s.audio;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.72),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_title(s), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: s.share,
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => shareMediaItem(
              context,
              item,
              serverUrl: serverUrl,
              token: token,
              session: session,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: item.kind == 'photo'
              ? InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width,
                      maxHeight: MediaQuery.sizeOf(context).height,
                    ),
                    child: mediaView(
                      kind: item.kind,
                      path: item.path,
                      filename: item.storedName,
                      serverUrl: serverUrl,
                      token: token,
                      session: session,
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: mediaView(
                    kind: item.kind,
                    path: item.path,
                    filename: item.storedName,
                    serverUrl: serverUrl,
                    token: token,
                    session: session,
                    fit: BoxFit.contain,
                  ),
                ),
        ),
      ),
    );
  }
}

/// 缩略图：点按进全屏，可带分享按钮。
class MediaPreviewCard extends StatelessWidget {
  const MediaPreviewCard({
    super.key,
    required this.item,
    this.serverUrl,
    this.token,
    this.session,
    this.height = 180,
    this.showShare = true,
    this.showTitle = true,
    this.trailing,
  });

  final MediaItem item;
  final String? serverUrl;
  final String? token;
  final String? session;
  final double height;
  final bool showShare;
  final bool showTitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle || showShare || trailing != null)
          Row(
            children: [
              Expanded(
                child: showTitle
                    ? Text(
                        item.label.isEmpty
                            ? (item.kind == 'photo'
                                ? s.photo
                                : item.kind == 'video'
                                    ? s.video
                                    : s.audio)
                            : s.mediaLabel(item.label),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      )
                    : const SizedBox.shrink(),
              ),
              if (showShare)
                IconButton(
                  tooltip: s.share,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => shareMediaItem(
                    context,
                    item,
                    serverUrl: serverUrl,
                    token: token,
                    session: session,
                  ),
                  icon: const Icon(Icons.ios_share_rounded, color: CamiColors.roseDeep),
                ),
              if (trailing != null) trailing!,
            ],
          ),
        Material(
          color: CamiColors.blush,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openMediaViewer(
              context,
              item: item,
              serverUrl: serverUrl,
              token: token,
              session: session,
            ),
            child: SizedBox(
              width: double.infinity,
              height: item.kind == 'audio' ? 96 : height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  mediaView(
                    kind: item.kind,
                    path: item.path,
                    filename: item.storedName,
                    serverUrl: serverUrl,
                    token: token,
                    session: session,
                  ),
                  if (item.kind == 'photo' || item.kind == 'video')
                    const Positioned(
                      right: 10,
                      bottom: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0x99000000),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.fullscreen, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
