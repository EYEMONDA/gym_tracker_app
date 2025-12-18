import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';
import '../screens/log_screen.dart';
import 'animated_widgets.dart';

class DynamicIsland extends StatefulWidget {
  const DynamicIsland({super.key});

  @override
  State<DynamicIsland> createState() => _DynamicIslandState();
}

class _DynamicIslandState extends State<DynamicIsland> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showFocusPanel = true;
  bool _showStreakCelebration = false;
  int? _lastStreakCelebrated;
  
  // Animation controller for morphing effects
  late AnimationController _morphController;
  late Animation<double> _morphAnimation;

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _morphAnimation = CurvedAnimation(
      parent: _morphController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _morphController.dispose();
    super.dispose();
  }

  void _triggerStreakCelebration(int streak) {
    if (_lastStreakCelebrated == streak) return;
    _lastStreakCelebrated = streak;
    setState(() => _showStreakCelebration = true);
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showStreakCelebration = false);
    });
  }

  String _formatMMSS(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color _accentFor({
    required bool workoutActive,
    required bool restRunning,
    required bool searching,
    required bool supersetMode,
    required bool progressReady,
  }) {
    if (_showStreakCelebration) return const Color(0xFFFF6B35); // Orange for celebration
    if (progressReady) return const Color(0xFFFFD700); // Gold for progress nudge
    if (searching) return const Color(0xFF7C7CFF);
    if (supersetMode && workoutActive) return const Color(0xFF00E5FF); // Cyan for superset
    if (workoutActive) return const Color(0xFF00D17A);
    if (restRunning) return const Color(0xFFFFB020);
    return const Color(0xFFFFFFFF);
  }

  /// Get contextual state label for the island
  String _getContextualLabel(AppState app) {
    if (_showStreakCelebration) {
      final streak = app.currentStreak;
      if (streak >= 7) return '🔥 $streak-day streak!';
      if (streak >= 3) return '🔥 $streak days in a row!';
      return '💪 Keep it up!';
    }
    
    final now = DateTime.now();
    final lastSession = app.sessions.isEmpty ? null : app.sessions.first;
    final daysSinceLast = lastSession == null 
        ? null 
        : DateTime(now.year, now.month, now.day)
            .difference(DateTime(lastSession.startedAt.year, lastSession.startedAt.month, lastSession.startedAt.day))
            .inDays;

    if (app.activeSession == null) {
      // Pre-workout states
      if (daysSinceLast == 0) return 'Rest day 💤';
      if (daysSinceLast == null || daysSinceLast > 3) return 'Ready to train?';
      return 'Search';
    }
    
    return 'Search';
  }

  String _formatSetLine(ExerciseSet s) {
    final w = s.weight.toStringAsFixed(s.weight == s.weight.roundToDouble() ? 0 : 1);
    final rpe = s.rpe;
    final rpeText = rpe == null ? '' : ' • RPE ${rpe.toStringAsFixed(rpe == rpe.roundToDouble() ? 0 : 1)}';
    return '${s.reps} reps • $w ${s.unit}$rpeText';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final rest = app.restTimer;
    final hits = app.searchAll(app.searchQuery);
    final workoutActive = app.activeSession != null;
    final focusMode = app.focusModeEnabled;
    final tapAssist = app.tapAssistEnabled;
    final supersetMode = app.supersetModeEnabled;

    // Check for streak celebration trigger (when reaching milestones)
    final streak = app.currentStreak;
    final workoutsThisWeek = app.workoutsThisWeek;
    if (workoutsThisWeek >= app.weeklyWorkoutGoal && streak >= 3 && !_showStreakCelebration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _triggerStreakCelebration(streak);
      });
    }

    // Check for progressive overload opportunity
    bool progressReady = false;
    if (workoutActive && app.activeSession!.exercises.isNotEmpty) {
      final exIndex = app.activeExerciseIndex.clamp(0, app.activeSession!.exercises.length - 1);
      final ex = app.activeSession!.exercises[exIndex];
      final suggestion = app.getProgressiveOverloadSuggestion(ex.name);
      progressReady = suggestion != null;
    }

    // Keep controller aligned when state changes from elsewhere.
    if (_controller.text != app.searchQuery) {
      _controller.value = TextEditingValue(
        text: app.searchQuery,
        selection: TextSelection.collapsed(offset: app.searchQuery.length),
      );
    }

    final size = MediaQuery.sizeOf(context);
    final maxWidth = min(560, size.width - 24);
    final collapsedWidth = min(workoutActive && focusMode ? 360 : 220, size.width - 24);
    final expanded = app.isSearchExpanded;

    final baseHeight = 42.0;
    final expandedHeight = min(320.0, size.height * 0.42);
    final height = expanded ? expandedHeight : baseHeight;
    final width = expanded ? maxWidth : collapsedWidth;

    final showRest = rest.isRunning && !expanded;
    final accent = _accentFor(
      workoutActive: workoutActive && focusMode,
      restRunning: rest.isRunning,
      searching: expanded && !_showFocusPanel,
      supersetMode: supersetMode,
      progressReady: progressReady,
    );

    // Keep panel choice sensible.
    if (!workoutActive || !focusMode) {
      _showFocusPanel = false;
    }

    final double iconMin = tapAssist ? 48 : 32;
    final double iconPad = tapAssist ? 10 : 0;

    return GestureDetector(
      // Gesture-based quick actions
      onVerticalDragEnd: (details) {
        if (expanded) return;
        if (details.primaryVelocity == null) return;
        
        if (details.primaryVelocity! > 200) {
          // Swipe down: start rest timer
          if (!rest.isRunning) {
            HapticFeedback.lightImpact();
            if (workoutActive && app.activeSession!.exercises.isNotEmpty) {
              final exIndex = app.activeExerciseIndex.clamp(0, app.activeSession!.exercises.length - 1);
              final ex = app.activeSession!.exercises[exIndex];
              final smartSeconds = app.getSmartRestSeconds(ex.name);
              app.startRestTimer(seconds: smartSeconds);
            } else {
              app.startRestTimer();
            }
          }
        } else if (details.primaryVelocity! < -200) {
          // Swipe up: open focus logger
          HapticFeedback.lightImpact();
          app.setSearchExpanded(true);
          if (workoutActive && focusMode) {
            setState(() => _showFocusPanel = true);
          }
        }
      },
      onHorizontalDragEnd: (details) {
        if (expanded) return;
        if (!workoutActive || app.activeSession!.exercises.isEmpty) return;
        if (details.primaryVelocity == null) return;
        
        final exercises = app.activeSession!.exercises;
        if (details.primaryVelocity!.abs() > 200) {
          HapticFeedback.selectionClick();
          if (details.primaryVelocity! > 0) {
            // Swipe right: previous exercise
            final newIndex = (app.activeExerciseIndex - 1).clamp(0, exercises.length - 1);
            app.setActiveExerciseIndex(newIndex);
          } else {
            // Swipe left: next exercise
            final newIndex = (app.activeExerciseIndex + 1).clamp(0, exercises.length - 1);
            app.setActiveExerciseIndex(newIndex);
          }
        }
      },
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(workoutActive || rest.isRunning ? 0.28 : 0.12),
              blurRadius: 24,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Material(
              color: const Color(0xCC0A0A0A),
              child: InkWell(
                onTap: () {
                  app.setSearchExpanded(true);
                  if (workoutActive && focusMode) {
                    setState(() => _showFocusPanel = true);
                  } else {
                    setState(() => _showFocusPanel = false);
                    _focusNode.requestFocus();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopRow(
                        app: app,
                        expanded: expanded,
                        showRest: showRest,
                        restText: _formatMMSS(rest.remaining),
                        focusMode: focusMode,
                        accent: accent,
                        focusPanel: _showFocusPanel,
                        tapAssistMinSize: iconMin,
                        tapAssistPadding: iconPad,
                        onTogglePanel: (focus) => setState(() => _showFocusPanel = focus),
                        onClose: () {
                          app.setSearchExpanded(false);
                          _focusNode.unfocus();
                        },
                        searchField: TextField(
                          key: const ValueKey('dynamic_island_search'),
                          controller: _controller,
                          focusNode: _focusNode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search exercises, sessions…',
                            hintStyle: TextStyle(color: Color(0x88FFFFFF)),
                            isDense: true,
                            border: InputBorder.none,
                          ),
                          onChanged: app.setSearchQuery,
                        ),
                      ),
                      if (expanded) ...[
                        const SizedBox(height: 10),
                        if (workoutActive && focusMode && _showFocusPanel)
                          Expanded(
                            child: _FocusLoggerPanel(
                              app: app,
                              accent: accent,
                              formatSetLine: _formatSetLine,
                            ),
                          )
                        else
                          Expanded(
                            child: _SearchPanel(
                              app: app,
                              hits: hits,
                              onPickRest: (s) => app.startRestTimer(seconds: s),
                              onClose: () {
                                app.setSearchExpanded(false);
                                _focusNode.unfocus();
                              },
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.app,
    required this.expanded,
    required this.showRest,
    required this.restText,
    required this.focusMode,
    required this.accent,
    required this.focusPanel,
    required this.tapAssistMinSize,
    required this.tapAssistPadding,
    required this.onTogglePanel,
    required this.onClose,
    required this.searchField,
  });

  final AppState app;
  final bool expanded;
  final bool showRest;
  final String restText;
  final bool focusMode;
  final Color accent;
  final bool focusPanel;
  final double tapAssistMinSize;
  final double tapAssistPadding;
  final void Function(bool focusPanel) onTogglePanel;
  final VoidCallback onClose;
  final Widget searchField;

  @override
  Widget build(BuildContext context) {
    final rest = app.restTimer;
    final workoutActive = app.activeSession != null;
    final hasExercises = (app.activeSession?.exercises.isNotEmpty ?? false);
    final supersetMode = app.supersetModeEnabled;

    final canShowFocusCollapsed = !expanded && focusMode && workoutActive && hasExercises;
    final ex = canShowFocusCollapsed ? app.activeSession!.exercises[app.activeExerciseIndex.clamp(0, app.activeSession!.exercises.length - 1)] : null;
    final nextSetNumber = ex == null ? 1 : ex.sets.length + 1;
    
    // Check for progressive overload opportunity
    final progressSuggestion = ex != null ? app.getProgressiveOverloadSuggestion(ex.name) : null;
    final showProgressNudge = progressSuggestion != null;
    
    // Get smart rest time for current exercise
    final smartRestLabel = ex != null && app.smartRestEnabled 
        ? (app.isCompoundExercise(ex.name) ? '⏱ 2:30' : '⏱ 1:15')
        : null;

    // Build collapsed label with contextual info
    String collapsedLabel;
    if (canShowFocusCollapsed) {
      if (showProgressNudge) {
        final s = progressSuggestion!;
        collapsedLabel = '📈 ${ex!.name} • +${s.suggestedWeight - s.currentWeight}${s.unit}?';
      } else if (supersetMode && app.supersetPairedIndices.contains(app.activeExerciseIndex)) {
        collapsedLabel = '🔄 ${ex!.name} • Set $nextSetNumber';
      } else {
        collapsedLabel = '${ex!.name} • Set $nextSetNumber';
      }
    } else if (showRest) {
      collapsedLabel = smartRestLabel != null ? 'Rest $restText $smartRestLabel' : 'Rest $restText';
    } else {
      collapsedLabel = app.searchQuery.trim().isEmpty ? 'Search' : app.searchQuery;
    }

    return Row(
      children: [
        Icon(
          canShowFocusCollapsed
              ? (showProgressNudge ? Icons.trending_up : (supersetMode ? Icons.sync : Icons.fitness_center))
              : (showRest ? Icons.timer : Icons.search),
          size: 18,
          color: canShowFocusCollapsed ? accent.withOpacity(0.95) : Colors.white.withOpacity(0.9),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: expanded
                ? (focusMode && workoutActive && focusPanel
                    ? Text(
                        supersetMode ? 'Focus logger (Superset)' : 'Focus logger',
                        key: const ValueKey('dynamic_island_focus_title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                      )
                    : searchField)
                : Text(
                    collapsedLabel,
                    key: ValueKey('dynamic_island_title_$collapsedLabel'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: showProgressNudge ? const Color(0xFFFFD700) : Colors.white, 
                      fontSize: 14, 
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        if (rest.isRunning && expanded)
          PulsingGlow(
            glowColor: const Color(0xFFFFB020),
            maxRadius: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB020).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                restText,
                style: const TextStyle(color: Color(0xFFFFB020), fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        if (expanded) ...[
          if (focusMode && workoutActive) ...[
            IconButton(
              tooltip: supersetMode ? 'Superset Off' : 'Superset Mode',
              padding: EdgeInsets.all(tapAssistPadding),
              constraints: BoxConstraints(minWidth: tapAssistMinSize, minHeight: tapAssistMinSize),
              icon: Icon(
                Icons.sync, 
                size: 18, 
                color: supersetMode ? const Color(0xFF00E5FF) : Colors.white54,
              ),
              onPressed: () => app.setSupersetModeEnabled(!supersetMode),
            ),
            IconButton(
              tooltip: focusPanel ? 'Search' : 'Focus',
              padding: EdgeInsets.all(tapAssistPadding),
              constraints: BoxConstraints(minWidth: tapAssistMinSize, minHeight: tapAssistMinSize),
              icon: Icon(focusPanel ? Icons.search : Icons.fitness_center, size: 18),
              onPressed: () => onTogglePanel(!focusPanel),
            ),
          ],
          IconButton(
            tooltip: 'Close',
            padding: EdgeInsets.all(tapAssistPadding),
            constraints: BoxConstraints(minWidth: tapAssistMinSize, minHeight: tapAssistMinSize),
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
          ),
        ] else if (canShowFocusCollapsed)
          IconButton(
            tooltip: showProgressNudge ? 'Add heavier set' : 'Add set',
            padding: EdgeInsets.all(tapAssistPadding),
            constraints: BoxConstraints(minWidth: tapAssistMinSize, minHeight: tapAssistMinSize),
            icon: Icon(
              showProgressNudge ? Icons.arrow_circle_up : Icons.add_circle, 
              size: 18, 
              color: accent.withOpacity(0.95),
            ),
            onPressed: () {
              final added = app.addQuickSetToActive(startSmartRest: true);
              if (added == null) return;
              
              final supersetInfo = supersetMode && app.supersetPairedIndices.length >= 2 
                  ? ' → Next exercise' 
                  : '';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added set $nextSetNumber • ${ex!.name}$supersetInfo'),
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => app.undoQuickSet(added),
                  ),
                ),
              );
            },
          )
        else if (rest.isRunning)
          IconButton(
            tooltip: 'Stop timer',
            padding: EdgeInsets.all(tapAssistPadding),
            constraints: BoxConstraints(minWidth: tapAssistMinSize, minHeight: tapAssistMinSize),
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            onPressed: app.stopRestTimer,
          ),
      ],
    );
  }
}

class _FocusLoggerPanel extends StatelessWidget {
  const _FocusLoggerPanel({
    required this.app,
    required this.accent,
    required this.formatSetLine,
  });

  final AppState app;
  final Color accent;
  final String Function(ExerciseSet) formatSetLine;

  @override
  Widget build(BuildContext context) {
    final session = app.activeSession!;
    final exIndex = app.activeExerciseIndex.clamp(0, session.exercises.length - 1);
    final ex = session.exercises[exIndex];
    final last = ex.sets.isEmpty ? null : ex.sets.last;
    final supersetMode = app.supersetModeEnabled;
    
    // Check for progressive overload
    final progressSuggestion = app.getProgressiveOverloadSuggestion(ex.name);
    final isCompound = app.isCompoundExercise(ex.name);
    final smartRestSeconds = app.getSmartRestSeconds(ex.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Exercise chips with superset indicators
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(session.exercises.length, (i) {
            final e = session.exercises[i];
            final isInSuperset = app.supersetPairedIndices.contains(i);
            return GestureDetector(
              onLongPress: supersetMode ? () {
                HapticFeedback.selectionClick();
                app.toggleSupersetExercise(i);
              } : null,
              child: ChoiceChip(
                selected: i == exIndex,
                avatar: supersetMode && isInSuperset 
                    ? const Icon(Icons.sync, size: 14, color: Color(0xFF00E5FF))
                    : null,
                label: Text(e.name, overflow: TextOverflow.ellipsis),
                onSelected: (_) => app.setActiveExerciseIndex(i),
              ),
            );
          }),
        ),
        if (supersetMode)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Long-press exercises to pair for superset',
              style: TextStyle(color: const Color(0xFF00E5FF).withOpacity(0.7), fontSize: 11),
            ),
          ),
        const SizedBox(height: 10),
        
        // Last set info with progress suggestion
        if (progressSuggestion != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, size: 16, color: Color(0xFFFFD700)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '📈 Ready to progress: ${progressSuggestion.currentWeight} → ${progressSuggestion.suggestedWeight} ${progressSuggestion.unit}',
                    style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          )
        else if (last != null)
          Text(
            'Last: ${formatSetLine(last)}${isCompound ? " (compound)" : ""}',
            style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
          )
        else
          const Text('Last: none yet', style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 12)),
        const SizedBox(height: 10),
        
        // Main action row
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  final added = app.addQuickSetToActive(startSmartRest: true);
                  if (added == null) return;
                  final supersetInfo = supersetMode && app.supersetPairedIndices.length >= 2 
                      ? ' → Next' 
                      : '';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added set • ${ex.name}$supersetInfo'),
                      duration: const Duration(seconds: 2),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () => app.undoQuickSet(added),
                      ),
                    ),
                  );
                },
                icon: Icon(Icons.add, color: Colors.black.withOpacity(0.9)),
                label: const Text('Add set'),
                style: FilledButton.styleFrom(backgroundColor: accent),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => app.startRestTimer(seconds: smartRestSeconds),
              icon: const Icon(Icons.timer),
              label: Text('Rest ${smartRestSeconds ~/ 60}:${(smartRestSeconds % 60).toString().padLeft(2, '0')}'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        // Warm-up and Save row
        Row(
          children: [
            // Warm-up sets button (only show if no sets yet)
            if (ex.sets.isEmpty && last == null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await showDialog<_WarmupConfig>(
                      context: context,
                      builder: (_) => const _WarmupDialog(),
                    );
                    if (result == null) return;
                    app.addWarmupSetsToExercise(exIndex, result.workingWeight, result.unit);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added 3 warm-up sets')),
                      );
                    }
                  },
                  icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                  label: const Text('Warm-up'),
                ),
              )
            else
              const SizedBox.shrink(),
            if (ex.sets.isEmpty && last == null) const SizedBox(width: 10),
            Expanded(
              child: _MorphingSaveButton(
                totalSets: session.exercises.fold(0, (sum, e) => sum + e.sets.length),
                onSave: () async {
                  await app.endWorkoutAndSave();
                  if (context.mounted) {
                    HapticFeedback.heavyImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('💪 Great workout! Saved.')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0x22FFFFFF)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final name = await showDialog<String>(
              context: context,
              builder: (_) => const _AddExerciseDialog(),
            );
            if (name == null) return;
            app.addExerciseToActive(name);
          },
          icon: const Icon(Icons.add),
          label: const Text('Add exercise'),
        ),
      ],
    );
  }
}

