import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../screens/log_screen.dart';

class DynamicIsland extends StatefulWidget {
  const DynamicIsland({super.key});

  @override
  State<DynamicIsland> createState() => _DynamicIslandState();
}

class _DynamicIslandState extends State<DynamicIsland> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatMMSS(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final rest = app.restTimer;
    final hits = app.searchAll(app.searchQuery);

    // Keep controller aligned when state changes from elsewhere.
    if (_controller.text != app.searchQuery) {
      _controller.value = TextEditingValue(
        text: app.searchQuery,
        selection: TextSelection.collapsed(offset: app.searchQuery.length),
      );
    }

    final size = MediaQuery.sizeOf(context);
    final maxWidth = min(560, size.width - 24);
    final collapsedWidth = min(220, size.width - 24);
    final expanded = app.isSearchExpanded;

    final baseHeight = 42.0;
    final expandedHeight = min(260.0, size.height * 0.35);
    final height = expanded ? expandedHeight : baseHeight;
    final width = expanded ? maxWidth : collapsedWidth;

    final showRest = rest.isRunning && !expanded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: const Color(0xCC0A0A0A),
            child: InkWell(
              onTap: () {
                app.setSearchExpanded(true);
                _focusNode.requestFocus();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          showRest ? Icons.timer : Icons.search,
                          size: 18,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            child: expanded
                                ? TextField(
                                    key: const ValueKey('dynamic_island_search'),
                                    controller: _controller,
                                    focusNode: _focusNode,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Search exercises, sessions…',
                                      hintStyle: TextStyle(color: Color(0x88FFFFFF)),
                                      isDense: true,
                                      border: InputBorder.none,
                                    ),
                                    onChanged: app.setSearchQuery,
                                  )
                                : Text(
                                    showRest
                                        ? 'Rest ${_formatMMSS(rest.remaining)}'
                                        : (app.searchQuery.trim().isEmpty
                                            ? 'Search'
                                            : app.searchQuery),
                                    key: const ValueKey('dynamic_island_title'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (rest.isRunning && expanded)
                          Text(
                            _formatMMSS(rest.remaining),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (expanded)
                          IconButton(
                            tooltip: 'Close',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              app.setSearchExpanded(false);
                              _focusNode.unfocus();
                            },
                          )
                        else if (rest.isRunning)
                          IconButton(
                            tooltip: 'Stop timer',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: const Icon(Icons.stop_circle_outlined, size: 18),
                            onPressed: app.stopRestTimer,
                          ),
                      ],
                    ),
                    if (expanded) ...[
                      const SizedBox(height: 10),
                      _QuickActionsRow(onPickRest: (s) => app.startRestTimer(seconds: s)),
                      const SizedBox(height: 10),
                      if (hits.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              app.searchQuery.trim().isEmpty
                                  ? 'Type to search. Try “bench” or “legs”.'
                                  : 'No matches.',
                              style: const TextStyle(color: Color(0x88FFFFFF)),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: hits.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x22FFFFFF)),
                            itemBuilder: (context, index) {
                              final h = hits[index];
                              return ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                                leading: Icon(
                                  h.kind == SearchHitKind.exercise ? Icons.fitness_center : Icons.history,
                                  size: 18,
                                  color: const Color(0xCCFFFFFF),
                                ),
                                title: Text(
                                  h.kind == SearchHitKind.exercise ? (h.name ?? '') : (h.title ?? ''),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  h.kind == SearchHitKind.exercise ? 'Add to workout' : 'Open session',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 12),
                                ),
                                onTap: () {
                                  if (h.kind == SearchHitKind.exercise) {
                                    if (app.activeSession == null) {
                                      app.startWorkout(title: 'Workout');
                                    }
                                    app.addExerciseToActive(h.name ?? '');
                                    app.setSearchExpanded(false);
                                    _focusNode.unfocus();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added “${h.name}”'),
                                        duration: const Duration(milliseconds: 900),
                                      ),
                                    );
                                  } else if (h.kind == SearchHitKind.session) {
                                    final id = h.sessionId;
                                    if (id == null) return;
                                    final session = app.sessions.where((s) => s.id == id).cast<WorkoutSession?>().firstOrNull;
                                    if (session == null) return;
                                    app.setSearchExpanded(false);
                                    _focusNode.unfocus();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => SessionDetailScreen(session: session),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.onPickRest});

  final void Function(int seconds) onPickRest;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PillButton(
          label: '30s',
          onTap: () => onPickRest(30),
        ),
        const SizedBox(width: 8),
        _PillButton(
          label: '60s',
          onTap: () => onPickRest(60),
        ),
        const SizedBox(width: 8),
        _PillButton(
          label: '90s',
          onTap: () => onPickRest(90),
        ),
        const SizedBox(width: 8),
        _PillButton(
          label: '2m',
          onTap: () => onPickRest(120),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x22FFFFFF)),
          color: const Color(0x11000000),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

