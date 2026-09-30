import 'dart:math';

import '../models/crafting.dart';
import '../models/enums.dart';
import '../models/equipment.dart';
import '../models/hunter.dart';
import '../models/potion.dart';
import '../models/quest.dart';
import 'combat.dart';
import 'game_config.dart';
import 'random_utils.dart';

class QuestResult {
  const QuestResult({
    required this.success,
    required this.successChance,
    required this.gold,
    required this.expEach,
    this.fameEach = 0,
    this.rankUps = const {},
    this.fameLost = const {},
    required this.deaths,
    required this.levelUps,
    required this.damageTaken,
    required this.healed,
    required this.potionsUsed,
    required this.brokenItems,
    required this.destroyedItems,
    required this.loot,
    required this.battleLog,
    required this.rounds,
  });

  final bool success;
  final double successChance;
  final int gold;
  final int expEach;

  /// Fame mỗi hunter sống sót nhận (0 nếu thất bại) và những ai vừa lên hạng.
  final int fameEach;
  final Map<Hunter, QuestTier> rankUps;

  /// Fame bị mất do thua quest thăng hạng.
  final Map<Hunter, int> fameLost;
  final List<Hunter> deaths;

  /// Hunter còn sống -> số cấp vừa lên.
  final Map<Hunter, int> levelUps;

  /// Hunter còn sống -> máu mất / máu được healer hồi.
  final Map<Hunter, double> damageTaken;
  final Map<Hunter, double> healed;

  /// Hunter còn sống -> các bình máu đã uống.
  final Map<Hunter, List<Potion>> potionsUsed;

  /// Đồ "sửa được" vừa hỏng / đồ "bền chắc" vừa vỡ vụn.
  final Map<Hunter, List<Equipment>> brokenItems;
  final Map<Hunter, List<Equipment>> destroyedItems;

  /// Hunter còn sống -> nguyên liệu nhặt được (cấp theo tier quest).
  final Map<Hunter, Map<Resource, int>> loot;

  /// Diễn biến trận đánh theo lượt.
  final List<String> battleLog;
  final int rounds;
}

class BattleEstimate {
  const BattleEstimate({required this.winRate, required this.deathRisk});

  final double winRate;

  /// Xác suất chết của từng hunter (gộp cả khả năng bị gục và tung tỉ lệ chết).
  final Map<Hunter, double> deathRisk;
}

class QuestResolver {
  QuestResolver(this._random);

  final Random _random;

  /// Trả về lý do không thể xuất phát, hoặc null nếu đội hợp lệ.
  static String? validateParty(Quest quest, List<Hunter> party) {
    if (party.length < quest.minParty) return 'Cần ít nhất ${quest.minParty} hunter';
    if (party.length > quest.maxParty) return 'Tối đa ${quest.maxParty} hunter';
    if (quest.promotionFor case final ownerId? when party.any((h) => h.id != ownerId)) {
      return 'Quest thăng hạng chỉ dành riêng cho 1 hunter';
    }
    if (party.any((h) => h.level < quest.tier.minLevel)) {
      return 'Mọi hunter phải đạt cấp ${quest.tier.minLevel}';
    }
    final lowRank = party.where((h) => h.maxQuestTier.index < quest.tier.index).firstOrNull;
    if (lowRank != null) {
      return '${lowRank.name} hạng ${lowRank.rank.label} chỉ nhận được quest tới tier ${lowRank.maxQuestTier.label}';
    }
    final patient = party.where((h) => h.inHospital).firstOrNull;
    if (patient != null) return '${patient.name} đang nằm viện';
    final away = party.where((h) => h.onQuest).firstOrNull;
    if (away != null) return '${away.name} đang đi làm nhiệm vụ';
    return null;
  }

  /// Tỉ lệ chết của hunter bị gục trong trận. Healer khác còn đứng vững cuối trận giúp cứu mạng.
  static double downedDeathChance(Hunter h, Quest quest, {required bool won, required int standingHealers}) {
    var chance = GameConfig.downedDeathBase + quest.tier.baseDeathChance;
    if (!won) chance *= GameConfig.lostDeathMultiplier;
    chance *= 1 + max(0, h.age - GameConfig.agingStartAge) * GameConfig.agingDeathPerYear;
    chance *= pow(GameConfig.healerDeathMultiplier, standingHealers);
    return chance.clamp(0.0, 0.95);
  }

  static int _standingHealers(Hunter h, List<Hunter> party, Set<Hunter> downed) =>
      party.where((o) => o != h && o.hunterClass == HunterClass.healer && !downed.contains(o)).length;

  /// Mô phỏng nhiều trận (không đụng dữ liệu thật) để ước tính tỉ lệ thắng và rủi ro chết của từng hunter.
  /// Dùng random cố định theo quest để con số không nhảy lung tung mỗi lần vẽ lại màn hình.
  static BattleEstimate estimate(Quest quest, List<Hunter> party, {int runs = GameConfig.estimateRuns}) {
    if (party.isEmpty) return const BattleEstimate(winRate: 0, deathRisk: {});
    final engine = CombatEngine(Random(quest.id));
    var wins = 0;
    final risk = {for (final h in party) h: 0.0};
    for (var i = 0; i < runs; i++) {
      final battle = engine.fight(quest, party, recordLog: false);
      if (battle.win) wins++;
      for (final h in battle.downed) {
        risk[h] =
            risk[h]! +
            downedDeathChance(h, quest, won: battle.win, standingHealers: _standingHealers(h, party, battle.downed));
      }
    }
    return BattleEstimate(
      winRate: wins / runs,
      deathRisk: {for (final MapEntry(key: h, value: r) in risk.entries) h: r / runs},
    );
  }

