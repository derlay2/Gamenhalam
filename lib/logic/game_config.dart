import 'dart:math';

import '../models/enums.dart';
import '../models/equipment.dart';
import '../models/stats.dart';

/// Mọi con số cân bằng game nằm ở đây (và trong các enum ở models/enums.dart).
abstract final class GameConfig {
  static const startingGold = 500;
  static const startingHunters = 4;
  static const refreshCost = 20;

  /// Guild thu phần này của tiền thưởng; phần còn lại chia đều vào ví các hunter sống sót.
  static const questTaxRate = 0.2;

  /// Khi bán đồ mới, món cũ được nhà rèn thu lại với % giá gốc (trả vào ví hunter).
  static const tradeInRate = 0.3;

  /// Hệ số chung cho chỉ số mọi trang bị mới (nhập hàng, chế tạo); giảm để trang bị bớt áp đảo.
  static const equipmentStatFactor = 0.4;

  // Trang bị có 2 chỉ số song song (đều tối đa [maxDurability]):
  // - Tình trạng: mòn nhanh, về 0 thì hỏng (mất chỉ số), sửa về 100% là dùng lại được.
  // - Độ bền: mòn chậm, không sửa được, về 0 thì vỡ vụn.
  static const maxDurability = 100;
  static const conditionWearPerQuest = 12.0;
  static const durabilityWearPerQuest = 3.0;

  /// Giá sửa = giá món × (phí cơ bản này + % độ bền đã mất). Đồ càng cũ sửa càng đắt.
  static const repairBaseRate = 0.1;

  /// Hunter tự đi sửa đồ khi tình trạng dưới mức này.
  static const repairThreshold = 0.3;

  /// Số bình máu tối đa 1 hunter mang theo.
  static const maxPotions = 3;

  // Thương đoàn: nhân viên guild đi chợ các khu khác mua trang bị/bản vẽ.
  /// Giá ở chợ khu vực = giá thường × (min..max) ngẫu nhiên.
  static const marketPriceMin = 0.9;
  static const marketPriceMax = 1.9;
  static const marketItemsPerRegion = 4;

  /// Xác suất mỗi chợ có bán 1 bản vẽ.
  static const marketBlueprintChance = 0.35;

  /// Phí đi lại trả cho nhân viên: mỗi buổi đường (tính cả đi lẫn về).
  static const caravanFeePerPhase = 10;
  static const maxCaravans = 2;

  /// Chợ các khu nhập hàng mới mỗi tuần.
  static const weekDays = 7;

  // Thương nhân nước ngoài (số ngày đi mỗi nước xem Country trong models/trade.dart)
  static const foreignPriceMin = 0.65;
  static const foreignPriceMax = 1.4;
  static const foreignItemsPerCountry = 5;
  static const foreignBlueprintsPerCountry = 2;

  /// Hàng các nước đổi mới mỗi chừng này ngày.
  static const foreignRestockDays = 3;

  /// Phí đi lại mỗi ngày đường (tính cả đi lẫn về); cao hơn đi chợ trong vùng.
  static const foreignFeePerDay = 40;

  /// Tỉ lệ nhặt được bản vẽ (loại đồ ngẫu nhiên, cấp theo tier) khi hoàn thành quest tier B trở lên.
  static const blueprintDropChance = <QuestTier, double>{
    QuestTier.b: 0.08,
    QuestTier.a: 0.12,
    QuestTier.s: 0.18,
    QuestTier.sss: 0.25,
  };

  /// Giá bản vẽ chế tạo (giá gốc, trước hệ số chợ), mỗi loại đồ mỗi cấp 1 bản vẽ riêng.
  static const blueprintPrice = <ItemGrade, int>{
    ItemGrade.basic: 150,
    ItemGrade.fine: 600,
    ItemGrade.master: 2000,
    ItemGrade.divine: 6000,
  };

