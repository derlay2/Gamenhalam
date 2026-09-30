import '../logic/game_config.dart';
import 'enums.dart';
import 'stats.dart';

enum EquipSlot {
  mainHand('Tay chính'),
  offHand('Tay phụ'),
  armor('Giáp');

  const EquipSlot(this.label);
  final String label;
}

const _allClasses = {HunterClass.mage, HunterClass.ranger, HunterClass.warrior, HunterClass.healer, HunterClass.tank};

enum ItemType {
  staff(
    'Gậy phép',
    EquipSlot.mainHand,
    twoHanded: true,
    classes: {HunterClass.mage, HunterClass.healer},
    bonus: Stats(power: 9, magicRes: 2),
  ),
  sword(
    'Kiếm',
    EquipSlot.mainHand,
    classes: {HunterClass.warrior, HunterClass.ranger, HunterClass.tank},
    bonus: Stats(power: 6),
  ),
  bow(
    'Cung',
    EquipSlot.mainHand,
    twoHanded: true,
    classes: {HunterClass.ranger},
    bonus: Stats(power: 9, agility: 2),
  ),
  shield(
    'Khiên',
    EquipSlot.offHand,
    classes: {HunterClass.tank, HunterClass.warrior},
    bonus: Stats(maxHp: 20, physRes: 5, magicRes: 3),
  ),
  dagger(
    'Dao',
    EquipSlot.offHand,
    classes: {HunterClass.warrior, HunterClass.ranger},
    bonus: Stats(power: 3, agility: 3),
  ),
  // 3 loại giáp: đổi né tránh lấy máu, tổng giá trị tương đương nhau.
  clothArmor('Giáp vải', EquipSlot.armor, classes: _allClasses, bonus: Stats(maxHp: 10, agility: 6)),
  leatherArmor('Giáp da', EquipSlot.armor, classes: _allClasses, bonus: Stats(maxHp: 25, agility: 3.5)),
  steelArmor('Giáp thép', EquipSlot.armor, classes: _allClasses, bonus: Stats(maxHp: 40, agility: 1));

  const ItemType(this.label, this.slot, {this.twoHanded = false, required this.classes, required this.bonus});

  final String label;
  final EquipSlot slot;

  /// Vũ khí 2 tay chiếm luôn tay phụ.
  final bool twoHanded;
  final Set<HunterClass> classes;

  /// Chỉ số ở cấp Sơ cấp.
  final Stats bonus;
}

enum ItemGrade {
  basic(
    'Sơ cấp',
    statMultiplier: 1,
    agilityMultiplier: 1,
    price: 60,
    minLevel: 1,
    offerWeight: 55,
    materialValueMultiplier: 1,
  ),
  fine(
    'Tinh luyện',
    statMultiplier: 2.2,
    agilityMultiplier: 1.4,
    price: 250,
    minLevel: 10,
    offerWeight: 30,
    materialValueMultiplier: 3,
  ),
  master(
    'Bậc thầy',
    statMultiplier: 4,
    agilityMultiplier: 1.8,
    price: 900,
    minLevel: 25,
    offerWeight: 12,
    materialValueMultiplier: 8,
  ),
  divine(
    'Thần khí',
    statMultiplier: 7,
    agilityMultiplier: 2.3,
    price: 3000,
    minLevel: 45,
    offerWeight: 3,
    materialValueMultiplier: 25,
  );

  const ItemGrade(
    this.label, {
    required this.statMultiplier,
    required this.agilityMultiplier,
    required this.price,
    required this.minLevel,
    required this.offerWeight,
    required this.materialValueMultiplier,
  });

  final String label;
  final double statMultiplier;

  /// Nhanh nhẹn tăng chậm hơn các chỉ số khác theo cấp đồ để né tránh không chạm trần quá sớm.
  final double agilityMultiplier;

  /// Giá gốc (món chất lượng 100%).
  final int price;
  final int minLevel;

  /// Trọng số xuất hiện khi nhập hàng (các đêm đầu game).
  final int offerWeight;

  /// Hệ số giá thu mua nguyên liệu cấp này.
  final double materialValueMultiplier;
}

