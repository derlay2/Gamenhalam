import 'dart:math';

import '../logic/game_config.dart';
import 'enums.dart';
import 'equipment.dart';
import 'potion.dart';
import 'skill.dart';
import 'stats.dart';

class Hunter {
  Hunter({
    required this.id,
    required this.name,
    required this.hunterClass,
    required this.rarity,
    required this.age,
    required Stats stats,
    this.personalSkillIndex = 0,
  }) : basePower = stats.power,
       baseMaxHp = stats.maxHp,
       basePhysRes = stats.physRes,
       baseMagicRes = stats.magicRes,
       baseAgility = stats.agility,
       hp = stats.maxHp;

  factory Hunter.fromJson(Map<String, dynamic> j) {
    final h =
        Hunter(
            id: j['id'] as int,
            name: j['name'] as String,
            hunterClass: HunterClass.values.byName(j['class'] as String),
            rarity: Rarity.values.byName(j['rarity'] as String),
            age: j['age'] as int,
            stats: Stats.fromJson(j['baseStats'] as Map<String, dynamic>),
            personalSkillIndex: j['skill'] as int? ?? 0,
          )
          ..level = j['level'] as int
          ..exp = j['exp'] as int
          ..questsDone = j['questsDone'] as int
          ..inHospital = j['inHospital'] as bool
          ..onQuest = j['onQuest'] as bool
          ..gold = j['gold'] as int;
    // Bản lưu cũ chưa có fame: xếp hạng theo cấp để không bị chặn quest đang làm được.
    // Bản lưu chưa có hạng riêng: hạng = mức fame đang có.
    h.fame =
        j['fame'] as int? ??
        Hunter.fameForRank(QuestTier.values.lastWhere((t) => t.minLevel <= h.level, orElse: () => QuestTier.d));
    h.rank = switch (j['rank']) {
      final String name => QuestTier.values.byName(name),
      _ => QuestTier.values.lastWhere((t) => h.fame >= fameForRank(t)),
    };
    for (final MapEntry(key: slot, value: item) in (j['equipment'] as Map<String, dynamic>).entries) {
      h.equipment[EquipSlot.values.byName(slot)] = Equipment.fromJson(item as Map<String, dynamic>);
    }
    h.potions.addAll([for (final p in j['potions'] as List) Potion.values.byName(p as String)]);
    h.stash.addAll([for (final e in j['stash'] as List? ?? const []) Equipment.fromJson(e as Map<String, dynamic>)]);
    h.hp = (j['hp'] as num).toDouble(); // sau khi mặc đồ, để không bị cắt theo máu tối đa gốc
    return h;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'class': hunterClass.name,
    'rarity': rarity.name,
    'skill': personalSkillIndex,
    'age': age,
    'baseStats': Stats(
      power: basePower,
      maxHp: baseMaxHp,
      physRes: basePhysRes,
      magicRes: baseMagicRes,
      agility: baseAgility,
    ).toJson(),
    'level': level,
    'exp': exp,
    'questsDone': questsDone,
    'hp': hp,
    'inHospital': inHospital,
    'onQuest': onQuest,
    'gold': gold,
    'fame': fame,
    'rank': rank.name,
    'equipment': {for (final MapEntry(key: slot, value: item) in equipment.entries) slot.name: item.toJson()},
    'potions': [for (final p in potions) p.name],
    'stash': [for (final e in stash) e.toJson()],
  };

  final int id;
  final String name;
  final HunterClass hunterClass;
  final Rarity rarity;

  int level = 1;
  int exp = 0;
  int age;
  int questsDone = 0;

  /// Chỉ số gốc (chưa tính trang bị).
  double basePower;
  double baseMaxHp;
  double basePhysRes;
  double baseMagicRes;
  double baseAgility;

  /// Máu hiện tại.
  double hp;
  bool inHospital = false;
  bool onQuest = false;

  bool get isAvailable => !inHospital && !onQuest;

  /// Ví riêng của hunter (80% tiền thưởng quest).
  int gold = 0;

  /// Danh tiếng riêng (tổng tích lũy), tích từ quest thành công; bị chặn ở mốc hạng kế tiếp
  /// cho tới khi vượt quest thăng hạng.
  int fame = 0;

  /// Tổng fame cần để đạt hạng [rank]: mỗi lần lên hạng cần gấp đôi lần trước.
  static int fameForRank(QuestTier rank) =>
      [for (var i = 0; i < rank.index; i++) GameConfig.hunterRankBaseFame << i].fold(0, (a, b) => a + b);

  /// Hạng hunter (D..SSS, SSS là tối đa); chỉ tăng khi vượt quest thăng hạng.
  QuestTier rank = QuestTier.d;

  /// Fame đã chạm trần: cần làm quest thăng hạng để lên [nextRank].
  bool get canPromote {
    final next = nextRank;
    return next != null && fame >= fameForRank(next);
  }

  /// Hạng kế tiếp, null nếu đã SSS.
  QuestTier? get nextRank => rank.index + 1 < QuestTier.values.length ? QuestTier.values[rank.index + 1] : null;

  /// Quest tier cao nhất hunter được nhận.
  QuestTier get maxQuestTier =>
      QuestTier.values[min(rank.index + GameConfig.hunterRankQuestReach, QuestTier.values.length - 1)];

