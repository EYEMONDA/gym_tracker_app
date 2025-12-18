import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/app_card.dart';

class MuscleHeatMapScreen extends StatefulWidget {
  const MuscleHeatMapScreen({super.key});

  @override
  State<MuscleHeatMapScreen> createState() => _MuscleHeatMapScreenState();
}

class _MuscleHeatMapScreenState extends State<MuscleHeatMapScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  int _dayRange = 7;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    
    if (!app.experimentalHeatMapEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Muscle Heat Map')),
        body: const Center(
          child: Text('Enable the Muscle Heat Map feature in Settings first.'),
        ),
      );
    }

    final heatMap = app.getMuscleHeatMap(days: _dayRange);
    final comparison = app.getStrengthComparison();
    final suggestions = app.getWorkoutSuggestions();
    final profile = app.userProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Muscle Heat Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Edit Profile',
            onPressed: () => _showProfileDialog(context, app),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Fatigue'),
            Tab(text: 'Volume'),
            Tab(text: 'Compare'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Day range selector
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('Time range: ', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('3 days'),
                  selected: _dayRange == 3,
                  onSelected: (_) => setState(() => _dayRange = 3),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('7 days'),
                  selected: _dayRange == 7,
                  onSelected: (_) => setState(() => _dayRange = 7),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('14 days'),
                  selected: _dayRange == 14,
                  onSelected: (_) => setState(() => _dayRange = 14),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                // Fatigue Tab
                _FatigueView(
                  heatMap: heatMap,
                  suggestions: suggestions,
                ),
                
                // Volume Tab
                _VolumeView(heatMap: heatMap),
                
                // Comparison Tab
                _ComparisonView(
                  comparison: comparison,
                  profile: profile,
                  onEditProfile: () => _showProfileDialog(context, app),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProfileDialog(BuildContext context, AppState app) async {
    final result = await showDialog<UserProfile>(
      context: context,
      builder: (_) => _ProfileDialog(currentProfile: app.userProfile),
    );
    if (result != null) {
      await app.setUserProfile(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    }
  }
}

class _FatigueView extends StatelessWidget {
  const _FatigueView({
    required this.heatMap,
    required this.suggestions,
  });

  final Map<MuscleGroup, MuscleHeatData> heatMap;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Suggestions card
        AppCardSpaced(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.lightbulb_outline, size: 20, color: Color(0xFFFFD700)),
                  SizedBox(width: 8),
                  Text('Suggestions', style: TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              ...suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Color(0xAAFFFFFF))),
                    Expanded(
                      child: Text(s, style: const TextStyle(color: Color(0xAAFFFFFF))),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Body heat map visualization
        const Text('Muscle Fatigue', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 8),
        const Text(
          'Green = recovered, Yellow = moderate fatigue, Red = needs rest',
          style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
        ),
        const SizedBox(height: 16),
        
        // Muscle body diagram
        _BodyDiagram(heatMap: heatMap, useIntensity: false),
        
        const SizedBox(height: 16),
        
        // Detailed list
        const Text('Details', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...MuscleGroup.values.map((muscle) {
          final data = heatMap[muscle];
          if (data == null) return const SizedBox.shrink();
          return _MuscleListTile(
            muscle: muscle,
            data: data,
            showFatigue: true,
          );
        }),
      ],
    );
  }
}

class _VolumeView extends StatelessWidget {
  const _VolumeView({required this.heatMap});

  final Map<MuscleGroup, MuscleHeatData> heatMap;

  @override
  Widget build(BuildContext context) {
    // Group by category
    final pushMuscles = MuscleGroup.values.where((m) => m.category == 'Push').toList();
    final pullMuscles = MuscleGroup.values.where((m) => m.category == 'Pull').toList();
    final legMuscles = MuscleGroup.values.where((m) => m.category == 'Legs').toList();
    final coreMuscles = MuscleGroup.values.where((m) => m.category == 'Core').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Training Volume', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 8),
        const Text(
          'Blue = undertrained, Green = optimal, Orange/Red = high volume',
          style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
        ),
        const SizedBox(height: 16),
        
        _BodyDiagram(heatMap: heatMap, useIntensity: true),
        
        const SizedBox(height: 16),
        
        // Volume bars by category
        _CategorySection(title: 'Push', muscles: pushMuscles, heatMap: heatMap),
        _CategorySection(title: 'Pull', muscles: pullMuscles, heatMap: heatMap),
        _CategorySection(title: 'Legs', muscles: legMuscles, heatMap: heatMap),
        _CategorySection(title: 'Core', muscles: coreMuscles, heatMap: heatMap),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.muscles,
    required this.heatMap,
  });

  final String title;
  final List<MuscleGroup> muscles;
  final Map<MuscleGroup, MuscleHeatData> heatMap;

  @override
  Widget build(BuildContext context) {
    return AppCardSpaced(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...muscles.map((muscle) {
            final data = heatMap[muscle];
            final intensity = data?.intensity ?? 0;
            final sets = data?.sets ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(muscle.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Text('$sets sets', style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (intensity / 2.0).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: const Color(0x22FFFFFF),
                      color: Color(data?.intensityColorValue ?? 0xFF4CAF50),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ComparisonView extends StatelessWidget {
  const _ComparisonView({
    required this.comparison,
    required this.profile,
    required this.onEditProfile,
  });

  final Map<MuscleGroup, double> comparison;
  final UserProfile? profile;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return Center(
        child: AppCardSpaced(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_add, size: 48, color: Color(0x88FFFFFF)),
              const SizedBox(height: 16),
              const Text(
                'Set up your profile to compare\nyour strength to average lifters',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xAAFFFFFF)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onEditProfile,
                icon: const Icon(Icons.person_add),
                label: const Text('Create Profile'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile summary
        AppCardSpaced(
          child: Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFF7C7CFF),
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile!.age} years, ${profile!.gender}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${profile!.weightKg.toStringAsFixed(1)} kg, ${profile!.heightCm.toStringAsFixed(0)} cm',
                      style: const TextStyle(color: Color(0xAAFFFFFF)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: onEditProfile,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        const Text('Strength vs Average', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 8),
        const Text(
          'How your estimated 1RM compares to average lifters with similar profile.\n'
          '100% = average, >100% = above average',
          style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
        ),
        const SizedBox(height: 16),
        
        ...MuscleGroup.values.map((muscle) {
          final ratio = comparison[muscle] ?? 0;
          final percentage = (ratio * 100).round();
          return AppCardSpaced(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(muscle.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    _PerformanceBadge(percentage: percentage),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (ratio / 2.0).clamp(0.0, 1.0), // Scale so 200% fills bar
                    minHeight: 8,
                    backgroundColor: const Color(0x22FFFFFF),
                    color: _getComparisonColor(ratio),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('0%', style: TextStyle(fontSize: 10, color: Color(0x66FFFFFF))),
                    Text('100%', style: TextStyle(fontSize: 10, color: Color(0x66FFFFFF))),
                    Text('200%', style: TextStyle(fontSize: 10, color: Color(0x66FFFFFF))),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _getComparisonColor(double ratio) {
    if (ratio < 0.5) return const Color(0xFFF44336); // Red - below average
    if (ratio < 0.8) return const Color(0xFFFF9800); // Orange - approaching average
    if (ratio < 1.2) return const Color(0xFF4CAF50); // Green - around average
    return const Color(0xFF2196F3); // Blue - above average
  }
}

class _PerformanceBadge extends StatelessWidget {
  const _PerformanceBadge({required this.percentage});

  final int percentage;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    
    if (percentage == 0) {
      color = const Color(0x66FFFFFF);
      label = 'No data';
    } else if (percentage < 50) {
      color = const Color(0xFFF44336);
      label = '$percentage%';
    } else if (percentage < 80) {
      color = const Color(0xFFFF9800);
      label = '$percentage%';
    } else if (percentage < 120) {
      color = const Color(0xFF4CAF50);
      label = '$percentage%';
    } else {
      color = const Color(0xFF2196F3);
      label = '$percentage%';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _BodyDiagram extends StatelessWidget {
  const _BodyDiagram({
    required this.heatMap,
    required this.useIntensity,
  });

  final Map<MuscleGroup, MuscleHeatData> heatMap;
  final bool useIntensity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        children: [
          // Upper body row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MuscleBox(
                label: 'Shoulders',
                data: heatMap[MuscleGroup.shoulders],
                useIntensity: useIntensity,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MuscleBox(
                label: 'Biceps',
                data: heatMap[MuscleGroup.biceps],
                useIntensity: useIntensity,
                small: true,
              ),
              const SizedBox(width: 8),
              _MuscleBox(
                label: 'Chest',
                data: heatMap[MuscleGroup.chest],
                useIntensity: useIntensity,
              ),
              const SizedBox(width: 8),
              _MuscleBox(
                label: 'Back',
                data: heatMap[MuscleGroup.back],
                useIntensity: useIntensity,
              ),
              const SizedBox(width: 8),
              _MuscleBox(
                label: 'Triceps',
                data: heatMap[MuscleGroup.triceps],
                useIntensity: useIntensity,
                small: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Core
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MuscleBox(
                label: 'Core',
                data: heatMap[MuscleGroup.core],
                useIntensity: useIntensity,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Lower body row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MuscleBox(
                label: 'Glutes',
                data: heatMap[MuscleGroup.glutes],
                useIntensity: useIntensity,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MuscleBox(
                label: 'Quads',
                data: heatMap[MuscleGroup.quads],
                useIntensity: useIntensity,
              ),
              const SizedBox(width: 8),
              _MuscleBox(
                label: 'Hamstrings',
                data: heatMap[MuscleGroup.hamstrings],
                useIntensity: useIntensity,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MuscleBox(
                label: 'Calves',
                data: heatMap[MuscleGroup.calves],
                useIntensity: useIntensity,
                small: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MuscleBox extends StatelessWidget {
  const _MuscleBox({
    required this.label,
    required this.data,
    required this.useIntensity,
    this.small = false,
  });

  final String label;
  final MuscleHeatData? data;
  final bool useIntensity;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final colorValue = data != null
        ? (useIntensity ? data!.intensityColorValue : data!.fatigueColorValue)
        : 0xFF424242;
    final color = Color(colorValue);
    final width = small ? 60.0 : 80.0;
    final height = small ? 50.0 : 60.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.7), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: small ? 9 : 10,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          if (data != null)
            Text(
              '${data!.sets}',
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: small ? 11 : 12,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}

class _MuscleListTile extends StatelessWidget {
  const _MuscleListTile({
    required this.muscle,
    required this.data,
    required this.showFatigue,
  });

  final MuscleGroup muscle;
  final MuscleHeatData data;
  final bool showFatigue;

  String _formatLastWorked(DateTime? lastWorked) {
    if (lastWorked == null) return 'Not trained';
    final now = DateTime.now();
    final diff = now.difference(lastWorked);
    if (diff.inHours < 24) return 'Today';
    if (diff.inHours < 48) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final colorValue = showFatigue ? data.fatigueColorValue : data.intensityColorValue;
    final color = Color(colorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF070707),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(muscle.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  '${data.sets} sets • ${_formatLastWorked(data.lastWorked)}',
                  style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                showFatigue
                    ? '${(data.fatigue * 100).round()}% fatigue'
                    : '${(data.intensity * 100).round()}% volume',
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
              ),
              if (data.bestWeight > 0)
                Text(
                  'Best: ${data.bestWeight.toStringAsFixed(1)} kg',
                  style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({this.currentProfile});

  final UserProfile? currentProfile;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late TextEditingController _age;
  late TextEditingController _weight;
  late TextEditingController _height;
  String _gender = 'male';

  @override
  void initState() {
    super.initState();
    final p = widget.currentProfile;
    _age = TextEditingController(text: (p?.age ?? 25).toString());
    _weight = TextEditingController(text: (p?.weightKg ?? 70).toStringAsFixed(1));
    _height = TextEditingController(text: (p?.heightCm ?? 170).toStringAsFixed(0));
    _gender = p?.gender ?? 'male';
  }

  @override
  void dispose() {
    _age.dispose();
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This helps compare your strength to average lifters with a similar profile.',
              style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _age,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Age (years)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _height,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Height (cm)'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _gender,
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
              ],
              onChanged: (v) => setState(() => _gender = v ?? 'male'),
              decoration: const InputDecoration(labelText: 'Gender'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final age = int.tryParse(_age.text) ?? 25;
            final weight = double.tryParse(_weight.text.replaceAll(',', '.')) ?? 70;
            final height = double.tryParse(_height.text.replaceAll(',', '.')) ?? 170;
            Navigator.pop(
              context,
              UserProfile(
                age: age.clamp(10, 100),
                weightKg: weight.clamp(30, 300),
                heightCm: height.clamp(100, 250),
                gender: _gender,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// Using shared AppCardSpaced widget from app_card.dart
