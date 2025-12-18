import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';

/// Dynamic Island - the central UI element for Fitness OS.
/// 
/// Design: Minimal, centered, no distractions.
class DynamicIsland extends StatefulWidget {
  const DynamicIsland({super.key});

  @override
  State<DynamicIsland> createState() => _DynamicIslandState();
}

class _DynamicIslandState extends State<DynamicIsland> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final size = MediaQuery.sizeOf(context);
    final session = app.activeSession;
    final isWorkoutActive = session != null;
    final rest = app.restTimer;
    
    // Sizing
    final double collapsedWidth = min(340.0, size.width - 48);
    final double expandedWidth = min(400.0, size.width - 32);
    final double collapsedHeight = 56.0;
    final double expandedHeight = min(400.0, size.height * 0.5);
    
    final double width = _expanded ? expandedWidth : collapsedWidth;
    final double height = _expanded ? expandedHeight : collapsedHeight;
    
    // Accent color based on state
    Color accent = Colors.white.withOpacity(0.3);
    if (isWorkoutActive) {
      accent = const Color(0xFF00D17A); // Green for active
    }
    if (rest.isRunning) {
      accent = const Color(0xFFFFB020); // Orange for rest
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _expanded = !_expanded);
      },
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! > 200 && _expanded) {
          HapticFeedback.lightImpact();
          setState(() => _expanded = false);
        } else if (details.primaryVelocity! < -200 && !_expanded) {
          HapticFeedback.lightImpact();
          setState(() => _expanded = true);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xF0111111),
          borderRadius: BorderRadius.circular(_expanded ? 32 : 28),
          border: Border.all(
            color: accent.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_expanded ? 32 : 28),
          child: _expanded
              ? _ExpandedContent(
                  app: app,
                  onClose: () => setState(() => _expanded = false),
                )
              : _CollapsedContent(
                  app: app,
                  accent: accent,
                ),
        ),
      ),
    );
  }
}

/// Collapsed state - single row with key info
class _CollapsedContent extends StatelessWidget {
  const _CollapsedContent({required this.app, required this.accent});

  final AppState app;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final session = app.activeSession;
    final rest = app.restTimer;
    final isWorkoutActive = session != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Left icon
          _buildLeftIcon(isWorkoutActive, rest.isRunning),
          const SizedBox(width: 12),
          
          // Center content
          Expanded(
            child: _buildCenterContent(session, rest),
          ),
          
          // Right icon/action
          _buildRightAction(app, isWorkoutActive, rest),
        ],
      ),
    );
  }

  Widget _buildLeftIcon(bool isWorkoutActive, bool isResting) {
    IconData icon;
    Color color;
    
    if (isResting) {
      icon = Icons.timer_outlined;
      color = const Color(0xFFFFB020);
    } else if (isWorkoutActive) {
      icon = Icons.stop_rounded;
      color = Colors.white;
    } else {
      icon = Icons.play_arrow_rounded;
      color = Colors.white;
    }
    
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildCenterContent(WorkoutSessionDraft? session, RestTimerState rest) {
    String title;
    String subtitle;
    
    if (rest.isRunning) {
      final remaining = rest.remaining;
      final mins = remaining.inMinutes;
      final secs = remaining.inSeconds % 60;
      title = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
      subtitle = 'REST';
    } else if (session != null) {
      final duration = DateTime.now().difference(session.startedAt);
      final mins = duration.inMinutes;
      final secs = duration.inSeconds % 60;
      title = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
      subtitle = 'ACTIVE SESSION';
    } else {
      title = 'START WORKOUT';
      subtitle = 'TAP TO BEGIN';
    }
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
<<<<<<< HEAD
        const SizedBox(width: 8),
        if (rest.isRunning && expanded)
          Text(
            restText,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
=======
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
>>>>>>> origin/main
          ),
        ),
      ],
    );
  }

  Widget _buildRightAction(AppState app, bool isWorkoutActive, RestTimerState rest) {
    if (rest.isRunning) {
      return IconButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          app.stopRestTimer();
        },
        icon: const Icon(Icons.close, color: Colors.white54, size: 20),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      );
    }
    
    return Icon(
      Icons.chevron_right,
      color: Colors.white.withOpacity(0.3),
      size: 20,
    );
  }
}

/// Expanded state - full controls
class _ExpandedContent extends StatefulWidget {
  const _ExpandedContent({required this.app, required this.onClose});

