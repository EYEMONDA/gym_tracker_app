import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import 'log_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selected = DateTime.now();

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final selectedDay = _dateOnly(_selected);
    final todaysSessions = app.sessions.where((s) => _dateOnly(s.startedAt) == selectedDay).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 78, 16, 24),
        children: [
          const Text('Calendar', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Pick a day to see what you trained.',
            style: TextStyle(color: Color(0xAAFFFFFF)),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF070707),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x22FFFFFF)),
            ),
            child: CalendarDatePicker(
              initialDate: _selected,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              onDateChanged: (d) => setState(() => _selected = d),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Workouts on ${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (todaysSessions.isEmpty)
            const _EmptyState()
          else
            ...todaysSessions.map((s) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF070707),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x22FFFFFF)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    '${s.exercises.length} exercises • ${s.duration.inMinutes} min',
                    style: const TextStyle(color: Color(0xAAFFFFFF)),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SessionDetailScreen(session: s)),
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF070707),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: const Text(
        'No workouts logged on this day.',
        style: TextStyle(color: Color(0xAAFFFFFF)),
      ),
    );
  }
}

