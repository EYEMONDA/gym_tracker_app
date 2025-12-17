import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';
import '../widgets/animated_widgets.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals & Achievements'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Goals'),
            Tab(text: 'Achievements'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // Goals Tab
          _GoalsTab(app: app),
          
          // Achievements Tab
          _AchievementsTab(app: app),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGoalDialog(context, app),
        icon: const Icon(Icons.add),
        label: const Text('New Goal'),
      ),
    );
  }

  Future<void> _showAddGoalDialog(BuildContext context, AppState app) async {
    final result = await showDialog<FitnessGoal>(
      context: context,
      builder: (_) => const _AddGoalDialog(),
    );
    if (result != null) {
      await app.addFitnessGoal(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Goal "${result.title}" created!')),
        );
      }
    }
  }
}

class _GoalsTab extends StatelessWidget {
  const _GoalsTab({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final activeGoals = app.activeGoals;
    final completedGoals = app.completedGoals;

    if (app.fitnessGoals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BounceIn(
                child: Icon(Icons.flag_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
              ),
              const SizedBox(height: 16),
              StaggeredListItem(
                index: 0,
                child: const Text(
                  'No goals yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              StaggeredListItem(
                index: 1,
                child: const Text(
                  'Set fitness goals with milestones to track your progress and stay motivated.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xAAFFFFFF)),
                ),
              ),
              const SizedBox(height: 24),
              StaggeredListItem(
                index: 2,
                child: PulsingGlow(
                  glowColor: const Color(0xFF4CAF50),
                  maxRadius: 6,
                  child: const Text(
                    'Tap the + button to create your first goal',
                    style: TextStyle(color: Color(0x88FFFFFF), fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    int itemIndex = 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (activeGoals.isNotEmpty) ...[
          StaggeredListItem(
            index: itemIndex++,
            child: const Text('Active Goals', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          const SizedBox(height: 12),
          ...activeGoals.map((goal) => StaggeredListItem(
            index: itemIndex++,
            child: _GoalCard(goal: goal, app: app),
          )),
        ],
        if (completedGoals.isNotEmpty) ...[
          const SizedBox(height: 24),
          StaggeredListItem(
            index: itemIndex++,
            child: const Text('Completed', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          const SizedBox(height: 12),
          ...completedGoals.map((goal) => StaggeredListItem(
            index: itemIndex++,
            child: _GoalCard(goal: goal, app: app, isCompleted: true),
          )),
        ],
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.app,
    this.isCompleted = false,
  });

  final FitnessGoal goal;
  final AppState app;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final progress = app.getGoalProgress(goal);
    final completedCount = goal.milestones.where((m) => m.isCompleted).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF070707),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted 
              ? const Color(0xFF4CAF50).withOpacity(0.3)
              : const Color(0x22FFFFFF),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getCategoryColor(goal.category).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            IconData(goal.category.iconCodePoint, fontFamily: 'MaterialIcons'),
            color: _getCategoryColor(goal.category),
            size: 20,
          ),
        ),
        title: Text(
          goal.title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? const Color(0x88FFFFFF) : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '$completedCount / ${goal.milestones.length} milestones',
              style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
            ),
            const SizedBox(height: 6),
            AnimatedProgressBar(
              value: progress,
              height: 6,
              backgroundColor: const Color(0x22FFFFFF),
              valueColor: isCompleted ? const Color(0xFF4CAF50) : _getCategoryColor(goal.category),
            ),
          ],
        ),
        children: [
          if (goal.description.isNotEmpty) ...[
            Text(
              goal.description,
              style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],
          const Text('Milestones', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...List.generate(goal.milestones.length, (index) {
            final milestone = goal.milestones[index];
            return _MilestoneTile(
              milestone: milestone,
              onToggle: () => app.toggleMilestoneComplete(goal.id, index),
            );
          }),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete Goal?'),
                      content: Text('Are you sure you want to delete "${goal.title}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await app.removeFitnessGoal(goal.id);
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(GoalCategory category) {
    switch (category) {
      case GoalCategory.strength:
        return const Color(0xFFF44336);
      case GoalCategory.endurance:
        return const Color(0xFF2196F3);
      case GoalCategory.weightLoss:
        return const Color(0xFFFF9800);
      case GoalCategory.muscleGain:
        return const Color(0xFF9C27B0);
      case GoalCategory.flexibility:
        return const Color(0xFF00BCD4);
      case GoalCategory.consistency:
        return const Color(0xFF4CAF50);
      case GoalCategory.custom:
        return const Color(0xFF607D8B);
    }
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({
    required this.milestone,
    required this.onToggle,
  });

  final GoalMilestone milestone;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: milestone.isCompleted 
              ? const Color(0xFF4CAF50).withOpacity(0.1)
              : const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: milestone.isCompleted 
                ? const Color(0xFF4CAF50).withOpacity(0.3)
                : const Color(0x11FFFFFF),
          ),
        ),
        child: Row(
          children: [
            Icon(
              milestone.isCompleted 
                  ? Icons.check_circle 
                  : Icons.radio_button_unchecked,
              color: milestone.isCompleted 
                  ? const Color(0xFF4CAF50)
                  : const Color(0x66FFFFFF),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestone.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: milestone.isCompleted 
                          ? TextDecoration.lineThrough 
                          : null,
                      color: milestone.isCompleted 
                          ? const Color(0x88FFFFFF) 
                          : null,
                    ),
                  ),
                  if (milestone.targetValue > 0)
                    Text(
                      '${milestone.targetValue.toStringAsFixed(milestone.targetValue == milestone.targetValue.roundToDouble() ? 0 : 1)} ${milestone.unit}',
                      style: const TextStyle(
                        color: Color(0xAAFFFFFF),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (milestone.isCompleted && milestone.completedAt != null)
              Text(
                _formatDate(milestone.completedAt!),
                style: const TextStyle(
                  color: Color(0x66FFFFFF),
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.month}/${d.day}';
  }
}

class _AchievementsTab extends StatefulWidget {
  const _AchievementsTab({required this.app});

  final AppState app;

  @override
  State<_AchievementsTab> createState() => _AchievementsTabState();
}

class _AchievementsTabState extends State<_AchievementsTab> {
  bool _showCelebration = false;

  void _triggerCelebration() {
    setState(() => _showCelebration = true);
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final achievements = AppState.achievements;
    final unlockedCount = widget.app.unlockedAchievements.length;
    final totalCount = achievements.length;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Progress summary with animations
            StaggeredListItem(
              index: 0,
              child: ScaleTap(
                onTap: unlockedCount > 0 ? _triggerCelebration : null,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A1A2E), Color(0xFF0A0A0A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x33FFD700)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          BounceIn(
                            delay: const Duration(milliseconds: 200),
                            child: PulsingGlow(
                              glowColor: const Color(0xFFFFD700),
                              enabled: unlockedCount > 0,
                              maxRadius: 8,
                              child: const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 32),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    AnimatedNumber(
                                      value: unlockedCount.toDouble(),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                                    ),
                                    Text(
                                      ' / $totalCount Unlocked',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                                    ),
                                  ],
                                ),
                                Text(
                                  unlockedCount == 0
                                      ? 'Start working out to unlock achievements!'
                                      : unlockedCount == totalCount
                                          ? '🎉 Congratulations! All unlocked!'
                                          : 'Tap to celebrate! Keep going!',
                                  style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AnimatedProgressBar(
                        value: totalCount > 0 ? unlockedCount / totalCount : 0,
                        height: 10,
                        valueColor: const Color(0xFFFFD700),
                        backgroundColor: const Color(0x33FFFFFF),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            StaggeredListItem(
              index: 1,
              child: const Text('Achievements', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.95,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: achievements.length,
              itemBuilder: (context, index) {
                final achievement = achievements[index];
                final isUnlocked = widget.app.isAchievementUnlocked(achievement.id);
                final progress = widget.app.getAchievementProgress(achievement.id);
                return StaggeredListItem(
                  index: index + 2,
                  child: _AchievementCard(
                    achievement: achievement,
                    isUnlocked: isUnlocked,
                    progress: progress,
                  ),
                );
              },
            ),
          ],
        ),
        // Celebration overlay
        if (_showCelebration)
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiCelebration(
                particleCount: 80,
                duration: const Duration(seconds: 3),
                onComplete: () {
                  if (mounted) setState(() => _showCelebration = false);
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.achievement,
    required this.isUnlocked,
    required this.progress,
  });

  final Achievement achievement;
  final bool isUnlocked;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final icon = IconData(achievement.iconCodePoint, fontFamily: 'MaterialIcons');
    
    return ScaleTap(
      onTap: () {
        // Show achievement details
        showDialog(
          context: context,
          builder: (_) => _AchievementDetailDialog(
            achievement: achievement,
            isUnlocked: isUnlocked,
            progress: progress,
          ),
        );
      },
      child: _buildCard(icon),
    );
  }

  Widget _buildCard(IconData icon) {
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnlocked 
            ? const Color(0xFF1A1A2E)
            : const Color(0xFF070707),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked 
              ? const Color(0xFFFFD700).withOpacity(0.4)
              : const Color(0x22FFFFFF),
          width: isUnlocked ? 2 : 1,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.15),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Progress ring (when not unlocked)
              if (!isUnlocked)
                SizedBox(
                  width: 52,
                  height: 52,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: const Color(0x22FFFFFF),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                  ),
                ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isUnlocked 
                      ? const Color(0xFFFFD700).withOpacity(0.2)
                      : const Color(0x22FFFFFF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isUnlocked ? icon : Icons.lock,
                  color: isUnlocked 
                      ? const Color(0xFFFFD700)
                      : const Color(0x66FFFFFF),
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: isUnlocked 
                  ? Colors.white
                  : const Color(0x88FFFFFF),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            achievement.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: isUnlocked 
                  ? const Color(0xAAFFFFFF)
                  : const Color(0x66FFFFFF),
            ),
          ),
          if (!isUnlocked && progress > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4CAF50),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AchievementDetailDialog extends StatelessWidget {
  const _AchievementDetailDialog({
    required this.achievement,
    required this.isUnlocked,
    required this.progress,
  });

  final Achievement achievement;
  final bool isUnlocked;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final icon = IconData(achievement.iconCodePoint, fontFamily: 'MaterialIcons');
    
    return Dialog(
      backgroundColor: const Color(0xFF0A0A0A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with animation
            BounceIn(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? const Color(0xFFFFD700).withOpacity(0.2)
                      : const Color(0x22FFFFFF),
                  shape: BoxShape.circle,
                  boxShadow: isUnlocked
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isUnlocked ? icon : Icons.lock,
                  color: isUnlocked ? const Color(0xFFFFD700) : const Color(0x66FFFFFF),
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              achievement.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              achievement.description,
              style: const TextStyle(
                color: Color(0xAAFFFFFF),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Progress or unlocked status
            if (isUnlocked) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Unlocked!',
                      style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Progress: ',
                        style: TextStyle(color: Color(0xAAFFFFFF)),
                      ),
                      AnimatedNumber(
                        value: progress * 100,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4CAF50),
                        ),
                        suffix: '%',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 200,
                    child: AnimatedProgressBar(
                      value: progress,
                      height: 8,
                      valueColor: const Color(0xFF4CAF50),
                      backgroundColor: const Color(0x33FFFFFF),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            // Close button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddGoalDialog extends StatefulWidget {
  const _AddGoalDialog();

  @override
  State<_AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends State<_AddGoalDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  GoalCategory _category = GoalCategory.strength;
  final List<_MilestoneDraft> _milestones = [];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  String _generateId() {
    final r = Random.secure();
    final bytes = List<int>.generate(8, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Goal'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Goal Title'),
                autofocus: true,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<GoalCategory>(
                value: _category,
                items: GoalCategory.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.displayName),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? GoalCategory.strength),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Milestones', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _milestones.add(_MilestoneDraft());
                      });
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (_milestones.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Add milestones to track progress toward your goal.',
                    style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
                  ),
                )
              else
                ...List.generate(_milestones.length, (index) {
                  return _MilestoneInput(
                    milestone: _milestones[index],
                    onRemove: () => setState(() => _milestones.removeAt(index)),
                  );
                }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _title.text.trim().isEmpty
              ? null
              : () {
                  final goal = FitnessGoal(
                    id: _generateId(),
                    title: _title.text.trim(),
                    description: _description.text.trim(),
                    category: _category,
                    milestones: _milestones
                        .where((m) => m.title.text.trim().isNotEmpty)
                        .map((m) => GoalMilestone(
                              title: m.title.text.trim(),
                              targetValue: double.tryParse(m.value.text) ?? 0,
                              unit: m.unit.text.trim(),
                              isCompleted: false,
                            ))
                        .toList(),
                    createdAt: DateTime.now(),
                  );
                  Navigator.pop(context, goal);
                },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _MilestoneDraft {
  final title = TextEditingController();
  final value = TextEditingController();
  final unit = TextEditingController();
}

class _MilestoneInput extends StatelessWidget {
  const _MilestoneInput({
    required this.milestone,
    required this.onRemove,
  });

  final _MilestoneDraft milestone;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x08FFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x11FFFFFF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: milestone.title,
                  decoration: const InputDecoration(
                    labelText: 'Milestone',
                    hintText: 'e.g., Bench 100kg',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: milestone.value,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Target (optional)',
                    hintText: '100',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: milestone.unit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    hintText: 'kg',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