  final AppState app;
  final VoidCallback onClose;

  @override
  State<_ExpandedContent> createState() => _ExpandedContentState();
}

class _ExpandedContentState extends State<_ExpandedContent> {
  final _exerciseController = TextEditingController();

  @override
  void dispose() {
    _exerciseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final session = app.activeSession;
    final isWorkoutActive = session != null;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Text(
                isWorkoutActive ? 'WORKOUT' : 'START',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ),
        
        const Divider(color: Color(0x22FFFFFF), height: 1),
        
        // Content
        Expanded(
          child: isWorkoutActive
              ? _ActiveWorkoutPanel(app: app, session: session!)
              : _StartWorkoutPanel(app: app, controller: _exerciseController),
        ),
        
        // Bottom actions
        if (isWorkoutActive)
          _BottomActions(app: app, onClose: widget.onClose),
      ],
    );
  }
}

class _StartWorkoutPanel extends StatelessWidget {
  const _StartWorkoutPanel({required this.app, required this.controller});

  final AppState app;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quick Start',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.play_arrow_rounded,
            label: 'Start Empty Workout',
            color: const Color(0xFF00D17A),
            onTap: () {
              HapticFeedback.mediumImpact();
              app.startWorkout(title: 'Workout');
            },
          ),
          const SizedBox(height: 8),
          _ActionButton(
            icon: Icons.timer_outlined,
            label: 'Start Rest Timer',
            color: const Color(0xFFFFB020),
            onTap: () {
              HapticFeedback.lightImpact();
              app.startRestTimer();
            },
          ),
          const Spacer(),
          Text(
            'Swipe down to close',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveWorkoutPanel extends StatelessWidget {
  const _ActiveWorkoutPanel({required this.app, required this.session});

  final AppState app;
  final WorkoutSessionDraft session;

  @override
  Widget build(BuildContext context) {
    final exercises = session.exercises;
    final currentIndex = app.activeExerciseIndex.clamp(0, exercises.isEmpty ? 0 : exercises.length - 1);
    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatItem(
              value: '${exercises.length}',
              label: 'EXERCISES',
            ),
            _StatItem(
              value: '${exercises.fold<int>(0, (s, e) => s + e.sets.length)}',
              label: 'SETS',
            ),
            _StatItem(
              value: _formatDuration(DateTime.now().difference(session.startedAt)),
              label: 'TIME',
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Current exercise
        if (exercises.isNotEmpty) ...[
          Text(
            'CURRENT',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          _ExerciseTile(
            exercise: exercises[currentIndex],
            isActive: true,
            onTap: () {},
            onAddSet: () {
              HapticFeedback.mediumImpact();
              app.addQuickSetToActive(startSmartRest: true);
            },
          ),
        ],
        
        const SizedBox(height: 12),
        
        // Add exercise button
        _ActionButton(
          icon: Icons.add,
          label: 'Add Exercise',
          color: Colors.white.withOpacity(0.1),
          textColor: Colors.white.withOpacity(0.7),
          onTap: () => _showAddExerciseDialog(context),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showAddExerciseDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Add Exercise'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Exercise name...',
            hintStyle: TextStyle(color: Colors.white38),
          ),
          onSubmitted: (name) {
            if (name.trim().isNotEmpty) {
              app.addExerciseToActive(name.trim());
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                app.addExerciseToActive(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.app, required this.onClose});

  final AppState app;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.timer_outlined,
              label: 'Rest',
              color: const Color(0xFFFFB020).withOpacity(0.2),
              textColor: const Color(0xFFFFB020),
              compact: true,
              onTap: () {
                HapticFeedback.lightImpact();
                app.startRestTimer();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              icon: Icons.check_rounded,
              label: 'Finish',
              color: const Color(0xFF00D17A),
              compact: true,
              onTap: () {
                HapticFeedback.heavyImpact();
                app.endWorkoutAndSave();
                onClose();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.exercise,
    required this.isActive,
    required this.onTap,
    required this.onAddSet,
  });

  final ExerciseDraft exercise;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onAddSet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF00D17A).withOpacity(0.1) : const Color(0x11FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFF00D17A).withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${exercise.sets.length} sets',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onAddSet,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Set'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00D17A),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.textColor,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color? textColor;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = textColor ?? (color.computeLuminance() > 0.5 ? Colors.black : Colors.white);
    
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 10 : 14,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: compact ? 16 : 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
