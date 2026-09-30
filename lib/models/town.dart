import 'enums.dart';

/// Cấp thị trấn, nâng/hạ theo danh tiếng.
enum TownRank {
  d('D', minReputation: 0, maxQuestTier: QuestTier.d, rareHunterBonus: 0, lootUpgradeChance: 0),
  c('C', minReputation: 60, maxQuestTier: QuestTier.c, rareHunterBonus: 0.02, lootUpgradeChance: 0.02),
  b('B', minReputation: 250, maxQuestTier: QuestTier.b, rareHunterBonus: 0.04, lootUpgradeChance: 0.04),
  a('A', minReputation: 700, maxQuestTier: QuestTier.a, rareHunterBonus: 0.06, lootUpgradeChance: 0.06),
  s('S', minReputation: 1800, maxQuestTier: QuestTier.sss, rareHunterBonus: 0.08, lootUpgradeChance: 0.08);

  const TownRank(
    this.label, {
    required this.minReputation,
    required this.maxQuestTier,
    required this.rareHunterBonus,
    required this.lootUpgradeChance,
  });

  final String label;
  final int minReputation;

  /// Quest khó nhất xuất hiện trên bảng.
  final QuestTier maxQuestTier;

  /// Tỉ lệ (tính trên tổng) chuyển từ hunter Thường sang Sử thi/Huyền thoại khi phát giấy mời.
  final double rareHunterBonus;

  /// Xác suất mỗi lô nguyên liệu rơi cao hơn 1 cấp.
  final double lootUpgradeChance;

  TownRank? get next => index + 1 < values.length ? values[index + 1] : null;

  static TownRank of(int reputation) => values.lastWhere((r) => reputation >= r.minReputation);
}

/// Lý do game kết thúc.
enum GameOverReason {
  bankrupt('Phá sản', 'Quỹ guild cạn kiệt và không còn gì để bán đủ tiền phát 1 giấy mời.'),
  abandoned('Thị trấn hoang phế', 'Không còn hunter nào và guild không đủ tiền chiêu mộ người mới.');

  const GameOverReason(this.label, this.description);
  final String label;
  final String description;
}
