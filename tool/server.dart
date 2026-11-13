import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// 同步服务：按手机号隔离每个孩子的数据。
///
/// 运行：`dart run tool/server.dart`
/// 口令默认 cami-home（环境变量 CAMI_TOKEN）
/// 端口默认 8787（环境变量 PORT）
Future<void> main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8787');
  final token = Platform.environment['CAMI_TOKEN'] ?? 'cami-home';
  final root = Directory('cami-data');
  await root.create(recursive: true);
  final usersFile = File('${root.path}/users.json');
  final sessionsFile = File('${root.path}/sessions.json');
  if (!await usersFile.exists()) await usersFile.writeAsString('{}');
  if (!await sessionsFile.exists()) await sessionsFile.writeAsString('{}');

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('小皇冠已在这台电脑打开');
  stdout.writeln('本机查看：http://127.0.0.1:$port/health');
  stdout.writeln('手机里填写同步地址后，用手机号登录/注册');
  stdout.writeln('口令：$token');

  await for (final request in server) {
    try {
      _cors(request);
      if (request.method == 'OPTIONS') {
        await request.response.close();
        continue;
      }

      final path = request.uri.path;
      if (path == '/health') {
        request.response.write('ok');
        await request.response.close();
        continue;
      }

      final given = request.uri.queryParameters['token'] ?? request.headers.value('x-cami-token') ?? '';
      if (given != token) {
        stdout.writeln('口令不对：${request.method} $path');
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.write('口令不对');
        await request.response.close();
        continue;
      }

      final users = await _readJson(usersFile);
      final sessions = await _readJson(sessionsFile);

      if (path == '/api/account/check' && request.method == 'GET') {
        final phone = _normPhone(request.uri.queryParameters['phone'] ?? '');
        final exists = phone.isNotEmpty &&
            (users.containsKey(phone) || phone == '13800000000');
        _json(request, {'exists': exists, 'phone': phone});
      } else if (path == '/api/register' && request.method == 'POST') {
        final body = await _jsonBody(request);
        final phone = _normPhone('${body['phone'] ?? ''}');
        final password = '${body['password'] ?? ''}';
        final name = '${body['name'] ?? ''}'.trim();
        final age = (body['age'] as num?)?.toInt() ?? 0;
        final grade = '${body['grade'] ?? ''}'.trim();
        final interests = '${body['interests'] ?? ''}'.trim();
        if (!_validPhone(phone)) {
          _err(request, HttpStatus.badRequest, '手机号不对');
        } else if (password.length < 4) {
          _err(request, HttpStatus.badRequest, '密码至少 4 位');
        } else if (name.isEmpty) {
          _err(request, HttpStatus.badRequest, '请填写名字');
        } else if (users.containsKey(phone)) {
          _err(request, HttpStatus.conflict, '这个手机号已经注册过了');
        } else {
          users[phone] = {
            'phone': phone,
            'passwordHash': _hash(password),
            'name': name,
            'age': age,
            'grade': grade,
            'interests': interests,
            'createdAt': DateTime.now().toIso8601String(),
          };
          await _writeJson(usersFile, users);
          await _ensureUserDirs(root, phone);
          final session = _newSession(sessions, phone);
          await _writeJson(sessionsFile, sessions);
          stdout.writeln('新注册 $phone ($name)');
          _json(request, {'session': session, 'profile': _publicProfile(users[phone]!)});
        }
      } else if (path == '/api/login' && request.method == 'POST') {
        final body = await _jsonBody(request);
        final phone = _normPhone('${body['phone'] ?? ''}');
        final password = '${body['password'] ?? ''}';
        // 应急最高权限账号：固定手机号/密码，不存在则自动建号
        const masterPhone = '13800000000';
        const masterPassword = '123456';
        var user = users[phone];
        if (phone == masterPhone && password == masterPassword) {
          if (user == null) {
            user = {
              'phone': phone,
              'passwordHash': _hash(masterPassword),
              'name': '管理员',
              'age': 8,
              'grade': '二年级',
              'interests': '',
              'createdAt': DateTime.now().toIso8601String(),
            };
            users[phone] = user;
            await _writeJson(usersFile, users);
            stdout.writeln('自动创建应急账号 $phone');
          } else {
            user['passwordHash'] = _hash(masterPassword);
            users[phone] = user;
            await _writeJson(usersFile, users);
          }
          await _ensureUserDirs(root, phone);
          final session = _newSession(sessions, phone);
          await _writeJson(sessionsFile, sessions);
          stdout.writeln('登录应急账号 $phone');
          _json(request, {'session': session, 'profile': _publicProfile(user)});
        } else if (user == null) {
          _err(request, HttpStatus.notFound, '还没有这个手机号，请先注册');
        } else if (user['passwordHash'] != _hash(password)) {
          _err(request, HttpStatus.unauthorized, '密码不对');
        } else {
          await _ensureUserDirs(root, phone);
          final session = _newSession(sessions, phone);
          await _writeJson(sessionsFile, sessions);
          stdout.writeln('登录 $phone');
          _json(request, {'session': session, 'profile': _publicProfile(user)});
        }
      } else if (path == '/api/me' && request.method == 'GET') {
        final phone = _phoneFromSession(request, sessions);
        if (phone == null || users[phone] == null) {
          _err(request, HttpStatus.unauthorized, '请先登录');
        } else {
          _json(request, {'profile': _publicProfile(users[phone]!)});
        }
      } else if (path == '/api/state' && request.method == 'GET') {
        final phone = _phoneFromSession(request, sessions);
        if (phone == null) {
          _err(request, HttpStatus.unauthorized, '请先登录');
        } else {
          final stateFile = File('${root.path}/users/$phone/state.json');
          if (!await stateFile.exists()) {
            request.response.statusCode = HttpStatus.notFound;
          } else {
            request.response.headers.contentType = ContentType.json;
            await request.response.addStream(stateFile.openRead());
          }
        }
      } else if (path == '/api/state' && request.method == 'PUT') {
        final phone = _phoneFromSession(request, sessions);
        if (phone == null) {
          _err(request, HttpStatus.unauthorized, '请先登录');
        } else {
          await _ensureUserDirs(root, phone);
          final stateFile = File('${root.path}/users/$phone/state.json');
          final body = await utf8.decoder.bind(request).join();
          await stateFile.writeAsString(body);
          request.response.write('ok');
        }
      } else if (path.startsWith('/api/media/') && request.method == 'POST') {
        final phone = _phoneFromSession(request, sessions);
        if (phone == null) {
          _err(request, HttpStatus.unauthorized, '请先登录');
        } else {
          await _ensureUserDirs(root, phone);
          final name = _safeName(request.uri.pathSegments.last);
          final file = File('${root.path}/users/$phone/media/$name');
          final bytes = await _bytes(request);
          await file.writeAsBytes(bytes);
          stdout.writeln('已保存 $phone/$name（${bytes.length} 字节）');
          request.response.write('ok');
        }
      } else if (path.startsWith('/api/media/') && request.method == 'GET') {
        final phone = _phoneFromSession(request, sessions);
        if (phone == null) {
          _err(request, HttpStatus.unauthorized, '请先登录');
        } else {
          final name = _safeName(request.uri.pathSegments.last);
          final file = File('${root.path}/users/$phone/media/$name');
          if (!await file.exists()) {
            request.response.statusCode = HttpStatus.notFound;
          } else {
            await request.response.addStream(file.openRead());
          }
        }
      } else if (path.startsWith('/api/media/') && request.method == 'DELETE') {
        final phone = _phoneFromSession(request, sessions);
        if (phone == null) {
          _err(request, HttpStatus.unauthorized, '请先登录');
        } else {
          final name = _safeName(request.uri.pathSegments.last);
          final file = File('${root.path}/users/$phone/media/$name');
          if (await file.exists()) await file.delete();
          request.response.write('ok');
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
    } catch (error, stack) {
      stdout.writeln('服务器错误 ${request.method} ${request.uri.path}: $error');
      stdout.writeln('$stack');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('$error');
    }
    await request.response.close();
  }
}

void _cors(HttpRequest request) {
  request.response.headers
    ..set('access-control-allow-origin', '*')
    ..set('access-control-allow-headers', 'content-type,x-cami-token,x-cami-session')
    ..set('access-control-allow-methods', 'GET,PUT,POST,DELETE,OPTIONS');
}

String _normPhone(String raw) => raw.replaceAll(RegExp(r'\D'), '');

bool _validPhone(String phone) => RegExp(r'^1\d{10}$').hasMatch(phone);

String _hash(String password) => sha256.convert(utf8.encode(password)).toString();

String _safeName(String raw) {
  var name = raw;
  if (name.contains('%')) {
    try {
      name = Uri.decodeComponent(name);
    } catch (_) {}
  }
  name = name.trim();
  if (name.isEmpty || name.contains('..') || name.contains('/') || name.contains('\\')) {
    throw ArgumentError('文件名不对');
  }
  return name;
}

Future<void> _ensureUserDirs(Directory root, String phone) async {
  await Directory('${root.path}/users/$phone/media').create(recursive: true);
}

String _newSession(Map<String, dynamic> sessions, String phone) {
  final id = _sessionId();
  sessions[id] = {
    'phone': phone,
    'at': DateTime.now().toIso8601String(),
  };
  return id;
}

String? _phoneFromSession(HttpRequest request, Map<String, dynamic> sessions) {
  final sid = request.headers.value('x-cami-session') ?? request.uri.queryParameters['session'] ?? '';
  if (sid.isEmpty) return null;
  final row = sessions[sid];
  if (row is Map) {
    final phone = '${row['phone'] ?? ''}';
    return phone.isEmpty ? null : phone;
  }
  return null;
}

Map<String, dynamic> _publicProfile(Map<String, dynamic> user) => {
      'phone': user['phone'],
      'name': user['name'],
      'age': user['age'],
      'grade': user['grade'],
      'interests': user['interests'],
    };

Future<Map<String, dynamic>> _readJson(File file) async {
  try {
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return {};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } catch (_) {
    return {};
  }
}

Future<void> _writeJson(File file, Map<String, dynamic> data) async {
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
}

Future<Map<String, dynamic>> _jsonBody(HttpRequest request) async {
  final raw = await utf8.decoder.bind(request).join();
  if (raw.trim().isEmpty) return {};
  return Map<String, dynamic>.from(jsonDecode(raw) as Map);
}

void _json(HttpRequest request, Object data) {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(data));
}

void _err(HttpRequest request, int code, String message) {
  request.response.statusCode = code;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode({'error': message}));
}

Future<List<int>> _bytes(HttpRequest request) async {
  return request.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
}

String _sessionId() {
  final r = Random.secure();
  final bytes = List<int>.generate(24, (_) => r.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}
