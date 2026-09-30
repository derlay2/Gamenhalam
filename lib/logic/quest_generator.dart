import 'dart:math';

import '../models/enums.dart';
import '../models/hunter.dart';
import '../models/quest.dart';
import '../models/world_map.dart';
import 'game_config.dart';
import 'random_utils.dart';

class QuestGenerator {
  QuestGenerator(this._random);

  final Random _random;

  /// Kiểu quái trong quest thăng hạng, đúng sở trường của lớp: true = quái đông, false = đầu lĩnh.
  bool promotionHorde(HunterClass c) => switch (c) {
    HunterClass.mage => true, // đánh lan dọn bầy
    HunterClass.tank => true, // gánh đòn của cả bầy
    HunterClass.ranger => false, // bắn hạ mục tiêu lớn
    HunterClass.healer => false, // trụ bền trước đầu lĩnh
    HunterClass.warrior => _random.nextBool(), // cân bằng
  };

  /// Quest thăng hạng riêng: solo, lên hạng kế tiếp của [hunter], kiểu quái hợp với lớp.
  Quest generatePromotion(int id, Hunter hunter) {
    final tier = hunter.nextRank!;
    final locations = Location.regions.where((l) => l.supports(tier)).toList();
    final location = locations[_random.nextInt(locations.length)];
    final variance = randomBetween(_random, 0.95, 1.05);
    return Quest(
      id: id,
      location: location,
      tier: tier,
      monster: location.monsters[_random.nextInt(location.monsters.length)],
      isHorde: promotionHorde(hunter.hunterClass),
      isGroup: false,
      minParty: 1,
      maxParty: 1,
      difficulty: tier.difficulty * variance * GameConfig.promotionDifficultyRate[hunter.hunterClass]!,
      gold: tier.gold,
      exp: tier.exp,
      promotionFor: hunter.id,
    );
  }

  /// [maxTier]: tier cao nhất thị trấn đã mở khóa.
  Quest generate(int id, {QuestTier maxTier = QuestTier.sss}) {
    // Chọn tier theo tỉ lệ chung trước, rồi chọn khu có quest tier đó -> giữ đúng tỉ lệ D/C/B/A/S/SSS.
    final tiers = QuestTier.values.where((t) => t.index <= maxTier.index).toList();
    final tier = pickWeighted(tiers, (t) => t.weight, _random);
    final locations = Location.regions.where((l) => l.supports(tier)).toList();
    final location = locations[_random.nextInt(locations.length)];
    final isGroup = _random.nextDouble() < GameConfig.groupQuestChance;
    final minParty = !isGroup ? 1 : (tier.index >= QuestTier.a.index ? 3 : 2);
    final variance = randomBetween(_random, 0.85, 1.15);
    // Quest nhóm khó hơn tổng sức của số người tối thiểu một chút.
    final partyFactor = isGroup ? minParty + 0.5 : 1.0;
    final isGathering = _random.nextDouble() < GameConfig.gatheringQuestChance;
    final (difficultyRate, goldRate, expRate) = isGathering
        ? (GameConfig.gatheringDifficultyRate, GameConfig.gatheringGoldRate, GameConfig.gatheringExpRate)
        : (1.0, 1.0, 1.0);

    return Quest(
      id: id,
      location: location,
      tier: tier,
      monster: location.monsters[_random.nextInt(location.monsters.length)],
      isHorde: _random.nextBool(),
      isGroup: isGroup,
      minParty: minParty,
      maxParty: isGroup ? GameConfig.maxParty : 1,
      difficulty: tier.difficulty * partyFactor * variance * difficultyRate,
      gold: (tier.gold * partyFactor * variance * goldRate).round(),
      exp: (tier.exp * (isGroup ? 1.2 : 1.0) * expRate).round(),
      isGathering: isGathering,
    );
  }
}