  QuestResult resolve(Quest quest, List<Hunter> party) {
    final chance = estimate(quest, party).winRate;
    final battle = CombatEngine(_random).fight(quest, party);
    final success = battle.win;
    final deaths = [
      for (final h in battle.downed)
        if (_random.nextDouble() <
            downedDeathChance(h, quest, won: success, standingHealers: _standingHealers(h, party, battle.downed)))
          h,
    ];
    final survivors = party.where((h) => !deaths.contains(h)).toList();

    // Máu sau trận; ai bị gục mà sống sót thì còn 1 máu.
    final damageTaken = <Hunter, double>{};
    for (final h in survivors) {
      final before = h.hp;
      h.hp = max(1, battle.hpAfter[h]!);
      damageTaken[h] = max(0, before - h.hp);
    }
    for (final h in deaths) {
      h.hp = 0;
    }

    // Healer sống sót hồi máu cho cả đội sau quest nhóm.
    final healed = <Hunter, double>{};
    if (quest.isGroup) {
      for (final healer in survivors.where((h) => h.hunterClass == HunterClass.healer)) {
        for (final h in survivors) {
          final before = h.hp;
          h.heal(h.maxHp * healer.rarity.healPercent);
          healed[h] = (healed[h] ?? 0) + h.hp - before;
        }
      }
    }

    // Trang bị bị mòn sau trận (thua thì mòn nhiều hơn).
    final brokenItems = <Hunter, List<Equipment>>{};
    final destroyedItems = <Hunter, List<Equipment>>{};
    for (final h in survivors) {
      for (final MapEntry(key: slot, value: item) in h.equipment.entries.toList()) {
        if (item.isBroken) continue; // đồ hỏng không được dùng nên không mòn thêm
        final failFactor = success ? 1.0 : GameConfig.failDamageMultiplier;
        item.condition = max(
          0,
          item.condition - GameConfig.conditionWearPerQuest * randomBetween(_random, 0.5, 1.5) * failFactor,
        );
        item.durability = max(
          0,
          item.durability - GameConfig.durabilityWearPerQuest * randomBetween(_random, 0.5, 1.5) * failFactor,
        );
        if (item.isDestroyed) {
          h.unequip(slot);
          (destroyedItems[h] ??= []).add(item);
        } else if (item.isBroken) {
          (brokenItems[h] ??= []).add(item);
        }
      }
      h.hp = min(h.hp, h.maxHp); // giáp hỏng làm giảm máu tối đa
    }

    // Nhặt nguyên liệu: quest săn lấy từ quái, quest thu thập khai thác tài nguyên của khu (nhiều hơn hẳn).
    final loot = <Hunter, Map<Resource, int>>{};
    final (minLoot, maxLoot) = GameConfig.lootPerHunter[quest.tier]!;
    for (final h in survivors) {
      var count = (minLoot + _random.nextInt(maxLoot - minLoot + 1)).toDouble();
      if (quest.isGathering) {
        count *= GameConfig.gatheringLootMultiplier;
      } else if (quest.isHorde) {
        count *= GameConfig.hordeLootMultiplier;
      }
      if (!success) count *= GameConfig.failLootMultiplier;
      final drops = quest.isGathering ? quest.location.gatherables : quest.monster.drops;
      final bag = <Resource, int>{};
      for (var i = 0; i < count.round(); i++) {
        final resource = drops[_random.nextInt(drops.length)];
        bag[resource] = (bag[resource] ?? 0) + 1;
      }
      if (bag.isNotEmpty) loot[h] = bag;
    }

    // Bình máu đã uống trong trận (không mất lượt) bị trừ khỏi túi thật, kể cả của người ngã xuống.
    final potionsUsed = <Hunter, List<Potion>>{};
    for (final MapEntry(key: h, value: used) in battle.potionsUsed.entries) {
      used.forEach(h.potions.remove);
      potionsUsed[h] = List.of(used);
    }
    // Sau trận, máu còn dưới ngưỡng nhập viện thì uống thêm (bình nhỏ trước).
    for (final h in survivors) {
      h.potions.sort((a, b) => a.index.compareTo(b.index));
      while (h.hpRatio < GameConfig.hospitalThreshold && h.potions.isNotEmpty) {
        final potion = h.potions.removeAt(0);
        h.heal(h.maxHp * potion.healPercent);
        (potionsUsed[h] ??= []).add(potion);
      }
    }

    final expEach = success ? quest.exp : (quest.exp * GameConfig.failExpRate).round();
    final levelUps = <Hunter, int>{};
    final baseFame = GameConfig.questFame[quest.tier]!;
    // Quest thăng hạng không cho fame: thắng thì lên hạng, thua thì mất một phần fame.
    final fameEach = !success || quest.isPromotion
        ? 0
        : (quest.isGathering ? (baseFame * GameConfig.gatheringReputationRate).ceil() : baseFame);
    final rankUps = <Hunter, QuestTier>{};
    final fameLost = <Hunter, int>{};
    for (final h in survivors) {
      h.completeQuest();
      levelUps[h] = h.gainExp(expEach);
      h.gainFame(fameEach);
      if (quest.isPromotion) {
        if (success) {
          h.promote();
          rankUps[h] = h.rank;
        } else {
          fameLost[h] = h.failPromotion();
        }
      }
    }
    return QuestResult(
      success: success,
      successChance: chance,
      gold: success ? quest.gold : 0,
      expEach: expEach,
      fameEach: fameEach,
      rankUps: rankUps,
      fameLost: fameLost,
      deaths: deaths,
      levelUps: levelUps,
      damageTaken: damageTaken,
      healed: healed,
      potionsUsed: potionsUsed,
      brokenItems: brokenItems,
      destroyedItems: destroyedItems,
      loot: loot,
      battleLog: battle.log,
      rounds: battle.rounds,
    );
  }
}
