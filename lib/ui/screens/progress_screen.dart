import 'dart:math';

import 'package:flutter/material.dart';

import '../../state/app_state.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String _prQuery = '';

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _startOfWeek(DateTime d) {
    final day = _dateOnly(d);
    // Monday=1 ... Sunday=7
    return day.subtract(Duration(days: day.weekday - 1));
  }

  int _sessionsInWeek(List<WorkoutSession> sessions, DateTime weekStart) {
    final endExclusive = weekStart.add(const Duration(days: 7));
    return sessions.where((s) => !s.startedAt.isBefore(weekStart) && s.startedAt.isBefore(endExclusive)).length;
  }

  List<_WeekBar> _lastWeeks(List<WorkoutSession> sessions, {int count = 8}) {
    final now = DateTime.now();
    final thisWeekStart = _startOfWeek(now);
    final bars = <_WeekBar>[];
    for (int i = count - 1; i >= 0; i--) {
      final start = thisWeekStart.subtract(Duration(days: 7 * i));
      final c = _sessionsInWeek(sessions, start);
      bars.add(_WeekBar(weekStart: start, count: c));
    }
    return bars;
  }

  List<_PrRow> _computePrs(List<WorkoutSession> sessions) {
    final best = <String, _PrRow>{};
    for (final session in sessions) {
      for (final ex in session.exercises) {
        final name = ex.name.trim();
        if (name.isEmpty) continue;
        for (final s in ex.sets) {
          if (s.weight <= 0 || s.reps <= 0) continue;
          // Epley 1RM estimate: 1RM = w * (1 + reps/30)
          final est1rm = s.weight * (1.0 + (s.reps / 30.0));
          final prev = best[name];
          if (prev == null || est1rm > prev.est1rm) {
            best[name] = _PrRow(
              exercise: name,
              est1rm: est1rm,
              bestWeight: s.weight,
              bestReps: s.reps,
              unit: s.unit,
            );
          }
        }
      }
    }
    final rows = best.values.toList()
      ..sort((a, b) => b.est1rm.compareTo(a.est1rm));
    return rows;
  }

  String _fmtWeight(double w) => w.toStringAsFixed(w == w.roundToDouble() ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sessions = app.sessions;

    final thisWeekStart = _startOfWeek(DateTime.now());
    final thisWeekCount = _sessionsInWeek(sessions, thisWeekStart);
    final goal = app.weeklyWorkoutGoal;
    final pct = (goal == 0) ? 0.0 : (thisWeekCount / goal).clamp(0.0, 1.0);
    final weeks = _lastWeeks(sessions, count: 8);

    final prsAll = _computePrs(sessions);
    final q = _prQuery.trim().toLowerCase();
    final prs = q.isEmpty
        ? prsAll.take(12).toList()
        : prsAll.where((p) => p.exercise.toLowerCase().contains(q)).take(30).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 78, 16, 24),
        children: [
          const Text('Progress', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Simple, easy-to-read progress: weekly consistency + personal records.',
            style: TextStyle(color: Color(0xAAFFFFFF)),
          ),
          const SizedBox(height: 18),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Weekly goal', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  '$thisWeekCount / $goal workouts this week',
                  style: const TextStyle(color: Color(0xDDFFFFFF), fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: pct,
                  minHeight: 10,
                  backgroundColor: const Color(0x22000000),
                  color: const Color(0xFF00D17A),
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => app.setWeeklyWorkoutGoal(goal - 1),
                      icon: const Icon(Icons.remove),
                      label: const Text('Less'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => app.setWeeklyWorkoutGoal(goal + 1),
                      icon: const Icon(Icons.add),
                      label: const Text('More'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Last 8 weeks', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                _WeekBars(weeks: weeks, goal: goal),
                const SizedBox(height: 6),
                const Text(
                  'Bars show workouts/week. Aim to keep it steady.',
                  style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Personal records (estimated 1RM)', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Filter exercises (e.g., bench, squat)…',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _prQuery = v),
                ),
                const SizedBox(height: 10),
                if (prsAll.isEmpty)
                  const Text(
                    'No PRs yet. Log weighted sets (weight > 0) to build records.',
                    style: TextStyle(color: Color(0xAAFFFFFF)),
                  )
                else
                  ...prs.map((p) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.exercise, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        'Best set: ${_fmtWeight(p.bestWeight)} ${p.unit} × ${p.bestReps}  •  Est 1RM: ${_fmtWeight(p.est1rm)}',
                        style: const TextStyle(color: Color(0xAAFFFFFF)),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.weeks, required this.goal});

  final List<_WeekBar> weeks;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final maxCount = max(1, weeks.map((w) => w.count).fold<int>(0, max));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: weeks.map((w) {
        final h = 56.0 * (w.count / maxCount);
        final hitGoal = goal > 0 && w.count >= goal;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 60,
            alignment: Alignment.bottomCenter,
            child: Container(
              height: max(6.0, h),
              decoration: BoxDecoration(
                color: (hitGoal ? const Color(0xFF00D17A) : const Color(0xFF7C7CFF)).withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _WeekBar {
  const _WeekBar({required this.weekStart, required this.count});
  final DateTime weekStart;
  final int count;
}

class _PrRow {
  const _PrRow({
    required this.exercise,
    required this.est1rm,
    required this.bestWeight,
    required this.bestReps,
    required this.unit,
  });

  final String exercise;
  final double est1rm;
  final double bestWeight;
  final int bestReps;
  final String unit;
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

