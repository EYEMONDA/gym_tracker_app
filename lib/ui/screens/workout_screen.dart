import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';
import '../widgets/animated_widgets.dart';

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
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
