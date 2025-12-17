import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final smartId = app.smartId ?? '…';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 78, 16, 24),
        children: [
          const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Offline-first. No login. Your data stays local unless you export it (coming next).',
            style: TextStyle(color: Color(0xAAFFFFFF)),
          ),
          const SizedBox(height: 18),
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
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
                const Text('Default rest timer', style: TextStyle(fontWeight: FontWeight.w800)),
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
                  'Tip: tap the Dynamic Island to start quick rests anytime.',
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
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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