  // Sự kiện đầu tuần (tuần đầu tiên yên bình)
  static const firstEventDay = 8;

  /// Bao vây: quái tấn công vào đêm ngày thứ (1 + chừng này) của tuần.
  static const siegeDayOffset = 2;

  /// Độ khó trận thủ thành = độ khó tier (theo hạng thị trấn) × hệ số này.
  static const siegeDifficultyFactor = 2.5;
  static const siegeRepairCostPerRank = 120;
  static const siegeWinReputation = 10;
  static const siegeFailReputation = 15;

  /// Dịch bệnh: tốc độ hồi ở bệnh viện nhân hệ số này (1/3 = lâu hơn 200%), chữa ngay đắt gấp.
  static const plagueRecoveryRate = 1 / 3;
  static const plagueHealCostMultiplier = 3;

  /// Thương nhân: giá cắt cổ = giá thường × (min..max).
  static const merchantPriceMin = 2.0;
  static const merchantPriceMax = 3.0;

  /// Thời tiết cực đoan: hunter đi chậm hơn chừng này (thời gian đi = thường / (1 - hệ số)).
  static const weatherSlowdown = 0.3;

  /// Thời tiết cực đoan: mỗi sáng mỗi hunter ở thị trấn tự trả tiền nhu yếu phẩm (nền + theo cấp), hết thì thôi.
  static const weatherProvisionBase = 10;
  static const weatherProvisionPerLevel = 2;

  /// Lạm phát: giá thu mua lô nguyên liệu nhân hệ số này, kéo dài 1..max ngày.
  static const inflationPriceMultiplier = 2;
  static const inflationMaxDays = 2;

  /// Tin đồn: danh tiếng bị trừ tạm thời chừng này phần; tỉ lệ hunter Hiếm trở lên nhân hệ số này.
  static const rumorReputationLoss = 0.2;
  static const rumorRareRate = 0.5;

  // Sự kiện có lựa chọn (không chọn trước sáng hôm sau = chọn B)
  /// Viện trợ vương quốc: số hunter mạnh nhất phải gửi, số ngày viễn chinh, thưởng khi thắng, phạt khi từ chối.
  static const royalPartySize = 3;
  static const royalDays = 3;
  static const royalReputation = 80;
  static const royalRefusePenalty = 8;

  /// Viễn chinh: độ khó = độ khó tier × hệ số này (trận nhóm 3 người, đối thủ mạnh).
  static const royalDifficultyFactor = 3.5;

  /// Thí nghiệm cấm: quái biến dị mạnh hơn (×) và thưởng vàng/EXP nhiều hơn (×).
  static const mutationStrength = 1.5;
  static const mutationReward = 2.0;

  /// Kẻ phản bội: tha thứ thì 50% cải tà (chỉ số gốc ×), 50% dắt quái về công thành sau chừng này ngày.
  static const traitorRedeemChance = 0.5;
  static const traitorRedeemStatBoost = 1.15;
  static const traitorSiegeDelay = 2;

  /// Mỗi đầu tuần, mỗi kẻ bị trục xuất có tỉ lệ quay lại làm boss phụ.
  static const renegadeReturnChance = 0.35;
  static const renegadeDifficultyFactor = 3.0;
  static const renegadeRewardFactor = 3.0;

  /// Nhập cư: tuổi tân binh.
  static const recruitMinAge = 16;
  static const recruitMaxAge = 20;

  // Nguyên liệu & chế tạo
  /// Số đơn vị nguyên liệu mỗi hunter sống sót nhặt được (min, max) theo tier.
  static const lootPerHunter = <QuestTier, (int, int)>{
    QuestTier.d: (1, 2),
    QuestTier.c: (1, 3),
    QuestTier.b: (2, 3),
    QuestTier.a: (2, 4),
    QuestTier.s: (3, 5),
    QuestTier.sss: (4, 6),
  };

  /// Lô nguyên liệu hunter mang về được giữ ở trạm thu mua chừng này ngày.
  static const materialLotDays = 3;

