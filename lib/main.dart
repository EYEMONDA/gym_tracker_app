import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const GymTrackerApp());
}

class GymTrackerApp extends StatelessWidget {
  const GymTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const WorkoutLogScreen(),
    );
  }
}

class WorkoutLogScreen extends StatefulWidget {
  const WorkoutLogScreen({super.key});

  @override
  WorkoutLogScreenState createState() => WorkoutLogScreenState();
}

class WorkoutLogScreenState extends State<WorkoutLogScreen> {
  final TextEditingController _exerciseController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _setsController = TextEditingController();
  bool _isWorkoutActive = false;
  bool _isBreakActive = false;
  Timer? _breakTimer;
  Timer? _workoutTimer;
  int _breakSeconds = 0;
  int _workoutSeconds = 0;
  int _totalBreakSeconds = 0;
  int _breakCount = 0;

  @override
  void initState() {
    super.initState();
    _checkWorkoutStatus();
  }

  // Check if a workout is active
  Future<void> _checkWorkoutStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isWorkoutActive = prefs.getBool('isWorkoutActive') ?? false;
      });
    }
  }

  // Start workout
  Future<void> _startWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isWorkoutActive', true);
    await prefs.setString('startTime', DateTime.now().toIso8601String());
    if (mounted) {
      setState(() {
        _isWorkoutActive = true;
        _workoutSeconds = 0;
        _totalBreakSeconds = 0;
        _breakCount = 0;
      });
      _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && !_isBreakActive) {
          setState(() {
            _workoutSeconds++;
          });
        } else if (!mounted) {
          timer.cancel();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout started!')),
      );
    }
  }

  // End workout
  Future<void> _endWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isWorkoutActive', false);
    await prefs.setString('endTime', DateTime.now().toIso8601String());
    // Save session details to history
    List<String> sessions = prefs.getStringList('sessions') ?? [];
    int activeTime = _workoutSeconds - _totalBreakSeconds;
    sessions.add(
      'Workout: ${_formatTime(_workoutSeconds)}, '
      'Breaks: ${_formatTime(_totalBreakSeconds)}, '
      'Active: ${_formatTime(activeTime < 0 ? 0 : activeTime)}, '
      'Breaks taken: $_breakCount',
    );
    await prefs.setStringList('sessions', sessions);
    if (mounted) {
      setState(() {
        _isWorkoutActive = false;
        _isBreakActive = false;
        _breakTimer?.cancel();
        _workoutTimer?.cancel();
        _breakSeconds = 0;
        _workoutSeconds = 0;
        _totalBreakSeconds = 0;
        _breakCount = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout ended!')),
      );
    }
  }

  // Start or restart break
  Future<void> _toggleBreak() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isBreakActive) {
      // End break
      if (mounted) {
        setState(() {
          _isBreakActive = false;
          _totalBreakSeconds += _breakSeconds;
          _breakTimer?.cancel();
          _breakSeconds = 0;
        });
        _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted && !_isBreakActive) {
            setState(() {
              _workoutSeconds++;
            });
          } else if (!mounted) {
            timer.cancel();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Break ended!')),
        );
      }
    } else {
      // Start break
      await prefs.setString('breakStartTime', DateTime.now().toIso8601String());
      if (mounted) {
        setState(() {
          _isBreakActive = true;
          _breakSeconds = 0;
          _breakCount++;
          _workoutTimer?.cancel();
        });
        _breakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _breakSeconds++;
            });
          } else {
            timer.cancel();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Break started!')),
        );
      }
    }
  }

  // Format seconds to MM:SS
  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Save workout to SharedPreferences
  Future<void> _saveWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    String exercise = _exerciseController.text;
    String reps = _repsController.text;
    String sets = _setsController.text;

    if (exercise.isNotEmpty && reps.isNotEmpty && sets.isNotEmpty) {
      List<String> workouts = prefs.getStringList('workouts') ?? [];
      workouts.add('$exercise: $reps reps, $sets sets');
      await prefs.setStringList('workouts', workouts);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout saved!')),
        );
        setState(() {
          _exerciseController.clear();
          _repsController.clear();
          _setsController.clear();
        });
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
    }
  }

  // Navigate to history screen
  void _goToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log a Workout'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_isWorkoutActive)
              Text(
                'Workout: ${_formatTime(_workoutSeconds)}',
                style: const TextStyle(fontSize: 16, color: Colors.green),
              ),
            Text(
              _isWorkoutActive ? 'Workout in progress' : 'No workout active',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_isBreakActive)
              Text(
                'Break: ${_formatTime(_breakSeconds)}',
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isWorkoutActive ? null : _startWorkout,
              child: const Text('Start Workout'),
            ),
            ElevatedButton(
              onPressed: _isWorkoutActive ? _toggleBreak : null,
              child: Text(_isBreakActive ? 'End Break' : 'Take a Break'),
            ),
            ElevatedButton(
              onPressed: _isWorkoutActive ? _endWorkout : null,
              child: const Text('End Workout'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _exerciseController,
              decoration: const InputDecoration(
                labelText: 'Exercise Name (e.g., Push-ups)',
              ),
            ),
            TextField(
              controller: _repsController,
              decoration: const InputDecoration(
                labelText: 'Reps',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _setsController,
              decoration: const InputDecoration(
                labelText: 'Sets',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveWorkout,
              child: const Text('Save Workout'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _goToHistory,
              child: const Text('View History'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _breakTimer?.cancel();
    _workoutTimer?.cancel();
    _exerciseController.dispose();
    _repsController.dispose();
    _setsController.dispose();
    super.dispose();
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  HistoryScreenState createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  Future<Map<String, List<String>>> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'workouts': prefs.getStringList('workouts') ?? [],
      'sessions': prefs.getStringList('sessions') ?? [],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History'),
      ),
      body: FutureBuilder<Map<String, List<String>>>(
        future: _loadHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData ||
              (snapshot.data!['workouts']!.isEmpty &&
                  snapshot.data!['sessions']!.isEmpty)) {
            return const Center(child: Text('No history logged yet.'));
          }
          return ListView.builder(
            itemCount: snapshot.data!['workouts']!.length +
                snapshot.data!['sessions']!.length,
            itemBuilder: (context, index) {
              if (index < snapshot.data!['sessions']!.length) {
                return ListTile(
                  title: Text('Session ${index + 1}'),
                  subtitle: Text(snapshot.data!['sessions']![index]),
                );
              }
              int workoutIndex = index - snapshot.data!['sessions']!.length;
              return ListTile(
                title: Text('Workout ${workoutIndex + 1}'),
                subtitle: Text(snapshot.data!['workouts']![workoutIndex]),
              );
            },
          );
        },
      ),
    );
  }
}