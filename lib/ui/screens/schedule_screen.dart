import 'package:flutter/material.dart';

import '../../state/app_state.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  static const _weekdayLabels = <int, String>{
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static const _categoryOrder = <RoutineCategory>[
    RoutineCategory.strength,
    RoutineCategory.cardio,
    RoutineCategory.mobility,
    RoutineCategory.custom,
  ];

  static String _categoryLabel(RoutineCategory c) {
    switch (c) {
      case RoutineCategory.strength:
        return 'Strength';
      case RoutineCategory.cardio:
        return 'Cardio';
      case RoutineCategory.mobility:
        return 'Mobility';
      case RoutineCategory.custom:
        return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final suggestion = app.suggestNextWorkout();
    final templates = List<RoutineTemplate>.of(app.routineTemplates)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final byCategory = <RoutineCategory, List<RoutineTemplate>>{};
    for (final t in templates) {
      (byCategory[t.category] ??= []).add(t);
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 78, 16, 24),
        children: [
          const Text('Schedule', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'A lightweight “smart” schedule: it adapts to your last workout and preferred days.',
            style: TextStyle(color: Color(0xAAFFFFFF)),
          ),
          const SizedBox(height: 18),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(suggestion.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 6),
                Text(
                  _formatDate(suggestion.date),
                  style: const TextStyle(color: Color(0xDDFFFFFF), fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(suggestion.reason, style: const TextStyle(color: Color(0xAAFFFFFF))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Routine templates', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                  'Use these to plan multiple routines per day in the Calendar.',
                  style: TextStyle(color: Color(0xAAFFFFFF)),
                ),
                const SizedBox(height: 10),
                if (templates.isEmpty)
                  const Text('No templates.', style: TextStyle(color: Color(0xAAFFFFFF)))
                else
                  ..._categoryOrder.where(byCategory.containsKey).expand((cat) sync* {
                    yield Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Text(
                        _categoryLabel(cat),
                        style: const TextStyle(color: Color(0xAAFFFFFF), fontWeight: FontWeight.w800),
                      ),
                    );
                    for (final t in byCategory[cat]!) {
                      final preview = t.exercises
                          .take(3)
                          .map((e) => e.name)
                          .where((s) => s.trim().isNotEmpty)
                          .join(', ');
                      yield Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0A0A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x22FFFFFF)),
                        ),
                        child: ListTile(
                          title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                            preview.isEmpty
                                ? '${t.exercises.length} items'
                                : '$preview${t.exercises.length > 3 ? '…' : ''}',
                            style: const TextStyle(color: Color(0xAAFFFFFF)),
                          ),
                          trailing: FilledButton.tonal(
                            onPressed: () {
                              // Quick-start this template now (not a calendar plan).
                              if (app.activeSession == null) {
                                app.startWorkout(title: t.name);
                                for (final e in t.exercises) {
                                  if (e.name.trim().isEmpty) continue;
                                  app.addExerciseToActive(e.name);
                                }
                                app.requestedTabIndex = 0;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Started workout from template.')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Finish/discard current workout first.')),
                                );
                              }
                            },
                            child: const Text('Start'),
                          ),
                        ),
                      );
                    }
                  }),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Preferred training days', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (i) {
                    final weekday = i + 1;
                    final selected = app.preferredWeekdays.contains(weekday);
                    return ChoiceChip(
                      selected: selected,
                      label: Text(_weekdayLabels[weekday]!),
                      onSelected: (_) => app.togglePreferredWeekday(weekday),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tip: pick 3–5 days for a sustainable schedule.',
                  style: TextStyle(color: Color(0xAAFFFFFF)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Suggested focus', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(
                  app.sessions.isEmpty
                      ? 'Start simple: Full Body (2–3x/week) with a few compounds.'
                      : 'Next: repeat what you’re consistent with. Keep it simple and progressive.',
                  style: const TextStyle(color: Color(0xAAFFFFFF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF070707),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: child,
    );
  }
}

