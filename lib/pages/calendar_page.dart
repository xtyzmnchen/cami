import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic.dart';
import '../store.dart';
import '../task_day_view.dart';
import '../theme.dart';
import '../widgets.dart';
import '../l10n/l10n.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;
  final _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _month = DateTime(_today.year, _today.month);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_month.year, _month.month, _clampDay(_month.year, _month.month, _today.day)),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(_today.year + 1, 12, 31),
      helpText: context.l10n.pickDate,
      cancelText: context.l10n.cancel,
      confirmText: context.l10n.view,
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: CamiColors.roseDeep,
                  onPrimary: Colors.white,
                  surface: CamiColors.paper,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _month = DateTime(picked.year, picked.month));
    if (!picked.isAfter(DateTime(_today.year, _today.month, _today.day))) {
      _open(picked);
    }
  }

  int _clampDay(int year, int month, int day) {
    final last = DateTime(year, month + 1, 0).day;
    return day.clamp(1, last);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final first = DateTime(_month.year, _month.month, 1);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final today = DateTime(_today.year, _today.month, _today.day);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        RoseHeroBanner(
          title: context.l10n.monthYear(_month.year, _month.month),
          subtitle: context.l10n.monthPointsLine(monthPoints(store.data, _month.year, _month.month), yearPoints(store.data, _month.year)),
          height: 120,
        ),
        const SizedBox(height: 12),
        GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: context.l10n.previousMonth,
                onPressed: () => _shiftMonth(-1),
                icon: const Icon(Icons.chevron_left, color: CamiColors.roseDeep),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        Text(
                          context.l10n.monthYear(_month.year, _month.month),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.tapPickDate,
                          style: const TextStyle(fontSize: 12, color: CamiColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n.nextMonth,
                onPressed: () => _shiftMonth(1),
                icon: const Icon(Icons.chevron_right, color: CamiColors.roseDeep),
              ),
              IconButton(
                tooltip: context.l10n.pickDate,
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined, color: CamiColors.roseDeep),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Legend(CamiColors.green, context.l10n.legendAllDone),
            _Legend(CamiColors.amber, context.l10n.legendPartial),
            _Legend(CamiColors.red, context.l10n.legendNone),
            _Legend(const Color(0xFFFFD0E0), context.l10n.legendNoTask),
          ],
        ),
        const SizedBox(height: 10),
        GlassPanel(
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            childAspectRatio: 0.78,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            children: [
              for (final name in context.l10n.weekdayShort)
                Center(child: Text(name, style: const TextStyle(color: CamiColors.muted, fontSize: 12))),
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              for (var day = 1; day <= days; day++)
                _cell(context, store, DateTime(_month.year, _month.month, day), today),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cell(BuildContext context, Store store, DateTime day, DateTime today) {
    final mark = markFor(store.data, day, today);
    final decor = decorFor(store.data, day);
    final points = dayPoints(store.data, dayKey(day));
    final bg = switch (mark) {
      DayMark.green => CamiColors.greenBg,
      DayMark.yellow => CamiColors.amberBg,
      DayMark.red => CamiColors.redBg,
      _ => Colors.transparent,
    };
    final fg = switch (mark) {
      DayMark.green => CamiColors.green,
      DayMark.yellow => const Color(0xFF8A5A10),
      DayMark.red => CamiColors.red,
      DayMark.future => const Color(0xFFE8A8BC),
      DayMark.open => CamiColors.ink,
    };
    return InkWell(
      onTap: mark == DayMark.future ? null : () => _open(day),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: mark == DayMark.open || dayKey(day) == dayKey(today)
                    ? Border.all(color: CamiColors.rose, width: 2)
                    : null,
              ),
              child: Text('${day.day}', style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
            ),
            if (points > 0 || decor != Decor.none)
              SizedBox(
                height: 14,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (points > 0)
                      Text('$points', style: const TextStyle(fontSize: 9, height: 1, color: CamiColors.muted)),
                    if (points > 0 && decor != Decor.none) const SizedBox(width: 2),
                    if (decor != Decor.none) DecorBadge(decor, size: 10),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _open(DateTime day) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DaySheet(day: day),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: CamiColors.muted)),
      ],
    );
  }
}

class _DaySheet extends StatelessWidget {
  const _DaySheet({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final key = dayKey(day);
    final points = dayPoints(store.data, key);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: CamiColors.line, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          Text(context.l10n.fullDate(day), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(context.l10n.dayPointsLine(points), style: const TextStyle(color: CamiColors.roseDeep, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          TaskDaySections(date: key),
        ],
      ),
    );
  }
}
