import 'package:flutter/material.dart';

import '../../state/app_state.dart';

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sessions = app.sessions;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 78, 16, 24),
        children: [
          const Text('Log', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Your saved workouts, stored locally.',
            style: TextStyle(color: Color(0xAAFFFFFF)),
          ),
          const SizedBox(height: 18),
          if (sessions.isEmpty)
            const _EmptyState(
              title: 'No workouts yet',
              subtitle: 'Start a workout on the Workout tab and save it.',
            )
          else
            ...sessions.map((s) {
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
                    '${_formatDate(s.startedAt)} • ${_formatDuration(s.duration)} • ${s.exercises.length} exercises',
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

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({required this.session, super.key});

  final WorkoutSession session;

  String _formatDateTime(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$m-$day $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(session.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _formatDateTime(session.startedAt),
            style: const TextStyle(color: Color(0xAAFFFFFF)),
          ),
          const SizedBox(height: 6),
          Text(
            'Exercises: ${session.exercises.length}',
            style: const TextStyle(color: Color(0xAAFFFFFF)),
          ),
          if (session.notes != null) ...[
            const SizedBox(height: 10),
            Text(session.notes!, style: const TextStyle(color: Color(0xDDFFFFFF))),
          ],
          const SizedBox(height: 16),
          ...session.exercises.map((e) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF070707),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x22FFFFFF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (e.sets.isEmpty)
                    const Text('No sets logged.', style: TextStyle(color: Color(0xAAFFFFFF)))
                  else
                    ...List.generate(e.sets.length, (i) {
                      final s = e.sets[i];
                      final w = s.weight.toStringAsFixed(s.weight == s.weight.roundToDouble() ? 0 : 1);
                      final rpe = s.rpe;
                      final rpeText =
                          rpe == null ? '' : ' • RPE ${rpe.toStringAsFixed(rpe == rpe.roundToDouble() ? 0 : 1)}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          'Set ${i + 1}: ${s.reps} reps • $w ${s.unit}$rpeText',
                          style: const TextStyle(color: Color(0xDDFFFFFF)),
                        ),
                      );
                    }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF070707),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Color(0xAAFFFFFF))),
        ],
      ),
    );
  }
}

