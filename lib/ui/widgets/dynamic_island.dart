import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../screens/log_screen.dart';

class DynamicIsland extends StatefulWidget {
  const DynamicIsland({super.key});

  @override
  State<DynamicIsland> createState() => _DynamicIslandState();
}

class _DynamicIslandState extends State<DynamicIsland> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showFocusPanel = true;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatMMSS(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color _accentFor({required bool workoutActive, required bool restRunning, required bool searching}) {
    if (searching) return const Color(0xFF7C7CFF);
    if (workoutActive) return const Color(0xFF00D17A);
    if (restRunning) return const Color(0xFFFFB020);
    return const Color(0xFFFFFFFF);
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
    final expandedHeight = min(260.0, size.height * 0.35);
    final height = expanded ? expandedHeight : baseHeight;
    final width = expanded ? maxWidth : collapsedWidth;

    final showRest = rest.isRunning && !expanded;
    final accent = _accentFor(
      workoutActive: workoutActive && focusMode,
      restRunning: rest.isRunning,
      searching: expanded && !_showFocusPanel,
    );

    // Keep panel choice sensible.
    if (!workoutActive || !focusMode) {
      _showFocusPanel = false;
    }

    final double iconMin = tapAssist ? 48 : 32;
    final double iconPad = tapAssist ? 10 : 0;

    return AnimatedContainer(
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

    final canShowFocusCollapsed = !expanded && focusMode && workoutActive && hasExercises;
    final ex = canShowFocusCollapsed ? app.activeSession!.exercises[app.activeExerciseIndex.clamp(0, app.activeSession!.exercises.length - 1)] : null;
    final nextSetNumber = ex == null ? 1 : ex.sets.length + 1;

    return Row(
      children: [
        Icon(
          canShowFocusCollapsed
              ? Icons.fitness_center
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
                        'Focus logger',
                        key: const ValueKey('dynamic_island_focus_title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                      )
                    : searchField)
                : Text(
                    canShowFocusCollapsed
                        ? '${ex!.name} • Set $nextSetNumber'
                        : (showRest ? 'Rest $restText' : (app.searchQuery.trim().isEmpty ? 'Search' : app.searchQuery)),
                    key: const ValueKey('dynamic_island_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        if (rest.isRunning && expanded)
          Text(
            restText,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        if (expanded) ...[
          if (focusMode && workoutActive)
            IconButton(
              tooltip: focusPanel ? 'Search' : 'Focus',
              padding: EdgeInsets.all(tapAssistPadding),
              constraints: BoxConstraints(minWidth: tapAssistMinSize, minHeight: tapAssistMinSize),
              icon: Icon(focusPanel ? Icons.search : Icons.fitness_center, size: 18),
              onPressed: () => onTogglePanel(!focusPanel),
            ),
          IconButton(
            tooltip: 'Close',
            padding: EdgeInsets.all(tapAssistPadding),
            constraints: BoxConstraints(minWidth: tapAssistMinSize, minHeight: tapAssistMinSize),
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
          ),
        ] else if (canShowFocusCollapsed)
          IconButton(
            tooltip: 'Add set',
            padding: EdgeInsets.all(tapAssistPadding),
            constraints: BoxConstraints(minWidth: tapAssistMinSize, minHeight: tapAssistMinSize),
            icon: Icon(Icons.add_circle, size: 18, color: accent.withOpacity(0.95)),
            onPressed: () {
              final added = app.addQuickSetToActive();
              if (added == null) return;
              app.startRestTimer();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added set $nextSetNumber • ${ex!.name}'),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(session.exercises.length, (i) {
            final e = session.exercises[i];
            return ChoiceChip(
              selected: i == exIndex,
              label: Text(e.name, overflow: TextOverflow.ellipsis),
              onSelected: (_) => app.setActiveExerciseIndex(i),
            );
          }),
        ),
        const SizedBox(height: 10),
        if (last != null)
          Text(
            'Last: ${formatSetLine(last)}',
            style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
          )
        else
          const Text('Last: none yet', style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 12)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  final added = app.addQuickSetToActive();
                  if (added == null) return;
                  app.startRestTimer();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added set • ${ex.name}'),
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
              onPressed: () => app.startRestTimer(),
              icon: const Icon(Icons.timer),
              label: const Text('Rest'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  await app.endWorkoutAndSave();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout saved.')));
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Save workout'),
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