/// Morphing save button that grows more prominent as sets are logged
class _MorphingSaveButton extends StatelessWidget {
  const _MorphingSaveButton({
    required this.totalSets,
    required this.onSave,
  });

  final int totalSets;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    // Button morphs based on workout progress
    final hasContent = totalSets > 0;
    final isSubstantial = totalSets >= 3;
    
    final buttonColor = isSubstantial 
        ? const Color(0xFF00D17A) 
        : (hasContent ? const Color(0xFF00D17A).withOpacity(0.7) : null);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: FilledButton.tonalIcon(
        onPressed: onSave,
        icon: Icon(
          isSubstantial ? Icons.check_circle : Icons.check,
          color: isSubstantial ? Colors.black87 : null,
        ),
        label: Text(
          isSubstantial ? 'Save workout 💪' : 'Save',
          style: TextStyle(
            fontWeight: isSubstantial ? FontWeight.w800 : FontWeight.w600,
            color: isSubstantial ? Colors.black87 : null,
          ),
        ),
        style: isSubstantial 
            ? FilledButton.styleFrom(backgroundColor: buttonColor)
            : null,
      ),
    );
  }
}

/// Dialog for configuring warm-up sets
class _WarmupDialog extends StatefulWidget {
  const _WarmupDialog();

  @override
  State<_WarmupDialog> createState() => _WarmupDialogState();
}

