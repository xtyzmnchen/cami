import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'l10n/l10n.dart';
import 'logic.dart';
import 'models.dart';
import 'storage/files.dart';
import 'poems/poems.dart';
import 'vocab/schedule.dart';
import 'vocab/words.dart';

class Store extends ChangeNotifier {
  Store() {
    data = AppData(
      pinHash: pinHashOf('2580'),
      childName: 'Cami',
      updatedAt: DateTime.now().toIso8601String(),
      tasks: seedTasks(),
      progress: [],
      rewards: seedRewards(),
      redemptions: [],
      playsUsed: {},
    );
  }

  late AppData data;
  String serverUrl = '';
  String serverToken = 'cami-home';
  String sessionId = '';
  String phone = '';
  UserProfile? profile;
  String? syncError;
  DateTime? lastSync;
  bool syncing = false;
  bool parentMode = false;
  /// 'zh' | 'en' — 家长设置里切换，本机持久化。
  String localeCode = 'zh';
  bool _pushAgain = false;
  final uploaded = <String>{};
  Timer? _syncTimer;
  final _uuid = const Uuid();

  /// 电脑端 cpolar 地址变更后写到 GitHub；手机同步失败时来这里拉最新地址。
  /// 注意：jsDelivr 的 `@main` 有 CDN 缓存，不能当准实时源；App 优先走 GitHub API。
  static const discoveryRepo = 'xtyzmnchen/cami';
  static const discoveryPath = 'web/sync-endpoint.json';

  String get todayKey => dayKey(DateTime.now());
  bool get isLoggedIn => sessionId.isNotEmpty && phone.isNotEmpty;

