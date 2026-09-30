import 'dart:math';

import '../models/enums.dart';
import '../models/hunter.dart';
import '../models/potion.dart';
import '../models/quest.dart';
import '../models/skill.dart';
import 'game_config.dart';
import 'random_utils.dart';

/// Một đơn vị trong trận (hunter hoặc quái). Là bản sao, không đụng vào dữ liệu hunter thật.
class Combatant {
  Combatant({
    required this.name,
    required this.maxHp,
    required this.hp,
    required this.power,
    required this.damageType,
    required this.physReduction,
    required this.magicReduction,
    required this.evasion,
    required double speed,
    required this.skills,
    required this.ultimate,
    this.skillScale = 1,
    this.hunter,
    this.backRow = false,
    List<Potion>? potions,
  }) : baseSpeed = speed,
       potions = potions ?? [];

  factory Combatant.fromHunter(Hunter h) => Combatant(
    name: h.name,
    maxHp: h.maxHp,
    hp: h.hp,
    power: h.power,
    damageType: h.damageType,
    physReduction: damageReduction(h.physRes),
    magicReduction: damageReduction(h.magicRes),
    evasion: h.evasion,
    speed: h.speed,
    skills: [h.personalSkill, ?h.weaponSkill, ?h.bonusSkill],
    ultimate: h.ultimate,
    skillScale: h.skillScale,
    hunter: h,
    potions: List.of(h.potions), // bản sao: trận mô phỏng không tiêu bình thật
  );

  final String name;
  final double maxHp;
  double hp;
  final double power;
  final DamageType damageType;
  final double physReduction;
  final double magicReduction;
  final double evasion;
  final double baseSpeed;
  final List<Skill> skills;
  final Skill? ultimate;
  final double skillScale;
  final Hunter? hunter;

  /// Đứng hàng sau (quái tư tế): đòn đơn mục tiêu phải hạ hàng trước trước, trừ thợ săn bắn xa;
  /// đòn đánh cả đám vẫn trúng.
  final bool backRow;
  HunterClass? get hunterClass => hunter?.hunterClass;

  final cooldowns = <Skill, int>{};

  /// Số lần đã dùng từng skill trong trận (Húc khiên mạnh dần).
  final casts = <Skill, int>{};
  double energy = 0;

  /// Action Value (kiểu Honkai: Star Rail): còn bao nhiêu "thời gian" nữa tới lượt.
  /// Đơn vị có AV thấp nhất ra đòn; sau lượt AV đặt lại = [GameConfig.actionGauge] / tốc độ.
  late double av = baseAv;
  double get baseAv => GameConfig.actionGauge / speed;

  /// Tốc độ hiện tại (chiến binh nhanh dần khi mất máu).
  double get speed => baseSpeed * (1 + (hunterClass == HunterClass.warrior ? rage * GameConfig.warriorRageSpeed : 0));

  /// Chiến binh: 0 khi đầy máu, tiến tới 1 khi sắp gục.
  double get rage => (1 - hpRatio).clamp(0.0, 1.0);

  /// Pháp sư: số kẻ địch đã tự tay hạ.
  int kills = 0;

  /// Thợ săn đánh dấu: số lần bị giảm kháng.
  int shredStacks = 0;

  /// Hồi máu: năng lượng đã nạp vào quả cầu và sức chứa của nó.
  double orb = 0;
  double get orbCapacity => maxHp * GameConfig.healerOrbHpRatio;

  /// Đỡ đòn: số lớp giảm sát thương đang cộng dồn.
  int guardStacks = 0;

  /// Sát thương cộng thêm từ nội tại.
  double get passiveDamage => switch (hunterClass) {
    HunterClass.mage => min(kills, GameConfig.mageKillMaxStacks) * GameConfig.mageKillDamage,
    HunterClass.warrior => rage * GameConfig.warriorRageDamage,
    _ => 0,
  };

  /// Bình máu mang theo và đã uống trong trận (uống không mất lượt).
  final List<Potion> potions;
  final usedPotions = <Potion>[];

