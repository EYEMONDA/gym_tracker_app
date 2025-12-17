import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
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

  /// Saved sessions.
  final List<WorkoutSession> sessions = [];

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
        defaultRestSeconds = db.defaultRestSeconds;
        preferredWeekdays
          ..clear()
          ..addAll(db.preferredWeekdays);
      } catch (_) {
        // If the DB is corrupt, keep the app usable.
      }
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final db = AppDb(
      sessions: sessions,
      defaultRestSeconds: defaultRestSeconds,
      preferredWeekdays: preferredWeekdays.toList()..sort(),
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
    notifyListeners();
  }

  Future<void> endWorkoutAndSave() async {
    final draft = activeSession;
    if (draft == null) return;
    final endedAt = DateTime.now();
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
    activeSession = null;
    stopRestTimer();
    await _persist();
    notifyListeners();
  }

  void discardActiveWorkout() {
    activeSession = null;
    stopRestTimer();
    notifyListeners();
  }

  void addExerciseToActive(String name) {
    final draft = activeSession;
    if (draft == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    draft.exercises.add(ExerciseDraft(name: trimmed));
    notifyListeners();
  }

  void addSetToExercise(int exerciseIndex,
      {int reps = 10, double weight = 0, String? unit}) {
    final draft = activeSession;
    if (draft == null) return;
    if (exerciseIndex < 0 || exerciseIndex >= draft.exercises.length) return;
    draft.exercises[exerciseIndex].sets.add(
          ExerciseSet(reps: reps, weight: weight, unit: unit ?? 'kg'),
        );
    notifyListeners();
  }

  void removeExerciseFromActive(int exerciseIndex) {
    final draft = activeSession;
    if (draft == null) return;
    if (exerciseIndex < 0 || exerciseIndex >= draft.exercises.length) return;
    draft.exercises.removeAt(exerciseIndex);
    notifyListeners();
  }

  void removeSetFromExercise(int exerciseIndex, int setIndex) {
    final draft = activeSession;
    if (draft == null) return;
    if (exerciseIndex < 0 || exerciseIndex >= draft.exercises.length) return;
    final ex = draft.exercises[exerciseIndex];
    if (setIndex < 0 || setIndex >= ex.sets.length) return;
    ex.sets.removeAt(setIndex);
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

  Future<void> setDefaultRestSeconds(int seconds) async {
    defaultRestSeconds = seconds.clamp(10, 600);
    await _persist();
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
    stopRestTimer();
    searchQuery = '';
    isSearchExpanded = false;
    defaultRestSeconds = 90;
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
    required this.defaultRestSeconds,
    required this.preferredWeekdays,
  });

  final List<WorkoutSession> sessions;
  final int defaultRestSeconds;
  final List<int> preferredWeekdays;

  factory AppDb.fromJson(Map<String, Object?> json) {
    final rawSessions = (json['sessions'] as List<dynamic>? ?? const []);
    return AppDb(
      sessions: rawSessions
          .whereType<Map<String, Object?>>()
          .map(WorkoutSession.fromJson)
          .toList(),
      defaultRestSeconds: (json['defaultRestSeconds'] as num?)?.toInt() ?? 90,
      preferredWeekdays: (json['preferredWeekdays'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((e) => e.toInt())
          .where((d) => d >= 1 && d <= 7)
          .toList(),
    );
  }

  Map<String, Object?> toJson() => {
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'defaultRestSeconds': defaultRestSeconds,
        'preferredWeekdays': preferredWeekdays,
      };
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
  const ExerciseSet({required this.reps, required this.weight, required this.unit});
  final int reps;
  final double weight;
  final String unit; // kg / lb / bw

  factory ExerciseSet.fromJson(Map<String, Object?> json) {
    return ExerciseSet(
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      unit: (json['unit'] as String?) ?? 'kg',
    );
  }

  Map<String, Object?> toJson() => {'reps': reps, 'weight': weight, 'unit': unit};
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

