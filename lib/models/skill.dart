import '../logic/game_config.dart';
import 'enums.dart';
import 'equipment.dart';

/// Phạm vi tác dụng của một phần hiệu ứng skill.
enum Scope { none, self, enemy, allEnemies, lowestAlly, allAllies }

/// Một kỹ năng trong trận theo lượt. Hệ số sát thương/hồi máu nhân với sức mạnh người dùng.
class Skill {
  const Skill(
    this.name, {
    this.hitScope = Scope.none,
    this.damage = 0,
    this.hits = 1,
    this.foeHpDamage = 0,
    this.foeHpDamagePerCast = 0,
    this.foeHpDamageMaxCasts = 0,
    this.lifesteal = 0,
    this.weaken = 0,
    this.healScope = Scope.none,
    this.heal = 0,
    this.buffScope = Scope.none,
    this.guard = 0,
    this.empower = 0,
    this.taunt = false,
    this.duration = 2,
    this.cooldown = 0,
  });

  final String name;

  /// Tấn công: [hitScope] là enemy hoặc allEnemies; mỗi mục tiêu trúng [hits] đòn × [damage].
  final Scope hitScope;
  final double damage;
  final int hits;

  /// Sát thương cộng thêm theo % máu tối đa của mục tiêu, chia đều cho số đồng đội còn đứng
  /// (solo nhận đủ, đi nhóm 4 người chỉ còn 1/4). Mỗi lần dùng trong trận tăng thêm
  /// [foeHpDamagePerCast], tối đa [foeHpDamageMaxCasts] lần.
  final double foeHpDamage;
  final double foeHpDamagePerCast;
  final int foeHpDamageMaxCasts;

  /// % máu tối đa mục tiêu sau [casts] lần đã dùng.
  double foeHpDamageAfter(int casts) => foeHpDamage + foeHpDamagePerCast * casts.clamp(0, foeHpDamageMaxCasts);

  /// % sát thương gây ra hồi lại cho người dùng.
  final double lifesteal;

  /// Giảm % sức mạnh của mục tiêu bị trúng đòn trong [duration] lượt.
  final double weaken;

  /// Hồi máu: [healScope] là lowestAlly hoặc allAllies, lượng = sức mạnh × [heal].
  final Scope healScope;
  final double heal;

  /// Hỗ trợ: [buffScope] là self hoặc allAllies.
  /// [guard] giảm % sát thương nhận vào, [empower] tăng % sức mạnh, [taunt] kéo mọi đòn đánh về mình.
  final Scope buffScope;
  final double guard;
  final double empower;
  final bool taunt;

  final int duration;
  final int cooldown;

  String get description => [
    if (damage > 0)
      '${hitScope == Scope.allEnemies ? 'Đánh cả đám' : 'Đánh 1 mục tiêu'} '
          '${hits > 1 ? '$hits × ' : ''}${(damage * 100).round()}% sức mạnh',
    if (foeHpDamage > 0)
      '+${(foeHpDamage * 100).round()}% máu tối đa mục tiêu, mỗi lần dùng +${(foeHpDamagePerCast * 100).round()}% '
          '(tối đa ${(foeHpDamageAfter(foeHpDamageMaxCasts) * 100).round()}%; chia theo số người trong đội)',
    if (lifesteal > 0) 'hút ${(lifesteal * 100).round()}% sát thương',
    if (weaken > 0) 'giảm ${(weaken * 100).round()}% sức mạnh mục tiêu',
    if (heal > 0)
      '${healScope == Scope.allAllies ? 'Hồi máu cả đội' : 'Hồi máu đồng đội yếu nhất'} '
          '${(heal * 100).round()}% sức mạnh',
    if (taunt) 'Khiêu khích',
    if (guard > 0)
      '${buffScope == Scope.allAllies ? 'Cả đội' : 'Bản thân'} giảm ${(guard * 100).round()}% sát thương nhận',
    if (empower > 0)
      '${buffScope == Scope.allAllies ? 'Cả đội' : 'Bản thân'} tăng ${(empower * 100).round()}% sức mạnh',
    if (guard > 0 || empower > 0 || weaken > 0 || taunt) 'trong $duration lượt',
    if (cooldown > 0) 'hồi chiêu $cooldown lượt',
  ].join(', ');
}

const basicAttack = Skill('Đánh thường', hitScope: Scope.enemy, damage: 1.0);