  /// Cộng fame, không vượt mốc hạng kế tiếp (SSS thì không giới hạn).
  void gainFame(int amount) {
    fame += amount;
    if (nextRank case final next?) fame = min(fame, fameForRank(next));
  }

  /// Vượt quest thăng hạng.
  void promote() {
    if (canPromote) rank = nextRank!;
  }

  /// Thua quest thăng hạng: mất một phần fame đang có để cày lại. Trả về số fame mất.
  int failPromotion() {
    final lost = (fame * GameConfig.promotionFailFameLoss).round();
    fame -= lost;
    return lost;
  }

  final equipment = <EquipSlot, Equipment>{};
  final potions = <Potion>[];

  /// Kho riêng: đồ nhặt được hoặc vừa thay ra, chưa mặc.
  final stash = <Equipment>[];

  Stats get equipmentBonus => equipment.values.fold(Stats.zero, (sum, e) => sum + e.effectiveBonus);

  double get power => basePower + equipmentBonus.power;
  double get maxHp => baseMaxHp + equipmentBonus.maxHp;
  double get physRes => basePhysRes + equipmentBonus.physRes;
  double get magicRes => baseMagicRes + equipmentBonus.magicRes;
  double get agility => baseAgility + equipmentBonus.agility;

  /// Né tránh quy từ nhanh nhẹn (giảm dần hiệu quả, tối đa 80%).
  double get evasion => GameConfig.evasionFromAgility(agility);

  double get hpRatio => hp / maxHp;
  bool get isFullHp => hp >= maxHp;

  DamageType get damageType => hunterClass.damageType;

  /// Vị trí skill bản thân trong bộ skill của lớp (bốc ngẫu nhiên khi hunter xuất hiện).
  final int personalSkillIndex;

  Skill get personalSkill => classSkillPools[hunterClass]![personalSkillIndex];

  /// Skill của vũ khí tay chính (hoặc tay phụ nếu tay chính trống); đồ hỏng thì không có.
  Skill? get weaponSkill {
    final weapon = equipment[EquipSlot.mainHand] ?? equipment[EquipSlot.offHand];
    if (weapon == null || weapon.isBroken) return null;
    return weaponSkills[weapon.type];
  }

  Skill get ultimate => classUltimates[hunterClass]!;

  /// Đòn riêng của char (hiện chỉ đỡ đòn có).
  Skill? get bonusSkill => classBonusSkills[hunterClass];

  /// Độ hiếm càng cao, skill càng mạnh.
  double get skillScale => 1 + GameConfig.skillScalePerRarity * rarity.index;

  /// Quyết định ai ra đòn trước trong trận: chính là nhanh nhẹn.
  double get speed => GameConfig.speedBase + agility;
  int get expToNext => GameConfig.expToNext(level);

  double resistanceTo(DamageType type) => type == DamageType.physical ? physRes : magicRes;

  void heal(double amount) => hp = min(maxHp, hp + amount);

  /// Hunter sống sót luôn còn ít nhất 1 máu.
  void takeDamage(double amount) => hp = max(1, hp - amount);

  /// Cộng EXP, trả về số cấp vừa lên.
  int gainExp(int amount) {
    exp += amount;
    var gained = 0;
    while (exp >= expToNext) {
      exp -= expToNext;
      level++;
      gained++;
      _applyGrowth();
    }
    return gained;
  }

  /// Ghi nhận 1 quest hoàn thành; cứ đủ số quest thì già thêm 1 tuổi.
  void completeQuest() {
    questsDone++;
    if (questsDone % GameConfig.questsPerYear == 0) age++;
  }

  /// Lý do không thể trang bị, hoặc null nếu được.
  String? equipError(Equipment item) {
    if (!item.type.classes.contains(hunterClass)) {
      return '${hunterClass.label} không dùng được ${item.type.label}';
    }
    if (level < item.grade.minLevel) return 'Cần cấp ${item.grade.minLevel}';
    return null;
  }

  /// Trang bị món đồ, trả về các món bị tháo ra.
  List<Equipment> equip(Equipment item) {
    final oldMaxHp = maxHp;
    final removed = <Equipment>[];
    void takeOff(EquipSlot slot) {
      final e = equipment.remove(slot);
      if (e != null) removed.add(e);
    }

    takeOff(item.type.slot);
    if (item.type.twoHanded) takeOff(EquipSlot.offHand);
    if (item.type.slot == EquipSlot.offHand && (equipment[EquipSlot.mainHand]?.type.twoHanded ?? false)) {
      takeOff(EquipSlot.mainHand);
    }
    equipment[item.type.slot] = item;
    _adjustHp(oldMaxHp);
    return removed;
  }

  Equipment? unequip(EquipSlot slot) {
    final oldMaxHp = maxHp;
    final item = equipment.remove(slot);
    _adjustHp(oldMaxHp);
    return item;
  }

  /// Máu tối đa tăng thì máu hiện tại tăng theo; giảm thì bị cắt bớt.
  void _adjustHp(double oldMaxHp) => hp = min(maxHp, hp + max(0.0, maxHp - oldMaxHp));

  void _applyGrowth() {
    final g = GameConfig.classGrowth[hunterClass]! * rarity.growthMultiplier;
    basePower += g.power;
    baseMaxHp += g.maxHp;
    hp += g.maxHp;
    basePhysRes += g.physRes;
    baseMagicRes += g.magicRes;
    baseAgility += g.agility;
  }
}
