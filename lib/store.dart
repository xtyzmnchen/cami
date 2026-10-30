import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'logic.dart';
import 'models.dart';
import 'storage/files.dart';

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
  String? syncError;
  DateTime? lastSync;
  bool syncing = false;
  bool _pushAgain = false;
  final uploaded = <String>{};
  Timer? _syncTimer;
  final _uuid = const Uuid();

  String get todayKey => dayKey(DateTime.now());

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    serverUrl = prefs.getString('cami_server_url') ?? '';
    serverToken = prefs.getString('cami_server_token') ?? 'cami-home';
    uploaded.addAll(prefs.getStringList('cami_uploaded') ?? const []);
    try {
      final raw = await readState();
      if (raw != null && raw.isNotEmpty) {
        data = AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    await _repairEnglishCheckIn();
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
    serverUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    serverToken = token.trim().isEmpty ? 'cami-home' : token.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cami_server_url', serverUrl);
    await prefs.setString('cami_server_token', serverToken);
    notifyListeners();
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
  bool addableBonus(String date) => canAddBonus(data, date);
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
    final base = safeMediaFileName(display);
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
      final uri = Uri.parse(
        '$serverUrl/api/media/${Uri.encodeComponent(storedName)}?token=${Uri.encodeQueryComponent(serverToken)}',
      );
      await http.delete(uri).timeout(const Duration(seconds: 15));
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
    if (task == null) return '找不到这件作业';
    final row = _ensure(date, taskId);
    if (row.media.isEmpty && !task.schoolOnly) {
      return '请先完成后再点击哦';
    }
    if (task.englishSpecial) {
      final missing = englishTypes.where((type) => row.media.every((m) => m.englishType != type)).toList();
      if (missing.isNotEmpty) {
        return '还没录完：${missing.join('、')}';
      }
    }
    row.done = true;
    row.points = task.bonus ? 1 : task.points.clamp(1, 5);
    row.timerEndsAt = null;
    await save();
    return null;
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

  Future<void> finishPlay(String date) async {
    data.playsUsed[date] = (data.playsUsed[date] ?? 0) + 1;
    await save();
  }

  Future<void> addBonus(String date, String title) async {
    data.tasks.add(TaskTemplate(
      id: _uuid.v4(),
      subject: '其他',
      title: title.trim().isEmpty ? '新任务' : title.trim(),
      minutes: 15,
      points: 1,
      bonus: true,
      bonusDate: date,
      note: '做完可以再玩一次',
    ));
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
    if (reward == null) return '找不到这个奖励';
    if (reward.cost > balance) return '积分还不够';
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

  Future<void> syncPush() async {
    if (serverUrl.isEmpty) return;
    if (syncing) {
      _pushAgain = true;
      return;
    }
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      for (final row in data.progress) {
        for (final media in row.media) {
          if (uploaded.contains(media.storedName)) continue;
          final bytes = await readMediaBytes(media.path);
          if (bytes == null) continue;
          final uri = Uri.parse(
            '$serverUrl/api/media/${Uri.encodeComponent(media.storedName)}?token=${Uri.encodeQueryComponent(serverToken)}',
          );
          final res = await http.post(uri, body: bytes).timeout(const Duration(seconds: 30));
          if (res.statusCode >= 300) {
            throw Exception('上传失败 ${res.statusCode}');
          }
          uploaded.add(media.storedName);
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('cami_uploaded', uploaded.toList());
      final res = await http
          .put(
            Uri.parse('$serverUrl/api/state?token=${Uri.encodeQueryComponent(serverToken)}'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(data.toJson()),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode >= 300) throw Exception('同步失败 ${res.statusCode}');
      lastSync = DateTime.now();
      syncError = null;
    } catch (e) {
      syncError = '还没连上同步电脑，检查地址和 cpolar';
    } finally {
      syncing = false;
      notifyListeners();
      if (_pushAgain) {
        _pushAgain = false;
        unawaited(syncPush());
      }
    }
  }

  Future<void> syncPull() async {
    if (serverUrl.isEmpty) {
      syncError = '先在设置里填写同步电脑地址';
      notifyListeners();
      return;
    }
    if (syncing) return;
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      final res = await http
          .get(Uri.parse('$serverUrl/api/state?token=${Uri.encodeQueryComponent(serverToken)}'))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 404) {
        lastSync = DateTime.now();
        syncing = false;
        notifyListeners();
        return;
      }
      if (res.statusCode >= 300) throw Exception('读取失败');
      final remote = AppData.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      if (remote.updatedAt.compareTo(data.updatedAt) >= 0) {
        data = remote;
        await writeState(jsonEncode(data.toJson()));
        final keep = data.progress.expand((row) => row.media).map((m) => m.storedName).toSet();
        uploaded.removeWhere((name) => !keep.contains(name));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('cami_uploaded', uploaded.toList());
        await pruneOrphanMedia(keep);
      }
      lastSync = DateTime.now();
      syncError = null;
    } catch (_) {
      syncError = '还没连上同步电脑，检查地址和 cpolar';
    } finally {
      syncing = false;
      notifyListeners();
    }
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
      TaskTemplate(id: 'e3', subject: '英语', title: '背诵3个单词', minutes: 10, points: 3),
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

