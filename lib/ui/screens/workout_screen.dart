import 'package:flutter/material.dart';

import '../../state/app_state.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final session = app.activeSession;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 78, 16, 24),
        children: [
          Text(
            session == null ? 'Workout' : session.title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            session == null ? 'Start a session and log sets as you go.' : 'Track sets, start rests, and save your log.',
            style: const TextStyle(color: Color(0xAAFFFFFF)),
          ),
          const SizedBox(height: 18),
          if (session == null)
            _StartWorkoutCard(
              onStart: () async {
                final title = await showDialog<String>(
                  context: context,
                  builder: (_) => const _StartWorkoutDialog(),
                );
                if (title == null) return;
                app.startWorkout(title: title);
              },
            )
          else ...[
            _ActiveWorkoutHeader(
              startedAt: session.startedAt,
              onAddExercise: () async {
                final name = await showDialog<String>(
                  context: context,
                  builder: (_) => const _AddExerciseDialog(),
                );
                if (name == null) return;
                app.addExerciseToActive(name);
              },
              onRest: () => app.startRestTimer(),
              onSave: () async {
                await app.endWorkoutAndSave();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Workout saved.')),
                  );
                }
              },
              onDiscard: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Discard workout?'),
                    content: const Text('This won’t be saved.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () {
                          app.discardActiveWorkout();
                          Navigator.pop(context);
                        },
                        child: const Text('Discard'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            if (session.exercises.isEmpty)
              const _EmptyState(text: 'Add your first exercise to begin logging sets.')
            else
              ...List.generate(session.exercises.length, (i) {
                final ex = session.exercises[i];
                return _ExerciseCard(
                  index: i,
                  name: ex.name,
                  sets: ex.sets,
                  onAddSet: () async {
                    final result = await showDialog<_SetDraft>(
                      context: context,
                      builder: (_) => const _AddSetDialog(),
                    );
                    if (result == null) return;
                    app.addSetToExercise(
                      i,
                      reps: result.reps,
                      weight: result.weight,
                      unit: result.unit,
                      rpe: result.rpe,
                    );
                    app.startRestTimer();
                  },
                  onRemoveExercise: () => app.removeExerciseFromActive(i),
                  onRemoveSet: (setIndex) => app.removeSetFromExercise(i, setIndex),
                );
              }),
          ],
        ],
      ),
    );
  }
}

class _StartWorkoutCard extends StatelessWidget {
  const _StartWorkoutCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready when you are',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'No login. Everything is stored locally on this device/browser.',
            style: TextStyle(color: Color(0xAAFFFFFF)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start workout'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveWorkoutHeader extends StatelessWidget {
  const _ActiveWorkoutHeader({
    required this.startedAt,
    required this.onAddExercise,
    required this.onRest,
    required this.onSave,
    required this.onDiscard,
  });

  final DateTime startedAt;
  final VoidCallback onAddExercise;
  final VoidCallback onRest;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Started ${TimeOfDay.fromDateTime(startedAt).format(context)}',
            style: const TextStyle(color: Color(0xAAFFFFFF)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onAddExercise,
                icon: const Icon(Icons.add),
                label: const Text('Exercise'),
              ),
              OutlinedButton.icon(
                onPressed: onRest,
                icon: const Icon(Icons.timer),
                label: const Text('Rest'),
              ),
              FilledButton.tonalIcon(
                onPressed: onSave,
                icon: const Icon(Icons.check),
                label: const Text('Save'),
              ),
              TextButton.icon(
                onPressed: onDiscard,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Discard'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.index,
    required this.name,
    required this.sets,
    required this.onAddSet,
    required this.onRemoveExercise,
    required this.onRemoveSet,
  });

  final int index;
  final String name;
  final List<ExerciseSet> sets;
  final VoidCallback onAddSet;
  final VoidCallback onRemoveExercise;
  final void Function(int setIndex) onRemoveSet;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Remove exercise',
                onPressed: onRemoveExercise,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (sets.isEmpty)
            const Text('No sets yet.', style: TextStyle(color: Color(0xAAFFFFFF)))
          else
            ...List.generate(sets.length, (i) {
              final s = sets[i];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Set ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(() {
                  final w = s.weight.toStringAsFixed(s.weight == s.weight.roundToDouble() ? 0 : 1);
                  final rpe = s.rpe;
                  final rpeText = rpe == null
                      ? ''
                      : ' • RPE ${rpe.toStringAsFixed(rpe == rpe.roundToDouble() ? 0 : 1)}';
                  return '${s.reps} reps • $w ${s.unit}$rpeText';
                }()),
                trailing: IconButton(
                  tooltip: 'Remove set',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => onRemoveSet(i),
                ),
              );
            }),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddSet,
                  icon: const Icon(Icons.add),
                  label: const Text('Add set'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF070707),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xAAFFFFFF))),
    );
  }
}

class _StartWorkoutDialog extends StatefulWidget {
  const _StartWorkoutDialog();

  @override
  State<_StartWorkoutDialog> createState() => _StartWorkoutDialogState();
}

class _StartWorkoutDialogState extends State<_StartWorkoutDialog> {
  final TextEditingController _title = TextEditingController(text: 'Workout');

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start workout'),
      content: TextField(
        controller: _title,
        decoration: const InputDecoration(labelText: 'Title'),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _title.text),
          child: const Text('Start'),
        ),
      ],
    );
  }
}

class _AddExerciseDialog extends StatefulWidget {
  const _AddExerciseDialog();

  @override
  State<_AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<_AddExerciseDialog> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add exercise'),
      content: TextField(
        controller: _name,
        decoration: const InputDecoration(labelText: 'Exercise (e.g., Bench Press)'),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _name.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _AddSetDialog extends StatefulWidget {
  const _AddSetDialog();

  @override
  State<_AddSetDialog> createState() => _AddSetDialogState();
}

class _AddSetDialogState extends State<_AddSetDialog> {
  final TextEditingController _reps = TextEditingController(text: '10');
  final TextEditingController _weight = TextEditingController(text: '0');
  final TextEditingController _rpe = TextEditingController();
  String _unit = 'kg';

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    _rpe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add set'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _reps,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Reps'),
          ),
          TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Weight'),
          ),
          TextField(
            controller: _rpe,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'RPE (optional, 1–10)'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _unit,
            items: const [
              DropdownMenuItem(value: 'kg', child: Text('kg')),
              DropdownMenuItem(value: 'lb', child: Text('lb')),
              DropdownMenuItem(value: 'bw', child: Text('bodyweight')),
            ],
            onChanged: (v) => setState(() => _unit = v ?? 'kg'),
            decoration: const InputDecoration(labelText: 'Unit'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final reps = int.tryParse(_reps.text.trim()) ?? 10;
            final w = double.tryParse(_weight.text.trim()) ?? 0;
            final rpeRaw = _rpe.text.trim();
            final rpe = rpeRaw.isEmpty ? null : double.tryParse(rpeRaw);
            Navigator.pop(
              context,
              _SetDraft(
                reps: reps.clamp(1, 999),
                weight: w,
                unit: _unit,
                rpe: rpe == null ? null : rpe.clamp(1, 10),
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _SetDraft {
  const _SetDraft({required this.reps, required this.weight, required this.unit, required this.rpe});
  final int reps;
  final double weight;
  final String unit;
  final double? rpe;
}

