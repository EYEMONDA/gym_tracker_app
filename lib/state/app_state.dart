import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Root app state.
///
/// - No login: everything is local-only.
/// - Persistence: JSON blob in SharedPreferences.
/// - "Smart encryption ID": a random, non-guessable token stored locally.
class AppState extends ChangeNotifier {
  static const _prefsKeyDb = 'gym_tracker_db_v1';
  static const _prefsKeySmartId = 'gym_tracker_smart_id_v1';

  SharedPreferences? _prefs;
  bool _loaded = false;

  /// Privacy-preserving identifier (random token).
  String? smartId;

  /// Active workout session (not yet saved).
  WorkoutSessionDraft? activeSession;

  /// If the active session was started from a plan, this links it.
  String? activePlannedWorkoutId;

  /// Focus mode: Dynamic Island becomes a quick logger during workouts.
  bool focusModeEnabled = true;

  /// Tap Assist: increases touch targets without changing layout.
  bool tapAssistEnabled = true;

  /// Experimental features live behind toggles.
  bool experimentalMapEnabled = false;

  /// Experimental: Muscle heat map feature.
  bool experimentalHeatMapEnabled = false;

  /// User profile for comparisons (optional).
  UserProfile? userProfile;

  /// User-defined fitness goals with milestones.
  final List<FitnessGoal> fitnessGoals = [];

  /// Unlocked achievement IDs.
  final Set<String> unlockedAchievements = {};

  /// Which exercise is currently “focused” for fast logging.
  int activeExerciseIndex = 0;

  /// Saved sessions.
  final List<WorkoutSession> sessions = [];

  /// Routine templates you can schedule repeatedly.
  final List<RoutineTemplate> routineTemplates = [];

  /// Planned routines on the calendar (can be multiple per day).
  final List<PlannedWorkout> plannedWorkouts = [];

  /// Map routes (experimental).
  final List<MapRoute> mapRoutes = [];

  /// Route usage logs (experimental).
  final List<RouteActivityLog> routeActivityLogs = [];

  /// Weekly goal: number of workouts per week.
  int weeklyWorkoutGoal = 3;

  /// Used to request a tab switch from deep UI actions (e.g. starting a plan).
  int? requestedTabIndex;

  /// Rest timer state, shown in the Dynamic Island.
  RestTimerState restTimer = RestTimerState.idle();

  Timer? _restTicker;

  /// Dynamic Island search.
  String searchQuery = '';
  bool isSearchExpanded = false;

  /// Default rest duration (seconds).
  int defaultRestSeconds = 90;

  /// Basic scheduling preference: preferred training days (Mon..Sun).
  /// 1=Mon ... 7=Sun (DateTime.weekday)
  final Set<int> preferredWeekdays = {1, 3, 5};

  /// Superset mode: auto-cycle to next exercise after logging a set.
  bool supersetModeEnabled = false;

  /// Exercises paired for superset (indices in active session).
  List<int> supersetPairedIndices = [];

  /// Smart rest: auto-adjust rest time based on exercise type.
  bool smartRestEnabled = true;

  /// Rest timer alerts: vibration when timer completes.
  bool restTimerAlertsEnabled = true;

  /// Compound exercises that warrant longer rest times.
  static const compoundExercises = {
    'squat', 'deadlift', 'bench press', 'bench', 'overhead press', 'ohp',
    'barbell row', 'row', 'pull-up', 'pullup', 'chin-up', 'chinup',
    'leg press', 'romanian deadlift', 'rdl', 'hip thrust', 'dip', 'dips',
    'clean', 'snatch', 'front squat', 'back squat', 'military press',
  };

  /// Exercise-to-muscle group mapping for heat map.
  static const exerciseToMuscles = <String, List<MuscleGroup>>{
    // Chest
    'bench press': [MuscleGroup.chest, MuscleGroup.triceps, MuscleGroup.shoulders],
    'bench': [MuscleGroup.chest, MuscleGroup.triceps, MuscleGroup.shoulders],
    'incline press': [MuscleGroup.chest, MuscleGroup.shoulders, MuscleGroup.triceps],
    'incline bench': [MuscleGroup.chest, MuscleGroup.shoulders, MuscleGroup.triceps],
    'decline press': [MuscleGroup.chest, MuscleGroup.triceps],
    'dumbbell press': [MuscleGroup.chest, MuscleGroup.triceps, MuscleGroup.shoulders],
    'chest fly': [MuscleGroup.chest],
    'fly': [MuscleGroup.chest],
    'pec deck': [MuscleGroup.chest],
    'cable crossover': [MuscleGroup.chest],
    'push-up': [MuscleGroup.chest, MuscleGroup.triceps, MuscleGroup.shoulders],
    'pushup': [MuscleGroup.chest, MuscleGroup.triceps, MuscleGroup.shoulders],
    'dip': [MuscleGroup.chest, MuscleGroup.triceps, MuscleGroup.shoulders],
    'dips': [MuscleGroup.chest, MuscleGroup.triceps, MuscleGroup.shoulders],
    
    // Back
    'pull-up': [MuscleGroup.back, MuscleGroup.biceps],
    'pullup': [MuscleGroup.back, MuscleGroup.biceps],
    'chin-up': [MuscleGroup.back, MuscleGroup.biceps],
    'chinup': [MuscleGroup.back, MuscleGroup.biceps],
    'lat pulldown': [MuscleGroup.back, MuscleGroup.biceps],
    'pulldown': [MuscleGroup.back, MuscleGroup.biceps],
    'row': [MuscleGroup.back, MuscleGroup.biceps],
    'barbell row': [MuscleGroup.back, MuscleGroup.biceps],
    'dumbbell row': [MuscleGroup.back, MuscleGroup.biceps],
    'cable row': [MuscleGroup.back, MuscleGroup.biceps],
    'seated row': [MuscleGroup.back, MuscleGroup.biceps],
    't-bar row': [MuscleGroup.back, MuscleGroup.biceps],
    'deadlift': [MuscleGroup.back, MuscleGroup.glutes, MuscleGroup.hamstrings],
    'romanian deadlift': [MuscleGroup.back, MuscleGroup.glutes, MuscleGroup.hamstrings],
    'rdl': [MuscleGroup.back, MuscleGroup.glutes, MuscleGroup.hamstrings],
    'face pull': [MuscleGroup.back, MuscleGroup.shoulders],
    'shrug': [MuscleGroup.back],
    
    // Shoulders
    'overhead press': [MuscleGroup.shoulders, MuscleGroup.triceps],
    'ohp': [MuscleGroup.shoulders, MuscleGroup.triceps],
    'military press': [MuscleGroup.shoulders, MuscleGroup.triceps],
    'shoulder press': [MuscleGroup.shoulders, MuscleGroup.triceps],
    'lateral raise': [MuscleGroup.shoulders],
    'front raise': [MuscleGroup.shoulders],
    'rear delt': [MuscleGroup.shoulders, MuscleGroup.back],
    'arnold press': [MuscleGroup.shoulders, MuscleGroup.triceps],
    'upright row': [MuscleGroup.shoulders, MuscleGroup.back],
    
    // Arms
    'bicep curl': [MuscleGroup.biceps],
    'curl': [MuscleGroup.biceps],
    'hammer curl': [MuscleGroup.biceps],
    'preacher curl': [MuscleGroup.biceps],
    'concentration curl': [MuscleGroup.biceps],
    'tricep extension': [MuscleGroup.triceps],
    'tricep pushdown': [MuscleGroup.triceps],
    'skull crusher': [MuscleGroup.triceps],
    'close grip bench': [MuscleGroup.triceps, MuscleGroup.chest],
    'kickback': [MuscleGroup.triceps],
    
    // Legs
    'squat': [MuscleGroup.quads, MuscleGroup.glutes, MuscleGroup.hamstrings],
    'front squat': [MuscleGroup.quads, MuscleGroup.glutes],
    'back squat': [MuscleGroup.quads, MuscleGroup.glutes, MuscleGroup.hamstrings],
    'leg press': [MuscleGroup.quads, MuscleGroup.glutes],
    'lunge': [MuscleGroup.quads, MuscleGroup.glutes, MuscleGroup.hamstrings],
    'split squat': [MuscleGroup.quads, MuscleGroup.glutes],
    'bulgarian split squat': [MuscleGroup.quads, MuscleGroup.glutes],
    'leg extension': [MuscleGroup.quads],
    'leg curl': [MuscleGroup.hamstrings],
    'hamstring curl': [MuscleGroup.hamstrings],
    'hip thrust': [MuscleGroup.glutes, MuscleGroup.hamstrings],
    'glute bridge': [MuscleGroup.glutes],
    'calf raise': [MuscleGroup.calves],
    'seated calf raise': [MuscleGroup.calves],
    'standing calf raise': [MuscleGroup.calves],
    
    // Core
    'plank': [MuscleGroup.core],
    'crunch': [MuscleGroup.core],
    'sit-up': [MuscleGroup.core],
    'situp': [MuscleGroup.core],
    'leg raise': [MuscleGroup.core],
    'russian twist': [MuscleGroup.core],
    'ab wheel': [MuscleGroup.core],
    'cable crunch': [MuscleGroup.core],
    'hanging leg raise': [MuscleGroup.core],
    'woodchop': [MuscleGroup.core],
    
    // Full body / Olympic
    'clean': [MuscleGroup.back, MuscleGroup.shoulders, MuscleGroup.quads, MuscleGroup.glutes],
    'snatch': [MuscleGroup.back, MuscleGroup.shoulders, MuscleGroup.quads, MuscleGroup.glutes],
    'clean and jerk': [MuscleGroup.back, MuscleGroup.shoulders, MuscleGroup.quads, MuscleGroup.glutes, MuscleGroup.triceps],
    'thruster': [MuscleGroup.quads, MuscleGroup.glutes, MuscleGroup.shoulders, MuscleGroup.triceps],
    'burpee': [MuscleGroup.chest, MuscleGroup.quads, MuscleGroup.core],
  };