  // Hiệu ứng: giá trị và số lượt còn lại.
  double guard = 0;
  int guardTurns = 0;
  double empower = 0;
  int empowerTurns = 0;
  double weaken = 0;
  int weakenTurns = 0;
  int tauntTurns = 0;

  bool get alive => hp > 0;
  double get hpRatio => hp / maxHp;
  /// % sát thương được giảm, đã trừ phần kháng bị thợ săn đánh dấu (có thể âm).
  double reductionFor(DamageType type) =>
      (type == DamageType.physical ? physReduction : magicReduction) - shredStacks * GameConfig.rangerShredPerStack;

  /// Gọi đầu lượt của đơn vị: giảm hồi chiêu và thời gian hiệu ứng.
  void startTurn() {
    cooldowns.updateAll((_, turns) => max(0, turns - 1));
    if (--guardTurns <= 0) {
      guard = 0;
      guardStacks = 0;
    }
    if (--empowerTurns <= 0) empower = 0;
    if (--weakenTurns <= 0) weaken = 0;
    if (tauntTurns > 0) tauntTurns--;
  }
}

/// % sát thương được giảm nhờ kháng (tối đa 60%).
double damageReduction(double res) => res / (res + 60) * 0.6;

class BattleResult {
  const BattleResult({
    required this.win,
    required this.rounds,
    required this.log,
    required this.hpAfter,
    required this.downed,
    this.potionsUsed = const {},
  });

  final bool win;

  /// Số chu kỳ (cycle) đã trôi qua.
  final int rounds;
  final List<String> log;

  /// Bình máu từng hunter đã uống trong trận.
  final Map<Hunter, List<Potion>> potionsUsed;

  /// Máu còn lại của từng hunter sau trận (0 = bị gục).
  final Map<Hunter, double> hpAfter;
  final Set<Hunter> downed;
}

class CombatEngine {
  CombatEngine(this._random);

  final Random _random;

  /// Dựng phe quái từ quest: quái đông = nhiều con nhỏ; quái ít = 1 đầu lĩnh (có tối thượng).
  /// Đôi khi kèm 1 tư tế máu mỏng chuyên hồi máu cho đồng bọn ([withHealer] để ép có/không).
  List<Combatant> buildEnemies(Quest quest, {bool? withHealer}) {
    final partyFactor = quest.difficulty / quest.tier.difficulty; // gồm hệ số nhóm và dao động
    final totalHp = quest.difficulty * GameConfig.enemyHpPerDifficulty;
    final totalPower =
        quest.tier.enemyDamage *
        partyFactor *
        GameConfig.enemyPowerPerDamage *
        (quest.isGroup ? GameConfig.groupEnemyPowerFactor : 1);
    final m = quest.monster;

    final healer = withHealer ?? _random.nextDouble() < GameConfig.enemyHealerChance;
    // Tư tế lấy bớt một phần máu của cả bầy nên tổng máu phe quái không đổi.
    final mainHp = totalHp * (healer ? 1 - GameConfig.enemyHealerHpShare : 1);

    Combatant make(String name, double share, {bool boss = false}) => Combatant(
      name: name,
      maxHp: mainHp * share,
      hp: mainHp * share,
      // Đầu lĩnh có tối thượng bù lại nên sức mạnh thường thấp hơn phần chia.
      power: totalPower * share * (boss ? GameConfig.bossPowerFactor : 1),
      damageType: m.attack,
      physReduction: m.physRes,
      magicReduction: m.magicRes,
      evasion: m.evasion,
      speed: GameConfig.speedBase + m.speed + quest.tier.minLevel * GameConfig.monsterSpeedPerTierLevel,
      skills: [m.ownSkill, m.signatureSkill],
      ultimate: boss ? m.bossUltimate : null,
    );

    final List<Combatant> units;
    if (quest.isHorde) {
      final count = (quest.isGroup ? 5 : 3) + _random.nextInt(2);
      units = [for (var i = 0; i < count; i++) make('${m.label} ${String.fromCharCode(65 + i)}', 1 / count)];
    } else if (quest.isGroup) {
      units = [make('${m.label} đầu lĩnh', 0.7, boss: true), make('${m.label} hộ vệ', 0.3)];
    } else {
      units = [make('${m.label} đầu lĩnh', 1, boss: true)];
    }
    if (healer) {
      units.add(
        Combatant(
          name: '${m.label} tư tế',
          maxHp: totalHp * GameConfig.enemyHealerHpShare,
          hp: totalHp * GameConfig.enemyHealerHpShare,
          power: totalPower * GameConfig.enemyHealerPowerShare,
          damageType: DamageType.magic,
          physReduction: 0,
          magicReduction: 0,
          evasion: m.evasion,
          speed: GameConfig.speedBase + m.speed + quest.tier.minLevel * GameConfig.monsterSpeedPerTierLevel,
          skills: [enemyHealSkill],
          ultimate: null,
          backRow: true,
        ),
      );
    }
    return units;
  }

