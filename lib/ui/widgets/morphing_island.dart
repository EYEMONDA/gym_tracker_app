import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';
import '../../data/exercise_database.dart';
import '../screens/log_screen.dart';

/// Morphing Dynamic Island that adapts to workout state.
/// 
/// Pre-workout mode: History | Play | Search | Routines
/// Active session mode: X | Stop | Timer | Wearable
class MorphingIsland extends StatefulWidget {
  const MorphingIsland({super.key});

  @override
  State<MorphingIsland> createState() => _MorphingIslandState();
}

class _MorphingIslandState extends State<MorphingIsland> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isSearchExpanded = false;
  bool _showRoutinesPanel = false;
  bool _showHistoryPanel = false;
  bool _showMultiSelectPanel = false;
  
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
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _morphController.dispose();
    super.dispose();
  }

  String _formatMMSS(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatWorkoutDuration(DateTime startedAt) {
    final duration = DateTime.now().difference(startedAt);
    final mins = duration.inMinutes;
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final workoutActive = app.activeSession != null;
    final size = MediaQuery.sizeOf(context);
    final maxWidth = min(600, size.width - 32);
    
    // Determine which mode to show
    if (workoutActive) {
      return _ActiveSessionMode(
        app: app,
        maxWidth: maxWidth,
        formatDuration: _formatWorkoutDuration,
        formatMMSS: _formatMMSS,
      );
    } else {
      return _PreWorkoutMode(
        app: app,
        maxWidth: maxWidth,
        searchController: _searchController,
        searchFocus: _searchFocus,
        isSearchExpanded: _isSearchExpanded,
        showRoutinesPanel: _showRoutinesPanel,
        showHistoryPanel: _showHistoryPanel,
        showMultiSelectPanel: _showMultiSelectPanel,
        onSearchExpanded: (expanded) => setState(() => _isSearchExpanded = expanded),
        onRoutinesPanel: (show) => setState(() {
          _showRoutinesPanel = show;
          _showHistoryPanel = false;
          _showMultiSelectPanel = false;
        }),
        onHistoryPanel: (show) => setState(() {
          _showHistoryPanel = show;
          _showRoutinesPanel = false;
          _showMultiSelectPanel = false;
        }),
        onMultiSelectPanel: (show) => setState(() {
          _showMultiSelectPanel = show;
          _showRoutinesPanel = false;
          _showHistoryPanel = false;
        }),
      );
    }
  }
}

/// Active Session Mode: X | Stop | Timer | Wearable
class _ActiveSessionMode extends StatelessWidget {
  const _ActiveSessionMode({
    required this.app,
    required this.maxWidth,
    required this.formatDuration,
    required this.formatMMSS,
  });

  final AppState app;
  final double maxWidth;
  final String Function(DateTime) formatDuration;
  final String Function(Duration) formatMMSS;

  @override
  Widget build(BuildContext context) {
    final session = app.activeSession!;
    final duration = formatDuration(session.startedAt);
    final rest = app.restTimer;
    final restText = rest.isRunning ? formatMMSS(rest.remaining) : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xCC0A0A0A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF00D17A).withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D17A).withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Row(
                children: [
                  // Red X button (discard)
                  IconButton(
                    icon: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF44336),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 18, color: Colors.white),
                    ),
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Discard workout?'),
                          content: const Text('This won\'t be saved.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
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
                    tooltip: 'Discard workout',
                  ),
                  
                  // Stop button
                  IconButton(
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.stop, size: 20, color: Colors.white),
                    ),
                    onPressed: () async {
                      await app.endWorkoutAndSave();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Workout saved.')),
                        );
                      }
                    },
                    tooltip: 'Save workout',
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Active Session text and timer
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACTIVE SESSION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF00D17A),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              duration,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            if (restText != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB020).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Rest $restText',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFFB020),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Wearable icon
                  IconButton(
                    icon: const Icon(Icons.watch, size: 20, color: Colors.white70),
                    onPressed: () {
                      // Future: Connect to wearable device
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Wearable integration coming soon')),
                      );
                    },
                    tooltip: 'Wearable device',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pre-Workout Mode: History | Play | Search | Routines
class _PreWorkoutMode extends StatelessWidget {
  const _PreWorkoutMode({
    required this.app,
    required this.maxWidth,
    required this.searchController,
    required this.searchFocus,
    required this.isSearchExpanded,
    required this.showRoutinesPanel,
    required this.showHistoryPanel,
    required this.showMultiSelectPanel,
    required this.onSearchExpanded,
    required this.onRoutinesPanel,
    required this.onHistoryPanel,
    required this.onMultiSelectPanel,
  });