  // Hạng hunter (D -> SSS, SSS là tối đa) theo danh tiếng (fame) riêng
  /// Fame cần để lên hạng C; mỗi lần lên hạng sau cần gấp đôi lần trước (20, 40, 80, 160, 320).
  static const hunterRankBaseFame = 20;

  /// Fame mỗi hunter sống sót nhận khi quest thành công (ít, để hunter hạng cao không lạm phát).
  static const questFame = <QuestTier, int>{
    QuestTier.d: 1,
    QuestTier.c: 2,
    QuestTier.b: 3,
    QuestTier.a: 5,
    QuestTier.s: 8,
    QuestTier.sss: 12,
  };

  /// Hunter chỉ nhận được quest cao hơn hạng mình tối đa chừng này tier.
  static const hunterRankQuestReach = 1;

  // Quest thăng hạng: fame chạm mốc thì dừng lại, hunter phải solo 1 quest riêng hợp với lớp của mình.
  /// Độ khó so với quest solo thường cùng tier, theo lớp: nhắm tỉ lệ thắng ~75% cho hunter vừa đủ cấp
  /// (hồi máu solo vốn yếu nên giữ mức thấp hơn).
  static const promotionDifficultyRate = <HunterClass, double>{
    HunterClass.mage: 1.08,
    HunterClass.ranger: 1.3,
    HunterClass.warrior: 1.25,
    HunterClass.healer: 0.98,
    HunterClass.tank: 0.92,
  };

  /// Thua thì mất chừng này phần fame đang có.
  static const promotionFailFameLoss = 0.2;

  // Quest thu thập
  /// Tỉ lệ quest sinh ra là quest thu thập.
  static const gatheringQuestChance = 0.3;

  /// So với quest săn cùng tier: quái canh giữ yếu hơn, EXP/vàng/danh tiếng ít hơn, nguyên liệu nhiều hơn.
  static const gatheringDifficultyRate = 0.6;
  static const gatheringExpRate = 0.4;
  static const gatheringGoldRate = 0.5;
  static const gatheringReputationRate = 0.5;
  static const gatheringLootMultiplier = 3.0;

  // Trang bị rơi từ quest
  /// Tỉ lệ mỗi hunter sống sót nhặt được 1 món trang bị khi quest thành công (cấp đồ theo tier).
  static const equipmentDropChance = <QuestTier, double>{
    QuestTier.d: 0.03,
    QuestTier.c: 0.04,
    QuestTier.b: 0.05,
    QuestTier.a: 0.06,
    QuestTier.s: 0.07,
    QuestTier.sss: 0.08,
  };

  /// Hunter bán đồ (không mặc được / thừa trong kho riêng) cho guild với chừng này % giá.
  static const lootSellRate = 0.5;

  /// Kho riêng giữ tối đa chừng này món mỗi ô (tay chính / tay phụ / giáp); thừa thì bán món yếu nhất cho guild.
  static const maxStashPerSlot = 3;

  /// Hunter hy sinh: guild mua lại đồ trong kho riêng với % giá này (đồ đang mặc thì hư luôn).
  static const estateBuybackRate = 0.8;

  /// Lô nguyên liệu quá hạn guild không mua: hunter bán chỗ khác được chừng này % giá.
  static const expiredLotSellRate = 0.5;

  /// Quái đông rơi nhiều hơn; thất bại thì nhặt được ít hơn.
  static const hordeLootMultiplier = 1.5;
  static const failLootMultiplier = 0.5;

  /// Bình máu có sẵn ở tiệm thuốc khi bắt đầu game.
  static const startingSmallPotions = 5;

  /// Hunter chỉ dùng tối đa chừng này % ví (sau khi mua đồ) để mua bình máu.
  static const potionBudgetRate = 0.5;

