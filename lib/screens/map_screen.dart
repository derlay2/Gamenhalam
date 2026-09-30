import 'dart:math';

import 'package:flutter/material.dart';

import '../logic/game_state.dart';
import '../models/day.dart';
import '../models/world_map.dart';
import '../widgets/visuals.dart';
import 'quest_board_screen.dart';
import 'quest_detail_screen.dart';

/// Bản đồ: thị trấn ở giữa, các khu xung quanh, đường đi (số buổi) và vị trí các đội.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key, required this.game});

  final GameState game;

  void _showLocation(BuildContext context, Location location) {
    final quests = game.quests.where((q) => q.location == location).toList();
    final teams = game.expeditions.where((e) => e.quest.location == location).toList();
    final travel = game.map.travelTime(Location.town, location);
    final route = game.map.path(Location.town, location).map((l) => l.label).join(' → ');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(12),
          children: [
            ListTile(
              leading: Icon(location.icon, color: location.dangerColor, size: 32),
              title: Text(location.label, style: Theme.of(context).textTheme.titleLarge),
              subtitle: location == Location.town
                  ? const Text('Trung tâm – nơi guild đóng quân')
                  : Text(
                      'Quest ${location.minTier.label}–${location.maxTier.label} · '
                      '${location.monsters.map((m) => m.label).join(', ')}\n'
                      'Đi $travel buổi: $route',
                    ),
            ),
            if (teams.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.all(8), child: Text('Đội hướng tới đây')),
              for (final e in teams)
                ListTile(
                  leading: const Icon(Icons.directions_walk),
                  title: Text(e.party.map((h) => h.name).join(', ')),
                  subtitle: Text(e.statusAt(game.now)),
                ),
            ],
            if (location != Location.town) ...[
              Padding(padding: const EdgeInsets.all(8), child: Text('Quest ở đây (${quests.length})')),
              if (quests.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Hiện không có quest.')),
              for (final q in quests)
                QuestCard(
                  quest: q,
                  map: game.map,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => QuestDetailScreen(game: game, quest: q),
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text('Bản đồ · ${describePhase(game.now)}')),
        body: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final side = min(constraints.maxWidth, constraints.maxHeight);
                  return InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 3,
                    child: Center(
                      child: SizedBox.square(
                        dimension: side,
                        child: _MapCanvas(game: game, side: side, onTap: _showLocation),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (game.expeditions.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final e in game.expeditions)
                      ListTile(
                        dense: true,
                        leading: Icon(_stageIcon(e.stageAt(game.now))),
                        title: Text(
                          '[${e.quest.tier.label}] ${e.quest.title} · ${e.party.map((h) => h.name).join(', ')}',
                        ),
                        subtitle: Text(e.statusAt(game.now)),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

IconData _stageIcon(ExpeditionStage stage) => switch (stage) {
  ExpeditionStage.outbound => Icons.directions_walk,
  ExpeditionStage.fighting => Icons.sports_martial_arts,
  ExpeditionStage.returning => Icons.keyboard_return,
};

class _MapCanvas extends StatelessWidget {
  const _MapCanvas({required this.game, required this.side, required this.onTap});

  final GameState game;
  final double side;
  final void Function(BuildContext, Location) onTap;

  static const _nodeWidth = 84.0;

  @override
  Widget build(BuildContext context) {
    final map = game.map;
    final colors = Theme.of(context).colorScheme;
    Offset toCanvas(Point<double> p) => Offset(p.x * side, p.y * side);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _RoadPainter(
              map: map,
              side: side,
              roadColor: colors.outlineVariant,
              labelColor: colors.onSurfaceVariant,
              activeRoutes: [for (final e in game.expeditions) e.route],
              activeColor: colors.primary,
            ),
          ),
        ),
        for (final location in Location.values)
          Positioned(
            left: toCanvas(map.positions[location]!).dx - _nodeWidth / 2,
            top: toCanvas(map.positions[location]!).dy - 22,
            width: _nodeWidth,
            child: _LocationNode(
              location: location,
              questCount: game.quests.where((q) => q.location == location).length,
              onTap: () => onTap(context, location),
            ),
          ),
        for (final (i, e) in game.expeditions.indexed)
          Builder(
            builder: (_) {
              final point = toCanvas(map.pointAlong(e.route, e.distanceAlongRoute(game.now)));
              // Lệch nhẹ để các đội cùng chỗ không đè lên nhau.
              final nudge = Offset(12.0 * (i % 3) - 12, -26.0 - 10 * (i ~/ 3));
              return Positioned(
                left: point.dx + nudge.dx - 14,
                top: point.dy + nudge.dy,
                child: Tooltip(
                  message: '${e.party.map((h) => h.name).join(', ')}\n${e.statusAt(game.now)}',
                  triggerMode: TooltipTriggerMode.tap,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    child: Icon(_stageIcon(e.stageAt(game.now)), size: 16),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _LocationNode extends StatelessWidget {
  const _LocationNode({required this.location, required this.questCount, required this.onTap});

  final Location location;
  final int questCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = location.dangerColor;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Badge(
            isLabelVisible: questCount > 0,
            label: Text('$questCount'),
            child: CircleAvatar(
              radius: location == Location.town ? 24 : 20,
              backgroundColor: color.withValues(alpha: 0.2),
              foregroundColor: color,
              child: Icon(location.icon),
            ),
          ),
          Text(
            location.label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  _RoadPainter({
    required this.map,
    required this.side,
    required this.roadColor,
    required this.labelColor,
    required this.activeRoutes,
    required this.activeColor,
  });

  final WorldMap map;
  final double side;
  final Color roadColor;
  final Color labelColor;
  final List<List<Location>> activeRoutes;
  final Color activeColor;

  Offset _at(Location l) => Offset(map.positions[l]!.x * side, map.positions[l]!.y * side);

  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = roadColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..color = activeColor.withValues(alpha: 0.6)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    for (final MapEntry(key: from, value: targets) in map.edges.entries) {
      for (final MapEntry(key: to, value: time) in targets.entries) {
        if (from.index > to.index) continue; // mỗi đường vẽ 1 lần
        final a = _at(from);
        final b = _at(to);
        canvas.drawLine(a, b, road);
        final label = TextPainter(
          text: TextSpan(
            text: '$time',
            style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, (a + b) / 2 - Offset(label.width / 2, label.height / 2));
      }
    }
    for (final route in activeRoutes) {
      for (var i = 0; i + 1 < route.length; i++) {
        canvas.drawLine(_at(route[i]), _at(route[i + 1]), active);
      }
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => true;
}