  BattleResult fight(Quest quest, List<Hunter> party, {bool recordLog = true}) {
    final heroes = [for (final h in party) Combatant.fromHunter(h)];
    final enemies = buildEnemies(quest);
    final log = <String>[];
    void say(String line) {
      if (recordLog) log.add(line);
    }

    say('⚔ ${heroes.map((c) => c.name).join(', ')} gặp ${enemies.map((c) => c.name).join(', ')}');

    // Dòng thời gian Action Value: không chia vòng cố định, ai tới lượt (AV thấp nhất) thì đánh.
    // Nhanh gấp đôi = được đánh gấp đôi số lần. Chu kỳ đầu dài 150%, các chu kỳ sau 100% (như HSR).
    for (final c in [...heroes, ...enemies]) {
      c.av *= randomBetween(_random, 0.95, 1.05); // lệch nhẹ vị trí xuất phát để tránh hòa
    }
    const firstCycle = GameConfig.cycleAv * 1.5;
    const timeLimit = firstCycle + GameConfig.cycleAv * (GameConfig.maxBattleRounds - 1);
    int cycleAt(double t) => t < firstCycle ? 1 : 2 + (t - firstCycle) ~/ GameConfig.cycleAv;

    var elapsed = 0.0;
    bool? win;
    while (win == null) {
      final alive = [...heroes, ...enemies].where((c) => c.alive);
      final unit = alive.reduce((a, b) => a.av <= b.av ? a : b);
      if (elapsed + unit.av > timeLimit) break; // hết giờ -> rút lui
      final step = unit.av;
      elapsed += step;
      for (final c in alive) {
        c.av -= step;
      }
      final isHero = heroes.contains(unit);
      _act(unit, isHero ? heroes : enemies, isHero ? enemies : heroes, isHero, cycleAt(elapsed), elapsed, say);
      unit.av = unit.baseAv;
      if (enemies.every((c) => !c.alive)) win = true;
      if (heroes.every((c) => !c.alive)) win = false;
    }
    win ??= false;
    final cycles = cycleAt(min(elapsed, timeLimit - 1));
    say(win ? '🏆 Chiến thắng sau $cycles chu kỳ!' : '💀 Thất bại sau $cycles chu kỳ.');

    return BattleResult(
      win: win,
      rounds: cycles,
      log: log,
      hpAfter: {for (final c in heroes) c.hunter!: max(0, c.hp)},
      downed: {
        for (final c in heroes)
          if (!c.alive) c.hunter!,
      },
      potionsUsed: {
        for (final c in heroes)
          if (c.usedPotions.isNotEmpty) c.hunter!: c.usedPotions,
      },
    );
  }