/// Mỗi hunter bốc ngẫu nhiên 1 skill bản thân từ bộ skill của lớp.
const classSkillPools = <HunterClass, List<Skill>>{
  HunterClass.mage: [
    Skill('Cầu lửa', hitScope: Scope.enemy, damage: 1.75, cooldown: 2),
    Skill('Mưa băng', hitScope: Scope.allEnemies, damage: 0.9, cooldown: 3),
    Skill('Tia sét', hitScope: Scope.enemy, damage: 0.9, hits: 3, cooldown: 3),
  ],
  HunterClass.ranger: [
    Skill('Bắn tỉa', hitScope: Scope.enemy, damage: 2.0, cooldown: 2),
    Skill('Mưa tên', hitScope: Scope.allEnemies, damage: 0.8, cooldown: 3),
    Skill(
      'Đặt bẫy',
      hitScope: Scope.enemy,
      damage: 1.2,
      weaken: 0.3,
      cooldown: 3,
    ),
  ],
  HunterClass.warrior: [
    Skill('Chém mạnh', hitScope: Scope.enemy, damage: 1.8, cooldown: 2),
    Skill(
      'Hét xung trận',
      buffScope: Scope.allAllies,
      empower: 0.25,
      duration: 4,
      cooldown: 4,
    ),
    Skill('Chém xoáy', hitScope: Scope.allEnemies, damage: 1.0, cooldown: 3),
  ],
  HunterClass.healer: [
    Skill('Hồi phục', healScope: Scope.lowestAlly, heal: 2.5, cooldown: 2),
    Skill('Ban phước', healScope: Scope.allAllies, heal: 1.2, cooldown: 3),
    Skill(
      'Ánh sáng thánh',
      hitScope: Scope.enemy,
      damage: 1.5,
      healScope: Scope.lowestAlly,
      heal: 1.0,
      cooldown: 3,
    ),
  ],
  HunterClass.tank: [
    Skill(
      'Khiêu khích',
      buffScope: Scope.self,
      taunt: true,
      guard: 0.3,
      cooldown: 3,
    ),
    Skill('Tường thành', buffScope: Scope.allAllies, guard: 0.25, cooldown: 4),
    Skill(
      'Đập khiên',
      hitScope: Scope.enemy,
      damage: 1.2,
      weaken: 0.25,
      cooldown: 3,
    ),
  ],
};

/// Skill theo loại vũ khí (ưu tiên vũ khí tay chính; đồ hỏng thì không dùng được).
const weaponSkills = <ItemType, Skill>{
  ItemType.sword: Skill(
    'Chém lan',
    hitScope: Scope.allEnemies,
    damage: 0.6,
    cooldown: 4,
  ),
  ItemType.bow: Skill(
    'Bắn xuyên',
    hitScope: Scope.enemy,
    damage: 1.4,
    cooldown: 3,
  ),
  ItemType.staff: Skill(
    'Cầu năng lượng',
    hitScope: Scope.enemy,
    damage: 1.3,
    cooldown: 3,
  ),
  ItemType.dagger: Skill(
    'Đâm liên hoàn',
    hitScope: Scope.enemy,
    damage: 0.5,
    hits: 3,
    cooldown: 4,
  ),
  ItemType.shield: Skill(
    'Giơ khiên',
    buffScope: Scope.self,
    guard: 0.4,
    taunt: true,
    cooldown: 4,
  ),
};

/// Đòn riêng của char, có thêm ngoài skill bản thân và skill vũ khí.
const classBonusSkills = <HunterClass, Skill>{
  // Bù sát thương cho đỡ đòn khi solo; đi nhóm thì phần theo máu bị chia nhỏ.
  HunterClass.tank: Skill(
    'Húc khiên',
    hitScope: Scope.enemy,
    damage: 0.5,
    foeHpDamage: 0.05,
    foeHpDamagePerCast: 0.02,
    foeHpDamageMaxCasts: 4,
    cooldown: 2,
  ),
};

/// Tối thượng theo lớp: tung ra khi thanh năng lượng đầy.
const classUltimates = <HunterClass, Skill>{
  HunterClass.mage: Skill(
    'Thiên thạch',
    hitScope: Scope.allEnemies,
    damage: 2.5,
  ),
  HunterClass.ranger: Skill(
    'Mũi tên định mệnh',
    hitScope: Scope.enemy,
    damage: 4.0,
  ),
  HunterClass.warrior: Skill(
    'Nộ chiến thần',
    hitScope: Scope.enemy,
    damage: 1.8,
    hits: 2,
    buffScope: Scope.self,
    empower: 0.3,
  ),
  HunterClass.healer: Skill(
    'Ánh sáng tái sinh',
    healScope: Scope.allAllies,
    heal: 3.0,
  ),
  HunterClass.tank: Skill(
    'Pháo đài bất khuất',
    buffScope: Scope.allAllies,
    guard: 0.5,
    taunt: true,
  ),
};

/// Skill của quái tư tế: hồi máu cho đồng bọn yếu nhất.
const enemyHealSkill = Skill('Chúc phúc hắc ám', healScope: Scope.lowestAlly, heal: 1.0, cooldown: 3);

