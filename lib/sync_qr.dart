import 'dart:convert';

/// 同步电脑二维码内容：纯网址，或带 token 的 JSON / 查询参数。
class SyncEndpoint {
  const SyncEndpoint({required this.url, this.token = 'cami-home'});

  final String url;
  final String token;

  String encode() {
    final clean = url.replaceAll(RegExp(r'/+$'), '');
    if (token.isEmpty || token == 'cami-home') return clean;
    return jsonEncode({'url': clean, 'token': token});
  }

  static SyncEndpoint? tryParse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    if (text.startsWith('{')) {
      try {
        final map = jsonDecode(text);
        if (map is! Map) return null;
        final url = '${map['url'] ?? map['server'] ?? ''}'.trim();
        if (url.isEmpty) return null;
        final token = '${map['token'] ?? 'cami-home'}'.trim();
        return SyncEndpoint(url: _normalizeUrl(url), token: token.isEmpty ? 'cami-home' : token);
      } catch (_) {
        return null;
      }
    }

    if (text.startsWith('cami://')) {
      final uri = Uri.tryParse(text);
      if (uri == null) return null;
      final url = (uri.queryParameters['url'] ?? '').trim();
      if (url.isEmpty) return null;
      final token = (uri.queryParameters['token'] ?? 'cami-home').trim();
      return SyncEndpoint(url: _normalizeUrl(url), token: token.isEmpty ? 'cami-home' : token);
    }

    final uri = Uri.tryParse(text.startsWith('http') ? text : 'https://$text');
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      return null;
    }
    final token = (uri.queryParameters['token'] ?? 'cami-home').trim();
    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    final base = uri.hasPort && uri.port != 80 && uri.port != 443
        ? '${uri.scheme}://${uri.host}:${uri.port}$path'
        : '${uri.scheme}://${uri.host}$path';
    return SyncEndpoint(url: base, token: token.isEmpty ? 'cami-home' : token);
  }

  static String _normalizeUrl(String url) {
    final trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    return 'https://$trimmed';
  }
}
