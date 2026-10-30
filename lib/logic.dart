import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

import 'models.dart';

enum DayMark { future, open, red, yellow, green }

enum Decor { none, berry, flower, crown }

enum GameKind { snake, memory, catchFruit, maze, math, puzzle, runner }

const gameTitles = {
  GameKind.snake: '贪吃蛇',
  GameKind.memory: '翻翻乐',
  GameKind.catchFruit: '接水果',
  GameKind.maze: '迷宫找皇冠',
  GameKind.math: '口算星星',
  GameKind.puzzle: '滑动拼图',
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

int playsEarned(AppData data, String date) {
  if (!allDefaultDone(data, date)) return 0;
  final bonusDone = data.tasks
      .where((t) => t.bonus && t.bonusDate == date && isDone(data, date, t.id))
      .length;
  return 1 + bonusDone;
}

bool canPlay(AppData data, String date) =>
    playsEarned(data, date) > (data.playsUsed[date] ?? 0);

bool canAddBonus(AppData data, String date) {
  final earned = playsEarned(data, date);
  final used = data.playsUsed[date] ?? 0;
  return allVisibleDone(data, date) && used > 0 && used >= earned;
}

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