/// Nội tại theo char: luôn có hiệu lực trong trận, không tốn lượt.
extension ClassPassive on HunterClass {
  String get passiveName => switch (this) {
    HunterClass.mage => 'Hấp thụ linh hồn',
    HunterClass.ranger => 'Đánh dấu con mồi',
    HunterClass.warrior => 'Cuồng huyết',
    HunterClass.tank => 'Thành trì',
    HunterClass.healer => 'Quả cầu thánh quang',
  };

  String get passiveDescription => switch (this) {
    HunterClass.mage =>
      'Mỗi kẻ địch tự tay hạ gục: +${_pct(GameConfig.mageKillDamage)} sát thương đến hết trận '
          '(tối đa ${GameConfig.mageKillMaxStacks} lần)',
    HunterClass.ranger =>
      'Mỗi lượt đánh trúng giảm ${_pct(GameConfig.rangerShredPerStack)} kháng của mục tiêu với mọi đòn, '
          'cộng dồn tối đa ${GameConfig.rangerShredMaxStacks} lần',
    HunterClass.warrior =>
      'Máu càng thấp càng mạnh: tới +${_pct(GameConfig.warriorRageDamage)} sát thương và '
          '+${_pct(GameConfig.warriorRageSpeed)} tốc độ khi sắp gục',
    HunterClass.tank =>
      'Giảm sát thương tự buff cho bản thân kéo dài thêm ${GameConfig.tankGuardBonusTurns} lượt và '
          'cộng dồn ${GameConfig.tankGuardStacks} lần (tối đa ${_pct(GameConfig.tankGuardCap)})',
    HunterClass.healer =>
      'Mọi lượng hồi máu nạp vào quả cầu năng lượng (chứa ${_pct(GameConfig.healerOrbHpRatio)} máu tối đa bản thân); '
          'đầy thì nổ gây sát thương ×${GameConfig.healerOrbDamage} sức chứa lên 1 kẻ địch',
  };
}

String _pct(double v) => '${(v * 100).round()}%';

extension MonsterCombat on MonsterType {
  double get speed => switch (this) {
    MonsterType.beast => 12,
    MonsterType.golem => 6,
    MonsterType.spirit => 10,
    MonsterType.demon => 10,
    MonsterType.goblin => 11,
    MonsterType.seaBeast => 9,
    MonsterType.harpy => 13,
    MonsterType.yeti => 8,
    MonsterType.soldier => 9,
  };

  double get evasion => this == MonsterType.harpy ? 0.15 : 0.03;

  /// Skill riêng của loài.
  Skill get ownSkill => switch (this) {
    MonsterType.beast => const Skill(
      'Cắn xé',
      hitScope: Scope.enemy,
      damage: 1.6,
      cooldown: 2,
    ),
    MonsterType.golem => const Skill(
      'Nện đất',
      hitScope: Scope.allEnemies,
      damage: 0.8,
      cooldown: 3,
    ),
    MonsterType.spirit => const Skill(
      'Hút hồn',
      hitScope: Scope.enemy,
      damage: 1.3,
      lifesteal: 0.5,
      cooldown: 3,
    ),
    MonsterType.demon => const Skill(
      'Lửa địa ngục',
      hitScope: Scope.allEnemies,
      damage: 1.0,
      cooldown: 3,
    ),
    MonsterType.goblin => const Skill(
      'Đâm lén',
      hitScope: Scope.enemy,
      damage: 1.5,
      cooldown: 2,
    ),
    MonsterType.seaBeast => const Skill(
      'Sóng dữ',
      hitScope: Scope.allEnemies,
      damage: 0.7,
      weaken: 0.15,
      cooldown: 3,
    ),
    MonsterType.harpy => const Skill(
      'Bổ nhào',
      hitScope: Scope.enemy,
      damage: 0.8,
      hits: 2,
      cooldown: 3,
    ),
    MonsterType.yeti => const Skill(
      'Gầm thét',
      hitScope: Scope.allEnemies,
      damage: 0.3,
      weaken: 0.25,
      cooldown: 4,
    ),
    MonsterType.soldier => const Skill(
      'Đội hình',
      buffScope: Scope.allAllies,
      guard: 0.25,
      cooldown: 4,
    ),
  };

  /// Đòn đặc trưng (tương tự skill vũ khí của hunter).
  Skill get signatureSkill => attack == DamageType.physical
      ? const Skill('Vuốt sắc', hitScope: Scope.enemy, damage: 1.3, cooldown: 2)
      : const Skill(
          'Cầu hắc ám',
          hitScope: Scope.allEnemies,
          damage: 0.6,
          cooldown: 3,
        );

  /// Tối thượng: chỉ quái đầu lĩnh mới có.
  Skill get bossUltimate => attack == DamageType.physical
      ? const Skill('Cuồng bạo', hitScope: Scope.allEnemies, damage: 1.6)
      : const Skill('Hắc diệt', hitScope: Scope.allEnemies, damage: 1.6);
}