  /// Uống bình máu ngay khi máu tụt dưới ngưỡng, không tốn lượt. Chọn bình nhỏ nhất đủ bù máu đã mất.
  void _drinkIfLow(Combatant c, void Function(String) say) {
    if (!c.alive || c.potions.isEmpty || c.hpRatio >= GameConfig.battlePotionThreshold) return;
    final missing = 1 - c.hpRatio;
    c.potions.sort((a, b) => a.index.compareTo(b.index));
    final potion = c.potions.firstWhere((p) => p.healPercent >= missing, orElse: () => c.potions.last);
    c.potions.remove(potion);
    c.usedPotions.add(potion);
    final before = c.hp;
    c.hp = min(c.maxHp, c.hp + c.maxHp * potion.healPercent);
    say('   🧪 ${c.name} uống ${potion.label} +${(c.hp - before).round()} HP (không mất lượt)');
  }

  void _act(
    Combatant unit,
    List<Combatant> allies,
    List<Combatant> foes,
    bool isHero,
    int cycle,
    double time,
    void Function(String) say,
  ) {
    unit.startTurn();
    final skill = _chooseSkill(unit, allies, foes);
    final isUltimate = skill == unit.ultimate;
    if (isUltimate) {
      unit.energy = 0;
    } else {
      unit.energy = min(GameConfig.maxEnergy, unit.energy + GameConfig.energyPerAction);
      if (skill.cooldown > 0) unit.cooldowns[skill] = skill.cooldown + 1; // +1 vì giảm ngay đầu lượt sau
    }

    final scale = skill == basicAttack ? 1.0 : unit.skillScale;
    final effects = <String>[];
    final passives = <String>[];

    // Tấn công
    if (skill.damage > 0) {
      final aliveFoes = foes.where((c) => c.alive).toList();
      final targets = skill.hitScope == Scope.allEnemies ? aliveFoes : [_pickTarget(aliveFoes, isHero, unit)];
      final foeHpShare = skill.foeHpDamageAfter(unit.casts[skill] ?? 0) / allies.where((c) => c.alive).length;
      // Sức mạnh quái đã nhân theo số người trong đội, nên đòn lan của quái giảm dần theo số mục tiêu
      // để không bị tính 2 lần (1 mục tiêu: 100%, 2: 67%, 4: 40% mỗi người).
      final spread = !isHero && targets.length > 1 ? 1 / (0.5 + 0.5 * targets.length) : 1.0;
      for (final target in targets) {
        var dealt = 0.0;
        var missed = 0;
        var crits = 0;
        for (var i = 0; i < skill.hits && target.alive; i++) {
          if (_random.nextDouble() < target.evasion) {
            missed++;
            continue;
          }
          final crit = _random.nextDouble() < GameConfig.critChance;
          if (crit) crits++;
          final damage =
              (unit.power * skill.damage + target.maxHp * foeHpShare) *
              (crit ? GameConfig.critMultiplier : 1) *
              scale *
              spread *
              (1 + unit.empower + unit.passiveDamage) *
              (1 - unit.weaken) *
              (1 - target.reductionFor(unit.damageType)) *
              (1 - target.guard) *
              randomBetween(_random, 1 - GameConfig.damageVariance, 1 + GameConfig.damageVariance);
          target.hp -= damage;
          target.energy = min(GameConfig.maxEnergy, target.energy + GameConfig.energyWhenHit);
          dealt += damage;
          if (!target.alive && unit.hunterClass == HunterClass.mage) {
            unit.kills++;
            if (unit.kills <= GameConfig.mageKillMaxStacks) {
              passives.add('🔮 +${(unit.passiveDamage * 100).round()}% sát thương');
            }
          }
        }
        if (unit.hunterClass == HunterClass.ranger &&
            dealt > 0 &&
            target.alive &&
            target.shredStacks < GameConfig.rangerShredMaxStacks) {
          target.shredStacks++;
          passives.add('🎯 ${target.name} đánh dấu ×${target.shredStacks}');
        }
        if (skill.weaken > 0 && dealt > 0) {
          target
            ..weaken = skill.weaken
            ..weakenTurns = skill.duration + 1;
        }
        if (skill.lifesteal > 0) unit.hp = min(unit.maxHp, unit.hp + dealt * skill.lifesteal);
        effects.add(
          dealt == 0
              ? '${target.name} né được'
              : crits > 0
              ? '${target.name} -${dealt.round()} ⚡chí mạng${target.alive ? '' : ' 💥 gục!'}'
              : '${target.name} -${dealt.round()}${missed > 0 ? ' (né $missed)' : ''}${target.alive ? '' : ' 💥 gục!'}',
        );
      }
    }

    if (skill.foeHpDamage > 0) unit.casts.update(skill, (n) => n + 1, ifAbsent: () => 1);

    // Hồi máu
    if (skill.heal > 0) {
      final aliveAllies = allies.where((c) => c.alive).toList();
      final targets = skill.healScope == Scope.allAllies
          ? aliveAllies
          : [aliveAllies.reduce((a, b) => a.hpRatio <= b.hpRatio ? a : b)];
      var healed = 0.0;
      for (final target in targets) {
        final before = target.hp;
        final amount = unit.power * skill.heal * scale;
        target.hp = min(target.maxHp, target.hp + amount);
        healed += target.hp - before;
        effects.add('${target.name} +${(target.hp - before).round()} HP');
      }
      if (unit.hunterClass == HunterClass.healer) _chargeOrb(unit, healed, foes, isHero, passives);
    }

    // Hỗ trợ
    if (skill.buffScope != Scope.none) {
      final targets = skill.buffScope == Scope.allAllies ? allies.where((c) => c.alive) : [unit];
      for (final target in targets) {
        if (skill.guard > 0) {
          final active = target.guardTurns > 0 && target.guard > 0;
          if (target == unit &&
              unit.hunterClass == HunterClass.tank &&
              active &&
              target.guardStacks < GameConfig.tankGuardStacks) {
            // Đỡ đòn: tự buff chồng lên lớp đang có.
            target
              ..guard = min(GameConfig.tankGuardCap, target.guard + skill.guard)
              ..guardStacks += 1;
            passives.add('🛡 ${target.name} cộng dồn giảm ${(target.guard * 100).round()}% sát thương');
          } else if (!active || skill.guard >= target.guard) {
            target
              ..guard = skill.guard
              ..guardStacks = 1;
          }
          final selfTank = target == unit && unit.hunterClass == HunterClass.tank;
          target.guardTurns = skill.duration + 1 + (selfTank ? GameConfig.tankGuardBonusTurns : 0);
        }
        if (skill.empower > 0) {
          target
            ..empower = skill.empower
            ..empowerTurns = skill.duration + 1;
        }
      }
      if (skill.taunt) unit.tauntTurns = skill.duration;
      effects.add(
        [
          if (skill.taunt) 'khiêu khích',
          if (skill.guard > 0) '${skill.buffScope == Scope.allAllies ? 'cả đội' : 'bản thân'} giảm sát thương',
          if (skill.empower > 0) '${skill.buffScope == Scope.allAllies ? 'cả đội' : 'bản thân'} tăng sức mạnh',
        ].join(', '),
      );
    }

    final label = isUltimate ? '🌟 TỐI THƯỢNG [${skill.name}]' : (skill == basicAttack ? 'đánh' : '[${skill.name}]');
    say('C$cycle · AV ${time.round()} · ${unit.name} $label → ${effects.join(', ')}');
    for (final line in passives) {
      say('   $line');
    }

    // Hunter bị đánh tụt máu thì uống bình ngay (hành động tự do).
    if (!isHero && skill.damage > 0) {
      for (final hero in foes) {
        _drinkIfLow(hero, say);
      }
    }
  }

