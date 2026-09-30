// ignore_for_file: avoid_print
// Mô phỏng hàng nghìn trận để cân bằng combat.
// Chạy: dart run tool/calibrate.dart
import 'dart:math';

import 'package:game/logic/combat.dart';
import 'package:game/logic/game_config.dart';
import 'package:game/models/enums.dart';
import 'package:game/models/equipment.dart';
import 'package:game/models/hunter.dart';
import 'package:game/models/quest.dart';
import 'package:game/models/world_map.dart';

const runs = 400;

Hunter makeHunter(HunterClass c, int level, {bool gear = false, int skill = 0}) {
  final h = Hunter(
    id: c.index,
    name: c.label,
    hunterClass: c,
    rarity: Rarity.common,
    age: 25,
    stats: GameConfig.classBaseStats[c]!,
    personalSkillIndex: skill,
  );
  while (h.level < level) {
    h.gainExp(h.expToNext);
  }
  if (gear) {
    final grade = ItemGrade.values.lastWhere((g) => g.minLevel <= level);
    final weapon = switch (c) {
      HunterClass.mage || HunterClass.healer => ItemType.staff,
      HunterClass.ranger => ItemType.bow,
      _ => ItemType.sword,
    };
    h.equip(Equipment.standard(id: 1, type: weapon, grade: grade));
    h.equip(Equipment.standard(id: 2, type: ItemType.leatherArmor, grade: grade));
    if (c == HunterClass.tank || c == HunterClass.warrior) {
      h.equip(Equipment.standard(id: 3, type: ItemType.shield, grade: grade));
    }
  }
  h.hp = h.maxHp;
  return h;
}

Quest makeQuest(QuestTier tier, {required bool horde, required bool group}) {
  final minParty = !group ? 1 : (tier.index >= QuestTier.a.index ? 3 : 2);
  final partyFactor = group ? minParty + 0.5 : 1.0;
  return Quest(
    id: 1,
    location: Location.grassland,
    tier: tier,
    monster: MonsterType.beast,
    isHorde: horde,
    isGroup: group,
    minParty: minParty,
    maxParty: 4,
    difficulty: tier.difficulty * partyFactor,
    gold: 0,
    exp: 0,
  );
}

({double win, double hpLoss, double downed, double rounds}) simulate(Quest q, List<Hunter> Function() party) {
  final engine = CombatEngine(Random(42));
  var wins = 0, downed = 0, units = 0, rounds = 0;
  var hpLoss = 0.0;
  for (var i = 0; i < runs; i++) {
    final p = party();
    final r = engine.fight(q, p, recordLog: false);
    if (r.win) wins++;
    rounds += r.rounds;
    for (final h in p) {
      units++;
      if (r.downed.contains(h)) downed++;
      hpLoss += (h.hp - r.hpAfter[h]!) / h.maxHp;
    }
  }
  return (win: wins / runs, hpLoss: hpLoss / units, downed: downed / units, rounds: rounds / runs);
}

String pct(double v) => '${(v * 100).round()}%'.padLeft(4);

void main() {
  print('Mô phỏng $runs trận/ô. Hunter thường, cấp = cấp tối thiểu tier + 2. Cột: thắng / mất máu / bị gục / số lượt');
  for (final gear in [false, true]) {
    print('\n=== ${gear ? 'CÓ trang bị đúng cấp' : 'KHÔNG trang bị'} ===');
    for (final tier in QuestTier.values) {
      final level = tier.minLevel + 2;
      final buffer = StringBuffer('${tier.label.padRight(3)} Lv${level.toString().padRight(3)}');
      for (final horde in [false, true]) {
        // Solo: trung bình các lớp.
        var win = 0.0, loss = 0.0, down = 0.0;
        for (final c in HunterClass.values) {
          final s = simulate(makeQuest(tier, horde: horde, group: false), () => [makeHunter(c, level, gear: gear)]);
          win += s.win / 5;
          loss += s.hpLoss / 5;
          down += s.downed / 5;
        }
        buffer.write(' | solo ${horde ? 'đông' : 'ít '} ${pct(win)} ${pct(loss)} ${pct(down)}');
      }
      for (final horde in [false, true]) {
        final q = makeQuest(tier, horde: horde, group: true);
        final classes = [HunterClass.warrior, HunterClass.healer, HunterClass.mage, HunterClass.tank];
        final s = simulate(q, () => [for (final c in classes.take(q.minParty)) makeHunter(c, level, gear: gear)]);
        buffer.write(' | nhóm ${horde ? 'đông' : 'ít '} ${pct(s.win)} ${pct(s.hpLoss)} ${pct(s.downed)} ${s.rounds.toStringAsFixed(1)}L');
      }
      print(buffer);
    }
  }

  print('\n=== Theo lớp (tier C, solo, không trang bị): quái ít / quái đông ===');
  for (final c in HunterClass.values) {
    final level = QuestTier.c.minLevel + 2;
    final few = simulate(makeQuest(QuestTier.c, horde: false, group: false), () => [makeHunter(c, level)]);
    final many = simulate(makeQuest(QuestTier.c, horde: true, group: false), () => [makeHunter(c, level)]);
    print('${c.label.padRight(11)} ít ${pct(few.win)} · đông ${pct(many.win)}');
  }
}