class Equipment {
  Equipment({
    required this.id,
    required this.type,
    required this.grade,
    required this.bonus,
    this.quality = 1,
    int? price,
  }) : price = price ?? grade.price,
       condition = GameConfig.maxDurability.toDouble(),
       durability = GameConfig.maxDurability.toDouble();

  /// Món đồ với chỉ số chuẩn (chất lượng 100%).
  Equipment.standard({required int id, required ItemType type, required ItemGrade grade})
    : this(id: id, type: type, grade: grade, bonus: standardBonus(type, grade));

  factory Equipment.fromJson(Map<String, dynamic> j) =>
      Equipment(
          id: j['id'] as int,
          type: ItemType.values.byName(j['type'] as String),
          grade: ItemGrade.values.byName(j['grade'] as String),
          bonus: Stats.fromJson(j['bonus'] as Map<String, dynamic>),
          quality: (j['quality'] as num).toDouble(),
          price: j['price'] as int,
        )
        ..condition = ((j['condition'] ?? GameConfig.maxDurability) as num).toDouble()
        ..durability = (j['durability'] as num).toDouble();

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'grade': grade.name,
    'bonus': bonus.toJson(),
    'quality': quality,
    'price': price,
    'condition': condition,
    'durability': durability,
  };

  final int id;
  final ItemType type;
  final ItemGrade grade;
  final Stats bonus;

  /// Hệ số chỉ số ngẫu nhiên so với chuẩn (1.0 = 100%).
  final double quality;
  final int price;

  /// Tình trạng (độ hỏng): mòn nhanh mỗi trận; về 0 thì hỏng, phải sửa về 100% mới dùng lại được.
  double condition;

  /// Độ bền (tuổi thọ): giảm chậm, không sửa được; về 0 thì vỡ vụn, mất luôn.
  double durability;

  double get conditionRatio => condition / GameConfig.maxDurability;
  double get durabilityRatio => durability / GameConfig.maxDurability;

  /// Hỏng: vẫn mặc trên người nhưng không có chỉ số cho tới khi sửa.
  bool get isBroken => condition <= 0;

  bool get isDestroyed => durability <= 0;

  /// Chỉ số thực tế (0 nếu đang hỏng).
  Stats get effectiveBonus => isBroken ? Stats.zero : bonus;

  bool get canRepair => condition < GameConfig.maxDurability && !isDestroyed;

  /// Sửa về 100% tình trạng; giá = giá món × (10% + % độ bền đã mất).
  int get repairCost => (price * (GameConfig.repairBaseRate + (1 - durabilityRatio))).ceil();

  /// Giá nhà rèn thu lại đồ cũ: theo độ bền còn lại, đồ đang hỏng chỉ được một nửa.
  int get tradeInValue => (price * GameConfig.tradeInRate * durabilityRatio * (isBroken ? 0.5 : 1)).round();

  void repair() => condition = GameConfig.maxDurability.toDouble();

  String get name => '${type.label} ${grade.label}';

  static Stats standardBonus(ItemType type, ItemGrade grade) {
    final b = type.bonus;
    final m = grade.statMultiplier * GameConfig.equipmentStatFactor;
    return Stats(
      power: b.power * m,
      maxHp: b.maxHp * m,
      physRes: b.physRes * m,
      magicRes: b.magicRes * m,
      agility: b.agility * grade.agilityMultiplier * GameConfig.equipmentStatFactor,
    );
  }
}

/// Bản vẽ chế tạo: riêng cho từng loại đồ và từng cấp (bản vẽ Khiên Sơ cấp không chế được Kiếm Sơ cấp).
typedef Blueprint = ({ItemType type, ItemGrade grade});

extension BlueprintInfo on Blueprint {
  String get label => '📜 Bản vẽ ${type.label} ${grade.label}';

  /// Dạng lưu: "sword:basic".
  String get key => '${type.name}:${grade.name}';

  static Blueprint parse(String key) {
    final [type, grade] = key.split(':');
    return (type: ItemType.values.byName(type), grade: ItemGrade.values.byName(grade));
  }

  /// Tất cả bản vẽ của 1 cấp.
  static List<Blueprint> ofGrade(ItemGrade grade) => [for (final t in ItemType.values) (type: t, grade: grade)];
}
