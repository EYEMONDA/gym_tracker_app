import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';
import 'map_routes_screen.dart';
import 'muscle_heat_map_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

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
    final smartId = app.smartId ?? '…';

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 78, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                SizedBox(height: 8),
                Text(
                  'Offline-first. No login. Your data stays local unless you export it (coming next).',
                  style: TextStyle(color: Color(0xAAFFFFFF)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'General'),
                Tab(text: 'Experimental'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Smart ID (encrypted)', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(
                            smartId,
                            style: const TextStyle(color: Color(0xDDFFFFFF), fontFamily: 'monospace'),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: smartId));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Copied Smart ID')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await showDialog<void>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Regenerate Smart ID?'),
                                      content: const Text(
                                        'This changes your local identifier. Your workout logs stay on-device.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () async {
                                            await app.clearLocalData(regenerateSmartId: true);
                                            if (context.mounted) Navigator.pop(context);
                                          },
                                          child: const Text('Regenerate'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text('Regenerate'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dynamic Island Focus Mode', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          const Text(
                            'When a workout is active, the Island morphs into a quick logger (one-tap “Add set”).',
                            style: TextStyle(color: Color(0xAAFFFFFF)),
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: app.focusModeEnabled,
                            onChanged: (v) => app.setFocusModeEnabled(v),
                            title: const Text('Enable Focus Mode'),
                            subtitle: const Text('Green glow = active workout • Amber glow = rest timer'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tap Assist', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          const Text(
                            'Increases touch targets without changing the visual layout (helps reduce missed taps).',
                            style: TextStyle(color: Color(0xAAFFFFFF)),
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: app.tapAssistEnabled,
                            onChanged: (v) => app.setTapAssistEnabled(v),
                            title: const Text('Enable Tap Assist'),
                            subtitle: const Text('Recommended on phones.'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Smart Rest Timer', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          const Text(
                            'Automatically adjusts rest time based on exercise type (compound vs isolation).',
                            style: TextStyle(color: Color(0xAAFFFFFF)),
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: app.smartRestEnabled,
                            onChanged: (v) => app.setSmartRestEnabled(v),
                            title: const Text('Enable Smart Rest'),
                            subtitle: const Text('Compound: 2:30 • Isolation: 1:15'),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: app.restTimerAlertsEnabled,
                            onChanged: (v) => app.setRestTimerAlertsEnabled(v),
                            title: const Text('Timer Alerts'),
                            subtitle: const Text('Vibrate when rest timer completes'),
                          ),
                          const SizedBox(height: 10),
                          const Text('Default rest timer (when Smart Rest is off)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(
                            '${app.defaultRestSeconds}s',
                            style: const TextStyle(color: Color(0xAAFFFFFF)),
                          ),
                          Slider(
                            min: 30,
                            max: 240,
                            divisions: 7,
                            value: app.defaultRestSeconds.toDouble().clamp(30, 240),
                            onChanged: (v) => app.setDefaultRestSeconds(v.round()),
                          ),
                          const Text(
                            'Tip: swipe down on the Dynamic Island to start a quick rest.',
                            style: TextStyle(color: Color(0xAAFFFFFF)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Superset Mode', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          const Text(
                            'Auto-cycle between paired exercises after logging each set. Great for supersets and circuits.',
                            style: TextStyle(color: Color(0xAAFFFFFF)),
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: app.supersetModeEnabled,
                            onChanged: (v) => app.setSupersetModeEnabled(v),
                            title: const Text('Enable Superset Mode'),
                            subtitle: const Text('Cyan glow when active • Long-press exercises to pair'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Local data', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(
                            '${app.sessions.length} saved session(s)',
                            style: const TextStyle(color: Color(0xAAFFFFFF)),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              await showDialog<void>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Reset all local data?'),
                                  content: const Text('This will delete your saved sessions on this device/browser.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () async {
                                        await app.clearLocalData(regenerateSmartId: false);
                                        if (context.mounted) Navigator.pop(context);
                                      },
                                      child: const Text('Reset'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('Reset'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Experimental Features', style: TextStyle(fontWeight: FontWeight.w900)),
                          SizedBox(height: 6),
                          Text(
                            'These features may be unstable, slower, or crash on some devices.',
                            style: TextStyle(color: Color(0xAAFFFFFF)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Map + Routes (experimental)', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          const Text(
                            'Create routes by tapping points on a map, then log usage as walk/jog/bike.',
                            style: TextStyle(color: Color(0xAAFFFFFF)),
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: app.experimentalMapEnabled,
                            onChanged: (v) => app.setExperimentalMapEnabled(v),
                            title: const Text('Enable Map'),
                            subtitle: const Text('Uses online tiles (network).'),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.tonalIcon(
                            onPressed: app.experimentalMapEnabled
                                ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const MapRoutesScreen()),
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Open Map'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Muscle Heat Map (experimental)', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          const Text(
                            'Visualize muscle fatigue and training volume. Compare your strength to average lifters with similar profile.',
                            style: TextStyle(color: Color(0xAAFFFFFF)),
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: app.experimentalHeatMapEnabled,
                            onChanged: (v) => app.setExperimentalHeatMapEnabled(v),
                            title: const Text('Enable Heat Map'),
                            subtitle: const Text('Track muscle recovery & progress.'),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.tonalIcon(
                            onPressed: app.experimentalHeatMapEnabled
                                ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const MuscleHeatMapScreen()),
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.local_fire_department_outlined),
                            label: const Text('Open Heat Map'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF070707),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: child,
    );
  }
}

