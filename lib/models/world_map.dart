import 'dart:math';

import '../logic/game_config.dart';
import 'enums.dart';

/// Các địa điểm trên bản đồ; thị trấn luôn ở trung tâm.
enum Location {
  town('Thị trấn', monsters: [], minTier: QuestTier.d, maxTier: QuestTier.d),
  grassland('Đồng cỏ', monsters: [MonsterType.beast], minTier: QuestTier.d, maxTier: QuestTier.c),
  goblinCave('Hang goblin', monsters: [MonsterType.goblin], minTier: QuestTier.d, maxTier: QuestTier.c),
  beach('Bãi biển', monsters: [MonsterType.seaBeast], minTier: QuestTier.c, maxTier: QuestTier.b),
  mine('Hầm mỏ', monsters: [MonsterType.golem, MonsterType.goblin], minTier: QuestTier.c, maxTier: QuestTier.b),
  elfForest('Rừng elf', monsters: [MonsterType.spirit], minTier: QuestTier.c, maxTier: QuestTier.b),
  rockyCanyon('Hẻm đá', monsters: [MonsterType.golem, MonsterType.harpy], minTier: QuestTier.b, maxTier: QuestTier.a),
  monsterForest(
    'Rừng ma vật',
    monsters: [MonsterType.beast, MonsterType.demon],
    minTier: QuestTier.b,
    maxTier: QuestTier.a,
  ),
  snowMountain(
    'Núi tuyết',
    monsters: [MonsterType.yeti, MonsterType.harpy],
    minTier: QuestTier.a,
    maxTier: QuestTier.s,
  ),
  dungeon(
    'Dungeon',
    monsters: [MonsterType.golem, MonsterType.spirit, MonsterType.demon, MonsterType.goblin],
    minTier: QuestTier.a,
    maxTier: QuestTier.sss,
  ),
  empire(
    'Đế quốc láng giềng',
    monsters: [MonsterType.soldier, MonsterType.demon],
    minTier: QuestTier.s,
    maxTier: QuestTier.sss,
  );

  const Location(this.label, {required this.monsters, required this.minTier, required this.maxTier});

  final String label;
  final List<MonsterType> monsters;
  final QuestTier minTier;
  final QuestTier maxTier;

  static List<Location> get regions => values.where((l) => l != town).toList();

  bool supports(QuestTier tier) => this != town && tier.index >= minTier.index && tier.index <= maxTier.index;

  /// 0 (an toàn nhất) .. 1 (nguy hiểm nhất), dùng để đặt khu nguy hiểm xa thị trấn hơn.
  double get danger => minTier.index / (QuestTier.values.length - 1);
}

/// Bản đồ của một lượt chơi: vị trí các khu (0..1) và đường đi giữa chúng (tính bằng số buổi).
class WorldMap {
  WorldMap({required this.positions, required this.edges});