  final AppState app;
  final double maxWidth;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final bool isSearchExpanded;
  final bool showRoutinesPanel;
  final bool showHistoryPanel;
  final bool showMultiSelectPanel;
  final void Function(bool) onSearchExpanded;
  final void Function(bool) onRoutinesPanel;
  final void Function(bool) onHistoryPanel;
  final void Function(bool) onMultiSelectPanel;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final expandedHeight = min(500.0, size.height * 0.6);
    
    if (isSearchExpanded || showRoutinesPanel || showHistoryPanel || showMultiSelectPanel) {
      return _ExpandedPreWorkoutMode(
        app: app,
        maxWidth: maxWidth,
        expandedHeight: expandedHeight,
        searchController: searchController,
        searchFocus: searchFocus,
        isSearchExpanded: isSearchExpanded,
        showRoutinesPanel: showRoutinesPanel,
        showHistoryPanel: showHistoryPanel,
        showMultiSelectPanel: showMultiSelectPanel,
        onSearchExpanded: onSearchExpanded,
        onRoutinesPanel: onRoutinesPanel,
        onHistoryPanel: onHistoryPanel,
        onMultiSelectPanel: onMultiSelectPanel,
      );
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xCC0A0A0A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x22FFFFFF)),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.05),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Row(
                children: [
                  // History icon (left)
                  IconButton(
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.history, size: 20, color: Colors.white),
                    ),
                    onPressed: () => onHistoryPanel(true),
                    tooltip: 'Recent exercises',
                  ),
                  
                  const SizedBox(width: 4),
                  
                  // Play button (quick start)
                  IconButton(
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00D17A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, size: 24, color: Colors.black),
                    ),
                    onPressed: () {
                      app.startWorkout();
                      app.requestedTabIndex = 0;
                    },
                    tooltip: 'Quick start workout',
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Search field
                  Expanded(
                    child: InkWell(
                      onTap: () => onSearchExpanded(true),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, size: 18, color: Color(0x88FFFFFF)),
                            const SizedBox(width: 8),
                            Text(
                              'Q FIND EXERCISE...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.7),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Routines button (R)
                  IconButton(
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        'R',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    onPressed: () => onRoutinesPanel(true),
                    tooltip: 'Routines',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Expanded panel for pre-workout mode
class _ExpandedPreWorkoutMode extends StatelessWidget {
  const _ExpandedPreWorkoutMode({
    required this.app,
    required this.maxWidth,
    required this.expandedHeight,
    required this.searchController,
    required this.searchFocus,
    required this.isSearchExpanded,
    required this.showRoutinesPanel,
    required this.showHistoryPanel,
    required this.showMultiSelectPanel,
    required this.onSearchExpanded,
    required this.onRoutinesPanel,
    required this.onHistoryPanel,
    required this.onMultiSelectPanel,
  });

  final AppState app;
  final double maxWidth;
  final double expandedHeight;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final bool isSearchExpanded;
  final bool showRoutinesPanel;
  final bool showHistoryPanel;
  final bool showMultiSelectPanel;
  final void Function(bool) onSearchExpanded;
  final void Function(bool) onRoutinesPanel;
  final void Function(bool) onHistoryPanel;
  final void Function(bool) onMultiSelectPanel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: expandedHeight),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xCC0A0A0A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x22FFFFFF)),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with close button
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        if (showRoutinesPanel)
                          const Text(
                            'ROUTINES',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          )
                        else if (showHistoryPanel)
                          const Text(
                            'RECENT EXERCISES',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          )
                        else if (showMultiSelectPanel)
                          const Text(
                            'SELECT EXERCISES',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Text(
                            'FIND EXERCISE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            onSearchExpanded(false);
                            onRoutinesPanel(false);
                            onHistoryPanel(false);
                            onMultiSelectPanel(false);
                            searchFocus.unfocus();
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(height: 1, color: Color(0x22FFFFFF)),
                  
                  // Content area
                  Flexible(
                    child: _buildContent(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (showRoutinesPanel) {
      return _RoutinesPanel(
        app: app,
        onStartRoutine: (template) {
          if (app.activeSession == null) {
            app.startWorkout(title: template.name);
            for (final e in template.exercises) {
              if (e.name.trim().isEmpty) continue;
              app.addExerciseToActive(e.name);
            }
            app.requestedTabIndex = 0;
            onRoutinesPanel(false);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Started "${template.name}"')),
              );
            }
          }
        },
      );
    } else if (showHistoryPanel) {
      return _HistoryPanel(
        app: app,
        onSelectExercise: (name) {
          if (app.activeSession == null) {
            app.startWorkout();
          }
          app.addExerciseToActive(name);
          onHistoryPanel(false);
        },
        onMultiSelect: () {
          onHistoryPanel(false);
          onMultiSelectPanel(true);
        },
      );
    } else if (showMultiSelectPanel) {
      return _MultiSelectPanel(
        app: app,
        onAddSelected: (exercises) {
          if (app.activeSession == null) {
            app.startWorkout();
          }
          app.addMultipleExercisesToActive(exercises);
          onMultiSelectPanel(false);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Added ${exercises.length} exercises')),
            );
          }
        },
      );
    } else {
      return _ExerciseSearchPanel(
        app: app,
        searchController: searchController,
        searchFocus: searchFocus,
        onSelectExercise: (name) {
          if (app.activeSession == null) {
            app.startWorkout();
          }
          app.addExerciseToActive(name);
          onSearchExpanded(false);
          searchFocus.unfocus();
        },
      );
    }
  }
}

