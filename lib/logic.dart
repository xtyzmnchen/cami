import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

import 'models.dart';

enum DayMark { future, open, red, yellow, green }

enum Decor { none, berry, flower, crown }

enum GameKind { snake, memory, catchFruit, sliceFruit, whackMole, match3, runner }

const gameTitles = {
  GameKind.snake: '贪吃蛇',
  GameKind.memory: '翻翻乐',
  GameKind.catchFruit: '接水果',
  GameKind.sliceFruit: '切水果',
  GameKind.whackMole: '打地鼠',
  GameKind.match3: '消消乐',
  GameKind.runner: '小公主跑酷',
};

String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String pinHashOf(String pin) => sha256.convert(pin.codeUnits).toString();

int earnedPoints(AppData data) => data.progress
    .where((p) => p.done)
    .fold(0, (sum, p) => sum + p.points);

int redeemedPoints(AppData data) =>
    data.redemptions.fold(0, (sum, r) => sum + r.cost);

int pointBalance(AppData data) => earnedPoints(data) - redeemedPoints(data);

List<TaskTemplate> tasksOn(AppData data, String date, [String? subject]) {
  return data.tasks.where((t) {
    if (subject != null && t.subject != subject) return false;
    if (t.bonus) return t.bonusDate == date;
    return true;
  }).toList();
}

TaskProgress? progressOf(AppData data, String date, String taskId) {
  for (final p in data.progress) {
    if (p.date == date && p.taskId == taskId) return p;
  }
  return null;
}

bool isDone(AppData data, String date, String taskId) =>
    progressOf(data, date, taskId)?.done == true;

int dayPoints(AppData data, String date) => data.progress
    .where((p) => p.date == date && p.done)
    .fold(0, (sum, p) => sum + p.points);

int monthPoints(AppData data, int year, int month) {
  final prefix = '$year-${month.toString().padLeft(2, '0')}';
  return data.progress
      .where((p) => p.done && p.date.startsWith(prefix))
      .fold(0, (sum, p) => sum + p.points);
}

int yearPoints(AppData data, int year) => data.progress
    .where((p) => p.done && p.date.startsWith('$year-'))
    .fold(0, (sum, p) => sum + p.points);

bool allDefaultDone(AppData data, String date) {
  final tasks = data.tasks.where((t) => !t.bonus);
  if (tasks.isEmpty) return false;
  return tasks.every((t) => isDone(data, date, t.id));
}

bool allVisibleDone(AppData data, String date) {
  final tasks = tasksOn(data, date);
  if (tasks.isEmpty) return false;
  return tasks.every((t) => isDone(data, date, t.id));
}

const playBudgetSeconds = 10 * 60;

/// 作业都做完后，当天一共可玩 10 分钟；中途退出保留剩余时间。
int remainingPlaySeconds(AppData data, String date) {
  if (!allDefaultDone(data, date)) return 0;
  if (data.playSecondsLeft.containsKey(date)) {
    return data.playSecondsLeft[date]!.clamp(0, playBudgetSeconds);
  }
  // 兼容旧数据：曾经按「轮次」记过，视为今天已玩完。
  if ((data.playsUsed[date] ?? 0) > 0) return 0;
  return playBudgetSeconds;
}

bool canPlay(AppData data, String date) => remainingPlaySeconds(data, date) > 0;

bool playTimeExhausted(AppData data, String date) =>
    allDefaultDone(data, date) && remainingPlaySeconds(data, date) <= 0;

DayMark markFor(AppData data, DateTime day, DateTime today) {
  final d = dateOnly(day);
  final t = dateOnly(today);
  if (d.isAfter(t)) return DayMark.future;
  final tasks = tasksOn(data, dayKey(d));
  final done = tasks.where((task) => isDone(data, dayKey(d), task.id)).length;
  if (done == 0) return d == t ? DayMark.open : DayMark.red;
  if (done == tasks.length) return DayMark.green;
  return DayMark.yellow;
}

Decor decorFor(AppData data, DateTime day) {
  final key = dayKey(day);
  final tasks = tasksOn(data, key);
  if (tasks.isEmpty) return Decor.none;
  final done = tasks.where((task) => isDone(data, key, task.id)).length;
  if (done == 0) return Decor.none;
  if (done == tasks.length) return Decor.crown;
  if (done * 2 >= tasks.length) return Decor.flower;
  return Decor.berry;
}

/// 一周 7 款各出现一次。下一周用新的随机顺序。
List<GameKind> weekGames(DateTime day) {
  final monday = dateOnly(day).subtract(Duration(days: day.weekday - 1));
  final rng = Random(monday.year * 1000 + monday.month * 50 + monday.day);
  final list = GameKind.values.toList()..shuffle(rng);
  return list;
}

GameKind gameForDay(DateTime day) => weekGames(day)[day.weekday - 1];

