enum DamageType {
  physical('Vật lý'),
  magic('Phép');

  const DamageType(this.label);
  final String label;
}

enum HunterClass {
  mage('Pháp sư', DamageType.magic),
  ranger('Thợ săn', DamageType.physical),
  warrior('Chiến binh', DamageType.physical),
  healer('Hồi máu', DamageType.magic),
  tank('Đỡ đòn', DamageType.physical);

  const HunterClass(this.label, this.damageType);
  final String label;
  final DamageType damageType;
}

enum Rarity {
  common('Thường', weight: 60, growthMultiplier: 1.0, joinFee: 80, healPercent: 0.10),
  rare('Hiếm', weight: 28, growthMultiplier: 1.3, joinFee: 250, healPercent: 0.15),
  epic('Sử thi', weight: 10, growthMultiplier: 1.7, joinFee: 700, healPercent: 0.22),
  legendary('Huyền thoại', weight: 2, growthMultiplier: 2.2, joinFee: 2000, healPercent: 0.30);

  const Rarity(
    this.label, {
    required this.weight,
    required this.growthMultiplier,
    required this.joinFee,
    required this.healPercent,
  });
  final String label;

  /// Vàng phải trả để hunter nhập thị trấn.
  final int joinFee;

  /// % máu tối đa mà healer có độ hiếm này hồi cho đồng đội sau quest nhóm.
  final double healPercent;

  /// Trọng số khi tuyển hunter ngẫu nhiên.
  final int weight;

  /// Hệ số nhân chỉ số cộng thêm mỗi lần lên cấp.
  final double growthMultiplier;
}

enum QuestTier {
  d('D', weight: 40, minLevel: 1, difficulty: 30, gold: 40, exp: 30, baseDeathChance: 0.02, enemyDamage: 20),
  c('C', weight: 30, minLevel: 5, difficulty: 55, gold: 120, exp: 80, baseDeathChance: 0.04, enemyDamage: 35),
  b('B', weight: 15, minLevel: 12, difficulty: 100, gold: 350, exp: 220, baseDeathChance: 0.07, enemyDamage: 60),
  a('A', weight: 9, minLevel: 22, difficulty: 160, gold: 900, exp: 550, baseDeathChance: 0.10, enemyDamage: 100),
  s('S', weight: 4, minLevel: 35, difficulty: 230, gold: 2500, exp: 1400, baseDeathChance: 0.15, enemyDamage: 150),
  sss('SSS', weight: 2, minLevel: 50, difficulty: 320, gold: 8000, exp: 4000, baseDeathChance: 0.20, enemyDamage: 220);

  const QuestTier(
    this.label, {
    required this.weight,
    required this.minLevel,
    required this.difficulty,
    required this.gold,
    required this.exp,
    required this.baseDeathChance,
    required this.enemyDamage,
  });

  final String label;

  /// Tỉ lệ xuất hiện (%).
  final int weight;

  /// Cấp tối thiểu của MỖI hunter tham gia.
  final int minLevel;

  /// Độ khó cơ bản cho 1 người (quest nhóm sẽ nhân lên).
  final double difficulty;
  final int gold;
  final int exp;
  final double baseDeathChance;

  /// Sát thương cơ bản quái gây ra cho mỗi hunter.
  final double enemyDamage;
}

/// Loại quái: quyết định quái đánh bằng gì và kháng gì.
enum MonsterType {
  beast('Sói', attack: DamageType.physical, physRes: 0, magicRes: 0),
  golem('Golem', attack: DamageType.physical, physRes: 0.4, magicRes: 0),
  spirit('U linh', attack: DamageType.magic, physRes: 0, magicRes: 0.4),
  demon('Quỷ', attack: DamageType.magic, physRes: 0.2, magicRes: 0.2),
  goblin('Goblin', attack: DamageType.physical, physRes: 0, magicRes: 0),
  seaBeast('Quái biển', attack: DamageType.physical, physRes: 0, magicRes: 0.2),
  harpy('Harpy', attack: DamageType.physical, physRes: 0.1, magicRes: 0),
  yeti('Yeti', attack: DamageType.physical, physRes: 0.3, magicRes: 0),
  soldier('Quân lính', attack: DamageType.physical, physRes: 0.3, magicRes: 0.1);

  const MonsterType(this.label, {required this.attack, required this.physRes, required this.magicRes});
  final String label;
  final DamageType attack;

  /// Phần trăm sát thương bị giảm (0..1).
  final double physRes;
  final double magicRes;

  double resistanceTo(DamageType type) => type == DamageType.physical ? physRes : magicRes;
}
