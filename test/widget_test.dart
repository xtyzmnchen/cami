import 'package:cami/logic.dart';
import 'package:cami/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('今天还没做完时，不标红', () {
    final today = DateTime(2026, 10, 28);
    final data = AppData(
      pinHash: 'x',
      childName: 'Cami',
      updatedAt: '',
      tasks: [
        TaskTemplate(id: 'a', subject: '语文', title: '阅读', minutes: 10, points: 3),
      ],
      progress: [],
      rewards: [],
      redemptions: [],
      playsUsed: {},
    );
    expect(markFor(data, today, today), DayMark.open);
    expect(markFor(data, today.subtract(const Duration(days: 1)), today), DayMark.red);
  });
}