  // Bản đồ (toạ độ 0..1, thị trấn ở giữa)
  /// Khoảng cách đi được trong 1 buổi.
  static const mapDistancePerPhase = 0.15;

  /// Hai khu gần hơn khoảng này có thể có đường tắt nối thẳng.
  static const mapShortcutDistance = 0.25;

  // Hiệp hội
  static const invitationCost = 30;
  static const invitationSize = 3;

  // Danh tiếng (mốc nâng hạng thị trấn nằm ở TownRank trong models/town.dart)
  /// Danh tiếng nhận khi hoàn thành quest thành công, theo tier.
  static const questReputation = <QuestTier, int>{
    QuestTier.d: 3,
    QuestTier.c: 6,
    QuestTier.b: 12,
    QuestTier.a: 25,
    QuestTier.s: 50,
    QuestTier.sss: 100,
  };

  /// Quest thất bại mất chừng này phần danh tiếng lẽ ra nhận được.
  static const failReputationRate = 0.5;

  /// Mỗi hunter hy sinh.
  static const deathReputationLoss = 8;

  /// Cứu kịp thời: chữa ngay hunter đang dưới [rescueHpRatio] máu, hoặc hồi sinh thành công.
  static const rescueHpRatio = 0.3;
  static const rescueReputation = 2;
  static const reviveReputation = 5;

  // Thanh lý (để tránh phá sản): guild bán lại hàng tồn với tỉ lệ giá này.
  static const potionSellRate = 0.3;
  static const materialSellRate = 0.5;

  // Bệnh viện
  /// Về từ quest với máu dưới mức này sẽ phải nhập viện.
  static const hospitalThreshold = 0.8;

  /// % máu tối đa hồi mỗi sáng khi nằm viện.
  static const hospitalHealPerDay = 0.3;
  static const healNowGoldPerHp = 0.5;

  // Nhà cầu nguyện
  static const reviveChance = 0.1;
  static const reviveMaxAge = 75;
  static const prayerBaseCost = 50;
  static const prayerCostPerLevel = 25;

  /// Hồi sinh xong chỉ còn chừng này % máu (và phải vào viện).
  static const reviveHpRatio = 0.1;

  /// Quest thất bại làm trang bị mòn nhiều hơn.
  static const failDamageMultiplier = 1.5;
  static const boardSize = 6;

  // Combat theo lượt
  /// Số chu kỳ tối đa của 1 trận; hết giờ mà chưa thắng thì rút lui (tính là thua).
  static const maxBattleRounds = 30;

  // Action Value (kiểu Honkai: Star Rail): mỗi lượt của 1 đơn vị tốn actionGauge / tốc độ "thời gian".
  static const actionGauge = 10000.0;

  /// Độ dài 1 chu kỳ = thời gian 1 lượt của đơn vị tốc độ 20 (chu kỳ đầu dài gấp 1.5).
  static const cycleAv = 500.0;

  /// Tốc độ = mức nền này + nhanh nhẹn (hunter) hoặc tốc độ loài (quái); nền giúp chênh lệch số lượt
  /// giữa lớp nhanh/chậm vừa phải (như HSR: 90 vs 150), không gấp 3.
  static const speedBase = 10.0;

  /// Quái nhanh dần theo tier: + cấp tối thiểu của tier × hệ số này (theo kịp nhanh nhẹn hunter tăng theo cấp).
  static const monsterSpeedPerTierLevel = 0.3;

  /// Hunter uống bình máu ngay trong trận (không mất lượt) khi máu tụt dưới mức này.
  static const battlePotionThreshold = 0.4;

  /// Sát thương mỗi đòn dao động ±chừng này; thêm chí mạng để trận đánh có yếu tố may rủi.
  static const damageVariance = 0.25;
  static const critChance = 0.1;
  static const critMultiplier = 1.6;

  /// Đầu lĩnh có tối thượng nên sức mạnh thường chỉ bằng chừng này phần chia.
  static const bossPowerFactor = 0.75;