  /// Average strength standards by muscle group (1RM as ratio of body weight).
  /// Based on intermediate lifter standards. Format: {gender: {muscleGroup: ratio}}
  static const _strengthStandards = <String, Map<MuscleGroup, double>>{
    'male': {
      MuscleGroup.chest: 1.25,      // Bench press ~1.25x BW
      MuscleGroup.back: 1.5,        // Deadlift contribution
      MuscleGroup.shoulders: 0.75,  // OHP ~0.75x BW
      MuscleGroup.biceps: 0.5,      // Curl ~0.5x BW
      MuscleGroup.triceps: 0.6,     // Close grip bench
      MuscleGroup.quads: 1.5,       // Squat ~1.5x BW
      MuscleGroup.hamstrings: 1.25, // RDL
      MuscleGroup.glutes: 1.75,     // Hip thrust
      MuscleGroup.calves: 1.5,      // Calf raise
      MuscleGroup.core: 0.5,        // Weighted core work
    },
    'female': {
      MuscleGroup.chest: 0.75,
      MuscleGroup.back: 1.0,
      MuscleGroup.shoulders: 0.5,
      MuscleGroup.biceps: 0.35,
      MuscleGroup.triceps: 0.4,
      MuscleGroup.quads: 1.25,
      MuscleGroup.hamstrings: 1.0,
      MuscleGroup.glutes: 1.5,
      MuscleGroup.calves: 1.25,
      MuscleGroup.core: 0.4,
    },
  };

  bool get loaded => _loaded;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    // Clean up legacy keys from the original prototype (single-screen logger).
    // This keeps storage tidy for users who ran older versions of the app.
    await _prefs!.remove('workouts');
    await _prefs!.remove('sessions');
    await _prefs!.remove('isWorkoutActive');
    await _prefs!.remove('startTime');
    await _prefs!.remove('endTime');
    await _prefs!.remove('breakStartTime');

    smartId = _prefs!.getString(_prefsKeySmartId);
    smartId ??= _generateSmartId();
    await _prefs!.setString(_prefsKeySmartId, smartId!);

    final raw = _prefs!.getString(_prefsKeyDb);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, Object?>;
        final db = AppDb.fromJson(decoded);
        sessions
          ..clear()
          ..addAll(db.sessions);
        routineTemplates
          ..clear()
          ..addAll(db.routineTemplates);
        plannedWorkouts
          ..clear()
          ..addAll(db.plannedWorkouts);
        defaultRestSeconds = db.defaultRestSeconds;
        focusModeEnabled = db.focusModeEnabled;
        tapAssistEnabled = db.tapAssistEnabled;
        experimentalMapEnabled = db.experimentalMapEnabled;
        weeklyWorkoutGoal = db.weeklyWorkoutGoal;
        preferredWeekdays
          ..clear()
          ..addAll(db.preferredWeekdays);

