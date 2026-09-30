import 'dart:math';

import '../models/enums.dart';
import '../models/hunter.dart';
import '../models/skill.dart';
import 'game_config.dart';
import 'random_utils.dart';

class HunterFactory {
  HunterFactory(this._random);

  final Random _random;

  /// Trọng số độ hiếm (tổng 1000): [rareBonus] tỉ lệ chuyển từ Thường sang Sử thi (3/4) và Huyền thoại (1/4);
  /// sau đó tỉ lệ Hiếm trở lên nhân [rareRate] (phần bớt đi trả về Thường).
  static int rarityWeight(Rarity r, double rareBonus, {double rareRate = 1}) {
    final bonus = rareBonus * 1000;
    double raw(Rarity r) => switch (r) {
      Rarity.common => r.weight * 10 - bonus,
      Rarity.rare => r.weight * 10.0,
      Rarity.epic => r.weight * 10 + bonus * 0.75,
      Rarity.legendary => r.weight * 10 + bonus * 0.25,
    };
    if (r != Rarity.common) return (raw(r) * rareRate).round();
    final rares = Rarity.values.skip(1).fold(0, (s, x) => s + (raw(x) * rareRate).round());
    return 1000 - rares;
  }

  Hunter create(int id, {Rarity? rarity, double rareBonus = 0, double rareRate = 1, bool young = false}) {
    final hunterClass = HunterClass.values[_random.nextInt(HunterClass.values.length)];
    final names = GameConfig.hunterNames;
    return Hunter(
      id: id,
      name: names[_random.nextInt(names.length)],
      hunterClass: hunterClass,
      rarity: rarity ?? pickWeighted(Rarity.values, (r) => rarityWeight(r, rareBonus, rareRate: rareRate), _random),
      age: young
          ? GameConfig.recruitMinAge + _random.nextInt(GameConfig.recruitMaxAge - GameConfig.recruitMinAge + 1)
          : 18 + _random.nextInt(28),
      stats: GameConfig.classBaseStats[hunterClass]! * randomBetween(_random, 0.9, 1.1),
      personalSkillIndex: _random.nextInt(classSkillPools[hunterClass]!.length),
    );
  }
}