  /// Tổng máu phe quái = độ khó quest × hệ số này.
  static const enemyHpPerDifficulty = 3.3;

  /// Tổng sức mạnh phe quái = sát thương cơ bản của tier (× hệ số nhóm) × hệ số này.
  static const enemyPowerPerDamage = 0.95;

  /// Quest nhóm: sức mạnh phe quái nhân thêm hệ số này (độ khó nhóm vốn đã cộng dư).
  static const groupEnemyPowerFactor = 0.8;

  /// Tỉ lệ phe quái có thêm 1 tư tế hồi máu. Tư tế máu mỏng (chiếm chừng này phần tổng máu, không kháng)
  /// và sức mạnh thấp (chừng này phần tổng sức mạnh), hunter luôn đánh con yếu máu nhất nên dễ bị hạ trước.
  static const enemyHealerChance = 0.25;
  static const enemyHealerHpShare = 0.08;
  static const enemyHealerPowerShare = 0.15;

  /// Năng lượng tối thượng: +mỗi lần ra đòn, +mỗi lần bị đánh; đầy 100 thì tung chiêu.
  static const energyPerAction = 20.0;
  static const energyWhenHit = 10.0;
  static const maxEnergy = 100.0;

  // Chứng khoán.
  /// Phí mỗi lệnh mua/bán (tối thiểu 1 🪙).
  static const stockFeeRate = 0.01;

  /// Giá kéo dần về giá gốc mỗi ngày (tránh tăng/giảm mãi).
  static const stockMeanReversion = 0.04;

  /// Mỗi ngày mỗi mã có chừng này cơ hội dính tin bất ngờ, làm giá đổi từ min đến max.
  static const stockNewsChance = 0.07;
  static const stockNewsMin = 0.08;
  static const stockNewsMax = 0.2;

  static const stockMinPrice = 1.0;
  static const stockHistoryDays = 30;

  /// Mỗi quest thu thập thành công hôm qua đẩy giá mỏ lên chừng này (tối đa 5 quest).
  static const stockGatherBoost = 0.01;

  // Nội tại theo char.
  /// Pháp sư: mỗi kẻ địch tự tay hạ trong trận +chừng này % sát thương, tối đa [mageKillMaxStacks] lần.
  static const mageKillDamage = 0.1;
  static const mageKillMaxStacks = 5;

  /// Thợ săn: mỗi lượt đánh trúng giảm kháng mục tiêu chừng này (cả đội hưởng), cộng dồn tối đa
  /// [rangerShredMaxStacks] lần; kháng có thể xuống âm (nhận thêm sát thương).
  static const rangerShredPerStack = 0.06;
  static const rangerShredMaxStacks = 5;

  /// Chiến binh: mất 100% máu thì +chừng này sát thương và tốc độ (tăng tuyến tính theo máu đã mất).
  static const warriorRageDamage = 0.5;
  static const warriorRageSpeed = 0.5;

  /// Đỡ đòn: giảm sát thương tự buff cho bản thân cộng dồn tối đa chừng này lần, tổng không quá [tankGuardCap].
  static const tankGuardStacks = 2;
  static const tankGuardCap = 0.6;

  /// Đỡ đòn: giảm sát thương tự buff kéo dài thêm chừng này lượt, đủ để lần dùng sau chồng lên.
  static const tankGuardBonusTurns = 2;

  /// Hồi máu: quả cầu năng lượng chứa được chừng này % máu tối đa của bản thân; mọi lượng hồi máu
  /// nạp vào quả cầu, đầy thì nổ gây sát thương = sức chứa × [healerOrbDamage] lên 1 kẻ địch.
  static const healerOrbHpRatio = 0.4;
  static const healerOrbDamage = 1.2;

  /// Hunter bị gục trong trận có tỉ lệ chết = mức này + tỉ lệ chết cơ bản của tier; thua thì nhân thêm.
  static const downedDeathBase = 0.2;
  static const lostDeathMultiplier = 1.5;