class _WarmupDialogState extends State<_WarmupDialog> {
  final TextEditingController _weight = TextEditingController(text: '60');
  String _unit = 'kg';

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add warm-up sets'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your working weight. We\'ll add:\n• 50% × 10 reps\n• 70% × 5 reps\n• 85% × 3 reps',
            style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Working weight'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _unit,
            items: const [
              DropdownMenuItem(value: 'kg', child: Text('kg')),
              DropdownMenuItem(value: 'lb', child: Text('lb')),
            ],
            onChanged: (v) => setState(() => _unit = v ?? 'kg'),
            decoration: const InputDecoration(labelText: 'Unit'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final w = double.tryParse(_weight.text.replaceAll(',', '.')) ?? 60;
            Navigator.pop(context, _WarmupConfig(workingWeight: w, unit: _unit));
          },
          child: const Text('Add warm-ups'),
        ),
      ],
    );
  }
}

class _WarmupConfig {
  const _WarmupConfig({required this.workingWeight, required this.unit});
  final double workingWeight;
  final String unit;
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.app,
    required this.hits,
    required this.onPickRest,
    required this.onClose,
  });

  final AppState app;
  final List<SearchHit> hits;
  final void Function(int seconds) onPickRest;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _QuickActionsRow(onPickRest: onPickRest),
        const SizedBox(height: 10),
        Expanded(
          child: hits.isEmpty
              ? Center(
                  child: Text(
                    app.searchQuery.trim().isEmpty ? 'Type to search. Try “bench” or “legs”.' : 'No matches.',
                    style: const TextStyle(color: Color(0x88FFFFFF)),
                  ),
                )
              : ListView.separated(
                  itemCount: hits.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x22FFFFFF)),
                  itemBuilder: (context, index) {
                    final h = hits[index];
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      leading: Icon(
                        h.kind == SearchHitKind.exercise ? Icons.fitness_center : Icons.history,
                        size: 18,
                        color: const Color(0xCCFFFFFF),
                      ),
                      title: Text(
                        h.kind == SearchHitKind.exercise ? (h.name ?? '') : (h.title ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        h.kind == SearchHitKind.exercise ? 'Add to workout' : 'Open session',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 12),
                      ),
                      onTap: () {
                        if (h.kind == SearchHitKind.exercise) {
                          if (app.activeSession == null) {
                            app.startWorkout(title: 'Workout');
                          }
                          app.addExerciseToActive(h.name ?? '');
                          onClose();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added “${h.name}”'),
                              duration: const Duration(milliseconds: 900),
                            ),
                          );
                        } else if (h.kind == SearchHitKind.session) {
                          final id = h.sessionId;
                          if (id == null) return;
                          final session = app.sessions.where((s) => s.id == id).cast<WorkoutSession?>().firstOrNull;
                          if (session == null) return;
                          onClose();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SessionDetailScreen(session: session),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
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

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.onPickRest});

  final void Function(int seconds) onPickRest;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PillButton(
          label: '30s',
          onTap: () => onPickRest(30),
        ),
        const SizedBox(width: 8),
        _PillButton(
          label: '60s',
          onTap: () => onPickRest(60),
        ),
        const SizedBox(width: 8),
        _PillButton(
          label: '90s',
          onTap: () => onPickRest(90),
        ),
        const SizedBox(width: 8),
        _PillButton(
          label: '2m',
          onTap: () => onPickRest(120),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x22FFFFFF)),
          color: const Color(0x11000000),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