  AppData _freshData({String childName = 'Cami'}) => AppData(
        pinHash: pinHashOf('2580'),
        childName: childName,
        updatedAt: DateTime.now().toIso8601String(),
        tasks: seedTasks(),
        progress: [],
        rewards: seedRewards(),
        redemptions: [],
        playsUsed: {},
      );

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    serverUrl = prefs.getString('cami_server_url') ?? '';
    serverToken = prefs.getString('cami_server_token') ?? 'cami-home';
    sessionId = prefs.getString('cami_session') ?? '';
    phone = prefs.getString('cami_phone') ?? '';
    parentMode = prefs.getBool('cami_parent_mode') == true;
    localeCode = prefs.getString('cami_locale') == 'en' ? 'en' : 'zh';
    final profileRaw = prefs.getString('cami_profile');
    if (profileRaw != null && profileRaw.isNotEmpty) {
      try {
        profile = UserProfile.fromJson(jsonDecode(profileRaw) as Map<String, dynamic>);
      } catch (_) {}
    }
    activeAccountPhone = phone;
    uploaded
      ..clear()
      ..addAll(prefs.getStringList(_uploadedKey) ?? const []);
    data = _freshData(childName: profile?.name ?? 'Cami');
    try {
      final raw = await readState();
      if (raw != null && raw.isNotEmpty) {
        data = AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    await _repairEnglishCheckIn();
    notifyListeners();
    // 未登录时由登录页负责发现地址，避免和 AuthPage 并发抢跑。
    // 启动后立刻拉云端并合并，避免两台设备积分/进度不一致
    if (isLoggedIn && serverUrl.isNotEmpty) {
      unawaited(syncPull(pushAfterMerge: true));
    } else if (isLoggedIn && serverUrl.isEmpty) {
      unawaited(() async {
        await refreshEndpointFromDiscovery();
        if (serverUrl.isNotEmpty) await syncPull(pushAfterMerge: true);
      }());
    }
  }

  String get _uploadedKey => phone.isEmpty ? 'cami_uploaded' : 'cami_uploaded_$phone';

  String _normPhone(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  bool validPhone(String raw) => RegExp(r'^1\d{10}$').hasMatch(_normPhone(raw));

  Future<bool> checkPhoneExists(String rawPhone) async {
    if (serverUrl.isEmpty) throw Exception(l10n.errNeedSyncUrl);
    final phoneNo = _normPhone(rawPhone);
    if (!validPhone(phoneNo)) throw Exception(l10n.errBadPhone);
    final res = await http
        .get(
          Uri.parse(_authed('/api/account/check?phone=${Uri.encodeQueryComponent(phoneNo)}')),
          headers: _gateHeaders,
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 401) throw Exception(l10n.errBadToken);
    if (res.statusCode >= 300) throw Exception(l10n.errNoServer);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['exists'] == true;
  }

  Future<String?> register({
    required String rawPhone,
    required String password,
    required String name,
    required int age,
    required String grade,
    required String interests,
  }) async {
    if (serverUrl.isEmpty) return l10n.errNeedSyncUrl;
    final phoneNo = _normPhone(rawPhone);
    if (!validPhone(phoneNo)) return l10n.errBadPhone;
    if (password.length < 4) return l10n.errPasswordShort;
    if (name.trim().isEmpty) return l10n.errNeedName;
    final res = await http
        .post(
          Uri.parse(_authed('/api/register')),
          headers: {..._gateHeaders, 'content-type': 'application/json'},
          body: jsonEncode({
            'phone': phoneNo,
            'password': password,
            'name': name.trim(),
            'age': age,
            'grade': grade.trim(),
            'interests': interests.trim(),
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = _decodeMap(res.body);
    if (res.statusCode >= 300) return '${body['error'] ?? l10n.errRegisterFail}';
    await _applyAuth(body);
    return null;
  }

  Future<String?> login({required String rawPhone, required String password}) async {
    if (serverUrl.isEmpty) return l10n.errNeedSyncUrl;
    final phoneNo = _normPhone(rawPhone);
    if (!validPhone(phoneNo)) return l10n.errBadPhone;
    final res = await http
        .post(
          Uri.parse(_authed('/api/login')),
          headers: {..._gateHeaders, 'content-type': 'application/json'},
          body: jsonEncode({'phone': phoneNo, 'password': password}),
        )
        .timeout(const Duration(seconds: 20));
    final body = _decodeMap(res.body);
    if (res.statusCode >= 300) return '${body['error'] ?? l10n.errLoginFail}';
    await _applyAuth(body);
    return null;
  }

  Map<String, dynamic> _decodeMap(String raw) {
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _applyAuth(Map<String, dynamic> body) async {
    sessionId = '${body['session'] ?? ''}';
    final profileJson = Map<String, dynamic>.from(body['profile'] as Map? ?? {});
    profile = UserProfile.fromJson(profileJson);
    phone = profile!.phone;
    activeAccountPhone = phone;
    data = _freshData(childName: profile!.name);
    uploaded.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cami_session', sessionId);
    await prefs.setString('cami_phone', phone);
    await prefs.setString('cami_profile', jsonEncode(profile!.toJson()));
    uploaded.addAll(prefs.getStringList(_uploadedKey) ?? const []);
    try {
      final raw = await readState();
      if (raw != null && raw.isNotEmpty) {
        data = AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
      // 不在这里 write 空数据：先拉服务器再合并，避免新时间戳把云端积分盖掉
    } catch (_) {}
    await _repairEnglishCheckIn();
    notifyListeners();
    await syncPull(pushAfterMerge: true);
  }

  Future<void> logout() async {
    sessionId = '';
    phone = '';
    profile = null;
    parentMode = false;
    activeAccountPhone = '';
    uploaded.clear();
    data = _freshData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cami_session');
    await prefs.remove('cami_phone');
    await prefs.remove('cami_profile');
    await prefs.setBool('cami_parent_mode', false);
    notifyListeners();
  }

  Future<void> setParentMode(bool value) async {
    parentMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cami_parent_mode', value);
    notifyListeners();
    if (value) unawaited(syncPull(pushAfterMerge: true));
  }

  AppL10n get l10n => AppL10n.fromCode(localeCode);

  Future<void> setLocaleCode(String code) async {
    localeCode = code == 'en' ? 'en' : 'zh';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cami_locale', localeCode);
    notifyListeners();
  }

  /// 防止「英语打卡」丢掉特殊标记后，四条录音对不上、看起来像任务消失。
  Future<void> _repairEnglishCheckIn() async {
    var changed = false;
    for (final task in data.tasks) {
      final isCheckIn = task.subject == '英语' && (task.id == 'e1' || task.title.contains('打卡'));
      if (isCheckIn && !task.englishSpecial) {
        task.englishSpecial = true;
        changed = true;
      }
    }
    for (final row in data.progress) {
      for (final media in row.media) {
        if (media.englishType.isNotEmpty) continue;
        for (final type in englishTypes) {
          if (media.label.contains(type) || media.storedName.contains(type)) {
            media.englishType = type;
            changed = true;
            break;
          }
        }
      }
    }
    if (changed) await save();
  }

  TaskTemplate? englishCheckIn([String? date]) {
    final list = tasksFor('英语', date ?? todayKey);
    for (final task in list) {
      if (task.englishSpecial) return task;
    }
    for (final task in list) {
      if (task.id == 'e1' || task.title.contains('打卡')) return task;
    }
    return null;
  }

  TaskTemplate? taskById(String id) {
    for (final task in data.tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  bool checkPin(String pin) => pinHashOf(pin) == data.pinHash;

  Future<void> setPin(String pin) async {
    data.pinHash = pinHashOf(pin);
    await save();
  }

  Future<void> setChildName(String name) async {
    data.childName = name.trim().isEmpty ? 'Cami' : name.trim();
    await save();
  }

  Future<void> setServer(String url, String token) async {
    var cleaned = url.trim();
    final uri = Uri.tryParse(cleaned);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final embedded = uri.queryParameters['token']?.trim() ?? '';
      if (embedded.isNotEmpty && token.trim().isEmpty) token = embedded;
      final port = uri.hasPort ? ':${uri.port}' : '';
      cleaned = '${uri.scheme}://${uri.host}$port${uri.path}';
    }
    serverUrl = cleaned.replaceAll(RegExp(r'/+$'), '');
    serverToken = token.trim().isEmpty ? 'cami-home' : token.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cami_server_url', serverUrl);
    await prefs.setString('cami_server_token', serverToken);
    notifyListeners();
  }

  /// 从 GitHub 发现文件拉取最新同步地址。返回是否改写了本地配置。
  Future<bool> refreshEndpointFromDiscovery() async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final candidates = <Future<String?> Function()>[
      // 1) GitHub Contents API 原始正文（无 CDN 缓存，最及时）
      () => _httpGetBody(
            'https://api.github.com/repos/$discoveryRepo/contents/$discoveryPath?ref=main&_=$stamp',
            headers: const {
              'Accept': 'application/vnd.github.raw+json',
              'User-Agent': 'cami-app',
            },
          ),
      // 2) 先取该文件最新 commit，再走 jsDelivr@sha（国内快且按 commit 无陈旧缓存）
      () async {
        final sha = await _latestEndpointCommitSha();
        if (sha == null || sha.isEmpty) return null;
        return _httpGetBody(
          'https://cdn.jsdelivr.net/gh/$discoveryRepo@$sha/$discoveryPath',
        );
      },
      // 3) raw.githubusercontent（带防缓存参数）
      () => _httpGetBody(
            'https://raw.githubusercontent.com/$discoveryRepo/main/$discoveryPath?_=$stamp',
            headers: const {'User-Agent': 'cami-app', 'Cache-Control': 'no-cache'},
          ),
      // 4) GitHub Pages
      () => _httpGetBody(
            'https://xtyzmnchen.github.io/cami/sync-endpoint.json?_=$stamp',
          ),
      // 5) jsDelivr @main（最后兜底，可能有延迟）
      () => _httpGetBody(
            'https://cdn.jsdelivr.net/gh/$discoveryRepo@main/$discoveryPath?_=$stamp',
          ),
    ];

    for (final fetch in candidates) {
      try {
        final body = await fetch();
        if (body == null || body.trim().isEmpty) continue;
        final applied = await _applyDiscoveryJson(body);
        if (applied != null) return applied;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  Future<String?> _httpGetBody(String url, {Map<String, String>? headers}) async {
    final res = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    return res.body;
  }

  Future<String?> _latestEndpointCommitSha() async {
    try {
      final res = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$discoveryRepo/commits'
              '?path=$discoveryPath&per_page=1',
            ),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'cami-app',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body);
      if (list is! List || list.isEmpty) return null;
      final first = list.first;
      if (first is! Map) return null;
      return '${first['sha'] ?? ''}';
    } catch (_) {
      return null;
    }
  }

  /// 解析发现 JSON；成功应用时返回是否发生了变更（true/false），解析失败返回 null。
  Future<bool?> _applyDiscoveryJson(String body) async {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final nextUrl = '${decoded['url'] ?? ''}'.trim().replaceAll(RegExp(r'/+$'), '');
    final nextToken = '${decoded['token'] ?? ''}'.trim();
    if (nextUrl.isEmpty) return null;
    final check = Uri.tryParse(nextUrl);
    if (check == null || !check.hasScheme || check.host.isEmpty) return null;
    final token = nextToken.isEmpty ? serverToken : nextToken;
    if (nextUrl == serverUrl && token == serverToken) return false;
    await setServer(nextUrl, token);
    return true;
  }

  Map<String, String> get _gateHeaders => {
        'x-cami-token': serverToken,
      };

  Map<String, String> get _authHeaders => {
        'x-cami-token': serverToken,
        if (sessionId.isNotEmpty) 'x-cami-session': sessionId,
      };

  String _authed(String path) {
    final join = path.contains('?') ? '&' : '?';
    var url = '$serverUrl$path${join}token=${Uri.encodeQueryComponent(serverToken)}';
    if (sessionId.isNotEmpty) {
      url += '&session=${Uri.encodeQueryComponent(sessionId)}';
    }
    return url;
  }

  List<TaskTemplate> tasksFor(String subject, String date) =>
      tasksOn(data, date, subject);

  TaskProgress? progress(String date, String taskId) =>
      progressOf(data, date, taskId);

  bool done(String date, String taskId) => isDone(data, date, taskId);

  int pointsOn(String date) => dayPoints(data, date);

  int get earned => earnedPoints(data);
  int get spent => redeemedPoints(data);
  int get balance => pointBalance(data);

  bool playable(String date) => canPlay(data, date);
  bool playExhausted(String date) => playTimeExhausted(data, date);
  int playSecondsLeftToday([String? date]) => remainingPlaySeconds(data, date ?? todayKey);
  GameKind todayGame([DateTime? day]) => gameForDay(day ?? DateTime.now());

  TaskProgress _ensure(String date, String taskId) {
    final found = progress(date, taskId);
    if (found != null) return found;
    final created = TaskProgress(taskId: taskId, date: date);
    data.progress.add(created);
    return created;
  }

  Future<MediaItem> addMedia({
    required String date,
    required String taskId,
    required String kind,
    required String label,
    required List<int> bytes,
    String englishType = '',
    String note = '',
    String noteZh = '',
  }) async {
    final ext = kind == 'photo'
        ? 'jpg'
        : kind == 'video'
            ? 'mp4'
            : 'm4a';
    final task = taskById(taskId);
    final display = mediaDisplayName(
      date: date,
      kind: kind,
      taskTitle: task?.title ?? label,
      englishType: englishType,
    );
    // 磁盘文件名只用 ASCII，中文放在 label 里显示。
    final base = safeMediaFileName('${date}_${kind}_${_uuid.v4().substring(0, 8)}');
    final used = data.progress
        .expand((row) => row.media)
        .map((item) => item.storedName)
        .toSet()
      ..addAll(uploaded);
    var stored = '$base.$ext';
    var index = 2;
    while (used.contains(stored)) {
      stored = '${base}_$index.$ext';
      index++;
    }
    final path = await saveMediaBytes(stored, bytes);
    final item = MediaItem(
      id: _uuid.v4(),
      kind: kind,
      storedName: stored,
      path: path,
      label: display,
      englishType: englishType,
      note: note,
      noteZh: noteZh,
    );
    _ensure(date, taskId).media.add(item);
    await save();
    return item;
  }

  Future<void> deleteMedia({
    required String date,
    required String taskId,
    required String mediaId,
  }) async {
    final row = progress(date, taskId);
    if (row == null) return;
    final index = row.media.indexWhere((m) => m.id == mediaId);
    if (index < 0) return;
    final item = row.media.removeAt(index);
    await deleteMediaFile(item.path, item.storedName);
    await _deleteRemoteMedia(item.storedName);
    if (uploaded.remove(item.storedName)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('cami_uploaded', uploaded.toList());
    }
    final task = taskById(taskId);
    if (row.done && task != null) {
      final emptyRequired = !task.schoolOnly && row.media.isEmpty;
      final englishMissing = task.englishSpecial &&
          englishTypes.any((type) => row.media.every((m) => m.englishType != type));
      if (emptyRequired || englishMissing) {
        row.done = false;
        row.points = 0;
      }
    }
    await save();
  }

  Future<void> _deleteRemoteMedia(String storedName) async {
    if (serverUrl.isEmpty || storedName.isEmpty) return;
    try {
      await http
          .delete(
            Uri.parse(_authed('/api/media/${Uri.encodeComponent(storedName)}')),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  Future<void> startTimer(String date, String taskId, int minutes) async {
    final row = _ensure(date, taskId);
    row.timerEndsAt = DateTime.now().add(Duration(minutes: minutes)).toIso8601String();
    await save();
  }

  Future<void> stopTimer(String date, String taskId) async {
    final row = _ensure(date, taskId);
    row.timerEndsAt = null;
    await save();
  }

  DateTime? timerEndsAt(String date, String taskId) {
    final raw = progress(date, taskId)?.timerEndsAt;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<String?> complete(String date, String taskId) async {
    final task = taskById(taskId);
    if (task == null) return l10n.errTaskNotFound;
    final row = _ensure(date, taskId);
    final isVocab = taskId == vocabTaskId || task.title.contains('单词');
    final isPoem = isPoemTaskIdTitle(taskId, task.title);
    if (isVocab) {
      final session = data.vocab.dayOf(date);
      if (session == null || !session.done) {
        return l10n.errVocabNotDone;
      }
    } else if (isPoem) {
      final session = data.poems.dayOf(date);
      if (session == null || !session.mastered) {
        return l10n.errPoemNotDone;
      }
    } else if (row.media.isEmpty && !task.schoolOnly) {
      return l10n.errFinishFirst;
    }
    if (task.englishSpecial) {
      final missing = englishTypes.where((type) => row.media.every((m) => m.englishType != type)).toList();
      if (missing.isNotEmpty) {
        return l10n.errStillRecord(missing.map(l10n.englishType).join(l10n.isEn ? ', ' : '、'));
      }
    }
    row.done = true;
    row.points = task.bonus ? 1 : task.points.clamp(1, 5);
    row.timerEndsAt = null;
    await save();
    return null;
  }

  VocabDayRecord ensureVocabToday([DateTime? now]) {
    final day = now ?? DateTime.now();
    final key = dayKey(day);
    final existing = data.vocab.dayOf(key);
    if (existing != null) return existing;

    final mode = vocabModeFor(day, data.vocab);
    final indexes = assignWordIndexes(mode: mode, state: data.vocab, day: day);
    final record = VocabDayRecord(
      date: key,
      mode: vocabModeKey(mode),
      wordIndexes: indexes,
      mastered: [],
    );
    if (mode == VocabMode.daily && indexes.isNotEmpty) {
      data.vocab.nextIndex = (indexes.last + 1).clamp(0, vocabBankSize);
    }
    data.vocab.days.add(record);
    data.vocab.days.sort((a, b) => a.date.compareTo(b.date));
    unawaited(save());
    return record;
  }

  Future<void> masterVocabWord(String date, int wordIndex) async {
    final row = data.vocab.dayOf(date) ?? ensureVocabToday();
    if (row.date != date) return;
    if (!row.wordIndexes.contains(wordIndex)) return;
    if (!row.mastered.contains(wordIndex)) {
      row.mastered.add(wordIndex);
    }
    await save();
    if (row.done) {
      await complete(date, vocabTaskId);
    }
  }

  String vocabTodayBadge([String? date]) {
    final key = date ?? todayKey;
    final row = data.vocab.dayOf(key);
    if (row == null) {
      final mode = vocabModeFor(DateTime.now(), data.vocab);
      final preview = assignWordIndexes(mode: mode, state: data.vocab, day: DateTime.now());
      final n = preview.isEmpty ? vocabDailyCount : preview.length;
      return l10n.vocabBadgePreview(vocabModeKey(mode), n);
    }
    return l10n.vocabBadge(row.mode, row.mastered.length, row.wordIndexes.length);
  }

  List<VocabDayRecord> vocabHistory() {
    final list = [...data.vocab.days]..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  PoemDayRecord ensurePoemToday([DateTime? now]) {
    final day = now ?? DateTime.now();
    final key = dayKey(day);
    final existing = data.poems.dayOf(key);
    if (existing != null) return existing;

    final cont = data.poems.continueIndex;
    final index = (cont != null && cont >= 0 && cont < poemBankSize)
        ? cont
        : data.poems.nextIndex.clamp(0, poemBankSize);
    final record = PoemDayRecord(
      date: key,
      poemIndex: index >= poemBankSize ? poemBankSize - 1 : index,
      mastered: false,
    );
    data.poems.days.add(record);
    data.poems.days.sort((a, b) => a.date.compareTo(b.date));
    unawaited(save());
    return record;
  }

  /// 背熟：推进下一首，完成作业。
  Future<void> masterPoemToday(String taskId) async {
    final key = todayKey;
    final row = data.poems.dayOf(key) ?? ensurePoemToday();
    row.mastered = true;
    if (data.poems.continueIndex == row.poemIndex) {
      data.poems.continueIndex = null;
    }
    data.poems.nextIndex = (row.poemIndex + 1).clamp(0, poemBankSize);
    await save();
    await complete(key, taskId);
  }

  /// 没背熟：明天继续同一首，今天作业不打勾。
  Future<void> deferPoemToday() async {
    final key = todayKey;
    final row = data.poems.dayOf(key) ?? ensurePoemToday();
    row.mastered = false;
    data.poems.continueIndex = row.poemIndex;
    final progressRow = progress(key, poemTaskId);
    if (progressRow != null) {
      progressRow.done = false;
      progressRow.points = 0;
    }
    // 也清掉标题含「古诗」的其它任务今日完成状态
    for (final task in data.tasks) {
      if (!isPoemTaskIdTitle(task.id, task.title)) continue;
      final p = progress(key, task.id);
      if (p != null) {
        p.done = false;
        p.points = 0;
      }
    }
    await save();
  }

  String poemTodayBadge() {
    final row = data.poems.dayOf(todayKey);
    final index = row?.poemIndex ?? data.poems.continueIndex ?? data.poems.nextIndex;
    final poem = poemAt(index.clamp(0, poemBankSize - 1));
    if (poem == null) return l10n.tr('古诗库已学完', 'Poem bank finished');
    final tag = row?.mastered == true
        ? l10n.tr('已背熟', 'Mastered')
        : (data.poems.continueIndex == index
            ? l10n.tr('继续背', 'Continue')
            : l10n.tr('今日', 'Today'));
    return '$tag · ${poem.title}';
  }

  Future<void> parentConfirmSchool(String date, String taskId) async {
    final task = taskById(taskId);
    if (task == null) return;
    final row = _ensure(date, taskId);
    row.done = true;
    row.points = task.points.clamp(1, 5);
    await save();
  }

  Future<void> setScore(String date, String taskId, int points, String comment) async {
    final row = _ensure(date, taskId);
    row.done = true;
    row.points = points.clamp(1, 5);
    row.comment = comment;
    await save();
  }

  Future<void> sendBack(String date, String taskId, String comment) async {
    final row = _ensure(date, taskId);
    row.done = false;
    row.points = 0;
    row.comment = comment;
    row.timerEndsAt = null;
    await save();
  }

  Future<void> saveTask(TaskTemplate task) async {
    final index = data.tasks.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      data.tasks[index] = task;
    } else {
      data.tasks.add(task);
    }
    await save();
  }

  Future<void> deleteTask(String id) async {
    data.tasks.removeWhere((t) => t.id == id);
    await save();
  }

  String newId() => _uuid.v4();

  /// 写入当天剩余游戏秒数；为 0 后不能再进。
  Future<void> savePlaySecondsLeft(String date, int seconds) async {
    data.playSecondsLeft[date] = seconds.clamp(0, playBudgetSeconds);
    if (seconds <= 0) {
      final prev = data.playsUsed[date] ?? 0;
      data.playsUsed[date] = prev < 1 ? 1 : prev;
    }
    await save();
  }

  Future<void> saveReward(Reward reward) async {
    final index = data.rewards.indexWhere((r) => r.id == reward.id);
    if (index >= 0) {
      data.rewards[index] = reward;
    } else {
      data.rewards.add(reward);
    }
    await save();
  }

  Future<void> deleteReward(String id) async {
    data.rewards.removeWhere((r) => r.id == id);
    await save();
  }

  String? redeem(String rewardId) {
    Reward? reward;
    for (final item in data.rewards) {
      if (item.id == rewardId) reward = item;
    }
    if (reward == null) return l10n.errRewardNotFound;
    if (reward.cost > balance) return l10n.errNotEnoughPts;
    data.redemptions.insert(
      0,
      Redemption(
        id: _uuid.v4(),
        title: reward.title,
        cost: reward.cost,
        at: DateTime.now().toIso8601String(),
      ),
    );
    save();
    return null;
  }

  Future<void> save() async {
    data.updatedAt = DateTime.now().toIso8601String();
    await writeState(jsonEncode(data.toJson()));
    notifyListeners();
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 1), syncPush);
  }

  Future<void> syncPush({bool allowDiscover = true}) async {
    if (serverUrl.isEmpty && allowDiscover) {
      await refreshEndpointFromDiscovery();
    }
    if (serverUrl.isEmpty || !isLoggedIn) return;
    if (syncing) {
      _pushAgain = true;
      return;
    }
    syncing = true;
    syncError = null;
    notifyListeners();
    var retryDiscover = false;
    try {
      final missing = <String>[];
      for (final row in data.progress) {
        for (final media in row.media) {
          final remoteUrl = _authed('/api/media/${Uri.encodeComponent(media.storedName)}');
          if (uploaded.contains(media.storedName)) {
            final check = await http
                .get(Uri.parse(remoteUrl), headers: _authHeaders)
                .timeout(const Duration(seconds: 15));
            if (check.statusCode == 200) continue;
            uploaded.remove(media.storedName);
          }
          final bytes = await readMediaBytes(media.path);
          if (bytes == null || bytes.isEmpty) {
            missing.add(media.label.isEmpty ? media.storedName : media.label);
            continue;
          }
          final res = await http
              .post(
                Uri.parse(remoteUrl),
                headers: {
                  ..._authHeaders,
                  'content-type': 'application/octet-stream',
                },
                body: bytes,
              )
              .timeout(const Duration(seconds: 120));
          if (res.statusCode == 401) throw Exception(l10n.errWrongPassphrase);
          if (res.statusCode >= 300) {
            throw Exception(l10n.errUploadFail(res.statusCode));
          }
          uploaded.add(media.storedName);
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_uploadedKey, uploaded.toList());
      final res = await http
          .put(
            Uri.parse(_authed('/api/state')),
            headers: {
              ..._authHeaders,
              'content-type': 'application/json',
            },
            body: jsonEncode(data.toJson()),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 401) throw Exception(l10n.errReLogin);
      if (res.statusCode >= 300) throw Exception(l10n.errSyncFail(res.statusCode));
      lastSync = DateTime.now();
      syncError = missing.isEmpty ? null : l10n.syncPartialMedia(missing.length);
    } catch (e) {
      syncError = _syncErrorMessage('$e');
      retryDiscover = allowDiscover && _looksLikeEndpointDown('$e');
    } finally {
      syncing = false;
      notifyListeners();
      if (_pushAgain) {
        _pushAgain = false;
        unawaited(syncPush(allowDiscover: allowDiscover));
      }
    }
    if (retryDiscover) {
      final updated = await refreshEndpointFromDiscovery();
      if (updated) await syncPush(allowDiscover: false);
    }
  }

  Future<void> syncPull({bool pushAfterMerge = false, bool allowDiscover = true}) async {
    if (serverUrl.isEmpty && allowDiscover) {
      await refreshEndpointFromDiscovery();
    }
    if (serverUrl.isEmpty) {
      syncError = l10n.errNeedUrlLogin;
      notifyListeners();
      return;
    }
    if (!isLoggedIn) {
      syncError = l10n.errNeedPhoneLogin;
      notifyListeners();
      return;
    }
    if (syncing) return;
    syncing = true;
    syncError = null;
    notifyListeners();
    var shouldPush = pushAfterMerge;
    var retryDiscover = false;
    try {
      final res = await http
          .get(
            Uri.parse(_authed('/api/state')),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 401) throw Exception(l10n.errReLogin);
      if (res.statusCode == 404) {
        // 云端还没有：把本地（含积分进度）上传上去
        lastSync = DateTime.now();
        shouldPush = true;
      } else if (res.statusCode >= 300) {
        throw Exception(l10n.errReadFail(res.statusCode));
      } else {
        final remote = AppData.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
        // 始终合并，避免「时间戳较新的空本地」盖掉另一台手机的积分
        data = mergeAppData(data, remote);
        await writeState(jsonEncode(data.toJson()));
        final keep = data.progress.expand((row) => row.media).map((m) => m.storedName).toSet();
        uploaded.removeWhere((name) => !keep.contains(name));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_uploadedKey, uploaded.toList());
        await pruneOrphanMedia(keep);
        shouldPush = true;
      }
      lastSync = DateTime.now();
      syncError = null;
    } catch (e) {
      syncError = _syncErrorMessage('$e');
      shouldPush = false;
      retryDiscover = allowDiscover && _looksLikeEndpointDown('$e');
    } finally {
      syncing = false;
      notifyListeners();
      if (shouldPush) unawaited(syncPush());
    }
    if (retryDiscover) {
      final updated = await refreshEndpointFromDiscovery();
      if (updated) await syncPull(pushAfterMerge: pushAfterMerge, allowDiscover: false);
    }
  }

  bool _looksLikeEndpointDown(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('socket') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection') ||
        lower.contains('timed out') ||
        lower.contains('timeout') ||
        lower.contains('network') ||
        lower.contains('clientexception') ||
        text.contains('离线') ||
        text.contains(l10n.errSyncOffline)) {
      return true;
    }
    final code = RegExp(r'\b([45]\d{2})\b').firstMatch(text)?.group(1);
    return code == '502' || code == '503' || code == '504' || code == '404';
  }

  String _syncErrorMessage(String text) {
    final lower = text.toLowerCase();
    if (text.contains(l10n.errReLogin) ||
        text.contains('请重新登录') ||
        lower.contains('sign in again') ||
        lower.contains('relogin')) {
      return l10n.errSessionExpired;
    }
    if (text.contains(l10n.errWrongPassphrase) ||
        text.contains(l10n.errBadToken) ||
        text.contains('口令') ||
        lower.contains('token') ||
        lower.contains('passphrase')) {
      return l10n.errTokenFix;
    }
    return l10n.errSyncOffline;
  }
}

List<TaskTemplate> seedTasks() => [
      TaskTemplate(id: 'cn1', subject: '语文', title: '校内作业', minutes: 0, points: 2, schoolOnly: true),
      TaskTemplate(id: 'cn2', subject: '语文', title: '黄冈每课一练', minutes: 15, points: 4),
      TaskTemplate(id: 'cn3', subject: '语文', title: '每课练字', minutes: 10, points: 3),
      TaskTemplate(id: 'cn4', subject: '语文', title: '每课阅读 + 课外阅读', minutes: 30, points: 5),
      TaskTemplate(id: 'm1', subject: '数学', title: '计算题', minutes: 15, points: 4),
      TaskTemplate(id: 'm2', subject: '数学', title: '每课一练', minutes: 20, points: 4),
      TaskTemplate(id: 'm3', subject: '数学', title: '每日一练', minutes: 20, points: 4),
      TaskTemplate(id: 'e1', subject: '英语', title: '英语打卡', minutes: 10, points: 4, englishSpecial: true),
      TaskTemplate(id: 'e2', subject: '英语', title: '每日3页阅读', minutes: 10, points: 3),
      TaskTemplate(id: 'e3', subject: '英语', title: '背诵单词', minutes: 10, points: 3),
      TaskTemplate(id: 'e4', subject: '英语', title: '英语默写', minutes: 20, points: 4),
      TaskTemplate(id: 'o1', subject: '其他', title: '运动', minutes: 20, points: 3, note: '下去玩的时间'),
      TaskTemplate(id: 'o2', subject: '其他', title: '背古诗', minutes: 10, points: 3),
      TaskTemplate(id: 'o3', subject: '其他', title: '上英语课', minutes: 30, points: 3),
    ];

List<Reward> seedRewards() => [
      Reward(id: 'r1', title: '一张贴纸', cost: 10),
      Reward(id: 'r2', title: '选一个睡前故事', cost: 20),
      Reward(id: 'r3', title: '看一集动画', cost: 30),
      Reward(id: 'r4', title: '周末小礼物', cost: 60),
    ];