/// 合并两台设备的数据：进度 / 兑换 / 奖励都保留，积分自然一致。
AppData mergeAppData(AppData local, AppData remote) {
  final newer = remote.updatedAt.compareTo(local.updatedAt) >= 0 ? remote : local;
  final older = identical(newer, remote) ? local : remote;

  final tasks = <String, TaskTemplate>{};
  for (final t in [...older.tasks, ...newer.tasks]) {
    tasks[t.id] = t;
  }

  final progress = <String, TaskProgress>{};
  for (final row in [...older.progress, ...newer.progress]) {
    final key = '${row.date}|${row.taskId}';
    final prev = progress[key];
    if (prev == null) {
      progress[key] = row;
      continue;
    }
    progress[key] = _mergeProgress(prev, row);
  }

  final rewards = <String, Reward>{};
  for (final r in [...older.rewards, ...newer.rewards]) {
    rewards[r.id] = r;
  }

  final redemptions = <String, Redemption>{};
  for (final r in [...older.redemptions, ...newer.redemptions]) {
    redemptions[r.id] = r;
  }
  final redemptionList = redemptions.values.toList()
    ..sort((a, b) => b.at.compareTo(a.at));

  final plays = <String, int>{...older.playsUsed};
  for (final e in newer.playsUsed.entries) {
    plays[e.key] = max(plays[e.key] ?? 0, e.value);
  }

  final playLeft = <String, int>{...older.playSecondsLeft};
  for (final e in newer.playSecondsLeft.entries) {
    final prev = playLeft[e.key];
    playLeft[e.key] = prev == null ? e.value : min(prev, e.value);
  }

  return AppData(
    pinHash: newer.pinHash.isNotEmpty ? newer.pinHash : older.pinHash,
    childName: newer.childName.trim().isNotEmpty ? newer.childName : older.childName,
    updatedAt: DateTime.now().toIso8601String(),
    tasks: tasks.values.toList(),
    progress: progress.values.toList(),
    rewards: rewards.values.toList(),
    redemptions: redemptionList,
    playsUsed: plays,
    playSecondsLeft: playLeft,
    vocab: mergeVocabState(local.vocab, remote.vocab),
    poems: mergePoemState(local.poems, remote.poems),
  );
}

PoemState mergePoemState(PoemState a, PoemState b) {
  final days = <String, PoemDayRecord>{};
  for (final d in [...a.days, ...b.days]) {
    final prev = days[d.date];
    if (prev == null) {
      days[d.date] = PoemDayRecord(date: d.date, poemIndex: d.poemIndex, mastered: d.mastered);
      continue;
    }
    days[d.date] = PoemDayRecord(
      date: d.date,
      poemIndex: prev.mastered ? prev.poemIndex : (d.mastered ? d.poemIndex : prev.poemIndex),
      mastered: prev.mastered || d.mastered,
    );
  }
  final sorted = days.values.toList()..sort((x, y) => x.date.compareTo(y.date));
  final cont = a.continueIndex ?? b.continueIndex;
  return PoemState(
    nextIndex: max(a.nextIndex, b.nextIndex),
    continueIndex: cont,
    days: sorted,
  );
}

VocabState mergeVocabState(VocabState a, VocabState b) {
  final days = <String, VocabDayRecord>{};
  for (final d in [...a.days, ...b.days]) {
    final prev = days[d.date];
    if (prev == null) {
      days[d.date] = VocabDayRecord(
        date: d.date,
        mode: d.mode,
        wordIndexes: [...d.wordIndexes],
        mastered: [...d.mastered],
      );
      continue;
    }
    final indexes = <int>{...prev.wordIndexes, ...d.wordIndexes}.toList()..sort();
    final mastered = <int>{...prev.mastered, ...d.mastered}.toList()..sort();
    final mode = prev.mode == 'monthly' || d.mode == 'monthly'
        ? 'monthly'
        : (prev.mode == 'weekly' || d.mode == 'weekly' ? 'weekly' : 'daily');
    days[d.date] = VocabDayRecord(
      date: d.date,
      mode: mode,
      wordIndexes: indexes,
      mastered: mastered,
    );
  }
  final sorted = days.values.toList()..sort((x, y) => x.date.compareTo(y.date));
  return VocabState(
    nextIndex: max(a.nextIndex, b.nextIndex),
    days: sorted,
  );
}

TaskProgress _mergeProgress(TaskProgress a, TaskProgress b) {
  final media = <String, MediaItem>{};
  for (final m in [...a.media, ...b.media]) {
    media[m.storedName.isNotEmpty ? m.storedName : m.id] = m;
  }
  final done = a.done || b.done;
  final points = max(a.points, b.points);
  final comment = b.comment.trim().isNotEmpty ? b.comment : a.comment;
  final timer = () {
    final at = a.timerEndsAt;
    final bt = b.timerEndsAt;
    if (at == null) return bt;
    if (bt == null) return at;
    return at.compareTo(bt) >= 0 ? at : bt;
  }();
  return TaskProgress(
    taskId: a.taskId,
    date: a.date,
    done: done,
    points: done ? (points > 0 ? points : max(a.points, b.points)) : 0,
    comment: comment,
    timerEndsAt: timer,
    media: media.values.toList(),
  );
}

String englishFileLabel(DateTime day, String type) =>
    'Cami_${DateFormat('yyyyMMdd').format(day)}_$type';

String safeMediaFileName(String raw) {
  // 只保留 ASCII，避免上传 URL / 服务端解码中文文件名时报错。
  var name = raw.trim();
  name = name.replaceAll(RegExp(r'[\\/:*?"<>|\n\r]+'), '_');
  name = name.replaceAll(RegExp(r'\s+'), '');
  name = name.replaceAll('·', '');
  name = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  name = name.replaceAll(RegExp(r'_+'), '_');
  name = name.replaceAll(RegExp(r'^_+|_+$'), '');
  if (name.isEmpty) name = 'media';
  if (name.length > 48) name = name.substring(0, 48);
  return name;
}

String mediaDisplayName({
  required String date,
  required String kind,
  required String taskTitle,
  String englishType = '',
}) {
  if (englishType.isNotEmpty) {
    final day = DateTime.tryParse(date) ?? DateTime.now();
    return englishFileLabel(day, englishType);
  }
  final type = kind == 'photo'
      ? '照片'
      : kind == 'video'
          ? '视频'
          : '录音';
  final title = taskTitle.trim().isEmpty ? '作业' : taskTitle.trim();
  return '${date}_$title$type';
}