  /// Hồi máu: toàn bộ lượng hồi (kể cả phần dư) nạp vào quả cầu năng lượng; đầy thì nổ lên 1 kẻ địch
  /// (không né được, không chí mạng, vẫn tính kháng), phần nạp thừa giữ lại cho quả sau.
  void _chargeOrb(Combatant unit, double healed, List<Combatant> foes, bool isHero, List<String> passives) {
    final capacity = unit.orbCapacity;
    unit.orb += healed;
    while (unit.orb >= capacity) {
      final aliveFoes = foes.where((c) => c.alive).toList();
      if (aliveFoes.isEmpty) return;
      unit.orb -= capacity;
      final target = _pickTarget(aliveFoes, isHero, unit);
      final damage =
          capacity *
          GameConfig.healerOrbDamage *
          (1 - target.reductionFor(unit.damageType)) *
          (1 - target.guard);
      target.hp -= damage;
      passives.add('✨ quả cầu năng lượng nổ → ${target.name} -${damage.round()}${target.alive ? '' : ' 💥 gục!'}');
    }
    passives.add('✨ quả cầu ${(unit.orb / capacity * 100).round()}%');
  }

  /// Hunter dồn đánh con yếu máu nhất; quái đánh ngẫu nhiên, nhưng phải đánh hunter đang khiêu khích.
  Combatant _pickTarget(List<Combatant> aliveFoes, bool isHero, Combatant attacker) {
    if (isHero) {
      final front = aliveFoes.where((c) => !c.backRow).toList();
      final pool = front.isEmpty || attacker.hunterClass == HunterClass.ranger ? aliveFoes : front;
      return pool.reduce((a, b) => a.hp <= b.hp ? a : b);
    }
    final taunting = aliveFoes.where((c) => c.tauntTurns > 0).toList();
    final pool = taunting.isNotEmpty ? taunting : aliveFoes;
    return pool[_random.nextInt(pool.length)];
  }

