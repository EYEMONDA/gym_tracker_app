import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import 'log_screen.dart';
import '../widgets/month_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selected = DateTime.now();
  DateTime _month = DateTime.now();

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final selectedDay = _dateOnly(_selected);
    final todaysSessions =
        app.sessions.where((s) => _dateOnly(s.startedAt) == selectedDay).toList();
    final todaysPlans = app.plannedWorkouts
        .where((p) => _dateOnly(p.date) == selectedDay)
        .toList()
      ..sort((a, b) {
        final ta = (a.timeLabel ?? '').toLowerCase();
        final tb = (b.timeLabel ?? '').toLowerCase();
        return ta.compareTo(tb);
      });

    final plannedCountByDay = <DateTime, int>{};
    final completedCountByDay = <DateTime, int>{};
    for (final p in app.plannedWorkouts) {
      final d = _dateOnly(p.date);
      plannedCountByDay[d] = (plannedCountByDay[d] ?? 0) + 1;
    }
    for (final s in app.sessions) {
      final d = _dateOnly(s.startedAt);
      completedCountByDay[d] = (completedCountByDay[d] ?? 0) + 1;
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 78, 16, 24),
        children: [
          const Text('Calendar', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Plan multiple routines per day, and track what you completed.',
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
            child: MonthCalendar(
              month: _month,
              selectedDate: _selected,
              onMonthChanged: (m) => setState(() => _month = m),
              onDateSelected: (d) => setState(() => _selected = d),
              plannedCountByDay: plannedCountByDay,
              completedCountByDay: completedCountByDay,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDate(selectedDay),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () async {
                  final result = await showDialog<_PlanDraft>(
                    context: context,
                    builder: (_) => _PlanRoutineDialog(templates: app.routineTemplates),
                  );
                  if (result == null) return;
                  await app.addPlannedWorkout(
                    date: selectedDay,
                    templateId: result.templateId,
                    timeLabel: result.timeLabel,
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Plan'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Planned', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (todaysPlans.isEmpty)
            const _EmptyPlanned()
          else
            ...todaysPlans.map((p) {
              final title = p.templateNameSnapshot;
              final subtitleParts = <String>[];
              if (p.timeLabel != null) subtitleParts.add(p.timeLabel!);
              subtitleParts.add(p.status.name);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF070707),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x22FFFFFF)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    subtitleParts.join(' • '),
                    style: const TextStyle(color: Color(0xAAFFFFFF)),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      if (p.status == PlannedWorkoutStatus.planned)
                        IconButton(
                          tooltip: app.activeSession != null ? 'Workout already active' : 'Start',
                          onPressed: app.activeSession != null
                              ? null
                              : () {
                                  app.startPlannedWorkout(p.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Started planned routine (Workout tab).')),
                                  );
                                },
                          icon: const Icon(Icons.play_arrow),
                        ),
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          switch (v) {
                            case 'done':
                              await app.setPlannedWorkoutStatus(p.id, PlannedWorkoutStatus.done);
                              break;
                            case 'skipped':
                              await app.setPlannedWorkoutStatus(p.id, PlannedWorkoutStatus.skipped);
                              break;
                            case 'delete':
                              await app.removePlannedWorkout(p.id);
                              break;
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'done', child: Text('Mark done')),
                          PopupMenuItem(value: 'skipped', child: Text('Mark skipped')),
                          PopupMenuDivider(),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 10),
          const Text('Completed', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (todaysSessions.isEmpty)
            const _EmptyCompleted()
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

class _EmptyPlanned extends StatelessWidget {
  const _EmptyPlanned();

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
        'Nothing planned. Tap “Plan” to add one or more routines for this day.',
        style: TextStyle(color: Color(0xAAFFFFFF)),
      ),
    );
  }
}

class _EmptyCompleted extends StatelessWidget {
  const _EmptyCompleted();

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

class _PlanRoutineDialog extends StatefulWidget {
  const _PlanRoutineDialog({required this.templates});

  final List<RoutineTemplate> templates;

  @override
  State<_PlanRoutineDialog> createState() => _PlanRoutineDialogState();
}

class _PlanRoutineDialogState extends State<_PlanRoutineDialog> {
  String? _selectedTemplateId;
  final TextEditingController _time = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.templates.isNotEmpty) {
      _selectedTemplateId = widget.templates.first.id;
    }
  }

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Plan routine'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedTemplateId,
            items: widget.templates
                .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                .toList(),
            onChanged: (v) => setState(() => _selectedTemplateId = v),
            decoration: const InputDecoration(labelText: 'Routine'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _time,
            decoration: const InputDecoration(
              labelText: 'Time label (optional)',
              hintText: 'AM / PM / 18:00 / Lunch',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _selectedTemplateId == null
              ? null
              : () => Navigator.pop(
                    context,
                    _PlanDraft(templateId: _selectedTemplateId!, timeLabel: _time.text),
                  ),
          child: const Text('Plan'),
        ),
      ],
    );
  }
}

class _PlanDraft {
  const _PlanDraft({required this.templateId, required this.timeLabel});
  final String templateId;
  final String timeLabel;
}

