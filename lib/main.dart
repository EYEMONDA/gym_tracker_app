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

  // Function to save workout to SharedPreferences
  Future<void> _saveWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    String exercise = _exerciseController.text;
    String reps = _repsController.text;
    String sets = _setsController.text;

    if (exercise.isNotEmpty && reps.isNotEmpty && sets.isNotEmpty) {
      List<String> workouts = prefs.getStringList('workouts') ?? [];
      workouts.add('$exercise: $reps reps, $sets sets');
      await prefs.setStringList('workouts', workouts);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout saved!')),
      );
      _exerciseController.clear();
      _repsController.clear();
      _setsController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
    }
  }

  // Function to navigate to history screen
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
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  HistoryScreenState createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  Future<List<String>> _loadWorkouts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('workouts') ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History'),
      ),
      body: FutureBuilder<List<String>>(
        future: _loadWorkouts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No workouts logged yet.'));
          }
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(snapshot.data![index]),
              );
            },
          );
        },
      ),
    );
  }
}