import 'package:cami/logic.dart';
import 'package:cami/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('一周七款游戏不重复，下一周顺序会变', () {
    final monday = DateTime(2026, 10, 26);
    final first = weekGames(monday);
    expect(first.toSet().length, 7);
    expect(gameForDay(monday.add(const Duration(days: 2))), first[2]);
    final next = weekGames(monday.add(const Duration(days: 7)));
    expect(next.toSet().length, 7);
    expect(next, isNot(first));
  });

  test('兑换会从总分里扣掉', () {
    final data = AppData(
      pinHash: 'x',
      childName: 'Cami',
      updatedAt: '',
      tasks: [],
      progress: [
        TaskProgress(taskId: 'a', date: '2026-10-28', done: true, points: 4),
        TaskProgress(taskId: 'b', date: '2026-10-28', done: true, points: 3),
      ],
      rewards: [],
      redemptions: [
        Redemption(id: '1', title: '贴纸', cost: 2, at: '2026-10-28T12:00:00'),
      ],
      playsUsed: {},
    );
    expect(earnedPoints(data), 7);
    expect(redeemedPoints(data), 2);
    expect(pointBalance(data), 5);
    expect(decorFor(data, DateTime(2026, 10, 28)), Decor.none);
  });

  test('合并时软移除优先，学生端任务列表看不到，数据仍保留', () {
    final parent = AppData(
      pinHash: 'x',
      childName: 'Cami',
      updatedAt: '2026-11-13T12:00:00',
      tasks: [
        TaskTemplate(id: 'keep', subject: '语文', title: '朗读', minutes: 10, points: 2),
        TaskTemplate(id: 'hide', subject: '数学', title: '口算', minutes: 10, points: 2, removed: true),
      ],
      progress: [],
      rewards: [
        Reward(id: 'r-keep', title: '贴纸', cost: 1),
      ],
      redemptions: [],
      playsUsed: {},
      removedTaskIds: {'hide'},
      deletedRewardIds: {'r-gone'},
    );
    final child = AppData(
      pinHash: 'x',
      childName: 'Cami',
      updatedAt: '2026-11-13T11:00:00',
      tasks: [
        TaskTemplate(id: 'keep', subject: '语文', title: '朗读', minutes: 10, points: 2),
        TaskTemplate(id: 'hide', subject: '数学', title: '口算', minutes: 10, points: 2),
      ],
      progress: [],
      rewards: [
        Reward(id: 'r-keep', title: '贴纸', cost: 1),
        Reward(id: 'r-gone', title: '旧奖', cost: 3),
      ],
      redemptions: [],
      playsUsed: {},
    );

    final merged = mergeAppData(child, parent);
    expect(merged.tasks.map((t) => t.id).toSet(), {'keep', 'hide'});
    expect(merged.tasks.firstWhere((t) => t.id == 'hide').removed, isTrue);
    expect(merged.removedTaskIds, contains('hide'));
    expect(tasksOn(merged, '2026-11-13').map((t) => t.id), ['keep']);
    expect(merged.rewards.map((r) => r.id), ['r-keep']);
    expect(merged.deletedRewardIds, contains('r-gone'));
  });

  test('较新一端恢复后，合并不再对学生隐藏', () {
    final restored = AppData(
      pinHash: 'x',
      childName: 'Cami',
      updatedAt: '2026-11-13T13:00:00',
      tasks: [
        TaskTemplate(id: 'hide', subject: '数学', title: '口算', minutes: 10, points: 2),
      ],
      progress: [],
      rewards: [],
      redemptions: [],
      playsUsed: {},
    );
    final oldRemoved = AppData(
      pinHash: 'x',
      childName: 'Cami',
      updatedAt: '2026-11-13T12:00:00',
      tasks: [
        TaskTemplate(id: 'hide', subject: '数学', title: '口算', minutes: 10, points: 2, removed: true),
      ],
      progress: [],
      rewards: [],
      redemptions: [],
      playsUsed: {},
      removedTaskIds: {'hide'},
    );
    final merged = mergeAppData(oldRemoved, restored);
    expect(merged.removedTaskIds.contains('hide'), isFalse);
    expect(merged.tasks.single.removed, isFalse);
    expect(tasksOn(merged, '2026-11-13').map((t) => t.id), ['hide']);
  });
}