        mapRoutes
          ..clear()
          ..addAll(db.mapRoutes);
        routeActivityLogs
          ..clear()
          ..addAll(db.routeActivityLogs);
        supersetModeEnabled = db.supersetModeEnabled;
        smartRestEnabled = db.smartRestEnabled;
        restTimerAlertsEnabled = db.restTimerAlertsEnabled;
        experimentalHeatMapEnabled = db.experimentalHeatMapEnabled;
        userProfile = db.userProfile;
        fitnessGoals
          ..clear()
          ..addAll(db.fitnessGoals);
        unlockedAchievements
          ..clear()
          ..addAll(db.unlockedAchievements);
      } catch (_) {
        // If the DB is corrupt, keep the app usable.
      }
    }

    // Seed defaults if the app is brand new.
    if (routineTemplates.isEmpty) {
      routineTemplates.addAll(_defaultTemplates());
    }

    _loaded = true;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final db = AppDb(
      sessions: sessions,
      routineTemplates: routineTemplates,
      plannedWorkouts: plannedWorkouts,
      defaultRestSeconds: defaultRestSeconds,
      focusModeEnabled: focusModeEnabled,
      tapAssistEnabled: tapAssistEnabled,
      experimentalMapEnabled: experimentalMapEnabled,
      weeklyWorkoutGoal: weeklyWorkoutGoal,
      preferredWeekdays: preferredWeekdays.toList()..sort(),
      mapRoutes: mapRoutes,
      routeActivityLogs: routeActivityLogs,
      supersetModeEnabled: supersetModeEnabled,
      smartRestEnabled: smartRestEnabled,
      restTimerAlertsEnabled: restTimerAlertsEnabled,
      experimentalHeatMapEnabled: experimentalHeatMapEnabled,
      userProfile: userProfile,
      fitnessGoals: fitnessGoals,
      unlockedAchievements: unlockedAchievements,
    );
    await prefs.setString(_prefsKeyDb, jsonEncode(db.toJson()));
  }

  String _generateSmartId() {
    // 18 bytes => 24 chars base64url-ish after encoding without padding.
    final r = Random.secure();
    final bytes = List<int>.generate(18, (_) => r.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  // ---------------------------
  // Workout lifecycle
  // ---------------------------

  void startWorkout({String? title}) {
    activeSession = WorkoutSessionDraft(
      id: _newId(),
      startedAt: DateTime.now(),
      title: title?.trim().isEmpty ?? true ? 'Workout' : title!.trim(),
    );
    activeExerciseIndex = 0;
    activePlannedWorkoutId = null;
    notifyListeners();
  }

  Future<void> endWorkoutAndSave() async {
    final draft = activeSession;
    if (draft == null) return;
    final endedAt = DateTime.now();
    final sessionId = draft.id;
    sessions.insert(
      0,
      WorkoutSession(
        id: draft.id,
        title: draft.title,
        startedAt: draft.startedAt,
        endedAt: endedAt,
        exercises: draft.exercises.map((e) => e.toFinal()).toList(),
        notes: draft.notes.trim().isEmpty ? null : draft.notes.trim(),
      ),
    );
    if (activePlannedWorkoutId != null) {
      final planId = activePlannedWorkoutId!;
      final idx = plannedWorkouts.indexWhere((p) => p.id == planId);
      if (idx != -1) {
        plannedWorkouts[idx] = plannedWorkouts[idx].copyWith(
          status: PlannedWorkoutStatus.done,
          completedSessionId: sessionId,
        );
      }
    }
    activeSession = null;
    activePlannedWorkoutId = null;
    stopRestTimer();
    await _persist();
    // Check for newly unlocked achievements
    checkAndUnlockAchievements();
    notifyListeners();
  }

  void discardActiveWorkout() {
    activeSession = null;
    activePlannedWorkoutId = null;
    stopRestTimer();
    activeExerciseIndex = 0;
    notifyListeners();
  }

  void addExerciseToActive(String name) {
    final draft = activeSession;
    if (draft == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    draft.exercises.add(ExerciseDraft(name: trimmed));
    activeExerciseIndex = draft.exercises.length - 1;
    notifyListeners();
  }

  void addSetToExercise(int exerciseIndex,
      {int reps = 10, double weight = 0, String? unit, double? rpe}) {
    final draft = activeSession;
    if (draft == null) return;
    if (exerciseIndex < 0 || exerciseIndex >= draft.exercises.length) return;
    draft.exercises[exerciseIndex].sets.add(
          ExerciseSet(reps: reps, weight: weight, unit: unit ?? 'kg', rpe: rpe),
        );
    activeExerciseIndex = exerciseIndex;
    notifyListeners();
  }

  void removeExerciseFromActive(int exerciseIndex) {
    final draft = activeSession;
    if (draft == null) return;
    if (exerciseIndex < 0 || exerciseIndex >= draft.exercises.length) return;
    draft.exercises.removeAt(exerciseIndex);
    if (draft.exercises.isEmpty) {
      activeExerciseIndex = 0;
    } else if (activeExerciseIndex >= draft.exercises.length) {
      activeExerciseIndex = draft.exercises.length - 1;
    } else if (exerciseIndex <= activeExerciseIndex && activeExerciseIndex > 0) {
      activeExerciseIndex -= 1;
    }
    notifyListeners();
  }

  void removeSetFromExercise(int exerciseIndex, int setIndex) {
    final draft = activeSession;
    if (draft == null) return;
    if (exerciseIndex < 0 || exerciseIndex >= draft.exercises.length) return;
    final ex = draft.exercises[exerciseIndex];
    if (setIndex < 0 || setIndex >= ex.sets.length) return;
    ex.sets.removeAt(setIndex);
    activeExerciseIndex = exerciseIndex;
    notifyListeners();
  }

  // ---------------------------
  // Rest timer
  // ---------------------------

  void startRestTimer({int? seconds}) {
    final s = seconds ?? defaultRestSeconds;
    final end = DateTime.now().add(Duration(seconds: s));
    restTimer = RestTimerState.running(
      startedAt: DateTime.now(),
      endsAt: end,
    );
    _restTicker?.cancel();
    _restTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final state = restTimer;
      if (!state.isRunning) return;
      if (DateTime.now().isAfter(state.endsAt!)) {
        stopRestTimer();
        restTimer = RestTimerState.done(lastDurationSeconds: s);
        // Vibration alert when timer completes
        if (restTimerAlertsEnabled) {
          HapticFeedback.heavyImpact();
          // Double vibration for stronger alert
          Future.delayed(const Duration(milliseconds: 200), () {
            HapticFeedback.heavyImpact();
          });
        }
        notifyListeners();
      } else {
        // tick
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void stopRestTimer() {
    _restTicker?.cancel();
    _restTicker = null;
    restTimer = RestTimerState.idle();
    notifyListeners();
  }

  // ---------------------------
  // UI actions
  // ---------------------------

  void setSearchExpanded(bool expanded) {
    if (isSearchExpanded == expanded) return;
    isSearchExpanded = expanded;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    searchQuery = q;
    notifyListeners();
  }

  Future<void> setFocusModeEnabled(bool enabled) async {
    if (focusModeEnabled == enabled) return;
    focusModeEnabled = enabled;
    await _persist();
    notifyListeners();
  }

  Future<void> setTapAssistEnabled(bool enabled) async {
    if (tapAssistEnabled == enabled) return;
    tapAssistEnabled = enabled;
    await _persist();
    notifyListeners();
  }

  Future<void> setExperimentalMapEnabled(bool enabled) async {
    if (experimentalMapEnabled == enabled) return;
    experimentalMapEnabled = enabled;
    await _persist();
    notifyListeners();
  }

  Future<void> setExperimentalHeatMapEnabled(bool enabled) async {
    if (experimentalHeatMapEnabled == enabled) return;
    experimentalHeatMapEnabled = enabled;
    await _persist();
    notifyListeners();
  }

  Future<void> setUserProfile(UserProfile? profile) async {
    userProfile = profile;
    await _persist();
    notifyListeners();
  }

  // ---------------------------
  // Fitness Goals
  // ---------------------------

  Future<void> addFitnessGoal(FitnessGoal goal) async {
    fitnessGoals.add(goal);
    await _persist();
    notifyListeners();
  }

  Future<void> updateFitnessGoal(String goalId, FitnessGoal updated) async {
    final idx = fitnessGoals.indexWhere((g) => g.id == goalId);
    if (idx == -1) return;
    fitnessGoals[idx] = updated;
    await _persist();
    notifyListeners();
  }

  Future<void> removeFitnessGoal(String goalId) async {
    fitnessGoals.removeWhere((g) => g.id == goalId);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleMilestoneComplete(String goalId, int milestoneIndex) async {
    final idx = fitnessGoals.indexWhere((g) => g.id == goalId);
    if (idx == -1) return;
    final goal = fitnessGoals[idx];
    if (milestoneIndex < 0 || milestoneIndex >= goal.milestones.length) return;
    
    final milestone = goal.milestones[milestoneIndex];
    final updatedMilestone = milestone.copyWith(
      isCompleted: !milestone.isCompleted,
      completedAt: !milestone.isCompleted ? DateTime.now() : null,
    );
    
    final updatedMilestones = List<GoalMilestone>.from(goal.milestones);
    updatedMilestones[milestoneIndex] = updatedMilestone;
    
    fitnessGoals[idx] = goal.copyWith(milestones: updatedMilestones);
    await _persist();
    notifyListeners();
  }

  /// Get progress percentage for a goal (0.0 - 1.0).
  double getGoalProgress(FitnessGoal goal) {
    if (goal.milestones.isEmpty) return 0.0;
    final completed = goal.milestones.where((m) => m.isCompleted).length;
    return completed / goal.milestones.length;
  }

  /// Get all active (non-completed) goals.
  List<FitnessGoal> get activeGoals => 
      fitnessGoals.where((g) => getGoalProgress(g) < 1.0).toList();

  /// Get all completed goals.
  List<FitnessGoal> get completedGoals => 
      fitnessGoals.where((g) => getGoalProgress(g) >= 1.0).toList();

  // ---------------------------
  // Achievements
  // ---------------------------

  /// All available achievements.
  static const achievements = <Achievement>[
    Achievement(
      id: 'first_workout',
      title: 'First Workout',
      description: 'Complete your first workout session',
      iconCodePoint: 0xe1e1, // fitness_center
    ),
    Achievement(
      id: 'week_warrior',
      title: 'Week Warrior',
      description: 'Work out 3 times in a single week',
      iconCodePoint: 0xe614, // event_repeat
    ),
    Achievement(
      id: 'streak_master',
      title: 'Streak Master',
      description: 'Maintain a 7-day workout streak',
      iconCodePoint: 0xe518, // local_fire_department
    ),
    Achievement(
      id: 'century_club',
      title: 'Century Club',
      description: 'Log 100 total sets',
      iconCodePoint: 0xe3f4, // looks_one
    ),
    Achievement(
      id: 'heavy_lifter',
      title: 'Heavy Lifter',
      description: 'Lift 100kg (220lb) or more on any exercise',
      iconCodePoint: 0xe1e1, // fitness_center
    ),
    Achievement(
      id: 'goal_getter',
      title: 'Goal Getter',
      description: 'Complete your first fitness goal',
      iconCodePoint: 0xe153, // flag
    ),
    Achievement(
      id: 'consistency_king',
      title: 'Consistency King',
      description: 'Work out for 4 consecutive weeks',
      iconCodePoint: 0xe99a, // emoji_events
    ),
    Achievement(
      id: 'pr_hunter',
      title: 'PR Hunter',
      description: 'Set 5 personal records',
      iconCodePoint: 0xe8e5, // trending_up
    ),
    Achievement(
      id: 'early_bird',
      title: 'Early Bird',
      description: 'Complete a workout before 7 AM',
      iconCodePoint: 0xe81a, // wb_sunny
    ),
    Achievement(
      id: 'night_owl',
      title: 'Night Owl',
      description: 'Complete a workout after 9 PM',
      iconCodePoint: 0xe51c, // nights_stay
    ),
    Achievement(
      id: 'volume_king',
      title: 'Volume King',
      description: 'Log 50 sets in a single week',
      iconCodePoint: 0xe6e1, // bar_chart
    ),
    Achievement(
      id: 'dedicated',
      title: 'Dedicated',
      description: 'Complete 25 workout sessions',
      iconCodePoint: 0xea23, // workspace_premium
    ),
  ];

  /// Check if an achievement is unlocked.
  bool isAchievementUnlocked(String achievementId) {
    return unlockedAchievements.contains(achievementId);
  }

  /// Check and unlock any newly earned achievements.
  Future<List<Achievement>> checkAndUnlockAchievements() async {
    final newlyUnlocked = <Achievement>[];

    for (final achievement in achievements) {
      if (unlockedAchievements.contains(achievement.id)) continue;

      final earned = _checkAchievementCondition(achievement.id);
      if (earned) {
        unlockedAchievements.add(achievement.id);
        newlyUnlocked.add(achievement);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      await _persist();
      notifyListeners();
    }

    return newlyUnlocked;
  }

  bool _checkAchievementCondition(String id) {
    switch (id) {
      case 'first_workout':
        return sessions.isNotEmpty;

      case 'week_warrior':
        return workoutsThisWeek >= 3;

      case 'streak_master':
        return currentStreak >= 7;

      case 'century_club':
        final totalSets = sessions.fold<int>(
          0,
          (sum, s) => sum + s.exercises.fold<int>(0, (eSum, e) => eSum + e.sets.length),
        );
        return totalSets >= 100;

      case 'heavy_lifter':
        for (final session in sessions) {
          for (final exercise in session.exercises) {
            for (final set in exercise.sets) {
              if (set.weight >= 100 && set.unit == 'kg') return true;
              if (set.weight >= 220 && set.unit == 'lb') return true;
            }
          }
        }
        return false;

      case 'goal_getter':
        return completedGoals.isNotEmpty;

      case 'consistency_king':
        // Check if worked out at least once per week for 4 weeks
        if (sessions.length < 4) return false;
        final now = DateTime.now();
        int consecutiveWeeks = 0;
        for (int w = 0; w < 8; w++) {
          final weekStart = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: now.weekday - 1 + (w * 7)));
          final weekEnd = weekStart.add(const Duration(days: 7));
          final hasWorkout = sessions.any((s) =>
              !s.startedAt.isBefore(weekStart) && s.startedAt.isBefore(weekEnd));
          if (hasWorkout) {
            consecutiveWeeks++;
          } else if (w > 0) {
            break;
          }
        }
        return consecutiveWeeks >= 4;

      case 'pr_hunter':
        // Count unique exercises with PRs
        final prs = <String>{};
        final bestByExercise = <String, double>{};
        for (final session in sessions) {
          for (final exercise in session.exercises) {
            final name = exercise.name.toLowerCase();
            for (final set in exercise.sets) {
              if (set.weight <= 0 || set.reps <= 0) continue;
              final est1rm = set.weight * (1 + set.reps / 30.0);
              if (est1rm > (bestByExercise[name] ?? 0)) {
                if (bestByExercise.containsKey(name)) {
                  prs.add(name);
                }
                bestByExercise[name] = est1rm;
              }
            }
          }
        }
        return prs.length >= 5;

      case 'early_bird':
        return sessions.any((s) => s.startedAt.hour < 7);

      case 'night_owl':
        return sessions.any((s) => s.endedAt.hour >= 21);

      case 'volume_king':
        final now = DateTime.now();
        final weekStart = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        int setsThisWeek = 0;
        for (final session in sessions) {
          if (!session.startedAt.isBefore(weekStart)) {
            setsThisWeek += session.exercises.fold<int>(
              0,
              (sum, e) => sum + e.sets.length,
            );
          }
        }
        return setsThisWeek >= 50;

      case 'dedicated':
        return sessions.length >= 25;

      default:
        return false;
    }
  }

  /// Get achievement progress (0.0 to 1.0) for display.
  double getAchievementProgress(String id) {
    if (unlockedAchievements.contains(id)) return 1.0;

    switch (id) {
      case 'first_workout':
        return sessions.isEmpty ? 0.0 : 1.0;

      case 'week_warrior':
        return (workoutsThisWeek / 3.0).clamp(0.0, 1.0);

      case 'streak_master':
        return (currentStreak / 7.0).clamp(0.0, 1.0);

      case 'century_club':
        final totalSets = sessions.fold<int>(
          0,
          (sum, s) => sum + s.exercises.fold<int>(0, (eSum, e) => eSum + e.sets.length),
        );
        return (totalSets / 100.0).clamp(0.0, 1.0);

      case 'heavy_lifter':
        double maxWeight = 0;
        for (final session in sessions) {
          for (final exercise in session.exercises) {
            for (final set in exercise.sets) {
              final weightKg = set.unit == 'lb' ? set.weight * 0.453592 : set.weight;
              if (weightKg > maxWeight) maxWeight = weightKg;
            }
          }
        }
        return (maxWeight / 100.0).clamp(0.0, 1.0);

      case 'goal_getter':
        if (fitnessGoals.isEmpty) return 0.0;
        final bestProgress = fitnessGoals
            .map((g) => getGoalProgress(g))
            .reduce((a, b) => a > b ? a : b);
        return bestProgress;

      case 'dedicated':
        return (sessions.length / 25.0).clamp(0.0, 1.0);

      default:
        return 0.0;
    }
  }

  /// Get muscle groups targeted by an exercise name.
  List<MuscleGroup> getMuscleGroups(String exerciseName) {
    final lower = exerciseName.trim().toLowerCase();
    // Direct match
    if (exerciseToMuscles.containsKey(lower)) {
      return exerciseToMuscles[lower]!;
    }
    // Partial match
    for (final entry in exerciseToMuscles.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        return entry.value;
      }
    }
    return [];
  }

  /// Calculate muscle fatigue/training intensity for each muscle group.
  /// Returns a map of muscle group to intensity (0.0 - 1.0+).
  /// Looks at workouts from the past [days] days.
  Map<MuscleGroup, MuscleHeatData> getMuscleHeatMap({int days = 7}) {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    
    // Collect volume per muscle group
    final volumeByMuscle = <MuscleGroup, double>{};
    final setsByMuscle = <MuscleGroup, int>{};
    final bestWeightByMuscle = <MuscleGroup, double>{};
    final lastWorkedByMuscle = <MuscleGroup, DateTime>{};
    
    for (final session in sessions) {
      if (session.startedAt.isBefore(cutoff)) continue;
      
      for (final exercise in session.exercises) {
        final muscles = getMuscleGroups(exercise.name);
        if (muscles.isEmpty) continue;
        
        for (final set in exercise.sets) {
          if (set.reps <= 0) continue;
          // Volume = weight * reps (or just reps for bodyweight)
          final volume = set.weight > 0 ? set.weight * set.reps : set.reps * 10.0;
          
          for (final muscle in muscles) {
            // Primary muscle gets full credit, secondary muscles get partial
            final isPrimary = muscle == muscles.first;
            final credit = isPrimary ? 1.0 : 0.5;
            
            volumeByMuscle[muscle] = (volumeByMuscle[muscle] ?? 0) + volume * credit;
            setsByMuscle[muscle] = (setsByMuscle[muscle] ?? 0) + 1;
            
            if (set.weight > (bestWeightByMuscle[muscle] ?? 0)) {
              bestWeightByMuscle[muscle] = set.weight;
            }
            
            final sessionDate = session.startedAt;
            if (lastWorkedByMuscle[muscle] == null || 
                sessionDate.isAfter(lastWorkedByMuscle[muscle]!)) {
              lastWorkedByMuscle[muscle] = sessionDate;
            }
          }
        }
      }
    }
    
    // Calculate intensity relative to expected weekly volume
    // Baseline: ~10 sets per muscle group per week is moderate
    const baselineSetsPerWeek = 10.0;
    final result = <MuscleGroup, MuscleHeatData>{};
    
    for (final muscle in MuscleGroup.values) {
      final sets = setsByMuscle[muscle] ?? 0;
      final volume = volumeByMuscle[muscle] ?? 0;
      final bestWeight = bestWeightByMuscle[muscle] ?? 0;
      final lastWorked = lastWorkedByMuscle[muscle];
      
      // Intensity based on sets (0.0 = no work, 1.0 = baseline, 2.0 = double baseline)
      final setsIntensity = sets / baselineSetsPerWeek;
      
      // Fatigue decay: muscles recover ~50% per day
      double fatigue = 0;
      if (lastWorked != null) {
        final daysSinceWorked = now.difference(lastWorked).inHours / 24.0;
        final recoveryFactor = (daysSinceWorked / 2.0).clamp(0.0, 1.0); // Full recovery in ~2 days
        fatigue = setsIntensity * (1.0 - recoveryFactor);
      }
      
      result[muscle] = MuscleHeatData(
        muscle: muscle,
        volume: volume,
        sets: sets,
        intensity: setsIntensity.clamp(0.0, 2.0),
        fatigue: fatigue.clamp(0.0, 1.0),
        bestWeight: bestWeight,
        lastWorked: lastWorked,
      );
    }
    
    return result;
  }

  /// Compare user's strength to average person of similar profile.
  /// Returns a map of muscle group to performance ratio (1.0 = average).
  Map<MuscleGroup, double> getStrengthComparison() {
    final profile = userProfile;
    if (profile == null) return {};
    
    final standards = _strengthStandards[profile.gender] ?? _strengthStandards['male']!;
    final bodyWeight = profile.weightKg;
    if (bodyWeight <= 0) return {};
    
    // Age adjustment: peak strength around 25-35, decline ~1% per year after 40
    double ageMultiplier = 1.0;
    if (profile.age > 40) {
      ageMultiplier = 1.0 - ((profile.age - 40) * 0.01);
    } else if (profile.age < 20) {
      ageMultiplier = 0.8 + ((profile.age - 15) * 0.04);
    }
    ageMultiplier = ageMultiplier.clamp(0.5, 1.1);
    
    // Find best lifts for each muscle group from all sessions
    final bestByMuscle = <MuscleGroup, double>{};
    for (final session in sessions) {
      for (final exercise in session.exercises) {
        final muscles = getMuscleGroups(exercise.name);
        if (muscles.isEmpty) continue;
        
        for (final set in exercise.sets) {
          if (set.weight <= 0 || set.reps <= 0) continue;
          // Estimate 1RM using Epley formula
          final est1rm = set.weight * (1.0 + set.reps / 30.0);
          
          for (final muscle in muscles) {
            if (est1rm > (bestByMuscle[muscle] ?? 0)) {
              bestByMuscle[muscle] = est1rm;
            }
          }
        }
      }
    }
    
    // Compare to standards
    final result = <MuscleGroup, double>{};
    for (final muscle in MuscleGroup.values) {
      final standard = standards[muscle];
      if (standard == null) continue;
      
      final expectedStrength = bodyWeight * standard * ageMultiplier;
      final actual = bestByMuscle[muscle] ?? 0;
      
      if (expectedStrength > 0) {
        result[muscle] = actual / expectedStrength;
      } else {
        result[muscle] = 0;
      }
    }
    
    return result;
  }

  /// Check if a muscle group is fatigued (worked recently).
  /// Useful for suggesting modifications to workout plans.
  bool isMuscleGroupFatigued(MuscleGroup muscle, {double threshold = 0.5}) {
    final heatMap = getMuscleHeatMap(days: 3);
    final data = heatMap[muscle];
    return data != null && data.fatigue >= threshold;
  }

  /// Get suggestions for workout based on muscle fatigue.
  List<String> getWorkoutSuggestions() {
    final suggestions = <String>[];
    final heatMap = getMuscleHeatMap(days: 3);
    
    // Check for fatigued push muscles
    final chestFatigue = heatMap[MuscleGroup.chest]?.fatigue ?? 0;
    final shoulderFatigue = heatMap[MuscleGroup.shoulders]?.fatigue ?? 0;
    final tricepsFatigue = heatMap[MuscleGroup.triceps]?.fatigue ?? 0;
    
    if (chestFatigue > 0.6 || shoulderFatigue > 0.6) {
      suggestions.add('Push muscles are fatigued. Consider a pull or leg day instead.');
    }
    
    // Check for fatigued pull muscles
    final backFatigue = heatMap[MuscleGroup.back]?.fatigue ?? 0;
    final bicepsFatigue = heatMap[MuscleGroup.biceps]?.fatigue ?? 0;
    
    if (backFatigue > 0.6 || bicepsFatigue > 0.6) {
      suggestions.add('Pull muscles are fatigued. Consider a push or leg day instead.');
    }
    
    // Check for fatigued legs
    final quadsFatigue = heatMap[MuscleGroup.quads]?.fatigue ?? 0;
    final hamstringsFatigue = heatMap[MuscleGroup.hamstrings]?.fatigue ?? 0;
    final glutesFatigue = heatMap[MuscleGroup.glutes]?.fatigue ?? 0;
    
    if (quadsFatigue > 0.6 || hamstringsFatigue > 0.6 || glutesFatigue > 0.6) {
      suggestions.add('Legs are fatigued. Consider an upper body day.');
    }
    
    // Check for neglected muscle groups (no work in 7 days)
    for (final entry in heatMap.entries) {
      if (entry.value.sets == 0) {
        suggestions.add('${entry.key.displayName} hasn\'t been trained this week.');
      }
    }
    
    if (suggestions.isEmpty) {
      suggestions.add('All muscle groups are balanced. Keep up the good work!');
    }
    
    return suggestions;
  }

  Future<void> setWeeklyWorkoutGoal(int goal) async {
    weeklyWorkoutGoal = goal.clamp(1, 14);
    await _persist();
    notifyListeners();
  }

  void setActiveExerciseIndex(int index) {
    final draft = activeSession;
    if (draft == null) return;
    if (draft.exercises.isEmpty) return;
    final clamped = index.clamp(0, draft.exercises.length - 1);
    if (activeExerciseIndex == clamped) return;
    activeExerciseIndex = clamped;
    notifyListeners();
  }

  /// One-tap logging: adds a set to the active exercise using last-set defaults.
  ///
  /// Returns info to support an "Undo" action.
  /// If superset mode is enabled, auto-cycles to next paired exercise.
  /// If [startSmartRest] is true and smart rest is enabled, auto-starts the rest timer.
  QuickSetAdded? addQuickSetToActive({bool startSmartRest = false}) {
    final draft = activeSession;
    if (draft == null) return null;
    if (draft.exercises.isEmpty) return null;

    final exIndex = activeExerciseIndex.clamp(0, draft.exercises.length - 1);
    final ex = draft.exercises[exIndex];

    final last = ex.sets.isEmpty ? null : ex.sets.last;
    final next = ExerciseSet(
      reps: (last?.reps ?? 10).clamp(1, 999),
      weight: last?.weight ?? 0,
      unit: last?.unit ?? 'kg',
      rpe: last?.rpe,
    );
    ex.sets.add(next);

    final added = QuickSetAdded(exerciseIndex: exIndex, setIndex: ex.sets.length - 1);

    // Auto-cycle in superset mode
    if (supersetModeEnabled && supersetPairedIndices.length >= 2) {
      final currentPosInSuperset = supersetPairedIndices.indexOf(exIndex);
      if (currentPosInSuperset != -1) {
        final nextPosInSuperset = (currentPosInSuperset + 1) % supersetPairedIndices.length;
        activeExerciseIndex = supersetPairedIndices[nextPosInSuperset];
      }
    }

    // Auto-start smart rest timer if requested
    if (startSmartRest && smartRestEnabled) {
      startRestTimer(seconds: getSmartRestSeconds(ex.name));
    }

    notifyListeners();
    return added;
  }

  bool undoQuickSet(QuickSetAdded added) {
    final draft = activeSession;
    if (draft == null) return false;
    if (added.exerciseIndex < 0 || added.exerciseIndex >= draft.exercises.length) return false;
    final ex = draft.exercises[added.exerciseIndex];
    if (added.setIndex < 0 || added.setIndex >= ex.sets.length) return false;
    ex.sets.removeAt(added.setIndex);
    notifyListeners();
    return true;
  }

  Future<void> setDefaultRestSeconds(int seconds) async {
    defaultRestSeconds = seconds.clamp(10, 600);
    await _persist();
    notifyListeners();
  }

  Future<void> setSupersetModeEnabled(bool enabled) async {
    if (supersetModeEnabled == enabled) return;
    supersetModeEnabled = enabled;
    if (!enabled) supersetPairedIndices = [];
    await _persist();
    notifyListeners();
  }

  Future<void> setSmartRestEnabled(bool enabled) async {
    if (smartRestEnabled == enabled) return;
    smartRestEnabled = enabled;
    await _persist();
    notifyListeners();
  }

  Future<void> setRestTimerAlertsEnabled(bool enabled) async {
    if (restTimerAlertsEnabled == enabled) return;
    restTimerAlertsEnabled = enabled;
    await _persist();
    notifyListeners();
  }

  /// Toggle an exercise index in/out of the superset pair list.
  void toggleSupersetExercise(int index) {
    if (supersetPairedIndices.contains(index)) {
      supersetPairedIndices.remove(index);
    } else {
      supersetPairedIndices.add(index);
    }
    notifyListeners();
  }

  /// Check if an exercise name is a compound lift (warrants longer rest).
  bool isCompoundExercise(String name) {
    final lower = name.trim().toLowerCase();
    return compoundExercises.any((c) => lower.contains(c));
  }

  /// Get smart rest duration based on exercise type.
  int getSmartRestSeconds(String exerciseName) {
    if (!smartRestEnabled) return defaultRestSeconds;
    return isCompoundExercise(exerciseName) ? 150 : 75; // 2.5min vs 1.25min
  }

  /// Calculate current workout streak (consecutive days with workouts).
  int get currentStreak {
    if (sessions.isEmpty) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Get unique workout days, sorted descending
    final workoutDays = sessions
        .map((s) => DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    
    if (workoutDays.isEmpty) return 0;
    
    // Check if most recent workout was today or yesterday
    final mostRecent = workoutDays.first;
    final daysSinceLast = today.difference(mostRecent).inDays;
    if (daysSinceLast > 1) return 0; // Streak broken
    
    int streak = 1;
    for (int i = 1; i < workoutDays.length; i++) {
      final prev = workoutDays[i - 1];
      final curr = workoutDays[i];
      final gap = prev.difference(curr).inDays;
      if (gap == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Get workouts this week count.
  int get workoutsThisWeek {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return sessions.where((s) => !s.startedAt.isBefore(startOfWeek)).length;
  }

  /// Check if user should be nudged to increase weight for an exercise.
  /// Returns suggested weight increase if ready, null otherwise.
  ProgressiveOverloadSuggestion? getProgressiveOverloadSuggestion(String exerciseName) {
    final name = exerciseName.trim().toLowerCase();
    if (name.isEmpty) return null;
    
    // Look at last 2 sessions with this exercise
    final relevantSessions = sessions
        .where((s) => s.exercises.any((e) => e.name.toLowerCase() == name))
        .take(2)
        .toList();
    
    if (relevantSessions.isEmpty) return null;
    
    final lastSession = relevantSessions.first;
    final exercise = lastSession.exercises.firstWhere(
      (e) => e.name.toLowerCase() == name,
    );
    
    if (exercise.sets.isEmpty) return null;
    
    // Check if user completed 3+ sets at same weight with good reps (8+)
    final workingSets = exercise.sets.where((s) => s.weight > 0).toList();
    if (workingSets.length < 3) return null;
    
    final weight = workingSets.first.weight;
    final unit = workingSets.first.unit;
    final allSameWeight = workingSets.every((s) => s.weight == weight);
    final allGoodReps = workingSets.every((s) => s.reps >= 8);
    
    if (allSameWeight && allGoodReps) {
      final increment = unit == 'lb' ? 5.0 : 2.5;
      return ProgressiveOverloadSuggestion(
        currentWeight: weight,
        suggestedWeight: weight + increment,
        unit: unit,
        reason: '${workingSets.length} sets × ${workingSets.first.reps}+ reps achieved',
      );
    }
    
    return null;
  }

  /// Generate warm-up sets based on working weight.
  List<ExerciseSet> generateWarmupSets(double workingWeight, String unit) {
    if (workingWeight <= 0) return [];
    return [
      ExerciseSet(reps: 10, weight: (workingWeight * 0.5).roundToDouble(), unit: unit, rpe: null),
      ExerciseSet(reps: 5, weight: (workingWeight * 0.7).roundToDouble(), unit: unit, rpe: null),
      ExerciseSet(reps: 3, weight: (workingWeight * 0.85).roundToDouble(), unit: unit, rpe: null),
    ];
  }

  /// Add warm-up sets to an exercise.
  void addWarmupSetsToExercise(int exerciseIndex, double workingWeight, String unit) {
    final draft = activeSession;
    if (draft == null) return;
    if (exerciseIndex < 0 || exerciseIndex >= draft.exercises.length) return;
    
    final warmups = generateWarmupSets(workingWeight, unit);
    for (final set in warmups) {
      draft.exercises[exerciseIndex].sets.add(set);
    }
    activeExerciseIndex = exerciseIndex;
    notifyListeners();
  }

  Future<void> togglePreferredWeekday(int weekday) async {
    if (preferredWeekdays.contains(weekday)) {
      preferredWeekdays.remove(weekday);
    } else {
      preferredWeekdays.add(weekday);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> clearLocalData({bool regenerateSmartId = false}) async {
    sessions.clear();
    activeSession = null;
    activePlannedWorkoutId = null;
    stopRestTimer();
    searchQuery = '';
    isSearchExpanded = false;
    focusModeEnabled = true;
    tapAssistEnabled = true;
    experimentalMapEnabled = false;
    experimentalHeatMapEnabled = false;
    supersetModeEnabled = false;
    smartRestEnabled = true;
    restTimerAlertsEnabled = true;
    supersetPairedIndices = [];
    activeExerciseIndex = 0;
    defaultRestSeconds = 90;
    weeklyWorkoutGoal = 3;
    userProfile = null;
    fitnessGoals.clear();
    unlockedAchievements.clear();
    routineTemplates
      ..clear()
      ..addAll(_defaultTemplates());
    plannedWorkouts.clear();
    mapRoutes.clear();
    routeActivityLogs.clear();
    preferredWeekdays
      ..clear()
      ..addAll({1, 3, 5});

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyDb);
    if (regenerateSmartId) {
      smartId = _generateSmartId();
      await prefs.setString(_prefsKeySmartId, smartId!);
    }

    await _persist();
    notifyListeners();
  }

  // ---------------------------
  // Routines / Planning
  // ---------------------------

  List<RoutineTemplate> _defaultTemplates() {
    return const [
      RoutineTemplate(
        id: 'tpl_full_body',
        name: 'Full Body',
        category: RoutineCategory.strength,
        exercises: [
          RoutineExerciseTemplate(name: 'Squat'),
          RoutineExerciseTemplate(name: 'Bench Press'),
          RoutineExerciseTemplate(name: 'Row'),
          RoutineExerciseTemplate(name: 'Overhead Press'),
        ],
      ),
      RoutineTemplate(
        id: 'tpl_upper',
        name: 'Upper',
        category: RoutineCategory.strength,
        exercises: [
          RoutineExerciseTemplate(name: 'Bench Press'),
          RoutineExerciseTemplate(name: 'Pull-up / Lat Pulldown'),
          RoutineExerciseTemplate(name: 'Incline Press'),
          RoutineExerciseTemplate(name: 'Row'),
        ],
      ),
      RoutineTemplate(
        id: 'tpl_lower',
        name: 'Lower',
        category: RoutineCategory.strength,
        exercises: [
          RoutineExerciseTemplate(name: 'Squat'),
          RoutineExerciseTemplate(name: 'RDL / Deadlift'),
          RoutineExerciseTemplate(name: 'Leg Press'),
          RoutineExerciseTemplate(name: 'Calf Raise'),
        ],
      ),
      RoutineTemplate(
        id: 'tpl_cardio',
        name: 'Cardio',
        category: RoutineCategory.cardio,
        exercises: [
          RoutineExerciseTemplate(name: 'Run / Bike / Row'),
          RoutineExerciseTemplate(name: 'Zone 2 (20–40m)'),
        ],
      ),
      RoutineTemplate(
        id: 'tpl_mobility',
        name: 'Mobility',
        category: RoutineCategory.mobility,
        exercises: [
          RoutineExerciseTemplate(name: 'Warm-up'),
          RoutineExerciseTemplate(name: 'Stretching'),
          RoutineExerciseTemplate(name: 'Core'),
        ],
      ),
    ];
  }

  Future<void> addPlannedWorkout({
    required DateTime date,
    required String templateId,
    String? timeLabel,
  }) async {
    final tpl = routineTemplates.where((t) => t.id == templateId).cast<RoutineTemplate?>().firstOrNull;
    if (tpl == null) return;
    plannedWorkouts.add(
      PlannedWorkout(
        id: _newId(),
        templateId: templateId,
        templateNameSnapshot: tpl.name,
        date: DateTime(date.year, date.month, date.day),
        timeLabel: timeLabel?.trim().isEmpty ?? true ? null : timeLabel!.trim(),
        status: PlannedWorkoutStatus.planned,
        completedSessionId: null,
      ),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> removePlannedWorkout(String id) async {
    plannedWorkouts.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> setPlannedWorkoutStatus(String id, PlannedWorkoutStatus status) async {
    final idx = plannedWorkouts.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    plannedWorkouts[idx] = plannedWorkouts[idx].copyWith(status: status);
    await _persist();
    notifyListeners();
  }

  /// Starts a workout from a plan and jumps to the Workout tab.
  ///
  /// If a workout is already active, this does nothing.
  void startPlannedWorkout(String plannedWorkoutId) {
    if (activeSession != null) return;
    final plan = plannedWorkouts.where((p) => p.id == plannedWorkoutId).cast<PlannedWorkout?>().firstOrNull;
    if (plan == null) return;
    final tpl = routineTemplates.where((t) => t.id == plan.templateId).cast<RoutineTemplate?>().firstOrNull;
    final title = tpl?.name ?? plan.templateNameSnapshot;

    final draft = WorkoutSessionDraft(
      id: _newId(),
      startedAt: DateTime.now(),
      title: title,
    );
    final exercises = (tpl?.exercises ?? const <RoutineExerciseTemplate>[]);
    for (final e in exercises) {
      final n = e.name.trim();
      if (n.isEmpty) continue;
      draft.exercises.add(ExerciseDraft(name: n));
    }
    activeSession = draft;
    activePlannedWorkoutId = plannedWorkoutId;
    activeExerciseIndex = 0;
    requestedTabIndex = 0; // Workout tab
    isSearchExpanded = false;
    notifyListeners();
  }

  void clearRequestedTabIndex() {
    requestedTabIndex = null;
  }

  // ---------------------------
  // Map routes (experimental)
  // ---------------------------

  Future<void> addMapRoute({
    required String name,
    required RouteActivityType activityType,
    required List<MapPoint> points,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (points.length < 2) return;
    mapRoutes.add(
      MapRoute(
        id: _newId(),
        name: trimmed,
        activityType: activityType,
        points: points,
        createdAt: DateTime.now(),
      ),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> deleteMapRoute(String id) async {
    mapRoutes.removeWhere((r) => r.id == id);
    routeActivityLogs.removeWhere((l) => l.routeId == id);
    await _persist();
    notifyListeners();
  }

  Future<void> logRouteActivity({
    required String routeId,
    required RouteActivityType activityType,
  }) async {
    routeActivityLogs.add(
      RouteActivityLog(
        id: _newId(),
        routeId: routeId,
        activityType: activityType,
        startedAt: DateTime.now(),
      ),
    );
    await _persist();
    notifyListeners();
  }

  // ---------------------------
  // Smart schedule
  // ---------------------------

  /// Simple “smart schedule”: suggest the next workout day based on
  /// preferred weekdays and time since last session.
  ///
  /// This is intentionally lightweight (no ML, no login).
  ScheduleSuggestion suggestNextWorkout() {
    final now = DateTime.now();
    final last = sessions.isEmpty ? null : sessions.first;
    final lastDay = last?.startedAt;

    // If user hasn't logged anything, suggest next preferred day (or tomorrow).
    if (lastDay == null) {
      final next = _nextPreferredDate(from: now);
      return ScheduleSuggestion(
        date: next,
        label: 'Next workout',
        reason: 'Based on your preferred training days.',
      );
    }

    final daysSince = now.difference(DateTime(lastDay.year, lastDay.month, lastDay.day)).inDays;
    final needsRest = daysSince == 0;
    final next = needsRest ? _nextPreferredDate(from: now.add(const Duration(days: 1))) : _nextPreferredDate(from: now);

    return ScheduleSuggestion(
      date: next,
      label: needsRest ? 'Rest day' : 'Next workout',
      reason: needsRest
          ? 'You trained today — recovery helps performance.'
          : 'Aligned to your preferred schedule.',
    );
  }

  DateTime _nextPreferredDate({required DateTime from}) {
    if (preferredWeekdays.isEmpty) {
      return DateTime(from.year, from.month, from.day).add(const Duration(days: 1));
    }
    for (int i = 0; i < 14; i++) {
      final d = DateTime(from.year, from.month, from.day).add(Duration(days: i));
      if (preferredWeekdays.contains(d.weekday)) return d;
    }
    return DateTime(from.year, from.month, from.day).add(const Duration(days: 1));
  }

  // ---------------------------
  // Search
  // ---------------------------

  List<SearchHit> searchAll(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final hits = <SearchHit>[];

    // Exercise hits from active session + saved sessions.
    final seen = <String>{};
    void addExerciseName(String name) {
      final key = name.toLowerCase();
      if (key.contains(q) && seen.add(key)) {
        hits.add(SearchHit.exercise(name: name));
      }
    }

    activeSession?.exercises.forEach((e) => addExerciseName(e.name));
    for (final s in sessions.take(80)) {
      for (final e in s.exercises) {
        addExerciseName(e.name);
      }
      if ((s.title).toLowerCase().contains(q)) {
        hits.add(SearchHit.session(sessionId: s.id, title: s.title));
      }
    }

    return hits.take(8).toList();
  }

  String _newId() {
    final r = Random.secure();
    final bytes = List<int>.generate(12, (_) => r.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    required AppState appState,
    required super.child,
    super.key,
  }) : super(notifier: appState);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }
}

class AppDb {
  const AppDb({
    required this.sessions,
    required this.routineTemplates,
    required this.plannedWorkouts,
    required this.defaultRestSeconds,
    required this.focusModeEnabled,
    required this.tapAssistEnabled,
    required this.experimentalMapEnabled,
    required this.weeklyWorkoutGoal,
    required this.preferredWeekdays,
    required this.mapRoutes,
    required this.routeActivityLogs,
    required this.supersetModeEnabled,
    required this.smartRestEnabled,
    required this.restTimerAlertsEnabled,
    required this.experimentalHeatMapEnabled,
    required this.userProfile,
    required this.fitnessGoals,
    required this.unlockedAchievements,
  });

  final List<WorkoutSession> sessions;
  final List<RoutineTemplate> routineTemplates;
  final List<PlannedWorkout> plannedWorkouts;
  final int defaultRestSeconds;
  final bool focusModeEnabled;
  final bool tapAssistEnabled;
  final bool experimentalMapEnabled;
  final int weeklyWorkoutGoal;
  final List<int> preferredWeekdays;
  final List<MapRoute> mapRoutes;
  final List<RouteActivityLog> routeActivityLogs;
  final bool supersetModeEnabled;
  final bool smartRestEnabled;
  final bool restTimerAlertsEnabled;
  final bool experimentalHeatMapEnabled;
  final UserProfile? userProfile;
  final List<FitnessGoal> fitnessGoals;
  final Set<String> unlockedAchievements;

  factory AppDb.fromJson(Map<String, Object?> json) {
    final rawSessions = (json['sessions'] as List<dynamic>? ?? const []);
    final rawTemplates = (json['routineTemplates'] as List<dynamic>? ?? const []);
    final rawPlans = (json['plannedWorkouts'] as List<dynamic>? ?? const []);
    final rawRoutes = (json['mapRoutes'] as List<dynamic>? ?? const []);
    final rawRouteLogs = (json['routeActivityLogs'] as List<dynamic>? ?? const []);
    final rawProfile = json['userProfile'] as Map<String, Object?>?;
    final rawGoals = (json['fitnessGoals'] as List<dynamic>? ?? const []);
    final rawAchievements = (json['unlockedAchievements'] as List<dynamic>? ?? const []);
    return AppDb(
      sessions: rawSessions
          .whereType<Map<String, Object?>>()
          .map(WorkoutSession.fromJson)
          .toList(),
      routineTemplates: rawTemplates
          .whereType<Map<String, Object?>>()
          .map(RoutineTemplate.fromJson)
          .toList(),
      plannedWorkouts: rawPlans
          .whereType<Map<String, Object?>>()
          .map(PlannedWorkout.fromJson)
          .toList(),
      defaultRestSeconds: (json['defaultRestSeconds'] as num?)?.toInt() ?? 90,
      focusModeEnabled: (json['focusModeEnabled'] as bool?) ?? true,
      tapAssistEnabled: (json['tapAssistEnabled'] as bool?) ?? true,
      experimentalMapEnabled: (json['experimentalMapEnabled'] as bool?) ?? false,
      weeklyWorkoutGoal: (json['weeklyWorkoutGoal'] as num?)?.toInt() ?? 3,
      preferredWeekdays: (json['preferredWeekdays'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((e) => e.toInt())
          .where((d) => d >= 1 && d <= 7)
          .toList(),
      mapRoutes:
          rawRoutes.whereType<Map<String, Object?>>().map(MapRoute.fromJson).where((r) => r.points.length >= 2).toList(),
      routeActivityLogs:
          rawRouteLogs.whereType<Map<String, Object?>>().map(RouteActivityLog.fromJson).where((l) => l.routeId.isNotEmpty).toList(),
      supersetModeEnabled: (json['supersetModeEnabled'] as bool?) ?? false,
      smartRestEnabled: (json['smartRestEnabled'] as bool?) ?? true,
      restTimerAlertsEnabled: (json['restTimerAlertsEnabled'] as bool?) ?? true,
      experimentalHeatMapEnabled: (json['experimentalHeatMapEnabled'] as bool?) ?? false,
      userProfile: rawProfile != null ? UserProfile.fromJson(rawProfile) : null,
      fitnessGoals: rawGoals.whereType<Map<String, Object?>>().map(FitnessGoal.fromJson).toList(),
      unlockedAchievements: rawAchievements.whereType<String>().toSet(),
    );
  }

  Map<String, Object?> toJson() => {
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'routineTemplates': routineTemplates.map((t) => t.toJson()).toList(),
        'plannedWorkouts': plannedWorkouts.map((p) => p.toJson()).toList(),
        'defaultRestSeconds': defaultRestSeconds,
        'focusModeEnabled': focusModeEnabled,
        'tapAssistEnabled': tapAssistEnabled,
        'experimentalMapEnabled': experimentalMapEnabled,
        'weeklyWorkoutGoal': weeklyWorkoutGoal,
        'preferredWeekdays': preferredWeekdays,
        'mapRoutes': mapRoutes.map((r) => r.toJson()).toList(),
        'routeActivityLogs': routeActivityLogs.map((l) => l.toJson()).toList(),
        'supersetModeEnabled': supersetModeEnabled,
        'smartRestEnabled': smartRestEnabled,
        'restTimerAlertsEnabled': restTimerAlertsEnabled,
        'experimentalHeatMapEnabled': experimentalHeatMapEnabled,
        'userProfile': userProfile?.toJson(),
        'fitnessGoals': fitnessGoals.map((g) => g.toJson()).toList(),
        'unlockedAchievements': unlockedAchievements.toList(),
      };
}

class QuickSetAdded {
  const QuickSetAdded({required this.exerciseIndex, required this.setIndex});
  final int exerciseIndex;
  final int setIndex;
}

class WorkoutSessionDraft {
  WorkoutSessionDraft({
    required this.id,
    required this.startedAt,
    required this.title,
  });

  final String id;
  final DateTime startedAt;
  String title;
  String notes = '';
  final List<ExerciseDraft> exercises = [];
}

class ExerciseDraft {
  ExerciseDraft({required this.name});
  final String name;
  final List<ExerciseSet> sets = [];

  ExerciseEntry toFinal() => ExerciseEntry(name: name, sets: List.of(sets));
}

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    required this.exercises,
    this.notes,
  });

  final String id;
  final String title;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<ExerciseEntry> exercises;
  final String? notes;

  Duration get duration => endedAt.difference(startedAt);

  factory WorkoutSession.fromJson(Map<String, Object?> json) {
    final rawExercises = (json['exercises'] as List<dynamic>? ?? const []);
    return WorkoutSession(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Workout',
      startedAt: DateTime.tryParse((json['startedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: DateTime.tryParse((json['endedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      exercises: rawExercises
          .whereType<Map<String, Object?>>()
          .map(ExerciseEntry.fromJson)
          .toList(),
      notes: (json['notes'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['notes'] as String?)?.trim(),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'notes': notes,
      };
}

class ExerciseEntry {
  const ExerciseEntry({required this.name, required this.sets});
  final String name;
  final List<ExerciseSet> sets;

  factory ExerciseEntry.fromJson(Map<String, Object?> json) {
    final rawSets = (json['sets'] as List<dynamic>? ?? const []);
    return ExerciseEntry(
      name: (json['name'] as String?) ?? '',
      sets: rawSets
          .whereType<Map<String, Object?>>()
          .map(ExerciseSet.fromJson)
          .toList(),
    );
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'sets': sets.map((s) => s.toJson()).toList(),
      };
}

class ExerciseSet {
  const ExerciseSet({
    required this.reps,
    required this.weight,
    required this.unit,
    this.rpe,
  });
  final int reps;
  final double weight;
  final String unit; // kg / lb / bw
  final double? rpe; // 1..10 (optional)

  factory ExerciseSet.fromJson(Map<String, Object?> json) {
    return ExerciseSet(
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      unit: (json['unit'] as String?) ?? 'kg',
      rpe: (json['rpe'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toJson() => {'reps': reps, 'weight': weight, 'unit': unit, 'rpe': rpe};
}

class RestTimerState {
  const RestTimerState._({
    required this.status,
    this.startedAt,
    this.endsAt,
    this.lastDurationSeconds,
  });

  final RestTimerStatus status;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final int? lastDurationSeconds;

  bool get isIdle => status == RestTimerStatus.idle;
  bool get isRunning => status == RestTimerStatus.running;
  bool get isDone => status == RestTimerStatus.done;

  Duration get remaining {
    if (!isRunning || endsAt == null) return Duration.zero;
    final d = endsAt!.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  static RestTimerState idle() => const RestTimerState._(status: RestTimerStatus.idle);

  static RestTimerState running({required DateTime startedAt, required DateTime endsAt}) =>
      RestTimerState._(status: RestTimerStatus.running, startedAt: startedAt, endsAt: endsAt);

  static RestTimerState done({required int lastDurationSeconds}) => RestTimerState._(
        status: RestTimerStatus.done,
        lastDurationSeconds: lastDurationSeconds,
      );
}

enum RestTimerStatus { idle, running, done }

class ScheduleSuggestion {
  const ScheduleSuggestion({
    required this.date,
    required this.label,
    required this.reason,
  });

  final DateTime date;
  final String label;
  final String reason;
}

class ProgressiveOverloadSuggestion {
  const ProgressiveOverloadSuggestion({
    required this.currentWeight,
    required this.suggestedWeight,
    required this.unit,
    required this.reason,
  });

  final double currentWeight;
  final double suggestedWeight;
  final String unit;
  final String reason;
}

class SearchHit {
  const SearchHit._(this.kind, {this.name, this.sessionId, this.title});
  final SearchHitKind kind;
  final String? name;
  final String? sessionId;
  final String? title;

  static SearchHit exercise({required String name}) => SearchHit._(SearchHitKind.exercise, name: name);
  static SearchHit session({required String sessionId, required String title}) =>
      SearchHit._(SearchHitKind.session, sessionId: sessionId, title: title);
}

enum SearchHitKind { exercise, session }

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class RoutineTemplate {
  const RoutineTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.exercises,
  });

  final String id;
  final String name;
  final RoutineCategory category;
  final List<RoutineExerciseTemplate> exercises;

  factory RoutineTemplate.fromJson(Map<String, Object?> json) {
    final raw = (json['exercises'] as List<dynamic>? ?? const []);
    return RoutineTemplate(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Routine',
      category: RoutineCategoryX.fromString((json['category'] as String?) ?? 'strength'),
      exercises: raw
          .whereType<Map<String, Object?>>()
          .map(RoutineExerciseTemplate.fromJson)
          .toList(),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };
}

enum RoutineCategory { strength, cardio, mobility, custom }

extension RoutineCategoryX on RoutineCategory {
  static RoutineCategory fromString(String raw) {
    switch (raw) {
      case 'cardio':
        return RoutineCategory.cardio;
      case 'mobility':
        return RoutineCategory.mobility;
      case 'custom':
        return RoutineCategory.custom;
      case 'strength':
      default:
        return RoutineCategory.strength;
    }
  }
}

class RoutineExerciseTemplate {
  const RoutineExerciseTemplate({required this.name});
  final String name;

  factory RoutineExerciseTemplate.fromJson(Map<String, Object?> json) {
    return RoutineExerciseTemplate(name: (json['name'] as String?) ?? '');
  }

  Map<String, Object?> toJson() => {'name': name};
}

class PlannedWorkout {
  const PlannedWorkout({
    required this.id,
    required this.templateId,
    required this.templateNameSnapshot,
    required this.date,
    required this.timeLabel,
    required this.status,
    required this.completedSessionId,
  });

  final String id;
  final String templateId;
  final String templateNameSnapshot;
  final DateTime date; // date-only
  final String? timeLabel; // e.g. "AM", "18:00"
  final PlannedWorkoutStatus status;
  final String? completedSessionId;

  factory PlannedWorkout.fromJson(Map<String, Object?> json) {
    return PlannedWorkout(
      id: (json['id'] as String?) ?? '',
      templateId: (json['templateId'] as String?) ?? '',
      templateNameSnapshot: (json['templateNameSnapshot'] as String?) ?? 'Routine',
      date: DateTime.tryParse((json['date'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      timeLabel: (json['timeLabel'] as String?)?.trim().isEmpty ?? true ? null : (json['timeLabel'] as String?)?.trim(),
      status: PlannedWorkoutStatusX.fromString((json['status'] as String?) ?? 'planned'),
      completedSessionId: (json['completedSessionId'] as String?),
    );
  }

  PlannedWorkout copyWith({
    PlannedWorkoutStatus? status,
    String? completedSessionId,
  }) {
    return PlannedWorkout(
      id: id,
      templateId: templateId,
      templateNameSnapshot: templateNameSnapshot,
      date: date,
      timeLabel: timeLabel,
      status: status ?? this.status,
      completedSessionId: completedSessionId ?? this.completedSessionId,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'templateId': templateId,
        'templateNameSnapshot': templateNameSnapshot,
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'timeLabel': timeLabel,
        'status': status.name,
        'completedSessionId': completedSessionId,
      };
}

enum PlannedWorkoutStatus { planned, done, skipped }

extension PlannedWorkoutStatusX on PlannedWorkoutStatus {
  static PlannedWorkoutStatus fromString(String raw) {
    switch (raw) {
      case 'done':
        return PlannedWorkoutStatus.done;
      case 'skipped':
        return PlannedWorkoutStatus.skipped;
      case 'planned':
      default:
        return PlannedWorkoutStatus.planned;
    }
  }
}

class MapRoute {
  const MapRoute({
    required this.id,
    required this.name,
    required this.activityType,
    required this.points,
    required this.createdAt,
  });

  final String id;
  final String name;
  final RouteActivityType activityType;
  final List<MapPoint> points;
  final DateTime createdAt;

  factory MapRoute.fromJson(Map<String, Object?> json) {
    final rawPts = (json['points'] as List<dynamic>? ?? const []);
    return MapRoute(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Route',
      activityType: RouteActivityTypeX.fromString((json['activityType'] as String?) ?? 'walk'),
      points: rawPts.whereType<Map<String, Object?>>().map(MapPoint.fromJson).toList(),
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'activityType': activityType.name,
        'points': points.map((p) => p.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };
}

class MapPoint {
  const MapPoint({required this.lat, required this.lng});
  final double lat;
  final double lng;

  factory MapPoint.fromJson(Map<String, Object?> json) {
    return MapPoint(
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, Object?> toJson() => {'lat': lat, 'lng': lng};
}

enum RouteActivityType { walk, jog, bike }

extension RouteActivityTypeX on RouteActivityType {
  static RouteActivityType fromString(String raw) {
    switch (raw) {
      case 'bike':
        return RouteActivityType.bike;
      case 'jog':
        return RouteActivityType.jog;
      case 'walk':
      default:
        return RouteActivityType.walk;
    }
  }

  String get label {
    switch (this) {
      case RouteActivityType.walk:
        return 'Walk';
      case RouteActivityType.jog:
        return 'Jog';
      case RouteActivityType.bike:
        return 'Bike';
    }
  }
}

class RouteActivityLog {
  const RouteActivityLog({
    required this.id,
    required this.routeId,
    required this.activityType,
    required this.startedAt,
  });

  final String id;
  final String routeId;
  final RouteActivityType activityType;
  final DateTime startedAt;

  factory RouteActivityLog.fromJson(Map<String, Object?> json) {
    return RouteActivityLog(
      id: (json['id'] as String?) ?? '',
      routeId: (json['routeId'] as String?) ?? '',
      activityType: RouteActivityTypeX.fromString((json['activityType'] as String?) ?? 'walk'),
      startedAt: DateTime.tryParse((json['startedAt'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'routeId': routeId,
        'activityType': activityType.name,
        'startedAt': startedAt.toIso8601String(),
      };
}

/// User profile for strength comparisons.
class UserProfile {
  const UserProfile({
    required this.age,
    required this.weightKg,
    required this.heightCm,
    required this.gender,
  });

  final int age;
  final double weightKg;
  final double heightCm;
  final String gender; // 'male' or 'female'

  factory UserProfile.fromJson(Map<String, Object?> json) {
    return UserProfile(
      age: (json['age'] as num?)?.toInt() ?? 25,
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 70,
      heightCm: (json['heightCm'] as num?)?.toDouble() ?? 170,
      gender: (json['gender'] as String?) ?? 'male',
    );
  }

  Map<String, Object?> toJson() => {
        'age': age,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'gender': gender,
      };

  UserProfile copyWith({
    int? age,
    double? weightKg,
    double? heightCm,
    String? gender,
  }) {
    return UserProfile(
      age: age ?? this.age,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      gender: gender ?? this.gender,
    );
  }
}

/// Muscle groups for heat map visualization.
enum MuscleGroup {
  chest,
  back,
  shoulders,
  biceps,
  triceps,
  quads,
  hamstrings,
  glutes,
  calves,
  core,
}

extension MuscleGroupX on MuscleGroup {
  String get displayName {
    switch (this) {
      case MuscleGroup.chest:
        return 'Chest';
      case MuscleGroup.back:
        return 'Back';
      case MuscleGroup.shoulders:
        return 'Shoulders';
      case MuscleGroup.biceps:
        return 'Biceps';
      case MuscleGroup.triceps:
        return 'Triceps';
      case MuscleGroup.quads:
        return 'Quads';
      case MuscleGroup.hamstrings:
        return 'Hamstrings';
      case MuscleGroup.glutes:
        return 'Glutes';
      case MuscleGroup.calves:
        return 'Calves';
      case MuscleGroup.core:
        return 'Core';
    }
  }

  /// Category for grouping (push/pull/legs).
  String get category {
    switch (this) {
      case MuscleGroup.chest:
      case MuscleGroup.shoulders:
      case MuscleGroup.triceps:
        return 'Push';
      case MuscleGroup.back:
      case MuscleGroup.biceps:
        return 'Pull';
      case MuscleGroup.quads:
      case MuscleGroup.hamstrings:
      case MuscleGroup.glutes:
      case MuscleGroup.calves:
        return 'Legs';
      case MuscleGroup.core:
        return 'Core';
    }
  }
}

/// Heat map data for a single muscle group.
class MuscleHeatData {
  const MuscleHeatData({
    required this.muscle,
    required this.volume,
    required this.sets,
    required this.intensity,
    required this.fatigue,
    required this.bestWeight,
    required this.lastWorked,
  });

  final MuscleGroup muscle;
  final double volume; // Total volume (weight × reps)
  final int sets; // Total sets in period
  final double intensity; // 0.0-2.0+ (1.0 = baseline)
  final double fatigue; // 0.0-1.0 (current fatigue level)
  final double bestWeight; // Best weight lifted
  final DateTime? lastWorked; // Last time this muscle was trained

  /// Get a color representing the fatigue level.
  /// Green = recovered, Yellow = moderate, Red = fatigued
  int get fatigueColorValue {
    if (fatigue < 0.3) return 0xFF4CAF50; // Green
    if (fatigue < 0.6) return 0xFFFFEB3B; // Yellow
    return 0xFFF44336; // Red
  }

  /// Get a color representing the intensity level.
  /// Blue = undertrained, Green = optimal, Orange/Red = high volume
  int get intensityColorValue {
    if (intensity < 0.5) return 0xFF2196F3; // Blue - undertrained
    if (intensity < 1.2) return 0xFF4CAF50; // Green - optimal
    if (intensity < 1.8) return 0xFFFF9800; // Orange - high
    return 0xFFF44336; // Red - very high
  }
}

/// A fitness goal with milestones.
class FitnessGoal {
  const FitnessGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.milestones,
    required this.createdAt,
    this.targetDate,
  });

  final String id;
  final String title;
  final String description;
  final GoalCategory category;
  final List<GoalMilestone> milestones;
  final DateTime createdAt;
  final DateTime? targetDate;

  factory FitnessGoal.fromJson(Map<String, Object?> json) {
    final rawMilestones = (json['milestones'] as List<dynamic>? ?? const []);
    return FitnessGoal(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Goal',
      description: (json['description'] as String?) ?? '',
      category: GoalCategoryX.fromString((json['category'] as String?) ?? 'strength'),
      milestones: rawMilestones
          .whereType<Map<String, Object?>>()
          .map(GoalMilestone.fromJson)
          .toList(),
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? DateTime.now(),
      targetDate: json['targetDate'] != null 
          ? DateTime.tryParse((json['targetDate'] as String?) ?? '')
          : null,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category.name,
        'milestones': milestones.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'targetDate': targetDate?.toIso8601String(),
      };

  FitnessGoal copyWith({
    String? title,
    String? description,
    GoalCategory? category,
    List<GoalMilestone>? milestones,
    DateTime? targetDate,
  }) {
    return FitnessGoal(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      milestones: milestones ?? this.milestones,
      createdAt: createdAt,
      targetDate: targetDate ?? this.targetDate,
    );
  }
}

/// A milestone within a fitness goal.
class GoalMilestone {
  const GoalMilestone({
    required this.title,
    required this.targetValue,
    required this.unit,
    required this.isCompleted,
    this.completedAt,
  });

  final String title;
  final double targetValue;
  final String unit;
  final bool isCompleted;
  final DateTime? completedAt;

  factory GoalMilestone.fromJson(Map<String, Object?> json) {
    return GoalMilestone(
      title: (json['title'] as String?) ?? '',
      targetValue: (json['targetValue'] as num?)?.toDouble() ?? 0,
      unit: (json['unit'] as String?) ?? '',
      isCompleted: (json['isCompleted'] as bool?) ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse((json['completedAt'] as String?) ?? '')
          : null,
    );
  }

  Map<String, Object?> toJson() => {
        'title': title,
        'targetValue': targetValue,
        'unit': unit,
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
      };

  GoalMilestone copyWith({
    String? title,
    double? targetValue,
    String? unit,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return GoalMilestone(
      title: title ?? this.title,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt,
    );
  }
}

/// Categories for fitness goals.
enum GoalCategory {
  strength,
  endurance,
  weightLoss,
  muscleGain,
  flexibility,
  consistency,
  custom,
}

extension GoalCategoryX on GoalCategory {
  static GoalCategory fromString(String raw) {
    switch (raw) {
      case 'endurance':
        return GoalCategory.endurance;
      case 'weightLoss':
        return GoalCategory.weightLoss;
      case 'muscleGain':
        return GoalCategory.muscleGain;
      case 'flexibility':
        return GoalCategory.flexibility;
      case 'consistency':
        return GoalCategory.consistency;
      case 'custom':
        return GoalCategory.custom;
      case 'strength':
      default:
        return GoalCategory.strength;
    }
  }

  String get displayName {
    switch (this) {
      case GoalCategory.strength:
        return 'Strength';
      case GoalCategory.endurance:
        return 'Endurance';
      case GoalCategory.weightLoss:
        return 'Weight Loss';
      case GoalCategory.muscleGain:
        return 'Muscle Gain';
      case GoalCategory.flexibility:
        return 'Flexibility';
      case GoalCategory.consistency:
        return 'Consistency';
      case GoalCategory.custom:
        return 'Custom';
    }
  }

  int get iconCodePoint {
    switch (this) {
      case GoalCategory.strength:
        return 0xe1e1; // fitness_center
      case GoalCategory.endurance:
        return 0xe566; // directions_run
      case GoalCategory.weightLoss:
        return 0xe8cb; // trending_down
      case GoalCategory.muscleGain:
        return 0xe8e5; // trending_up
      case GoalCategory.flexibility:
        return 0xe90f; // self_improvement
      case GoalCategory.consistency:
        return 0xe614; // event_repeat
      case GoalCategory.custom:
        return 0xe838; // flag
    }
  }
}

/// Achievement definition.
class Achievement {
  final String id;
  final String title;
  final String description;
  final int iconCodePoint;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconCodePoint,
  });
}