  /// AI chọn chiêu có giá trị cao nhất lúc này; tối thượng dùng ngay khi đầy năng lượng.
  Skill _chooseSkill(Combatant unit, List<Combatant> allies, List<Combatant> foes) {
    if (unit.ultimate != null && unit.energy >= GameConfig.maxEnergy) return unit.ultimate!;

    final aliveFoes = foes.where((c) => c.alive).length;
    final aliveAllies = allies.where((c) => c.alive).toList();
    final lowestAlly = aliveAllies.map((c) => c.hpRatio).reduce(min);
    final weakestFoeMaxHp = foes.where((c) => c.alive).fold<Combatant?>(null, (a, b) => a == null || b.hp < a.hp ? b : a)?.maxHp ?? 0;

    double score(Skill s) {
      final perHit =
          s.damage +
          (s.foeHpDamage > 0
              ? s.foeHpDamageAfter(unit.casts[s] ?? 0) * weakestFoeMaxHp / unit.power / aliveAllies.length
              : 0);
      var value = perHit * s.hits * (s.hitScope == Scope.allEnemies ? aliveFoes : 1);
      if (s.heal > 0) {
        final missing = s.healScope == Scope.allAllies
            ? aliveAllies.fold(0.0, (sum, c) => sum + (1 - c.hpRatio))
            : 1 - lowestAlly;
        value += s.heal * missing * 2;
      }
      final buffCount = s.buffScope == Scope.allAllies ? aliveAllies.length : 1;
      final canStackGuard = unit.hunterClass == HunterClass.tank && unit.guardStacks < GameConfig.tankGuardStacks;
      if (s.guard > 0 && (unit.guardTurns <= 0 || canStackGuard)) value += s.guard * 3 * buffCount;
      if (s.empower > 0 && unit.empowerTurns <= 0) value += s.empower * 4 * buffCount;
      if (s.taunt && unit.tauntTurns <= 0 && aliveAllies.length > 1) value += 1.5;
      if (s.weaken > 0) value += s.weaken * 2;
      return value;
    }

    var best = basicAttack;
    var bestScore = score(basicAttack);
    for (final s in unit.skills) {
      if ((unit.cooldowns[s] ?? 0) > 0) continue;
      final value = score(s);
      if (value > bestScore) {
        best = s;
        bestScore = value;
      }
    }
    return best;
  }
}
