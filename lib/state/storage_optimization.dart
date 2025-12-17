/// Storage optimization for Gym Tracker.
/// 
/// Implements compact JSON keys and compression to reduce storage by ~80%.
/// 
/// ## Migration Strategy
/// - Reading: Supports both old (verbose) and new (compact) keys
/// - Writing: Always uses compact keys
/// - Compression: Applied on mobile, skipped on web (dart:io not available)
library;

import 'dart:convert';
import 'dart:typed_data';

// Conditionally import dart:io for compression
import 'compression_stub.dart'
    if (dart.library.io) 'compression_io.dart' as compression;

/// Compact key mappings for JSON storage optimization.
/// 
/// Reduces JSON size by ~40% through shorter keys.
/// 
/// Format: verbose key -> compact key
abstract final class K {
  // ============ AppDb (top-level) ============
  static const sessions = 's';
  static const routineTemplates = 'rt';
  static const plannedWorkouts = 'pw';
  static const mapRoutes = 'mr';
  static const routeActivityLogs = 'rl';
  static const fitnessGoals = 'fg';
  static const userProfile = 'up';
  static const unlockedAchievements = 'ua';
  static const defaultRestSeconds = 'dr';
  static const focusModeEnabled = 'fm';
  static const tapAssistEnabled = 'ta';
  static const experimentalMapEnabled = 'em';
  static const experimentalHeatMapEnabled = 'eh';
  static const weeklyWorkoutGoal = 'wg';
  static const preferredWeekdays = 'pd';
  static const supersetModeEnabled = 'sm';
  static const smartRestEnabled = 'sr';
  static const restTimerAlertsEnabled = 'ra';

  // ============ WorkoutSession ============
  static const id = 'i';
  static const title = 't';
  static const startedAt = 'a';
  static const endedAt = 'b';
  static const exercises = 'e';
  static const notes = 'n';

  // ============ ExerciseEntry ============
  static const name = 'n';
  static const sets = 's';

  // ============ ExerciseSet ============
  static const reps = 'r';
  static const weight = 'w';
  static const unit = 'u';
  static const rpe = 'p';

  // ============ RoutineTemplate ============
  static const exerciseTemplates = 'et';
  static const defaultSets = 'ds';
  static const defaultReps = 'de';
  static const defaultWeight = 'dw';

  // ============ PlannedWorkout ============
  static const templateId = 'ti';
  static const date = 'd';
  static const status = 'st';
  static const completedSessionId = 'cs';

  // ============ MapRoute ============
  static const points = 'pt';
  static const lat = 'la';
  static const lng = 'lo';
  static const distanceMeters = 'dm';
  static const color = 'c';

  // ============ RouteActivityLog ============
  static const routeId = 'ri';
  static const durationSeconds = 'ds';

  // ============ UserProfile ============
  static const age = 'ag';
  static const weightKg = 'wk';
  static const heightCm = 'hc';
  static const gender = 'g';

  // ============ FitnessGoal ============
  static const description = 'dc';
  static const category = 'ca';
  static const milestones = 'ms';
  static const createdAt = 'cr';
  static const targetDate = 'td';

  // ============ GoalMilestone ============
  static const targetValue = 'tv';
  static const isCompleted = 'ic';
  static const completedAt = 'co';
}

/// Unit string to int mapping for compact storage.
/// 
/// Saves ~2 bytes per set (3000 sets = 6KB savings).
abstract final class UnitCode {
  static const kg = 0;
  static const lb = 1;
  static const bw = 2;

  static int encode(String unit) {
    switch (unit) {
      case 'lb':
        return lb;
      case 'bw':
        return bw;
      case 'kg':
      default:
        return kg;
    }
  }

  static String decode(Object? code) {
    switch (code) {
      case 1:
      case 'lb':
        return 'lb';
      case 2:
      case 'bw':
        return 'bw';
      case 0:
      case 'kg':
      default:
        return 'kg';
    }
  }
}

/// Status codes for PlannedWorkout.
abstract final class StatusCode {
  static const planned = 0;
  static const skipped = 1;
  static const done = 2;

  static int encode(String status) {
    switch (status) {
      case 'skipped':
        return skipped;
      case 'done':
        return done;
      case 'planned':
      default:
        return planned;
    }
  }

  static String decode(Object? code) {
    switch (code) {
      case 1:
      case 'skipped':
        return 'skipped';
      case 2:
      case 'done':
        return 'done';
      case 0:
      case 'planned':
      default:
        return 'planned';
    }
  }
}

/// Read a value supporting both old (verbose) and new (compact) keys.
/// 
/// Example:
/// ```dart
/// final title = readKey(json, K.title, 'title') as String?;
/// ```
T? readKey<T>(Map<String, Object?> json, String compactKey, String verboseKey) {
  return (json[compactKey] ?? json[verboseKey]) as T?;
}

/// Parse DateTime from either ISO string or milliseconds timestamp.
/// 
/// Compact format uses milliseconds (smaller), verbose uses ISO string.
DateTime? parseDateTime(Object? value) {
  if (value == null) return null;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Encode DateTime as milliseconds timestamp (compact).
int? encodeDateTime(DateTime? dt) => dt?.millisecondsSinceEpoch;

/// Compress JSON string to bytes (mobile only).
/// 
/// Returns null on web or if compression fails.
Uint8List? compressString(String data) => compression.compress(data);

/// Decompress bytes back to JSON string.
/// 
/// Returns null on web or if decompression fails.
String? decompressToString(Uint8List data) => compression.decompress(data);

/// Check if compression is available on this platform.
bool get isCompressionAvailable => compression.isAvailable;

/// Storage format version for migration support.
const int storageVersion = 2;

/// Estimate storage size reduction.
/// 
/// Returns a map with estimated bytes for different scenarios.
Map<String, int> estimateStorageSize({
  required int sessionCount,
  required int exercisesPerSession,
  required int setsPerExercise,
}) {
  final totalSets = sessionCount * exercisesPerSession * setsPerExercise;
  
  // Bytes per component in different formats
  final verboseJson = totalSets * 55 + sessionCount * 180;
  final compactJson = totalSets * 25 + sessionCount * 70;
  final compactGzip = (compactJson * 0.25).round();
  
  return {
    'verboseJson': verboseJson,
    'compactJson': compactJson,
    'compactGzip': compactGzip,
    'savingsPercent': ((1 - compactGzip / verboseJson) * 100).round(),
  };
}
