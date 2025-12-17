import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../state/app_state.dart';

class MapRoutesScreen extends StatelessWidget {
  const MapRoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.experimentalMapEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Map (Experimental)')),
        body: const Center(
          child: Text('Enable the Map experimental feature in Settings first.'),
        ),
      );
    }

    final routes = List<MapRoute>.of(app.mapRoutes)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final logs = List<RouteActivityLog>.of(app.routeActivityLogs)
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map (Experimental)'),
        actions: [
          IconButton(
            tooltip: 'New route',
            onPressed: () async {
              final draft = await Navigator.of(context).push<_RouteDraft>(
                MaterialPageRoute(builder: (_) => const RouteEditorScreen()),
              );
              if (draft == null) return;
              await app.addMapRoute(
                name: draft.name,
                activityType: draft.activityType,
                points: draft.points,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Route saved.')));
              }
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Experimental', style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text(
                  'This map uses online tiles and may impact performance on some devices.',
                  style: TextStyle(color: Color(0xAAFFFFFF)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('Routes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (routes.isEmpty)
            const _Card(
              child: Text('No routes yet. Tap + to create one.', style: TextStyle(color: Color(0xAAFFFFFF))),
            )
          else
            ...routes.map((r) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF070707),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x22FFFFFF)),
                ),
                child: ListTile(
                  title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    '${r.activityType.label} • ${r.points.length} pts',
                    style: const TextStyle(color: Color(0xAAFFFFFF)),
                  ),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      FilledButton.tonal(
                        onPressed: () async {
                          final picked = await showDialog<RouteActivityType>(
                            context: context,
                            builder: (_) => _PickActivityDialog(defaultType: r.activityType),
                          );
                          if (picked == null) return;
                          await app.logRouteActivity(routeId: r.id, activityType: picked);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Logged ${picked.label} on “${r.name}”.')),
                            );
                          }
                        },
                        child: const Text('Use'),
                      ),
                      PopupMenuButton<String>(
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'view', child: Text('View')),
                          PopupMenuDivider(),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                        onSelected: (v) async {
                          if (v == 'view') {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => RouteViewerScreen(route: r)),
                            );
                          } else if (v == 'delete') {
                            await app.deleteMapRoute(r.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          Text('Recent route activity', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (logs.isEmpty)
            const _Card(
              child: Text('No route activity yet.', style: TextStyle(color: Color(0xAAFFFFFF))),
            )
          else
            ...logs.take(15).map((l) {
              final routeName = app.mapRoutes.where((r) => r.id == l.routeId).cast<MapRoute?>().firstOrNull?.name ?? 'Route';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(routeName, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${l.activityType.label} • ${_fmtDateTime(l.startedAt)}',
                  style: const TextStyle(color: Color(0xAAFFFFFF)),
                ),
              );
            }),
        ],
      ),
    );
  }

  static String _fmtDateTime(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$m-$day $hh:$mm';
  }
}

class RouteViewerScreen extends StatelessWidget {
  const RouteViewerScreen({required this.route, super.key});

  final MapRoute route;

  @override
  Widget build(BuildContext context) {
    final points = route.points.map((p) => LatLng(p.lat, p.lng)).toList();
    final center = points.isEmpty ? const LatLng(0, 0) : points[0];

    return Scaffold(
      appBar: AppBar(title: Text(route.name)),
      body: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 13),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.gym_tracker_app',
          ),
          if (points.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(points: points, strokeWidth: 4, color: const Color(0xFF7C7CFF)),
              ],
            ),
          MarkerLayer(
            markers: points.map((p) {
              return Marker(
                point: p,
                width: 12,
                height: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D17A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class RouteEditorScreen extends StatefulWidget {
  const RouteEditorScreen({super.key});

  @override
  State<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

class _RouteEditorScreenState extends State<RouteEditorScreen> {
  final MapController _map = MapController();
  final TextEditingController _name = TextEditingController(text: 'My Route');
  RouteActivityType _type = RouteActivityType.walk;
  final List<LatLng> _points = [];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _points.isEmpty ? const LatLng(37.7749, -122.4194) : _points.last;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create route'),
        actions: [
          TextButton(
            onPressed: _points.length < 2
                ? null
                : () {
                    Navigator.of(context).pop(
                      _RouteDraft(
                        name: _name.text,
                        activityType: _type,
                        points: _points.map((p) => MapPoint(lat: p.latitude, lng: p.longitude)).toList(),
                      ),
                    );
                  },
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Route name'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<RouteActivityType>(
                  value: _type,
                  items: RouteActivityType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) => setState(() => _type = v ?? RouteActivityType.walk),
                  decoration: const InputDecoration(labelText: 'Default activity'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _points.isEmpty ? null : () => setState(() => _points.removeLast()),
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _points.isEmpty ? null : () => setState(() => _points.clear()),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear'),
                    ),
                    const Spacer(),
                    Text(
                      '${_points.length} pt${_points.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: Color(0xAAFFFFFF)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap the map to drop points. Save requires 2+ points.',
                  style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13,
                onTap: (tapPosition, point) => setState(() => _points.add(point)),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.gym_tracker_app',
                ),
                if (_points.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(points: _points, strokeWidth: 4, color: const Color(0xFF7C7CFF)),
                    ],
                  ),
                MarkerLayer(
                  markers: _points.map((p) {
                    return Marker(
                      point: p,
                      width: 14,
                      height: 14,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D17A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xAA000000)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickActivityDialog extends StatelessWidget {
  const _PickActivityDialog({required this.defaultType});

  final RouteActivityType defaultType;

  @override
  Widget build(BuildContext context) {
    RouteActivityType selected = defaultType;
    return AlertDialog(
      title: const Text('Use route as…'),
      content: StatefulBuilder(
        builder: (context, setState) {
          return DropdownButtonFormField<RouteActivityType>(
            value: selected,
            items: RouteActivityType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (v) => setState(() => selected = v ?? defaultType),
            decoration: const InputDecoration(labelText: 'Activity'),
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, selected), child: const Text('Log')),
      ],
    );
  }
}

class _RouteDraft {
  const _RouteDraft({required this.name, required this.activityType, required this.points});
  final String name;
  final RouteActivityType activityType;
  final List<MapPoint> points;
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

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

