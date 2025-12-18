import 'package:flutter/material.dart';

import '../../state/app_state.dart';

/// Minimal workout screen - Dynamic Island is the focus.
/// 
/// Design philosophy: No distractions, subtle, useful.
/// The Dynamic Island (shown via RootShell) is the primary UI.
class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final session = app.activeSession;
    final hasExercises = session != null && session.exercises.isNotEmpty;

    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            // Spacer to push content down (Dynamic Island is in RootShell overlay)
            const Spacer(flex: 2),
            
            // Middle area - minimal info when workout active
            if (session != null && hasExercises) ...[
              _MinimalWorkoutInfo(session: session, app: app),
            ],
            
            const Spacer(flex: 3),
            
            // Bottom branding
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                'FITNESS OS V1.0',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.2),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal workout info shown below the Dynamic Island when active.
class _MinimalWorkoutInfo extends StatelessWidget {
  const _MinimalWorkoutInfo({required this.session, required this.app});

  final WorkoutSessionDraft session;
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final exercises = session.exercises;
    final totalSets = exercises.fold<int>(0, (sum, e) => sum + e.sets.length);
    final currentEx = app.activeExerciseIndex.clamp(0, exercises.isEmpty ? 0 : exercises.length - 1);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Current exercise name
          if (exercises.isNotEmpty)
            Text(
              exercises[currentEx].name.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 8),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatChip(
                label: 'EXERCISES',
                value: '${exercises.length}',
              ),
              const SizedBox(width: 16),
              _StatChip(
                label: 'SETS',
                value: '$totalSets',
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Exercise dots (pagination)
          if (exercises.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(exercises.length, (i) {
                final isActive = i == currentEx;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive 
                        ? const Color(0xFF00D17A) 
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
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