  /// Skill mạnh thêm chừng này % cho mỗi bậc độ hiếm.
  static const skillScalePerRarity = 0.1;

  /// Số trận mô phỏng để ước tính tỉ lệ thắng hiển thị cho người chơi.
  static const estimateRuns = 100;

  // Nhanh nhẹn: dùng thẳng làm tốc độ (ai cao ra đòn trước) và quy ra né tránh, giảm dần hiệu quả,
  // không bao giờ vượt [maxEvasion]. Nhanh nhẹn = [agilityHalfEvasion] thì né được nửa mức trần (40%).
  static const maxEvasion = 0.8;
  static const agilityHalfEvasion = 70.0;

  static double evasionFromAgility(double agility) =>
      maxEvasion * agility / (agility + agilityHalfEvasion);
  static const questsPerYear = 10;

  /// Xác suất 1 quest sinh ra là quest nhóm.
  static const groupQuestChance = 0.35;
  static const maxParty = 4;

  /// Hệ số phần thưởng/EXP khi thất bại.
  static const failExpRate = 0.3;

  /// Mỗi healer khác còn đứng vững cuối trận nhân tỉ lệ chết của hunter bị gục với số này.
  static const healerDeathMultiplier = 0.4;

  /// Từ tuổi này trở lên, mỗi năm tăng thêm % tỉ lệ chết.
  static const agingStartAge = 30;
  static const agingDeathPerYear = 0.05;

  static int expToNext(int level) => (50 * pow(level, 1.4)).round();

  static const classBaseStats = <HunterClass, Stats>{
    HunterClass.mage: Stats(
      power: 14,
      maxHp: 70,
      physRes: 3,
      magicRes: 8,
      agility: 11,
    ),
    HunterClass.ranger: Stats(
      power: 12,
      maxHp: 80,
      physRes: 5,
      magicRes: 4,
      agility: 15,
    ),
    HunterClass.warrior: Stats(
      power: 11,
      maxHp: 110,
      physRes: 8,
      magicRes: 5,
      agility: 10,
    ),
    HunterClass.healer: Stats(
      power: 9,
      maxHp: 80,
      physRes: 4,
      magicRes: 9,
      agility: 10,
    ),
    HunterClass.tank: Stats(
      power: 9,
      maxHp: 150,
      physRes: 14,
      magicRes: 10,
      agility: 9,
    ),
  };

  /// Chỉ số cộng mỗi cấp (trước khi nhân hệ số độ hiếm).
  static const classGrowth = <HunterClass, Stats>{
    HunterClass.mage: Stats(
      power: 3.2,
      maxHp: 7,
      physRes: 0.5,
      magicRes: 1.2,
      agility: 0.4,
    ),
    HunterClass.ranger: Stats(
      power: 2.8,
      maxHp: 8,
      physRes: 0.8,
      magicRes: 0.6,
      agility: 0.8,
    ),
    HunterClass.warrior: Stats(
      power: 2.5,
      maxHp: 12,
      physRes: 1.0,
      magicRes: 0.8,
      agility: 0.5,
    ),
    HunterClass.healer: Stats(
      power: 1.9,
      maxHp: 8,
      physRes: 0.6,
      magicRes: 1.3,
      agility: 0.4,
    ),
    HunterClass.tank: Stats(
      power: 1.8,
      maxHp: 18,
      physRes: 1.8,
      magicRes: 1.4,
      agility: 0.2,
    ),
  };

  static const hunterNames = [
    'Aren',
    'Kira',
    'Lâm',
    'Minh',
    'Tuấn',
    'Linh',
    'Hạo',
    'Vân',
    'Ryu',
    'Zed', //
    'Mai',
    'Phong',
    'Sora',
    'Kai',
    'Nam',
    'Yuki',
    'Long',
    'Thảo',
    'Hùng',
    'Lyra',
  ];
}
