/// Exercise database with common exercises for search and suggestions.
class ExerciseDatabase {
  static const List<String> exercises = [
    // Chest
    'Bench Press',
    'Incline Bench Press',
    'Decline Bench Press',
    'Dumbbell Press',
    'Incline Dumbbell Press',
    'Chest Fly',
    'Dumbbell Fly',
    'Cable Crossover',
    'Pec Deck',
    'Push-up',
    'Dips',
    'Close Grip Bench Press',
    
    // Back
    'Pull-up',
    'Chin-up',
    'Lat Pulldown',
    'Barbell Row',
    'Dumbbell Row',
    'Cable Row',
    'Seated Row',
    'T-Bar Row',
    'Deadlift',
    'Romanian Deadlift',
    'RDL',
    'Face Pull',
    'Shrug',
    
    // Shoulders
    'Overhead Press',
    'OHP',
    'Military Press',
    'Shoulder Press',
    'Dumbbell Shoulder Press',
    'Lateral Raise',
    'Front Raise',
    'Rear Delt Fly',
    'Arnold Press',
    'Upright Row',
    
    // Arms
    'Bicep Curl',
    'Barbell Curl',
    'Dumbbell Curl',
    'Hammer Curl',
    'Preacher Curl',
    'Concentration Curl',
    'Tricep Extension',
    'Tricep Pushdown',
    'Skull Crusher',
    'Close Grip Push-up',
    
    // Legs
    'Squat',
    'Front Squat',
    'Back Squat',
    'Leg Press',
    'Leg Extension',
    'Bulgarian Split Squat',
    'Lunge',
    'Walking Lunge',
    'Leg Curl',
    'Romanian Deadlift',
    'Hip Thrust',
    'Glute Bridge',
    'Calf Raise',
    'Seated Calf Raise',
    
    // Core
    'Plank',
    'Side Plank',
    'Crunch',
    'Sit-up',
    'Leg Raise',
    'Hanging Leg Raise',
    'Russian Twist',
    'Ab Wheel',
    'Cable Crunch',
    'Mountain Climber',
    
    // Full Body
    'Clean',
    'Snatch',
    'Clean and Jerk',
    'Thruster',
    'Burpee',
    'Kettlebell Swing',
    
    // Cardio
    'Running',
    'Cycling',
    'Rowing',
    'Elliptical',
    'Jump Rope',
  ];

  /// Search exercises by name (case-insensitive, partial match).
  static List<String> search(String query) {
    if (query.trim().isEmpty) return exercises;
    final q = query.trim().toLowerCase();
    return exercises.where((e) => e.toLowerCase().contains(q)).toList();
  }

  /// Get popular/common exercises.
  static List<String> getPopular() {
    return exercises.take(20).toList();
  }
}
