import 'package:flutter/material.dart';

/// A lightweight month calendar with per-day markers.
///
/// Week starts on Monday.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    required this.month,
    required this.selectedDate,
    required this.onMonthChanged,
    required this.onDateSelected,
    required this.plannedCountByDay,
    required this.completedCountByDay,
    super.key,
  });

  final DateTime month; // any date within the month
  final DateTime selectedDate;
  final void Function(DateTime newMonth) onMonthChanged;
  final void Function(DateTime date) onDateSelected;
  final Map<DateTime, int> plannedCountByDay;
  final Map<DateTime, int> completedCountByDay;

  DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final m0 = _monthStart(month);
    final firstWeekday = m0.weekday; // 1=Mon .. 7=Sun
    final daysInMonth = DateTime(m0.year, m0.month + 1, 0).day;
    final leadingEmpty = firstWeekday - 1; // Mon-start grid
    final totalCells = leadingEmpty + daysInMonth;
    final rows = ((totalCells) / 7).ceil();

    final label = '${_monthName(m0.month)} ${m0.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () => onMonthChanged(DateTime(m0.year, m0.month - 1, 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => onMonthChanged(DateTime(m0.year, m0.month + 1, 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _W('Mon'),
            _W('Tue'),
            _W('Wed'),
            _W('Thu'),
            _W('Fri'),
            _W('Sat'),
            _W('Sun'),
          ],
        ),
        const SizedBox(height: 6),
        ...List.generate(rows, (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: List.generate(7, (col) {
                final cell = row * 7 + col;
                final dayNum = cell - leadingEmpty + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 44));
                }
                final date = DateTime(m0.year, m0.month, dayNum);
                final d0 = _dateOnly(date);
                final isSelected = _dateOnly(selectedDate) == d0;
                final planned = plannedCountByDay[d0] ?? 0;
                final completed = completedCountByDay[d0] ?? 0;

                return Expanded(
                  child: _DayCell(
                    day: dayNum,
                    selected: isSelected,
                    plannedCount: planned,
                    completedCount: completed,
                    onTap: () => onDateSelected(date),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }

  String _monthName(int m) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[(m - 1).clamp(0, 11)];
  }
}

class _W extends StatelessWidget {
  const _W(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.plannedCount,
    required this.completedCount,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final int plannedCount;
  final int completedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected ? const Color(0x66FFFFFF) : const Color(0x22FFFFFF);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0x14FFFFFF) : const Color(0x08000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$day',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            const Spacer(),
            Row(
              children: [
                if (plannedCount > 0) ...[
                  _Dot(count: plannedCount, color: const Color(0xFF7C7CFF)),
                  const SizedBox(width: 4),
                ],
                if (completedCount > 0) _Dot(count: completedCount, color: const Color(0xFF00D17A)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = count.clamp(1, 9);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        '$c',
        style: TextStyle(color: color.withOpacity(0.95), fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }
}