/// Exercise search panel
class _ExerciseSearchPanel extends StatefulWidget {
  const _ExerciseSearchPanel({
    required this.app,
    required this.searchController,
    required this.searchFocus,
    required this.onSelectExercise,
  });

  final AppState app;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final void Function(String) onSelectExercise;

  @override
  State<_ExerciseSearchPanel> createState() => _ExerciseSearchPanelState();
}

class _ExerciseSearchPanelState extends State<_ExerciseSearchPanel> {
  String _query = '';
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onSearchChanged);
    _updateSuggestions();
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _query = widget.searchController.text;
      _updateSuggestions();
    });
  }

  void _updateSuggestions() {
    final query = _query.trim().toLowerCase();
    final allSuggestions = <String>[];
    
    // Add favorites first
    for (final fav in widget.app.favoriteExercises) {
      if (query.isEmpty || fav.toLowerCase().contains(query)) {
        allSuggestions.add(fav);
      }
    }
    
    // Add from database
    final dbResults = query.isEmpty
        ? ExerciseDatabase.getPopular()
        : ExerciseDatabase.search(_query);
    for (final ex in dbResults) {
      if (!allSuggestions.contains(ex)) {
        allSuggestions.add(ex);
      }
    }
    
    // Add from recent sessions
    final seen = <String>{};
    for (final session in widget.app.sessions.take(20)) {
      for (final exercise in session.exercises) {
        final name = exercise.name;
        if (!seen.contains(name) && 
            (query.isEmpty || name.toLowerCase().contains(query)) &&
            !allSuggestions.contains(name)) {
          allSuggestions.add(name);
        }
        seen.add(name);
      }
    }
    
    setState(() => _suggestions = allSuggestions.take(20).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search field
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: widget.searchController,
            focusNode: widget.searchFocus,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search exercises...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        widget.searchController.clear();
                      },
                    )
                  : null,
            ),
          ),
        ),
        
        // Suggestions list
        Expanded(
          child: _suggestions.isEmpty
              ? Center(
                  child: Text(
                    _query.isEmpty
                        ? 'Start typing to search exercises'
                        : 'No exercises found',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final exercise = _suggestions[index];
                    final isFavorite = widget.app.isFavoriteExercise(exercise);
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isFavorite ? Icons.star : Icons.fitness_center,
                        size: 20,
                        color: isFavorite ? const Color(0xFFFFD700) : Colors.white70,
                      ),
                      title: Text(exercise),
                      trailing: IconButton(
                        icon: Icon(
                          isFavorite ? Icons.star : Icons.star_border,
                          size: 20,
                          color: isFavorite ? const Color(0xFFFFD700) : Colors.white54,
                        ),
                        onPressed: () {
                          widget.app.toggleFavoriteExercise(exercise);
                          _updateSuggestions();
                        },
                      ),
                      onTap: () => widget.onSelectExercise(exercise),
                    );
                  },
                ),
        ),
        
        // Custom exercise option
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () {
              if (_query.trim().isNotEmpty) {
                widget.onSelectExercise(_query.trim());
              }
            },
            icon: const Icon(Icons.add),
            label: Text(_query.trim().isEmpty
                ? 'Add Custom Exercise'
                : 'Add "${_query.trim()}"'),
          ),
        ),
      ],
    );
  }
}

/// Routines quick-start panel
class _RoutinesPanel extends StatelessWidget {
  const _RoutinesPanel({
    required this.app,
    required this.onStartRoutine,
  });

  final AppState app;
  final void Function(RoutineTemplate) onStartRoutine;

