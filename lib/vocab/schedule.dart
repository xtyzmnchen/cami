import '../logic.dart';
import '../models.dart';
import 'words.dart';

const vocabTaskId = 'e3';
const vocabDailyCount = 3;
const vocabWeeklyCount = 15;

enum VocabMode { daily, weekly, monthly }

String vocabModeKey(VocabMode m) => switch (m) {
      VocabMode.daily => 'daily',
      VocabMode.weekly => 'weekly',
      VocabMode.monthly => 'monthly',
    };

VocabMode parseVocabMode(String raw) => switch (raw) {
      'weekly' => VocabMode.weekly,
      'monthly' => VocabMode.monthly,
      _ => VocabMode.daily,
    };

String vocabModeTitle(VocabMode mode) => switch (mode) {
      VocabMode.daily => '今日新学',
      VocabMode.weekly => '周六周复习',
      VocabMode.monthly => '月度复盘',
    };

String vocabModeHint(VocabMode mode, int count) => switch (mode) {
      VocabMode.daily => '今天要背 $count 个新单词',
      VocabMode.weekly => '复习上一周的 $count 个单词',
      VocabMode.monthly => '复盘近一个月的 $count 个单词',
    };

/// 周六：默认周复习；每满约 4 周做一次月度复盘。
VocabMode vocabModeFor(DateTime day, VocabState state) {
  if (day.weekday != DateTime.saturday) return VocabMode.daily;
  final firstDaily = state.days.where((d) => d.mode == 'daily').toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  if (firstDaily.isEmpty) return VocabMode.weekly;
  final first = DateTime.tryParse(firstDaily.first.date);
  if (first == null) return VocabMode.weekly;
  final weeks = dateOnly(day).difference(dateOnly(first)).inDays ~/ 7;
  if (weeks > 0 && weeks % 4 == 0) return VocabMode.monthly;
  return VocabMode.weekly;
}

List<int> _uniquePreserve(Iterable<int> raw) {
  final seen = <int>{};
  final out = <int>[];
  for (final i in raw) {
    if (i < 0 || i >= vocabBankSize) continue;
    if (seen.add(i)) out.add(i);
  }
  return out;
}

/// 最近学过的新词（按学习日从近到远），用于周复习。
List<int> lastDailyWordIndexes(VocabState state, {int count = vocabWeeklyCount}) {
  final daily = state.days.where((d) => d.mode == 'daily').toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  final out = <int>[];
  for (final d in daily) {
    for (final i in d.wordIndexes.reversed) {
      if (out.contains(i)) continue;
      out.add(i);
      if (out.length >= count) return out.reversed.toList();
    }
  }
  return out.reversed.toList();
}

/// 近 28 天内每日新学的全部单词，用于月度复盘。
List<int> monthlyWordIndexes(VocabState state, DateTime saturday) {
  final end = dateOnly(saturday).subtract(const Duration(days: 1));
  final start = end.subtract(const Duration(days: 27));
  final startKey = dayKey(start);
  final endKey = dayKey(end);
  final out = <int>[];
  final days = state.days.where((d) => d.mode == 'daily').toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  for (final d in days) {
    if (d.date.compareTo(startKey) < 0) continue;
    if (d.date.compareTo(endKey) > 0) continue;
    out.addAll(d.wordIndexes);
  }
  return _uniquePreserve(out);
}

List<int> assignWordIndexes({
  required VocabMode mode,
  required VocabState state,
  required DateTime day,
}) {
  switch (mode) {
    case VocabMode.weekly:
      final list = lastDailyWordIndexes(state, count: vocabWeeklyCount);
      return list.isEmpty ? <int>[] : list;
    case VocabMode.monthly:
      final list = monthlyWordIndexes(state, day);
      return list.isEmpty ? lastDailyWordIndexes(state, count: vocabWeeklyCount) : list;
    case VocabMode.daily:
      final start = state.nextIndex.clamp(0, vocabBankSize);
      if (start >= vocabBankSize) return <int>[];
      final end = (start + vocabDailyCount).clamp(0, vocabBankSize);
      return [for (var i = start; i < end; i++) i];
  }
}

String normalizeDictation(String raw) =>
    raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

bool dictationMatches(String input, String answer) =>
    normalizeDictation(input) == normalizeDictation(answer);
