// ignore_for_file: avoid_print
import 'dart:math';

import 'package:game/logic/game_config.dart';
import 'package:game/logic/quest_generator.dart';
import 'package:game/logic/quest_resolver.dart';
import 'package:game/models/enums.dart';
import 'package:game/models/hunter.dart';

/// Tỉ lệ thắng quest thăng hạng theo lớp, hunter thường, không trang bị, cấp = cấp tối thiểu tier + 2.
void main() {
  final random = Random(1);
  final generator = QuestGenerator(random);
  for (final tier in QuestTier.values.skip(1)) {
    final cells = <String>[];
    for (final c in HunterClass.values) {
      var wins = 0;
      const runs = 300;
      for (var i = 0; i < runs; i++) {
        final h = Hunter(
          id: 1,
          name: c.label,
          hunterClass: c,
          rarity: Rarity.common,
          age: 25,
          stats: GameConfig.classBaseStats[c]!,
          personalSkillIndex: random.nextInt(3),
        );
        while (h.level < tier.minLevel + 2) {
          h.gainExp(h.expToNext);
        }
        h
          ..hp = h.maxHp
          ..rank = QuestTier.values[tier.index - 1]
          ..fame = Hunter.fameForRank(tier);
        final q = generator.generatePromotion(i, h);
        if (QuestResolver(random).resolve(q, [h]).success) wins++;
      }
      cells.add('${c.label.padRight(10)} ${(wins * 100 / runs).round().toString().padLeft(3)}%');
    }
    print('${tier.label.padRight(3)} | ${cells.join(' | ')}');
  }
}