  @override
  Widget build(BuildContext context) {
    final routines = app.routineTemplates;
    
    if (routines.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No routines yet.\nCreate one in Schedule tab.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0x88FFFFFF)),
          ),
        ),
      );
    }
    
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: routines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final routine = routines[index];
        final preview = routine.exercises
            .take(3)
            .map((e) => e.name)
            .where((s) => s.trim().isNotEmpty)
            .join(', ');
        
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          child: ListTile(
            title: Text(
              routine.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              preview.isEmpty
                  ? '${routine.exercises.length} exercises'
                  : '$preview${routine.exercises.length > 3 ? '...' : ''}',
              style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
            ),
            trailing: FilledButton(
              onPressed: () => onStartRoutine(routine),
              child: const Text('Start'),
            ),
          ),
        );
      },
    );
  }
}

/// Recent exercises history panel
class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.app,
    required this.onSelectExercise,
    required this.onMultiSelect,
  });

  final AppState app;
  final void Function(String) onSelectExercise;
  final void Function() onMultiSelect;

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final recent = <String>[];
    
    for (final session in app.sessions.take(30)) {
      for (final exercise in session.exercises) {
        if (seen.add(exercise.name)) {
          recent.add(exercise.name);
        }
      }
    }
    
    if (recent.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 48, color: Colors.white.withOpacity(0.3)),
              const SizedBox(height: 16),
              const Text(
                'No recent exercises',
                style: TextStyle(color: Color(0x88FFFFFF)),
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      children: [
        // Multi-select button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Spacer(),
              OutlinedButton.icon(
                onPressed: onMultiSelect,
                icon: const Icon(Icons.checklist),
                label: const Text('Multi-select'),
              ),
            ],
          ),
        ),
        
        // Recent exercises list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recent.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final exercise = recent[index];
              final isFavorite = app.isFavoriteExercise(exercise);
              return ListTile(
                dense: true,
                leading: Icon(
                  isFavorite ? Icons.star : Icons.fitness_center,
                  size: 20,
                  color: isFavorite ? const Color(0xFFFFD700) : Colors.white70,
                ),
                title: Text(exercise),
                trailing: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    size: 20,
                    color: isFavorite ? const Color(0xFFFFD700) : Colors.white54,
                  ),
                  onPressed: () => app.toggleFavoriteExercise(exercise),
                ),
                onTap: () => onSelectExercise(exercise),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Multi-select exercises panel
class _MultiSelectPanel extends StatefulWidget {
  const _MultiSelectPanel({
    required this.app,
    required this.onAddSelected,
  });

  final AppState app;
  final void Function(List<String>) onAddSelected;

  @override
  State<_MultiSelectPanel> createState() => _MultiSelectPanelState();
}

class _MultiSelectPanelState extends State<_MultiSelectPanel> {
  final Set<String> _selected = {};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _getExercises() {
    final query = _query.trim().toLowerCase();
    final all = <String>[];
    
    // Add favorites
    for (final fav in widget.app.favoriteExercises) {
      if (query.isEmpty || fav.toLowerCase().contains(query)) {
        all.add(fav);
      }
    }
    
    // Add from database
    final dbResults = query.isEmpty
        ? ExerciseDatabase.getPopular()
        : ExerciseDatabase.search(_query);
    for (final ex in dbResults) {
      if (!all.contains(ex)) all.add(ex);
    }
    
    // Add from recent
    final seen = <String>{};
    for (final session in widget.app.sessions.take(20)) {
      for (final exercise in session.exercises) {
        if (!seen.contains(exercise.name) &&
            (query.isEmpty || exercise.name.toLowerCase().contains(query)) &&
            !all.contains(exercise.name)) {
          all.add(exercise.name);
        }
        seen.add(exercise.name);
      }
    }
    
    return all.take(50).toList();
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _getExercises();
    
    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search exercises...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        
        // Selected count
        if (_selected.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF00D17A).withOpacity(0.1),
            child: Row(
              children: [
                Text(
                  '${_selected.length} selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00D17A),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selected.clear()),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        
        // Exercises list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: exercises.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              final isSelected = _selected.contains(exercise);
              final isFavorite = widget.app.isFavoriteExercise(exercise);
              
              return CheckboxListTile(
                dense: true,
                value: isSelected,
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selected.add(exercise);
                    } else {
                      _selected.remove(exercise);
                    }
                  });
                },
                title: Text(exercise),
                secondary: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    size: 20,
                    color: isFavorite ? const Color(0xFFFFD700) : Colors.white54,
                  ),
                  onPressed: () {
                    widget.app.toggleFavoriteExercise(exercise);
                    setState(() {});
                  },
                ),
              );
            },
          ),
        ),
        
        // Add selected button
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _selected.isEmpty
                ? null
                : () {
                    widget.onAddSelected(_selected.toList());
                  },
            icon: const Icon(Icons.add),
            label: Text('Add ${_selected.length} Exercise${_selected.length != 1 ? 's' : ''}'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00D17A),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
      ],
    );
  }
}
