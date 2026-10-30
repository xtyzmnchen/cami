import 'dart:convert';
import 'dart:io';

/// 家里的同步服务。
///
/// 运行：`dart run tool/server.dart`
/// 口令默认 cami-home，可用环境变量 CAMI_TOKEN 修改。
/// 端口默认 8787，可用环境变量 PORT 修改。
Future<void> main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8787');
  final token = Platform.environment['CAMI_TOKEN'] ?? 'cami-home';
  final root = Directory('cami-data');
  final media = Directory('cami-data/media');
  await media.create(recursive: true);
  final stateFile = File('${root.path}/state.json');

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('萱萱小皇冠已在这台电脑打开');
  stdout.writeln('本机查看：http://127.0.0.1:$port/health');
  stdout.writeln('手机里填写：http://这台电脑的地址:$port');
  stdout.writeln('口令：$token');

  await for (final request in server) {
    try {
      _cors(request);
      if (request.method == 'OPTIONS') {
        await request.response.close();
        continue;
      }
      final given = request.uri.queryParameters['token'] ?? request.headers.value('x-cami-token') ?? '';
      if (request.uri.path != '/health' && given != token) {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.write('口令不对');
        await request.response.close();
        continue;
      }
      if (request.uri.path == '/health') {
        request.response.write('ok');
      } else if (request.uri.path == '/api/state' && request.method == 'GET') {
        if (!await stateFile.exists()) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.headers.contentType = ContentType.json;
          await request.response.addStream(stateFile.openRead());
        }
      } else if (request.uri.path == '/api/state' && request.method == 'PUT') {
        final body = await utf8.decoder.bind(request).join();
        await stateFile.writeAsString(body);
        request.response.write('ok');
      } else if (request.uri.path.startsWith('/api/media/') && request.method == 'POST') {
        final name = _safeName(request.uri.pathSegments.last);
        final file = File('${media.path}/$name');
        await file.writeAsBytes(await _bytes(request));
        request.response.write('ok');
      } else if (request.uri.path.startsWith('/api/media/') && request.method == 'GET') {
        final name = _safeName(request.uri.pathSegments.last);
        final file = File('${media.path}/$name');
        if (!await file.exists()) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          await request.response.addStream(file.openRead());
        }
      } else if (request.uri.path.startsWith('/api/media/') && request.method == 'DELETE') {
        final name = _safeName(request.uri.pathSegments.last);
        final file = File('${media.path}/$name');
        if (await file.exists()) await file.delete();
        request.response.write('ok');
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
    } catch (error) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('$error');
    }
    await request.response.close();
  }
}

void _cors(HttpRequest request) {
  request.response.headers
    ..set('access-control-allow-origin', '*')
    ..set('access-control-allow-headers', 'content-type,x-cami-token')
    ..set('access-control-allow-methods', 'GET,PUT,POST,DELETE,OPTIONS');
}

String _safeName(String raw) {
  final name = Uri.decodeComponent(raw);
  if (name.contains('..') || name.contains('/') || name.contains('\\')) {
    throw ArgumentError('文件名不对');
  }
  return name;
}

Future<List<int>> _bytes(HttpRequest request) async {
  final chunks = await request.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
  return chunks;
}