  /// Sinh bản đồ ngẫu nhiên: khu nguy hiểm có xu hướng nằm xa hơn, nhưng hướng và đường nối mỗi game mỗi khác.
  factory WorldMap.generate(Random random) {
    final positions = <Location, Point<double>>{Location.town: const Point(0.5, 0.5)};
    final regions = Location.regions..shuffle(random);
    final slice = 2 * pi / regions.length;
    final startAngle = random.nextDouble() * 2 * pi;
    for (final (i, region) in regions.indexed) {
      final angle = startAngle + i * slice + (random.nextDouble() - 0.5) * slice * 0.6;
      final radius = 0.2 + region.danger * 0.15 + random.nextDouble() * 0.1;
      positions[region] = Point(0.5 + radius * cos(angle), 0.5 + radius * sin(angle));
    }

    final edges = <Location, Map<Location, int>>{for (final l in Location.values) l: {}};
    void connect(Location a, Location b) {
      final time = max(1, (positions[a]!.distanceTo(positions[b]!) / GameConfig.mapDistancePerPhase).round());
      edges[a]![b] = time;
      edges[b]![a] = time;
    }

    // Cây khung: từ gần tới xa, mỗi khu nối với điểm gần nhất đã được nối -> luôn đi tới được mọi khu.
    final byDistance = Location.regions
      ..sort(
        (a, b) => positions[a]!
            .distanceTo(positions[Location.town]!)
            .compareTo(positions[b]!.distanceTo(positions[Location.town]!)),
      );
    final connected = [Location.town];
    for (final region in byDistance) {
      final nearest = connected.reduce(
        (a, b) => positions[a]!.distanceTo(positions[region]!) <= positions[b]!.distanceTo(positions[region]!) ? a : b,
      );
      connect(region, nearest);
      connected.add(region);
    }
    // Thêm vài đường tắt giữa các khu gần nhau để có nhiều lối đi.
    for (final a in Location.regions) {
      for (final b in Location.regions) {
        if (a.index >= b.index || edges[a]!.containsKey(b)) continue;
        if (positions[a]!.distanceTo(positions[b]!) < GameConfig.mapShortcutDistance && random.nextBool()) {
          connect(a, b);
        }
      }
    }
    return WorldMap(positions: positions, edges: edges);
  }

  factory WorldMap.fromJson(Map<String, dynamic> j) => WorldMap(
    positions: {
      for (final MapEntry(key: name, value: p) in (j['positions'] as Map<String, dynamic>).entries)
        Location.values.byName(name): Point(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()),
    },
    edges: {
      for (final l in Location.values) l: {},
      for (final MapEntry(key: from, value: targets) in (j['edges'] as Map<String, dynamic>).entries)
        Location.values.byName(from): {
          for (final MapEntry(key: to, value: time) in (targets as Map<String, dynamic>).entries)
            Location.values.byName(to): time as int,
        },
    },
  );

  Map<String, dynamic> toJson() => {
    'positions': {
      for (final MapEntry(key: l, value: p) in positions.entries) l.name: [p.x, p.y],
    },
    'edges': {
      for (final MapEntry(key: from, value: targets) in edges.entries)
        from.name: {for (final MapEntry(key: to, value: time) in targets.entries) to.name: time},
    },
  };

  final Map<Location, Point<double>> positions;
  final Map<Location, Map<Location, int>> edges;

  /// Đường đi nhanh nhất (Dijkstra), gồm cả điểm đầu và điểm cuối.
  List<Location> path(Location from, Location to) {
    final dist = {for (final l in Location.values) l: 1 << 30};
    final prev = <Location, Location>{};
    final open = Location.values.toSet();
    dist[from] = 0;
    while (open.isNotEmpty) {
      final current = open.reduce((a, b) => dist[a]! <= dist[b]! ? a : b);
      open.remove(current);
      if (current == to) break;
      for (final MapEntry(key: next, value: time) in edges[current]!.entries) {
        if (dist[current]! + time < dist[next]!) {
          dist[next] = dist[current]! + time;
          prev[next] = current;
        }
      }
    }
    final result = [to];
    while (result.first != from) {
      result.insert(0, prev[result.first]!);
    }
    return result;
  }

  /// Số buổi đi từ [from] tới [to] theo đường nhanh nhất.
  int travelTime(Location from, Location to) {
    final route = path(from, to);
    var total = 0;
    for (var i = 0; i + 1 < route.length; i++) {
      total += edges[route[i]]![route[i + 1]]!;
    }
    return total;
  }

  /// Vị trí (0..1) sau khi đi được [elapsed] buổi dọc theo [route].
  Point<double> pointAlong(List<Location> route, double elapsed) {
    var remaining = elapsed;
    for (var i = 0; i + 1 < route.length; i++) {
      final time = edges[route[i]]![route[i + 1]]!;
      if (remaining <= time) {
        final a = positions[route[i]]!;
        final b = positions[route[i + 1]]!;
        return a + (b - a) * (remaining / time);
      }
      remaining -= time;
    }
    return positions[route.last]!;
  }
}
