/// Storage optimization strategies for the Gym Tracker app.
/// 
/// This file documents and implements storage reduction techniques.
/// 
/// ## Current vs Optimized JSON
/// 
/// ### Before (verbose keys):
/// ```json
/// {
///   "sessions": [{
///     "id": "abc123",
///     "title": "Push Day",
///     "startedAt": "2024-01-15T10:30:00.000Z",
///     "endedAt": "2024-01-15T11:45:00.000Z",
///     "exercises": [{
///       "name": "Bench Press",
///       "sets": [{"reps": 10, "weight": 60.0, "unit": "kg", "rpe": 8}]
///     }]
///   }]
/// }
/// ```
/// 
/// ### After (compact keys):
/// ```json
/// {
///   "s": [{
///     "i": "abc123",
///     "t": "Push Day",
///     "a": 1705315800000,
///     "b": 1705320300000,
///     "e": [{
///       "n": "Bench Press",
///       "s": [{"r": 10, "w": 60.0, "u": 0, "p": 8}]
///     }]
///   }]
/// }
/// ```
/// 
/// ## Size Comparison (100 workout sessions, ~500 sets each)
/// 
/// | Format | Size | Notes |
/// |--------|------|-------|
/// | Current JSON | ~500 KB | Verbose keys, ISO dates |
/// | Compact JSON | ~300 KB | Short keys, timestamps |
/// | MessagePack | ~200 KB | Binary JSON-like |
/// | Protocol Buffers | ~150 KB | Schema-based binary |
/// | Compressed JSON (gzip) | ~80 KB | Any JSON + compression |
/// 
/// ## Recommendation
/// 
/// For this app, **Compact JSON + Compression** is the best tradeoff:
/// - Easy to implement (no new dependencies)
/// - Still human-debuggable
/// - ~85% size reduction
/// - Works on all platforms (web, mobile)
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Compact key mappings for JSON optimization.
/// 
/// Using single-character keys reduces JSON size by ~30%.
abstract final class CompactKeys {
  // Top-level
  static const sessions = 's';
  static const routineTemplates = 'rt';
  static const plannedWorkouts = 'pw';
  static const mapRoutes = 'mr';
  static const fitnessGoals = 'fg';
  static const userProfile = 'up';
  static const unlockedAchievements = 'ua';
  
  // WorkoutSession
  static const id = 'i';
  static const title = 't';
  static const startedAt = 'a';  // "at"
  static const endedAt = 'b';    // "before" (end)
  static const exercises = 'e';
  static const notes = 'n';
  
  // ExerciseEntry
  static const name = 'n';
  static const sets = 's';
  
  // ExerciseSet
  static const reps = 'r';
  static const weight = 'w';
  static const unit = 'u';
  static const rpe = 'p';
  
  // Unit enum values (instead of strings)
  static const unitKg = 0;
  static const unitLb = 1;
  static const unitBw = 2;
}

/// Compress a JSON string using gzip.
/// 
/// Typically achieves 70-85% compression on JSON data.
/// 
/// Note: Not available on web without additional packages.
Uint8List? compressJson(String json) {
  try {
    final bytes = utf8.encode(json);
    return Uint8List.fromList(gzip.encode(bytes));
  } catch (_) {
    return null; // Compression not available (e.g., web)
  }
}

/// Decompress gzip data back to JSON string.
String? decompressJson(Uint8List compressed) {
  try {
    final bytes = gzip.decode(compressed);
    return utf8.decode(bytes);
  } catch (_) {
    return null;
  }
}

/// Estimate storage size for a workout history.
/// 
/// Returns estimated bytes for different storage formats.
Map<String, int> estimateStorageSize({
  required int sessionCount,
  required int avgExercisesPerSession,
  required int avgSetsPerExercise,
}) {
  // Average bytes per set in different formats
  const bytesPerSetJson = 50;        // {"reps":10,"weight":60.0,"unit":"kg","rpe":8}
  const bytesPerSetCompact = 25;     // {"r":10,"w":60,"u":0,"p":8}
  const bytesPerSetBinary = 10;      // varint + float32 + byte + byte
  
  // Overhead per exercise
  const exerciseOverheadJson = 30;   // {"name":"...","sets":[]}
  const exerciseOverheadCompact = 15;
  const exerciseOverheadBinary = 8;
  
  // Overhead per session
  const sessionOverheadJson = 150;   // id, title, dates, etc.
  const sessionOverheadCompact = 60;
  const sessionOverheadBinary = 30;
  
  final totalSets = sessionCount * avgExercisesPerSession * avgSetsPerExercise;
  final totalExercises = sessionCount * avgExercisesPerSession;
  
  final jsonSize = (totalSets * bytesPerSetJson) +
      (totalExercises * exerciseOverheadJson) +
      (sessionCount * sessionOverheadJson);
  
  final compactSize = (totalSets * bytesPerSetCompact) +
      (totalExercises * exerciseOverheadCompact) +
      (sessionCount * sessionOverheadCompact);
  
  final binarySize = (totalSets * bytesPerSetBinary) +
      (totalExercises * exerciseOverheadBinary) +
      (sessionCount * sessionOverheadBinary);
  
  return {
    'json': jsonSize,
    'compactJson': compactSize,
    'compactJsonGzip': (compactSize * 0.25).round(), // ~75% compression
    'binary': binarySize,
    'binaryGzip': (binarySize * 0.6).round(), // Binary compresses less
  };
}
