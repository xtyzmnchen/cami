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
}
