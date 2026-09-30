import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game/logic/save_service.dart';
import 'package:game/logic/combat.dart';
import 'package:game/logic/game_config.dart';
import 'package:game/logic/game_state.dart';
import 'package:game/logic/hunter_factory.dart';
import 'package:game/logic/market.dart';
import 'package:game/models/events.dart';
import 'package:game/logic/quest_resolver.dart';
import 'package:game/logic/shopping.dart';
import 'package:game/main.dart';
import 'package:game/screens/map_screen.dart';
import 'package:game/screens/hunter_list_screen.dart';
import 'package:game/screens/hunter_detail_screen.dart';
import 'package:game/widgets/hunter_roster_card.dart';
import 'package:game/screens/quest_board_screen.dart';
import 'package:game/screens/quest_detail_screen.dart';
import 'package:game/widgets/phase_report_dialog.dart';
import 'package:game/screens/stock_market_screen.dart';
import 'package:game/logic/stock_market.dart';
import 'package:game/models/stock.dart';
import 'package:flutter/material.dart';
import 'package:game/models/enums.dart';
import 'package:game/models/hunter.dart';
import 'package:game/models/crafting.dart';
import 'package:game/models/day.dart';
import 'package:game/models/equipment.dart';
import 'package:game/models/potion.dart';
import 'package:game/models/quest.dart';
import 'package:game/models/skill.dart';
import 'package:game/models/stats.dart';
import 'package:game/models/town.dart';
import 'package:game/models/trade.dart';
import 'package:game/models/world_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game/logic/quest_generator.dart';

Quest _quest({bool isHorde = false, bool isGroup = false, QuestTier tier = QuestTier.d}) => Quest(
      id: 0,
      location: Location.grassland,
      tier: tier,
      monster: MonsterType.beast,
      isHorde: isHorde,
      isGroup: isGroup,
      minParty: isGroup ? 2 : 1,
      maxParty: isGroup ? 4 : 1,
      difficulty: 40,
      gold: 10,
      exp: 10,
    );

Hunter _hunter(HunterClass c, {int age = 20, Rarity rarity = Rarity.common}) => Hunter(
      id: c.index,
      name: c.label,
      hunterClass: c,
      rarity: rarity,
      age: age,
      stats: GameConfig.classBaseStats[c]!,
    );

void main() {
  _hunterScreensLayoutTests();
  Quest battleQuest({required bool horde, double difficulty = 55}) => Quest(
        id: 7,
        location: Location.grassland,
        tier: QuestTier.c,
        monster: MonsterType.beast,
        isHorde: horde,
        isGroup: false,
        minParty: 1,
        maxParty: 1,
        difficulty: difficulty,
        gold: 0,
        exp: 0,
      );

  Hunter leveled(HunterClass c, int level, {int skill = 0}) {
    final h = Hunter(
      id: c.index,
      name: c.label,
      hunterClass: c,
      rarity: Rarity.common,
      age: 25,
      stats: GameConfig.classBaseStats[c]!,
      personalSkillIndex: skill,
    );
    while (h.level < level) {
      h.gainExp(h.expToNext);
    }
    h.hp = h.maxHp;
    return h;
  }

  test('combat theo lượt: có nhật ký, dùng skill, tối thượng; không đụng máu thật của hunter', () {
    final h = leveled(HunterClass.warrior, 7);
    final hpBefore = h.hp;
    final battle = CombatEngine(Random(1)).fight(battleQuest(horde: false), [h]);
    expect(battle.log.first, startsWith('⚔'));
    expect(battle.log.any((l) => l.contains('[${h.personalSkill.name}]')), isTrue);
    expect(battle.log.last, anyOf(startsWith('🏆'), startsWith('💀')));
    expect(h.hp, hpBefore); // chỉ resolve mới ghi máu vào hunter
    expect(battle.hpAfter[h], lessThan(hpBefore));
  });

  test('quái đông = nhiều con, quái ít = 1 đầu lĩnh có tối thượng; tổng máu theo độ khó', () {
    final engine = CombatEngine(Random(1));
    final horde = engine.buildEnemies(battleQuest(horde: true), withHealer: false);
    final boss = engine.buildEnemies(battleQuest(horde: false), withHealer: false);
    expect(horde.length, greaterThanOrEqualTo(3));
    expect(horde.every((c) => c.ultimate == null), isTrue);
    expect(boss, hasLength(1));
    expect(boss.single.ultimate, isNotNull);
    expect(horde.fold(0.0, (s, c) => s + c.maxHp), closeTo(55 * GameConfig.enemyHpPerDifficulty, 0.01));
  });

  test('pháp sư (đánh lan) hợp quái đông hơn quái ít; thợ săn (Bắn tỉa) không kém khi gặp đầu lĩnh', () {
    final mage = leveled(HunterClass.mage, 7, skill: 1); // Mưa băng
    final ranger = leveled(HunterClass.ranger, 7); // Bắn tỉa
    final mageHorde = QuestResolver.estimate(battleQuest(horde: true), [mage], runs: 300).winRate;
    final mageBoss = QuestResolver.estimate(battleQuest(horde: false), [mage], runs: 300).winRate;
    final rangerBoss = QuestResolver.estimate(battleQuest(horde: false), [ranger], runs: 300).winRate;
    expect(mageHorde, greaterThan(mageBoss));
    expect(rangerBoss, greaterThan(mageBoss));
  });

  test('bị gục mới có thể chết; healer đứng vững giảm mạnh tỉ lệ chết, tuổi cao tăng tỉ lệ chết', () {
    final q = _quest();
    final young = _hunter(HunterClass.warrior, age: 20);
    final old = _hunter(HunterClass.warrior, age: 60);
    final alone = QuestResolver.downedDeathChance(young, q, won: false, standingHealers: 0);
    expect(QuestResolver.downedDeathChance(young, q, won: false, standingHealers: 1), lessThan(alone * 0.5));
    expect(QuestResolver.downedDeathChance(old, q, won: false, standingHealers: 0), greaterThan(alone));
    expect(QuestResolver.downedDeathChance(young, q, won: true, standingHealers: 0), lessThan(alone));

    // Hunter mạnh đánh quest rất dễ: không bị gục nên không chết.
    final strong = leveled(HunterClass.warrior, 20);
    for (var seed = 0; seed < 20; seed++) {
      expect(QuestResolver(Random(seed)).resolve(battleQuest(horde: false, difficulty: 5), [strong]).deaths, isEmpty);
    }
  });

  test('nội tại: pháp sư mạnh dần theo số kill, chiến binh mất máu thì nhanh và mạnh hơn', () {
    final mage = Combatant.fromHunter(leveled(HunterClass.mage, 7));
    expect(mage.passiveDamage, 0);
    mage.kills = 2;
    expect(mage.passiveDamage, closeTo(2 * GameConfig.mageKillDamage, 1e-9));
    mage.kills = 99;
    expect(mage.passiveDamage, closeTo(GameConfig.mageKillMaxStacks * GameConfig.mageKillDamage, 1e-9));

    final warrior = Combatant.fromHunter(leveled(HunterClass.warrior, 7));
    final fullSpeed = warrior.speed;
    expect(warrior.passiveDamage, 0);
    warrior.hp = warrior.maxHp / 2;
    expect(warrior.speed, closeTo(fullSpeed * (1 + GameConfig.warriorRageSpeed / 2), 1e-9));
    expect(warrior.passiveDamage, closeTo(GameConfig.warriorRageDamage / 2, 1e-9));
    expect(warrior.baseAv, lessThan(GameConfig.actionGauge / fullSpeed));

    // Lớp khác không có nội tại sát thương.
    final tank = Combatant.fromHunter(leveled(HunterClass.tank, 7))..hp = 1;
    expect(tank.passiveDamage, 0);
  });

  test('nội tại trong trận: thợ săn đánh dấu giảm kháng, healer nạp quả cầu năng lượng rồi nổ, tank cộng dồn giáp', () {
    bool logged(HunterClass c, String mark, {int skill = 0, bool horde = false}) {
      for (var seed = 0; seed < 10; seed++) {
        final battle = CombatEngine(Random(seed)).fight(battleQuest(horde: horde), [leveled(c, 7, skill: skill)]);
        if (battle.log.any((l) => l.contains(mark))) return true;
      }
      return false;
    }

    expect(logged(HunterClass.ranger, '🎯'), isTrue);
    expect(logged(HunterClass.healer, '✨ quả cầu năng lượng nổ', skill: 1), isTrue);
    expect(logged(HunterClass.tank, '🛡'), isTrue);
    expect(logged(HunterClass.mage, '🔮', skill: 1, horde: true), isTrue);

    final monster = CombatEngine(Random(1)).buildEnemies(battleQuest(horde: false), withHealer: false).single;
    final res = monster.reductionFor(DamageType.physical);
    monster.shredStacks = 2;
    expect(monster.reductionFor(DamageType.physical), closeTo(res - 2 * GameConfig.rangerShredPerStack, 1e-9));
  });

  test('đỡ đòn có Húc khiên theo máu đối thủ, solo mạnh hơn đi nhóm', () {
    final tank = leveled(HunterClass.tank, 7);
    expect(tank.bonusSkill!.foeHpDamage, greaterThan(0));
    expect(leveled(HunterClass.mage, 7).bonusSkill, isNull);

    /// Sát thương trung bình mỗi lần Húc khiên.
    double slamDamage(int partySize) {
      var total = 0.0;
      var count = 0;
      for (var seed = 0; seed < 30; seed++) {
        final party = [tank, for (var i = 1; i < partySize; i++) leveled(HunterClass.warrior, 7)];
        final battle = _NoHealerEngine(Random(seed)).fight(battleQuest(horde: false, difficulty: 400), party);
        for (final l in battle.log.where((l) => l.contains('Đỡ đòn [Húc khiên]'))) {
          final m = RegExp(r'-(\d+)').firstMatch(l);
          if (m != null) {
            total += int.parse(m.group(1)!);
            count++;
          }
        }
      }
      return total / count;
    }

    expect(slamDamage(1), greaterThan(slamDamage(4) * 1.5));
  });

  test('Húc khiên: 5% máu tối đa đối thủ, +2% mỗi lần dùng, tối đa 4 lần', () {
    final slam = leveled(HunterClass.tank, 7).bonusSkill!;
    expect(slam.foeHpDamageAfter(0), closeTo(0.05, 1e-9));
    expect(slam.foeHpDamageAfter(2), closeTo(0.09, 1e-9));
    expect(slam.foeHpDamageAfter(4), closeTo(0.13, 1e-9));
    expect(slam.foeHpDamageAfter(10), closeTo(0.13, 1e-9));
  });

  test('quái tư tế: máu mỏng, hồi máu cho đồng bọn, tổng máu phe quái không đổi', () {
    final engine = CombatEngine(Random(1));
    final quest = battleQuest(horde: false);
    final plain = engine.buildEnemies(quest, withHealer: false);
    final withHealer = engine.buildEnemies(quest, withHealer: true);
    expect(withHealer, hasLength(plain.length + 1));
    final priest = withHealer.last;
    expect(priest.skills, [enemyHealSkill]);
    expect(priest.maxHp, lessThan(withHealer.first.maxHp * 0.2));
    double total(List<Combatant> units) => units.fold(0.0, (s, c) => s + c.maxHp);
    expect(total(withHealer), closeTo(total(plain), 0.01));

    var healed = false;
    for (var seed = 0; seed < 20 && !healed; seed++) {
      final engine = _HealerEngine(Random(seed));
      final battle = engine.fight(quest, [leveled(HunterClass.tank, 7)]);
      healed = battle.log.any((l) => l.contains('[${enemyHealSkill.name}]'));
    }
    expect(healed, isTrue);
  });

  test('chứng khoán: mua/bán có phí, cập nhật vốn, không mua quá tiền, đêm đóng cửa', () {
    final game = GameState(random: Random(1))..gold = 1000;
    const c = Company.royalBank;
    final price = game.stocks.priceOf(c);
    final cost = game.stocks.buyCost(c, 3);
    expect(cost, price * 3 + StockMarket.feeFor(price * 3));
    game.buyShares(c, 3);
    expect(game.gold, 1000 - cost);
    expect(game.stocks.sharesOf(c), 3);
    expect(game.stocks.holdings[c]!.averageCost, closeTo(cost / 3, 1e-9));
    expect(game.stockTradeError(c, 1000, buy: true), 'Không đủ vàng');
    expect(game.stockTradeError(c, 4, buy: false), 'Không đủ cổ phiếu để bán');
    expect(game.stocks.maxAffordable(c, game.gold), lessThanOrEqualTo(game.gold ~/ price));
    expect(game.stocks.buyCost(c, game.stocks.maxAffordable(c, game.gold)), lessThanOrEqualTo(game.gold));

    final before = game.gold;
    game.sellShares(c, 2);
    expect(game.gold, before + game.stocks.sellProceeds(c, 2));
    expect(game.stocks.sharesOf(c), 1);
    game.sellShares(c, 1);
    expect(game.stocks.holdings, isEmpty);

    game.advancePhase();
    game.advancePhase(); // đêm
    expect(game.stockMarketOpen, isFalse);
    expect(game.stockTradeError(c, 1, buy: true), 'Sàn đóng cửa ban đêm');
  });

  test('chứng khoán: giá đổi mỗi sáng, lịch sử giới hạn, cổ tức đầu tuần, tính vào thanh lý', () {
    final game = GameState(random: Random(2))..gold = 100000;
    game.buyShares(Company.royalBank, 10);
    final liquidation = game.liquidationValue;
    expect(liquidation, greaterThanOrEqualTo(game.stocks.sellProceeds(Company.royalBank, 10)));

    final start = Map.of(game.stocks.prices);
    var dividends = 0;
    while (game.day < GameConfig.weekDays + 1) {
      final r = game.advancePhase();
      if (r.stocks case final s?) {
        expect(s.changes.keys, containsAll(Company.values));
        dividends += s.dividendTotal;
      }
    }
    expect(game.isDividendDay, isTrue);
    expect(dividends, greaterThan(0)); // trả đúng sáng ngày 8
    expect(game.stocks.prices, isNot(equals(start)));
    for (var i = 0; i < GameConfig.stockHistoryDays * 3 + 3; i++) {
      game.advancePhase();
    }
    expect(game.stocks.history[Company.mining]!.length, GameConfig.stockHistoryDays);
    expect(game.dailyReports.any((d) => d.stocks > 0), isTrue); // cổ tức vào dòng tiền chứng khoán
  });

  test('chứng khoán: dịch bệnh đẩy giá Đền Ánh Sáng lên, thời tiết xấu kéo Thương Đoàn xuống', () {
    double avgChange(Company c, WeeklyEventType type) {
      var total = 0.0;
      for (var seed = 0; seed < 200; seed++) {
        final m = StockMarket();
        final changes = m.tick(Random(seed), event: WeeklyEvent(type: type, startDay: 1), day: 1);
        total += changes[c]!;
      }
      return total / 200;
    }

    expect(avgChange(Company.temple, WeeklyEventType.plague), greaterThan(0.02));
    expect(avgChange(Company.caravan, WeeklyEventType.weather), lessThan(-0.015));
  });

  test('chứng khoán được lưu; bản lưu cũ không có sàn vẫn mở được', () {
    final game = GameState(random: Random(3))..gold = 5000;
    game.buyShares(Company.arcane, 5);
    for (var i = 0; i < 3; i++) {
      game.advancePhase();
    }
    final loaded = GameState.fromJson(jsonDecode(jsonEncode(game.toJson())) as Map<String, dynamic>);
    expect(loaded.stocks.sharesOf(Company.arcane), 5);
    expect(loaded.stocks.prices, game.stocks.prices);
    expect(loaded.stocks.history[Company.arcane], game.stocks.history[Company.arcane]);
    expect(loaded.stocks.holdings[Company.arcane]!.cost, game.stocks.holdings[Company.arcane]!.cost);

    final old = game.toJson()..remove('stocks');
    expect(GameState.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>).stocks.holdings, isEmpty);
  });

  test('skill vũ khí theo vũ khí tay chính; vũ khí hỏng thì mất skill', () {
    final h = leveled(HunterClass.warrior, 1);
    expect(h.weaponSkill, isNull);
    final sword = Equipment.standard(id: 1, type: ItemType.sword, grade: ItemGrade.basic);
    h.equip(sword);
    expect(h.weaponSkill!.name, 'Chém lan');
    sword.condition = 0;
    expect(h.weaponSkill, isNull);
  });

  test('hunter hiếm tăng nhiều chỉ số hơn khi lên cấp, né tránh tối đa 80%', () {
    final common = _hunter(HunterClass.ranger);
    final legendary = _hunter(HunterClass.ranger, rarity: Rarity.legendary);
    common.gainExp(100000);
    legendary.gainExp(100000);
    expect(legendary.power, greaterThan(common.power));
    legendary.gainExp(100000000);
    expect(legendary.evasion, lessThanOrEqualTo(GameConfig.maxEvasion));
  });

  test('quest nhóm bắt buộc đủ người và đủ cấp', () {
    final q = _quest(isGroup: true, tier: QuestTier.c);
    final h = HunterFactory(Random(1)).create(1);
    expect(QuestResolver.validateParty(q, [h]), isNotNull);
    h.gainExp(100000);
    expect(QuestResolver.validateParty(q, [h, h]), isNull);
  });

  test('tỉ lệ xuất hiện tier gần đúng cấu hình', () {
    final generator = QuestGenerator(Random(42));
    const samples = 20000;
    final counts = <QuestTier, int>{};
    for (var i = 0; i < samples; i++) {
      final tier = generator.generate(i).tier;
      counts[tier] = (counts[tier] ?? 0) + 1;
    }
    for (final tier in QuestTier.values) {
      expect(counts[tier]! / samples * 100, closeTo(tier.weight, 1.5), reason: tier.label);
    }
  });

  test('game mới có bảng nhiệm vụ đầy đủ', () {
    expect(GameState(random: Random(42)).quests.length, GameConfig.boardSize);
  });

  test('vũ khí 2 tay tháo luôn vũ khí phụ', () {
    final ranger = _hunter(HunterClass.ranger);
    ranger.equip(Equipment.standard(id: 1, type: ItemType.sword, grade: ItemGrade.basic));
    ranger.equip(Equipment.standard(id: 2, type: ItemType.dagger, grade: ItemGrade.basic));
    final removed = ranger.equip(Equipment.standard(id: 3, type: ItemType.bow, grade: ItemGrade.basic));
    expect(removed.map((e) => e.type), unorderedEquals([ItemType.sword, ItemType.dagger]));
    expect(ranger.equipment.keys, [EquipSlot.mainHand]);
  });

  test('trang bị giới hạn theo lớp và cấp', () {
    final mage = _hunter(HunterClass.mage);
    expect(mage.equipError(Equipment.standard(id: 1, type: ItemType.sword, grade: ItemGrade.basic)), isNotNull);
    expect(mage.equipError(Equipment.standard(id: 2, type: ItemType.staff, grade: ItemGrade.fine)), isNotNull);
    expect(mage.equipError(Equipment.standard(id: 3, type: ItemType.staff, grade: ItemGrade.basic)), isNull);
  });

  test('healer sống sót hồi máu cho đồng đội sau quest nhóm, solo thì không', () {
    for (var seed = 0; seed < 20; seed++) {
      final warrior = _hunter(HunterClass.warrior);
      final healer = _hunter(HunterClass.healer);
      final result = QuestResolver(Random(seed)).resolve(_quest(isGroup: true), [warrior, healer]);
      if (result.deaths.isEmpty && result.damageTaken[warrior]! > 0) {
        expect(result.healed[warrior], greaterThan(0));
      }

      final solo = _hunter(HunterClass.healer);
      expect(QuestResolver(Random(seed)).resolve(_quest(), [solo]).healed, isEmpty);
    }
  });

  PhaseReport toNextMorning(GameState game) {
    game.advancePhase(); // trưa
    game.advancePhase(); // đêm
    return game.advancePhase(); // sáng mai: hunter đi mua sắm
  }

  void passDay(GameState game) {
    for (var i = 0; i < 3; i++) {
      game.advancePhase();
    }
  }

  test('bệnh viện hồi máu mỗi sáng, báo cáo lượng hồi và cho xuất viện', () {
    final game = GameState(random: Random(1));
    final h = game.hunters.first;
    h.hp = h.maxHp * 0.3;
    game.admit(h);
    game.advancePhase(); // trưa
    game.advancePhase(); // đêm
    expect(h.hp, closeTo(h.maxHp * 0.3, 0.01));
    final morning = game.advancePhase();
    expect(morning.phase, DayPhase.morning);
    expect(morning.healed[h], closeTo(h.maxHp * GameConfig.hospitalHealPerDay, 0.01));
    for (var i = 0; i < 3; i++) {
      passDay(game);
    }
    expect(h.inHospital, isFalse);
    expect(h.isFullHp, isTrue);
  });

  WorldMap lineMap() {
    // Thị trấn -1- Đồng cỏ -1- Hầm mỏ (Hầm mỏ không nối thẳng thị trấn); các khu khác nối thị trấn 3 buổi.
    final edges = <Location, Map<Location, int>>{for (final l in Location.values) l: {}};
    void connect(Location a, Location b, int time) {
      edges[a]![b] = time;
      edges[b]![a] = time;
    }

    connect(Location.town, Location.grassland, 1);
    connect(Location.grassland, Location.mine, 1);
    for (final l in Location.regions.where((l) => l != Location.grassland && l != Location.mine)) {
      connect(Location.town, l, 3);
    }
    return WorldMap(
      positions: {for (final (i, l) in Location.values.indexed) l: Point(i / 10, i / 10)},
      edges: edges,
    );
  }

  test('bản đồ ngẫu nhiên mỗi game, luôn đi được tới mọi khu', () {
    final a = WorldMap.generate(Random(1));
    final b = WorldMap.generate(Random(2));
    expect(a.positions[Location.dungeon], isNot(b.positions[Location.dungeon]));
    for (final map in [a, b]) {
      expect(map.positions[Location.town], const Point(0.5, 0.5));
      for (final l in Location.regions) {
        expect(map.path(Location.town, l).first, Location.town);
        expect(map.travelTime(Location.town, l), greaterThanOrEqualTo(1));
      }
    }
    expect(lineMap().path(Location.town, Location.mine), [Location.town, Location.grassland, Location.mine]);
    expect(lineMap().travelTime(Location.town, Location.mine), 2);
  });

  test('mọi tier đều có khu, quest sinh ra đúng khu & quái của khu', () {
    for (final tier in QuestTier.values) {
      expect(Location.regions.where((l) => l.supports(tier)), isNotEmpty, reason: tier.label);
    }
    final generator = QuestGenerator(Random(3));
    for (var i = 0; i < 300; i++) {
      final q = generator.generate(i);
      expect(q.location.supports(q.tier), isTrue);
      expect(q.location.monsters, contains(q.monster));
    }
  });

  test('thời gian quest theo đường đi: gần về đêm cùng ngày, xa về hôm sau; bị trừ thuế 20%', () {
    Quest q(QuestTier tier, Location location) => Quest(
          id: tier.index,
          location: location,
          tier: tier,
          monster: MonsterType.beast,
          isHorde: false,
          isGroup: false,
          minParty: 1,
          maxParty: 1,
          difficulty: 1,
          gold: 100,
          exp: 0,
        );
    final game = GameState(random: Random(3))..map = lineMap();
    final [a, b, ...] = game.hunters;
    final near = q(QuestTier.d, Location.grassland); // đi 1 buổi
    final far = q(QuestTier.c, Location.mine); // đi 2 buổi qua Đồng cỏ
    b.level = QuestTier.c.minLevel;
    game.quests.addAll([near, far]);
    final nearTrip = game.dispatch(near, [a]);
    final farTrip = game.dispatch(far, [b]);
    expect(game.dispatchError(near, [a]), isNotNull); // a đang đi
    expect(farTrip.route, [Location.town, Location.grassland, Location.mine]);
    expect(describePhase(nearTrip.returnAt), 'Ngày 1 · Đêm');
    expect(describePhase(farTrip.returnAt), 'Ngày 2 · Trưa');

    game.advancePhase(); // trưa: a đang đánh ở Đồng cỏ, b đang ở giữa đường
    expect(nearTrip.stageAt(game.now), ExpeditionStage.fighting);
    expect(farTrip.stageAt(game.now), ExpeditionStage.outbound);
    expect(game.map.pointAlong(farTrip.route, farTrip.distanceAlongRoute(game.now)),
        game.map.positions[Location.grassland]);
    expect(game.canDispatchNow, isTrue); // buổi trưa vẫn giao được

    final night = game.advancePhase();
    expect(night.returns.map((r) => r.quest), [near]);
    expect(a.onQuest, isFalse);
    for (final r in night.returns.where((r) => r.result.success && r.result.deaths.isEmpty)) {
      expect(r.guildShare, 20);
      expect(r.hunterShareEach, 80);
      expect(a.gold, 80);
    }
    expect(night.daily, isNull); // tổng kết hiện khi sang sáng
    expect(game.dispatchError(q(QuestTier.d, Location.grassland), [game.hunters[2]]),
        'Ban đêm không giao nhiệm vụ, chờ sáng mai');

    final morning2 = game.advancePhase(); // sáng ngày 2
    expect(morning2.returns, isEmpty);
    expect(morning2.daily!.day, 1);
    expect(morning2.daily!.succeeded + morning2.daily!.failed, 1); // tính vào tổng kết ngày 1
    expect(farTrip.stageAt(game.now), ExpeditionStage.returning);
    final noon2 = game.advancePhase();
    expect(noon2.returns.map((r) => r.quest), [far]);
    expect(b.onQuest, isFalse);
  });

  // ---------------- Thương đoàn, bản vẽ, sự kiện ----------------

  test('chợ các khu: giá 90–190%, cấp hàng theo độ nguy hiểm của khu', () {
    final game = GameState(random: Random(5));
    expect(game.markets.keys, containsAll(Location.regions));
    for (final MapEntry(key: l, value: offers) in game.markets.entries) {
      for (final o in offers) {
        if (o.item case final item?) {
          expect(MarketGenerator.gradesAt(l), contains(item.grade));
          final base = item.grade.price * item.quality;
          expect(o.price, inInclusiveRange(base * GameConfig.marketPriceMin - 1, base * GameConfig.marketPriceMax + 1));
          expect(item.price, o.price); // hunter mua lại đúng giá guild đã trả
        }
      }
    }
    expect(MarketGenerator.gradesAt(Location.grassland), [ItemGrade.basic]);
    expect(MarketGenerator.gradesAt(Location.empire), [ItemGrade.divine]);
  });

  test('thương đoàn: trả tiền hàng + phí đi lại trước, hàng về khi nhân viên quay lại', () {
    final game = GameState(random: Random(5))..gold = 100000;
    final l = Location.regions.reduce(
      (a, b) => game.map.travelTime(Location.town, a) <= game.map.travelTime(Location.town, b) ? a : b,
    );
    final goods = game.markets[l]!.take(2).toList();
    final cost = goods.fold(0, (s, o) => s + o.price);
    final fee = game.caravanFee(l);
    expect(fee, game.map.travelTime(Location.town, l) * 2 * GameConfig.caravanFeePerPhase);

    final trip = game.sendCaravan(l, goods);
    expect(game.gold, 100000 - cost - fee);
    expect(game.markets[l], isNot(contains(goods.first)));
    expect(game.caravanError(l, [game.markets[l]!.first]), isNull);
    game.sendCaravan(l, [game.markets[l]!.first]);
    expect(game.caravanError(l, [game.markets[l]!.first]), contains('Tối đa'));

    PhaseReport? arrived;
    while (game.now < trip.returnAt) {
      final r = game.advancePhase();
      if (r.caravans.contains(trip)) arrived = r;
    }
    expect(arrived, isNotNull);
    final items = [for (final o in goods) ?o.item];
    final owned = [...game.shopStock, for (final h in game.hunters) ...h.equipment.values];
    expect(owned, containsAll(items)); // có thể đã được hunter mua ngay sáng đó
  });

  test('chế trang bị cần bản vẽ đúng cấp; bình máu thì không', () {
    final game = GameState(random: Random(1));
    game.materials[(Resource.ore, ItemGrade.basic)] = 10;
    game.materials[(Resource.wood, ItemGrade.basic)] = 10;
    game.materials[(Resource.blood, ItemGrade.basic)] = 10;
    game.materials[(Resource.core, ItemGrade.basic)] = 10;
    expect(game.blueprints, isEmpty);
    expect(game.canCraft(Recipe.sword, ItemGrade.basic), isFalse);
    expect(game.canCraft(Recipe.potion, ItemGrade.basic), isTrue);
    game.blueprints.add((type: ItemType.shield, grade: ItemGrade.basic));
    expect(game.canCraft(Recipe.shield, ItemGrade.basic), isTrue);
    expect(game.canCraft(Recipe.sword, ItemGrade.basic), isFalse); // bản vẽ riêng từng loại đồ
    game.blueprints.add((type: ItemType.sword, grade: ItemGrade.basic));
    expect(game.canCraft(Recipe.sword, ItemGrade.basic), isTrue);
    expect(game.canCraft(Recipe.sword, ItemGrade.fine), isFalse); // và từng cấp
  });

  test('thương nhân nước ngoài: giá 65–140%, luôn có bản vẽ, mỗi nước số ngày đi khác nhau, đổi hàng mỗi 3 ngày', () {
    final game = GameState(random: Random(4))..gold = 1000000;
    expect({for (final c in Country.values) c.travelDays}.length, Country.values.length);
    for (final c in Country.values) {
      final offers = game.foreignMarkets[c]!;
      expect(offers.where((o) => o.blueprint != null).length, GameConfig.foreignBlueprintsPerCountry);
      for (final o in offers) {
        if (o.item case final item?) {
          expect(c.grades, contains(item.grade));
          final base = item.grade.price * item.quality;
          expect(o.price, inInclusiveRange(base * GameConfig.foreignPriceMin - 1, base * GameConfig.foreignPriceMax + 1));
        }
      }
      expect(game.foreignFee(c), c.travelDays * 2 * GameConfig.foreignFeePerDay);
      expect(game.foreignFee(c), greaterThan(game.caravanFee(Location.regions.first)));
    }

    const c = Country.northKingdom;
    final bp = game.foreignMarkets[c]!.firstWhere((o) => o.blueprint != null);
    final trip = game.sendForeignCaravan(c, [bp]);
    expect(trip.returnAt - trip.departAt, c.travelDays * 2 * 3);

    final before = List.of(game.foreignMarkets[Country.portRepublic]!);
    while (game.day <= GameConfig.foreignRestockDays) {
      game.advancePhase();
    }
    expect(game.day, GameConfig.foreignRestockDays + 1);
    expect(game.foreignMarkets[Country.portRepublic], isNot(before)); // đã đổi hàng
    while (game.now < trip.returnAt) {
      game.advancePhase();
    }
    expect(game.blueprints, contains(bp.blueprint));
  });

  test('quest tier B trở lên có thể rơi bản vẽ guild chưa có, tier thấp hơn thì không', () {
    var drops = 0;
    for (var seed = 0; seed < 200; seed++) {
      final game = GameState(random: Random(seed));
      final h = leveled(HunterClass.warrior, 30);
      game.hunters.add(h);
      final q = Quest(
        id: 1,
        location: Location.grassland,
        tier: seed.isEven ? QuestTier.sss : QuestTier.c,
        monster: MonsterType.beast,
        isHorde: false,
        isGroup: false,
        minParty: 1,
        maxParty: 1,
        difficulty: 1,
        gold: 0,
        exp: 0,
      );
      game.expeditions.add(
        Expedition(quest: q, party: [h], route: const [Location.town], departAt: 0, arriveAt: 0, returnAt: 0),
      );
      final report = game.advancePhase().returns.single;
      if (report.blueprint case final b?) {
        drops++;
        expect(q.tier, QuestTier.sss);
        expect(b.grade, ItemGrade.divine);
        expect(game.blueprints, contains(b));
      }
    }
    // SSS: 25% x 100 lần ~ 25
    expect(drops, inInclusiveRange(10, 45));
  });

  test('sự kiện đầu tuần: tuần đầu yên bình, từ tuần 2 luôn có sự kiện; chợ nhập hàng mới', () {
    final game = GameState(random: Random(3));
    final firstMarket = List.of(game.markets[Location.grassland]!);
    WeeklyEvent? started;
    while (game.day < GameConfig.firstEventDay) {
      expect(game.event, isNull);
      final r = game.advancePhase();
      if (r.newEvent != null) started = r.newEvent;
    }
    expect(game.day, GameConfig.firstEventDay);
    expect(started, isNotNull);
    expect(game.event, started);
    expect(game.markets[Location.grassland], isNot(firstMarket));
  });

  WeeklyEvent forceEvent(GameState game, WeeklyEventType type) {
    final e = WeeklyEvent(type: type, startDay: game.day, siegeDay: game.day, siegeMonster: MonsterType.beast);
    game.event = e;
    return e;
  }

  test('bao vây: không ai thủ thì thua, mất tiền sửa và danh tiếng', () {
    final game = GameState(random: Random(1))
      ..gold = 1000
      ..reputation = 100;
    forceEvent(game, WeeklyEventType.siege);
    game.advancePhase(); // trưa
    final report = game.advancePhase(); // đêm: quái tấn công
    final siege = report.siege!;
    expect(siege.won, isFalse);
    expect(siege.defenders, isEmpty);
    expect(siege.repairCost, GameConfig.siegeRepairCostPerRank * (game.rank.index + 1));
    expect(game.reputation, 100 - GameConfig.siegeFailReputation);
    expect(game.event!.siegeResolved, isTrue);
  });

  test('bao vây: hunter mạnh thủ thành thì thắng, cộng danh tiếng, không mất tiền', () {
    final game = GameState(random: Random(1));
    final e = forceEvent(game, WeeklyEventType.siege);
    for (final h in game.hunters) {
      while (h.level < 15) {
        h.gainExp(h.expToNext);
      }
      h.hp = h.maxHp;
      game.toggleDefender(h);
    }
    expect(e.defenderIds.length, GameConfig.startingHunters);
    game.advancePhase();
    final goldBefore = game.gold;
    final siege = game.advancePhase().siege!;
    expect(siege.won, isTrue);
    expect(siege.repairCost, 0);
    expect(game.reputation, GameConfig.siegeWinReputation);
    expect(game.gold, goldBefore);
  });

  test('dịch bệnh: hồi phục chậm gấp 3, chữa ngay đắt gấp 3', () {
    final game = GameState(random: Random(1));
    final h = game.hunters.first..hp = 10;
    final normalCost = game.healNowCost(h);
    forceEvent(game, WeeklyEventType.plague);
    expect(game.healNowCost(h), normalCost * GameConfig.plagueHealCostMultiplier);

    game.admit(h);
    game
      ..advancePhase()
      ..advancePhase();
    final report = game.advancePhase(); // sáng hôm sau
    expect(report.healed[h], closeTo(h.maxHp * GameConfig.hospitalHealPerDay / 3, 0.01));
  });

  test('thương nhân: chỉ bán trong ngày, hàng về ngay', () {
    final game = GameState(random: Random(1))..gold = 1000000;
    final e = forceEvent(game, WeeklyEventType.merchant);
    e.merchantOffers.addAll(MarketGenerator(Random(2)).merchant(() => 9000 + e.merchantOffers.length));
    final blueprint = e.merchantOffers.firstWhere((o) => o.blueprint != null);
    game.buyFromMerchant(blueprint);
    expect(game.blueprints, contains(blueprint.blueprint));
    expect(e.merchantOffers, isNot(contains(blueprint)));
    final material = e.merchantOffers.firstWhere((o) => o.material != null);
    game.buyFromMerchant(material);
    expect(game.materialCount(material.material!.$1, ItemGrade.divine), greaterThanOrEqualTo(3));
    for (var i = 0; i < 3; i++) {
      game.advancePhase();
    }
    expect(game.merchantHere, isFalse);
  });

  test('thời tiết cực đoan: đi chậm hơn 30%, hunter ở thị trấn tự trả tiền nhu yếu phẩm mỗi sáng', () {
    final game = GameState(random: Random(1))..map = lineMap();
    final normal = game.travelTime(Location.mine); // 2 buổi
    forceEvent(game, WeeklyEventType.weather);
    expect(game.travelTime(Location.mine), (normal / (1 - GameConfig.weatherSlowdown)).ceil());

    final quest = Quest(
      id: 1,
      location: Location.mine,
      tier: QuestTier.d,
      monster: MonsterType.beast,
      isHorde: false,
      isGroup: false,
      minParty: 1,
      maxParty: 1,
      difficulty: 1,
      gold: 0,
      exp: 0,
    );
    game.quests.add(quest);
    final traveller = game.hunters.first;
    final e = game.dispatch(quest, [traveller]);
    expect(e.arriveAt - e.departAt, game.travelTime(Location.mine));

    final stay = game.hunters[1]..gold = 1000;
    traveller.gold = 1000;
    game.potionStock.clear();
    game
      ..advancePhase()
      ..advancePhase();
    final report = game.advancePhase(); // sáng
    expect(report.provisions, greaterThanOrEqualTo(game.provisionCost(stay)));
    expect(stay.gold, 1000 - game.provisionCost(stay));
  });

  test('lạm phát: giá thu mua lô nguyên liệu gấp đôi trong 1–2 ngày', () {
    final game = GameState(random: Random(1))..gold = 10000;
    final h = game.hunters.first..gold = 0;
    final lot = MaterialLot(hunter: h, resource: Resource.ore, grade: ItemGrade.basic, quantity: 2, day: game.day);
    game.materialLots.add(lot);
    game.event = WeeklyEvent(type: WeeklyEventType.inflation, startDay: game.day, endDay: game.day);
    expect(game.lotPrice(lot), lot.price * GameConfig.inflationPriceMultiplier);
    game.buyLot(lot);
    expect(h.gold, lot.price * GameConfig.inflationPriceMultiplier); // hunter được lợi, guild bù lỗ
    for (var i = 0; i < 3; i++) {
      game.advancePhase();
    }
    expect(game.isInflation, isFalse); // hết hạn sang ngày hôm sau
    expect(game.lotPrice(lot), lot.price);
  });

  test('tin đồn: danh tiếng giảm tạm thời (có thể tụt hạng), hunter hiếm giảm 50%, hết tuần thì hồi lại', () {
    final game = GameState(random: Random(1))..reputation = TownRank.c.minReputation;
    expect(game.rank, TownRank.c);
    game.event = WeeklyEvent(
      type: WeeklyEventType.rumor,
      startDay: game.day,
      reputationPenalty: (game.reputation * GameConfig.rumorReputationLoss).round(),
    );
    expect(game.effectiveReputation, lessThan(game.reputation));
    expect(game.rank, TownRank.d); // tụt hạng tạm thời
    expect(game.rareRate, GameConfig.rumorRareRate);

    int rareShare(double rate) => [Rarity.rare, Rarity.epic, Rarity.legendary]
        .fold(0, (s, r) => s + HunterFactory.rarityWeight(r, 0, rareRate: rate));
    expect(rareShare(0.5), closeTo(rareShare(1) / 2, 2));
    expect(Rarity.values.fold(0, (s, r) => s + HunterFactory.rarityWeight(r, 0, rareRate: 0.5)), 1000);

    final rumor = game.event!;
    while (game.day < rumor.endDay + 1) {
      game.advancePhase();
    }
    game.event = rumor; // bỏ qua sự kiện tuần mới vừa bốc, chỉ xét tin đồn cũ đã hết hạn
    expect(game.reputationPenalty, 0);
    expect(game.rank, TownRank.of(game.reputation));
  });

  // ---------------- Trang bị rơi & kho riêng ----------------

  test('nhặt đồ: tốt hơn thì mặc luôn (đồ cũ vào kho riêng), kém hơn thì cất kho', () {
    final game = GameState(random: Random(1));
    final h = leveled(HunterClass.warrior, 10);
    final weak = Equipment(id: 1, type: ItemType.sword, grade: ItemGrade.basic, bonus: const Stats(power: 1));
    h.equip(weak);
    final strong = Equipment(id: 2, type: ItemType.sword, grade: ItemGrade.basic, bonus: const Stats(power: 20));
    final drop = game.receiveGear(h, strong).single;
    expect(drop.outcome, GearOutcome.equipped);
    expect(h.equipment[EquipSlot.mainHand], strong);
    expect(h.stash, [weak]);

    final worse = Equipment(id: 3, type: ItemType.sword, grade: ItemGrade.basic, bonus: const Stats(power: 2));
    expect(game.receiveGear(h, worse).single.outcome, GearOutcome.stashed);
    expect(h.stash, containsAll([weak, worse]));
  });

  test('nhặt đồ lớp không dùng được thì bán cho guild; guild hết tiền thì bán cho thương lái', () {
    final game = GameState(random: Random(1))..gold = 1000;
    final mage = leveled(HunterClass.mage, 5)..gold = 0;
    final shield = Equipment.standard(id: 1, type: ItemType.shield, grade: ItemGrade.basic);
    final price = (shield.price * GameConfig.lootSellRate).round();
    final drop = game.receiveGear(mage, shield).single;
    expect(drop.outcome, GearOutcome.soldToGuild);
    expect(game.shopStock, contains(shield));
    expect(game.gold, 1000 - price);
    expect(mage.gold, price);

    game.gold = 0;
    final bow = Equipment.standard(id: 2, type: ItemType.bow, grade: ItemGrade.basic);
    expect(game.receiveGear(mage, bow).single.outcome, GearOutcome.soldElsewhere);
    expect(game.shopStock, isNot(contains(bow)));
  });

  test('kho riêng quá 3 áo giáp thì bán món yếu nhất cho guild', () {
    final game = GameState(random: Random(1))..gold = 100000;
    final h = leveled(HunterClass.warrior, 10);
    h.equip(Equipment(id: 99, type: ItemType.steelArmor, grade: ItemGrade.basic, bonus: const Stats(maxHp: 500)));
    final armors = [
      for (var i = 1; i <= GameConfig.maxStashPerSlot + 1; i++)
        Equipment(id: i, type: ItemType.leatherArmor, grade: ItemGrade.basic, bonus: Stats(maxHp: i * 10.0)),
    ];
    final drops = [for (final a in armors) ...game.receiveGear(h, a)];
    expect(h.stash.length, GameConfig.maxStashPerSlot);
    expect(h.stash, isNot(contains(armors.first))); // yếu nhất bị bán
    expect(drops.where((d) => d.outcome == GearOutcome.soldToGuild).single.item, armors.first);
  });

  test('mỗi sáng hunter lấy đồ tốt hơn trong kho riêng ra mặc (đủ cấp mới mặc)', () {
    final game = GameState(random: Random(1))..potionStock.clear();
    final h = game.hunters.firstWhere((h) => h.hunterClass != HunterClass.mage && h.hunterClass != HunterClass.healer,
        orElse: () => game.hunters.first);
    final armor = Equipment(id: 1, type: ItemType.clothArmor, grade: ItemGrade.basic, bonus: const Stats(maxHp: 50));
    final tooHigh = Equipment(id: 2, type: ItemType.steelArmor, grade: ItemGrade.fine, bonus: const Stats(maxHp: 999));
    h.stash.addAll([armor, tooHigh]);
    game
      ..advancePhase()
      ..advancePhase();
    final report = game.advancePhase(); // sáng
    expect(h.equipment[EquipSlot.armor], armor);
    expect(h.stash, [tooHigh]); // chưa đủ cấp 10
    expect(report.purchases.any((p) => p.hunter == h && p.price == 0), isTrue);
  });

  test('hunter hy sinh: đồ đang mặc hư luôn, guild mua lại kho riêng 80% giá', () {
    final game = GameState(random: Random(1))..gold = 1000;
    final h = leveled(HunterClass.warrior, 10);
    final worn = Equipment.standard(id: 1, type: ItemType.sword, grade: ItemGrade.basic);
    h.equip(worn);
    final kept = Equipment.standard(id: 2, type: ItemType.dagger, grade: ItemGrade.basic);
    final pricey = Equipment.standard(id: 3, type: ItemType.bow, grade: ItemGrade.divine);
    h.stash.addAll([kept, pricey]);

    final estate = game.settleEstate(h);
    expect(estate.destroyed, [worn]);
    expect(h.equipment, isEmpty);
    expect(estate.bought, [kept]);
    expect(estate.paid, (kept.price * GameConfig.estateBuybackRate).round());
    expect(estate.lost, [pricey]); // quá đắt, guild không đủ tiền
    expect(game.gold, 1000 - estate.paid);
    expect(game.shopStock, contains(kept));
    expect(h.stash, isEmpty);
  });

  test('quest thành công có tỉ lệ nhỏ rơi trang bị, cấp theo tier; kho riêng được lưu', () {
    var drops = 0;
    for (var seed = 0; seed < 150; seed++) {
      final game = GameState(random: Random(seed));
      final h = leveled(HunterClass.warrior, 30);
      game.hunters.add(h);
      final q = Quest(
        id: 1,
        location: Location.grassland,
        tier: QuestTier.b,
        monster: MonsterType.beast,
        isHorde: false,
        isGroup: false,
        minParty: 1,
        maxParty: 1,
        difficulty: 1,
        gold: 0,
        exp: 0,
      );
      game.expeditions.add(
        Expedition(quest: q, party: [h], route: const [Location.town], departAt: 0, arriveAt: 0, returnAt: 0),
      );
      for (final d in game.advancePhase().returns.single.gearDrops) {
        if (d.hunter != h) continue;
        drops++;
        expect(d.item.grade, QuestTier.b.materialGrade);
      }
    }
    // Tier B: 5% × 150 ~ 7.5
    expect(drops, inInclusiveRange(1, 20));

    final h = leveled(HunterClass.tank, 2)..stash.add(Equipment.standard(id: 5, type: ItemType.shield, grade: ItemGrade.basic));
    final loaded = Hunter.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect(loaded.stash.single.type, ItemType.shield);
  });

  // ---------------- Sự kiện có lựa chọn ----------------

  WeeklyEvent choiceEvent(GameState game, WeeklyEventType type, {int? targetId}) {
    final e = WeeklyEvent(type: type, startDay: game.day, targetId: targetId);
    game.event = e;
    return e;
  }

  test('viện trợ vương quốc A: 3 hunter mạnh nhất đi viễn chinh 3 ngày, thắng được danh tiếng lớn + vũ khí Thần khí', () {
    final game = GameState(random: Random(1));
    for (final h in game.hunters) {
      while (h.level < 40) {
        h.gainExp(h.expToNext);
      }
      h.hp = h.maxHp;
    }
    final expected = game.royalCandidates;
    expect(expected.length, GameConfig.royalPartySize);
    choiceEvent(game, WeeklyEventType.royalAid);
    game.chooseEvent(true);
    expect(expected.every((h) => h.onQuest), isTrue);
    final trip = game.expeditions.single;
    expect(trip.quest.isRoyal, isTrue);
    expect(trip.returnAt - trip.departAt, GameConfig.royalDays * 3);

    ExpeditionReport? back;
    while (back == null) {
      back = game.advancePhase().returns.where((r) => r.quest.isRoyal).firstOrNull;
    }
    expect(back.result.success, isTrue);
    expect(back.reputation, greaterThanOrEqualTo(GameConfig.royalReputation));
    final weapon = back.gearDrops.firstWhere((d) => d.item.grade == ItemGrade.divine).item;
    expect(weapon.type.slot, isNot(EquipSlot.armor));
  });

  test('viện trợ vương quốc B / không chọn kịp: trừ chút danh tiếng', () {
    final game = GameState(random: Random(1))..reputation = 50;
    choiceEvent(game, WeeklyEventType.royalAid);
    game
      ..advancePhase()
      ..advancePhase();
    final morning = game.advancePhase(); // sáng hôm sau: tự chọn B
    expect(morning.eventOutcome, isNotNull);
    expect(game.event!.choice, isFalse);
    expect(game.reputation, 50 - GameConfig.royalRefusePenalty);
  });

  test('thí nghiệm cấm A: quái biến dị mạnh hơn 50%, thưởng gấp đôi, cả quest mới sinh ra trong tuần', () {
    final game = GameState(random: Random(1))..gold = 1000;
    final before = {for (final q in game.quests) q.id: q};
    choiceEvent(game, WeeklyEventType.experiment);
    game.chooseEvent(true);
    for (final q in game.quests) {
      final old = before[q.id]!;
      expect(q.isMutated, isTrue);
      expect(q.difficulty, closeTo(old.difficulty * GameConfig.mutationStrength, 0.001));
      expect(q.gold, (old.gold * GameConfig.mutationReward).round());
      expect(q.title, contains('biến dị'));
    }
    game.refreshQuests();
    expect(game.quests.every((q) => q.isMutated), isTrue);
    expect(Quest.fromJson(game.quests.first.toJson()).isMutated, isTrue);

    final calm = GameState(random: Random(1));
    choiceEvent(calm, WeeklyEventType.experiment);
    calm.chooseEvent(false);
    expect(calm.quests.any((q) => q.isMutated), isFalse);
  });

  test('kẻ phản bội: đang bị tố giác thì không giao quest; trục xuất rồi có thể quay lại làm boss phụ', () {
    final game = GameState(random: Random(1));
    final h = game.hunters.first;
    choiceEvent(game, WeeklyEventType.traitor, targetId: h.id);
    final quest = game.quests.firstWhere((q) => !q.isGroup && q.tier == QuestTier.d);
    expect(game.dispatchError(quest, [h]), contains('điều tra'));

    game.chooseEvent(true);
    expect(game.hunters, isNot(contains(h)));
    expect(game.exiles, contains(h));

    // Qua vài tuần, kẻ bị đuổi quay lại thành quest boss phụ.
    Quest? renegade;
    for (var i = 0; i < 40 * 3 && renegade == null; i++) {
      game.gold = 100000;
      game.advancePhase();
      renegade = game.quests.where((q) => q.renegadeId == h.id).firstOrNull;
    }
    expect(renegade, isNotNull);
    expect(renegade!.tier, h.rank);
    expect(renegade.title, contains(h.name));
    game.refreshQuests();
    expect(game.quests, contains(renegade)); // quest đặc biệt không bị làm mới mất
  });

  test('kẻ phản bội B: 50% cải tà (tăng chỉ số), 50% bỏ trốn dắt quái về công thành', () {
    var redeemed = 0, betrayed = 0;
    for (var seed = 0; seed < 40; seed++) {
      final game = GameState(random: Random(seed));
      final h = game.hunters.first;
      final power = h.basePower;
      choiceEvent(game, WeeklyEventType.traitor, targetId: h.id);
      game.chooseEvent(false);
      if (game.hunters.contains(h)) {
        redeemed++;
        expect(h.basePower, closeTo(power * GameConfig.traitorRedeemStatBoost, 0.001));
      } else {
        betrayed++;
        expect(game.exiles, contains(h));
        expect(game.event!.type, WeeklyEventType.siege);
        expect(game.event!.siegeDay, game.day + GameConfig.traitorSiegeDelay);
      }
    }
    expect(redeemed, greaterThan(5));
    expect(betrayed, greaterThan(5));
  });

  test('nhập cư: giấy mời miễn phí, tân binh trẻ', () {
    final game = GameState(random: Random(1))..gold = 0;
    forceEvent(game, WeeklyEventType.immigration);
    expect(game.invitationCost, 0);
    game.sendInvitations();
    expect(game.candidates.length, GameConfig.invitationSize);
    final young = HunterFactory(Random(1)).create(1, young: true);
    expect(young.age, inInclusiveRange(GameConfig.recruitMinAge, GameConfig.recruitMaxAge));
  });

  test('bản vẽ, chợ, thương đoàn, sự kiện được lưu', () {
    final game = GameState(random: Random(1))..gold = 100000;
    game.blueprints.add((type: ItemType.bow, grade: ItemGrade.fine));
    final l = Location.regions.first;
    game.sendCaravan(l, [game.markets[l]!.first]);
    forceEvent(game, WeeklyEventType.siege).defenderIds.add(game.hunters.first.id);
    final loaded = GameState.fromJson(jsonDecode(jsonEncode(game.toJson())) as Map<String, dynamic>);
    expect(loaded.toJson(), game.toJson());
    expect(loaded.blueprints, {(type: ItemType.bow, grade: ItemGrade.fine)});
    expect(loaded.foreignMarkets[Country.desertDynasty]!.length, game.foreignMarkets[Country.desertDynasty]!.length);
    expect(loaded.caravans.single.goods.single.price, game.caravans.single.goods.single.price);
    expect(loaded.event!.defenderIds, {game.hunters.first.id});

    // Bản lưu cũ chưa có bản vẽ: tặng bản vẽ Sơ cấp mọi loại đồ.
    final old = game.toJson()..remove('blueprints');
    expect(GameState.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>).blueprints, BlueprintInfo.ofGrade(ItemGrade.basic).toSet());
  });

  test('đồ tier cao có chỉ số lớn hơn, chất lượng ±25%', () {
    final factory = EquipmentFactory(Random(9));
    for (var i = 0; i < 200; i++) {
      final item = factory.roll(i);
      expect(item.quality, inInclusiveRange(0.75, 1.25));
      final standard = Equipment.standardBonus(item.type, item.grade);
      expect(item.bonus.power, inInclusiveRange(standard.power * 0.75, standard.power * 1.25));
    }
    expect(
      Equipment.standardBonus(ItemType.sword, ItemGrade.divine).power,
      greaterThan(Equipment.standardBonus(ItemType.sword, ItemGrade.basic).power),
    );
  });

  test('hunter tự mua đồ nâng cấp và bình máu, đồ cũ thu lại 30%', () {
    final game = GameState(random: Random(1));
    final warrior = _hunter(HunterClass.warrior)..gold = 200;
    warrior.equip(Equipment(id: 90, type: ItemType.sword, grade: ItemGrade.basic, bonus: Stats(power: 1), price: 50));
    game.hunters.add(warrior);
    final sword = Equipment.standard(id: 91, type: ItemType.sword, grade: ItemGrade.basic);
    final staff = Equipment.standard(id: 92, type: ItemType.staff, grade: ItemGrade.basic);
    game.shopStock
      ..clear()
      ..addAll([sword, staff]);
    final guildBefore = game.gold;

    final morning = toNextMorning(game);
    // 200 - 60 (kiếm) + 15 (thu lại kiếm cũ) = 155; ngân sách thuốc 77 -> 2 bình nhỏ.
    expect(morning.purchases.where((p) => p.hunter == warrior).map((p) => p.itemName),
        ['Kiếm Sơ cấp', 'Bình máu nhỏ', 'Bình máu nhỏ']);
    expect(warrior.equipment[EquipSlot.mainHand], sword);
    expect(warrior.gold, 95);
    expect(game.shopStock, [staff]); // chiến binh không dùng gậy
    expect(game.gold, guildBefore + 120);
  });

  test('sau trận, máu dưới ngưỡng nhập viện thì hunter uống thêm bình (bình nhỏ trước)', () {
    final h = _hunter(HunterClass.warrior);
    h.potions.addAll([Potion.large, Potion.small]);
    h.hp = h.maxHp * 0.5; // trên ngưỡng uống trong trận, dưới ngưỡng nhập viện
    final quest = Quest(
      id: 0,
      location: Location.grassland,
      tier: QuestTier.d,
      monster: MonsterType.beast,
      isHorde: false,
      isGroup: false,
      minParty: 1,
      maxParty: 1,
      difficulty: 1,
      gold: 0,
      exp: 0,
    );
    final result = QuestResolver(Random(1)).resolve(quest, [h]);
    expect(result.potionsUsed[h]!.first, Potion.small);
    expect(h.hpRatio, greaterThanOrEqualTo(GameConfig.hospitalThreshold));
  });

  test('bình máu dùng ngay trong trận khi máu tụt thấp, không mất lượt; trận mô phỏng không tiêu bình thật', () {
    final quest = Quest(
      id: 0,
      location: Location.grassland,
      tier: QuestTier.c,
      monster: MonsterType.beast,
      isHorde: false,
      isGroup: false,
      minParty: 1,
      maxParty: 1,
      difficulty: 80,
      gold: 0,
      exp: 0,
    );
    for (var seed = 0; seed < 50; seed++) {
      final h = leveled(HunterClass.warrior, 7)..potions.addAll([Potion.medium, Potion.medium]);
      final battle = CombatEngine(Random(seed)).fight(quest, [h]);
      final used = battle.potionsUsed[h];
      if (used == null) continue;
      expect(h.potions.length, 2); // fight() chỉ dùng bản sao
      expect(battle.log.any((l) => l.contains('không mất lượt')), isTrue);

      // Resolve thật thì trừ bình khỏi túi.
      final real = leveled(HunterClass.warrior, 7)..potions.addAll([Potion.medium, Potion.medium]);
      final result = QuestResolver(Random(seed)).resolve(quest, [real]);
      expect(real.potions.length, 2 - result.potionsUsed[real]!.length);
      return;
    }
    fail('không trận nào phải uống bình');
  });

  test('Action Value: nhanh gấp đôi thì được ra đòn gấp đôi số lần', () {
    final quest = Quest(
      id: 0,
      location: Location.grassland,
      tier: QuestTier.d,
      monster: MonsterType.golem, // tốc độ 6
      isHorde: false,
      isGroup: false,
      minParty: 1,
      maxParty: 1,
      difficulty: 1000000, // không ai chết, đánh tới hết giờ
      gold: 0,
      exp: 0,
    );
    final golemSpeed = CombatEngine(Random(1)).buildEnemies(quest, withHealer: false).single.speed;
    final hero = leveled(HunterClass.warrior, 1)
      ..baseMaxHp = 1e9
      ..hp = 1e9
      ..baseAgility = golemSpeed * 2 - GameConfig.speedBase; // tốc độ gấp đôi golem
    final battle = CombatEngine(Random(1)).fight(quest, [hero]);
    int turns(String name) => battle.log.where((l) => RegExp('AV \\d+ · $name ').hasMatch(l)).length;
    final ratio = turns(hero.name) / turns('Golem đầu lĩnh');
    expect(ratio, closeTo(2, 0.15));
    expect(battle.rounds, GameConfig.maxBattleRounds);
    expect(battle.win, isFalse); // hết giờ = rút lui
  });

  Quest easyQuest() => Quest(
        id: 0,
        location: Location.grassland,
        tier: QuestTier.d,
        monster: MonsterType.beast,
        isHorde: false,
        isGroup: false,
        minParty: 1,
        maxParty: 1,
        difficulty: 1,
        gold: 0,
        exp: 0,
      );

  test('mỗi trận: tình trạng mòn nhanh, độ bền mòn chậm; độ bền < 100% vẫn dùng bình thường', () {
    expect(GameConfig.durabilityWearPerQuest, lessThan(GameConfig.conditionWearPerQuest));
    final h = _hunter(HunterClass.warrior);
    final sword = Equipment.standard(id: 1, type: ItemType.sword, grade: ItemGrade.basic);
    h.equip(sword);
    final powerWithSword = h.power;

    QuestResolver(Random(1)).resolve(easyQuest(), [h]);
    expect(sword.condition, lessThan(GameConfig.maxDurability));
    expect(sword.durability, lessThan(GameConfig.maxDurability));
    expect(GameConfig.maxDurability - sword.condition, greaterThan(GameConfig.maxDurability - sword.durability));
    expect(h.power, powerWithSword); // vẫn đủ chỉ số
  });

  test('tình trạng về 0 thì hỏng (mất chỉ số), sửa về 100% là dùng lại được; sửa không hồi độ bền', () {
    final h = _hunter(HunterClass.warrior);
    final sword = Equipment.standard(id: 1, type: ItemType.sword, grade: ItemGrade.basic)..condition = 1;
    h.equip(sword);
    final powerWithSword = h.power;

    final result = QuestResolver(Random(1)).resolve(easyQuest(), [h]);
    expect(result.deaths, isEmpty);
    expect(result.brokenItems[h], [sword]);
    expect(h.equipment[EquipSlot.mainHand], sword); // vẫn mặc
    expect(h.power, lessThan(powerWithSword));

    // Giá sửa = giá × (10% + % độ bền đã mất): kiếm 60 vàng còn 70 độ bền -> 60 × 40% = 24.
    expect(Equipment.standard(id: 2, type: ItemType.sword, grade: ItemGrade.basic).repairCost, 6);
    expect((Equipment.standard(id: 3, type: ItemType.sword, grade: ItemGrade.basic)..durability = 70).repairCost, 24);
    final durabilityBefore = sword.durability;
    sword.repair();
    expect(sword.condition, GameConfig.maxDurability);
    expect(sword.durability, durabilityBefore);
    expect(h.power, powerWithSword);
  });

  test('độ bền về 0 là vỡ vụn, mất luôn, không sửa được', () {
    final h = _hunter(HunterClass.warrior);
    final armor = Equipment.standard(id: 1, type: ItemType.steelArmor, grade: ItemGrade.basic)..durability = 1;
    h.equip(armor);

    final result = QuestResolver(Random(1)).resolve(easyQuest(), [h]);
    expect(result.destroyedItems[h], [armor]);
    expect(h.equipment, isEmpty);
    expect(armor.canRepair, isFalse);
    expect(h.hp, lessThanOrEqualTo(h.maxHp));
  });

  test('hunter tự đi sửa đồ hỏng khi mua sắm', () {
    final game = GameState(random: Random(1));
    final h = _hunter(HunterClass.warrior)..gold = 100;
    final sword = Equipment.standard(id: 1, type: ItemType.sword, grade: ItemGrade.basic)..condition = 0;
    h.equip(sword);
    game.hunters.add(h);
    game.shopStock.clear();

    final morning = toNextMorning(game);
    expect(morning.purchases.first.itemName, 'Sửa Kiếm Sơ cấp');
    expect(sword.isBroken, isFalse);
    expect(h.gold, lessThan(100));
  });

  test('hunter nhặt nguyên liệu đúng loại quái, cấp theo tier quest', () {
    final quest = Quest(
      id: 0,
      location: Location.grassland,
      tier: QuestTier.b,
      monster: MonsterType.golem,
      isHorde: true,
      isGroup: false,
      minParty: 1,
      maxParty: 1,
      difficulty: 1,
      gold: 0,
      exp: 0,
    );
    expect(quest.tier.materialGrade, ItemGrade.fine);
    for (var seed = 0; seed < 20; seed++) {
      final h = _hunter(HunterClass.tank);
      final result = QuestResolver(Random(seed)).resolve(quest, [h]);
      for (final bag in result.loot.values) {
        expect(bag.keys, everyElement(isIn(MonsterType.golem.drops)));
        expect(bag.values.fold(0, (a, b) => a + b), greaterThanOrEqualTo(2));
      }
    }
  });

  test('thu mua nguyên liệu: guild trả tiền vào ví hunter; lô giữ 3 ngày', () {
    final game = GameState(random: Random(1));
    final h = game.hunters.first;
    final lot = MaterialLot(hunter: h, resource: Resource.ore, grade: ItemGrade.basic, quantity: 3, day: 1);
    final wood = MaterialLot(hunter: h, resource: Resource.wood, grade: ItemGrade.basic, quantity: 1, day: 1);
    game.materialLots.addAll([lot, wood]);
    final guildBefore = game.gold;

    expect(game.buyLot(lot), isTrue);
    expect(game.gold, guildBefore - 30);
    expect(h.gold, 30);
    expect(game.materialCount(Resource.ore, ItemGrade.basic), 3);

    expect(wood.daysLeft(1), GameConfig.materialLotDays);
    for (var day = 2; day <= GameConfig.materialLotDays; day++) {
      passDay(game);
      expect(game.materialLots, [wood], reason: 'ngày $day vẫn còn');
    }
    passDay(game); // sáng ngày 4: quá hạn
    expect(game.materialLots, isEmpty);
  });

  test('chữa ngay: guild trả tiền, không đụng ví hunter', () {
    final game = GameState(random: Random(1));
    final h = game.hunters.first..gold = 0;
    h.hp = h.maxHp / 2;
    game.admit(h);
    final cost = game.healNowCost(h);
    final guildBefore = game.gold;

    game.healNow(h);
    expect(h.isFullHp, isTrue);
    expect(h.inHospital, isFalse);
    expect(h.gold, 0);
    expect(game.gold, guildBefore - cost);
  });

  test('báo số lô nguyên liệu mới khi đội trở về', () {
    final game = GameState(random: Random(2))..map = lineMap();
    final quest = Quest(
      id: 999,
      location: Location.grassland,
      tier: QuestTier.d,
      monster: MonsterType.beast,
      isHorde: true,
      isGroup: false,
      minParty: 1,
      maxParty: 1,
      difficulty: 1,
      gold: 0,
      exp: 0,
    );
    game.quests.add(quest);
    game.dispatch(quest, [game.hunters.first]);
    game.advancePhase();
    final night = game.advancePhase();
    expect(night.newLotCount, game.materialLots.length);
  });

  test('chế tạo theo công thức: tốn nguyên liệu cùng cấp, đồ vào kho, bình máu vào tiệm thuốc', () {
    final game = GameState(random: Random(1))..blueprints.addAll([for (final g in ItemGrade.values) ...BlueprintInfo.ofGrade(g)]);
    game.materials[(Resource.ore, ItemGrade.fine)] = 3;
    game.materials[(Resource.wood, ItemGrade.fine)] = 1;
    expect(game.canCraft(Recipe.sword, ItemGrade.basic), isFalse);
    expect(game.canCraft(Recipe.sword, ItemGrade.fine), isTrue);

    final stockBefore = game.shopStock.length;
    game.craft(Recipe.sword, ItemGrade.fine);
    expect(game.shopStock.length, stockBefore + 1);
    expect(game.shopStock.last.type, ItemType.sword);
    expect(game.shopStock.last.grade, ItemGrade.fine);
    expect(game.materialCount(Resource.ore, ItemGrade.fine), 0);

    game.materials[(Resource.blood, ItemGrade.fine)] = 2;
    game.materials[(Resource.core, ItemGrade.fine)] = 1;
    game.craft(Recipe.potion, ItemGrade.fine);
    expect(game.potionStock[Potion.medium], 1);
  });

  test('hunter chỉ mua được bình máu còn trong kho', () {
    final game = GameState(random: Random(1));
    final h = _hunter(HunterClass.warrior)..gold = 1000;
    game.hunters.add(h);
    game.shopStock.clear();
    game.potionStock
      ..clear()
      ..[Potion.large] = 1;
    toNextMorning(game);
    expect(h.potions, [Potion.large]);
    expect(game.potionStock[Potion.large], 0);
  });

  test('tổng kết ngày hiện khi sang sáng hôm sau, so sánh với hôm trước', () {
    final game = GameState(random: Random(1));
    game.advancePhase();
    expect(game.advancePhase().daily, isNull); // đêm
    final morning2 = game.advancePhase();
    expect(morning2.daily!.day, 1);
    expect(morning2.yesterday, isNull);
    game.advancePhase();
    game.advancePhase();
    final morning3 = game.advancePhase();
    expect(morning3.daily!.day, 2);
    expect(morning3.yesterday!.day, 1);
  });

  test('giao nhiệm vụ được buổi trưa, về muộn hơn giao buổi sáng một buổi', () {
    final game = GameState(random: Random(3))..map = lineMap();
    final h = game.hunters.first;
    final quest = Quest(
      id: 500,
      location: Location.grassland,
      tier: QuestTier.d,
      monster: MonsterType.beast,
      isHorde: false,
      isGroup: false,
      minParty: 1,
      maxParty: 1,
      difficulty: 1,
      gold: 10,
      exp: 1,
    );
    game.quests.add(quest);
    game.advancePhase(); // trưa
    expect(game.dispatchError(quest, [h]), isNull);
    final trip = game.dispatch(quest, [h]);
    expect(describePhase(trip.arriveAt), 'Ngày 1 · Đêm');
    expect(describePhase(trip.returnAt), 'Ngày 2 · Sáng');
  });

  test('không thể hồi sinh hunter trên 75 tuổi', () {
    final game = GameState(random: Random(1));
    final old = _hunter(HunterClass.warrior, age: 76);
    game.fallen.add(old);
    final goldBefore = game.gold;
    expect(game.pray(old), isFalse);
    expect(game.gold, goldBefore);
  });

  test('lưu rồi đọc lại cho ra đúng trạng thái game', () {
    final game = GameState(random: Random(7));
    final h = game.hunters.first..gold = 500;
    h.equip(Equipment.standard(id: 900, type: ItemType.clothArmor, grade: ItemGrade.basic)..durability = 42);
    h.potions.add(Potion.small);
    game.materials[(Resource.ore, ItemGrade.fine)] = 4;
    game.dispatch(game.quests.firstWhere((q) => !q.isGroup && q.tier == QuestTier.d, orElse: () {
      final q = Quest(
        id: 999,
        location: Location.grassland,
        tier: QuestTier.d,
        monster: MonsterType.beast,
        isHorde: false,
        isGroup: false,
        minParty: 1,
        maxParty: 1,
        difficulty: 30,
        gold: 40,
        exp: 30,
      );
      game.quests.add(q);
      return q;
    }), [game.hunters[1]]);
    for (var i = 0; i < 4; i++) {
      game.advancePhase();
    }

    final json = jsonDecode(jsonEncode(game.toJson())) as Map<String, dynamic>;
    final loaded = GameState.fromJson(json);
    expect(loaded.toJson(), game.toJson());

    final h2 = loaded.hunters.firstWhere((x) => x.id == h.id);
    expect(h2.gold, h.gold);
    expect(h2.potions, h.potions);
    expect(h2.equipment[EquipSlot.armor]!.durability, h.equipment[EquipSlot.armor]!.durability);
    expect(h2.maxHp, h.maxHp);
    expect(loaded.materialCount(Resource.ore, ItemGrade.fine), 4);
  });

  test('3 slot lưu độc lập, xoá được', () async {
    SharedPreferences.setMockInitialValues({});
    final saves = SaveService();
    expect(await saves.listSlots(), [null, null, null]);

    final game = GameState(random: Random(1))..gold = 1234;
    await saves.save(1, game);
    final slots = await saves.listSlots();
    expect(slots[0], isNull);
    expect(slots[1]!.gold, 1234);
    expect((await saves.load(1))!.gold, 1234);

    await saves.delete(1);
    expect(await saves.load(1), isNull);
  });

  testWidgets('bản đồ hiện đủ các khu và đội đang đi', (tester) async {
    final game = GameState(random: Random(4));
    final quest = game.quests.firstWhere((q) => !q.isGroup && q.tier == QuestTier.d, orElse: () {
      final q = Quest(
        id: 999,
        location: Location.grassland,
        tier: QuestTier.d,
        monster: MonsterType.beast,
        isHorde: false,
        isGroup: false,
        minParty: 1,
        maxParty: 1,
        difficulty: 30,
        gold: 40,
        exp: 30,
      );
      game.quests.add(q);
      return q;
    });
    game.dispatch(quest, [game.hunters.first]);

    await tester.pumpWidget(MaterialApp(home: MapScreen(game: game)));
    await tester.pumpAndSettle();
    for (final l in Location.values) {
      expect(find.text(l.label), findsOneWidget, reason: l.label);
    }
    expect(find.textContaining('Đang đi tới ${quest.location.label}'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(quest.location.label));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đi ${game.map.travelTime(Location.town, quest.location)} buổi'), findsOneWidget);
  });

  // ---------------- Danh tiếng & game over ----------------

  Quest soloQuest(QuestTier tier, {double difficulty = 30}) => Quest(
        id: 5000 + tier.index,
        location: Location.grassland,
        tier: tier,
        monster: MonsterType.beast,
        isHorde: false,
        isGroup: false,
        minParty: 1,
        maxParty: 1,
        difficulty: difficulty,
        gold: 40,
        exp: 30,
      );

  ExpeditionReport runUntilReturn(GameState game) {
    for (var i = 0; i < 12; i++) {
      final report = game.advancePhase();
      if (report.returns.isNotEmpty) return report.returns.single;
    }
    throw StateError('Đội không trở về');
  }

  test('hạng thị trấn theo mốc danh tiếng; bảng nhiệm vụ chỉ có quest tới tier đã mở', () {
    expect(TownRank.of(0), TownRank.d);
    expect(TownRank.of(TownRank.c.minReputation - 1), TownRank.d);
    expect(TownRank.of(TownRank.c.minReputation), TownRank.c);
    expect(TownRank.of(99999), TownRank.s);
    expect(TownRank.s.maxQuestTier, QuestTier.sss);

    final game = GameState(random: Random(3));
    expect(game.rank, TownRank.d);
    expect(game.quests.every((q) => q.tier == QuestTier.d), isTrue);

    game
      ..reputation = TownRank.b.minReputation
      ..gold = 100000;
    for (var i = 0; i < 30; i++) {
      game.refreshQuests();
      expect(game.quests.every((q) => q.tier.index <= QuestTier.b.index), isTrue);
    }
    final generator = QuestGenerator(Random(1));
    final tiers = {for (var i = 0; i < 500; i++) generator.generate(i, maxTier: QuestTier.c).tier};
    expect(tiers, {QuestTier.d, QuestTier.c});
  });

  test('hạng cao tăng tỉ lệ hunter Sử thi/Huyền thoại thêm tối đa 8%', () {
    int total(double bonus) => Rarity.values.fold(0, (s, r) => s + HunterFactory.rarityWeight(r, bonus));
    int rareShare(double bonus) =>
        HunterFactory.rarityWeight(Rarity.epic, bonus) + HunterFactory.rarityWeight(Rarity.legendary, bonus);

    expect(total(0), 1000);
    expect(total(TownRank.s.rareHunterBonus), 1000);
    expect(rareShare(TownRank.s.rareHunterBonus) - rareShare(0), 80);
    expect(HunterFactory.rarityWeight(Rarity.rare, 0.08), HunterFactory.rarityWeight(Rarity.rare, 0));
  });

  test('quest thành công tăng danh tiếng theo tier, có trong báo cáo và tổng kết ngày', () {
    final game = GameState(random: Random(2));
    final h = game.hunters.first;
    while (h.level < 15) {
      h.gainExp(h.expToNext);
    }
    h.hp = h.maxHp;
    final quest = soloQuest(QuestTier.d, difficulty: 10);
    game.quests.add(quest);
    game.dispatch(quest, [h]);

    final report = runUntilReturn(game);
    expect(report.result.success, isTrue);
    expect(report.reputation, GameConfig.questReputation[QuestTier.d]);
    expect(game.reputation, GameConfig.questReputation[QuestTier.d]);

    while (game.phase != DayPhase.night) {
      game.advancePhase();
    }
    final reputation = game.reputation;
    game.advancePhase(); // sáng hôm sau mới chốt tổng kết
    expect(game.dailyReports.last.reputation, reputation);
  });

  test('quest thất bại và hunter hy sinh làm giảm danh tiếng, không xuống dưới 0', () {
    final game = GameState(random: Random(5))..reputation = 100;
    final quest = soloQuest(QuestTier.d, difficulty: 5000);
    game.quests.add(quest);
    game.dispatch(quest, [game.hunters.first]);

    final report = runUntilReturn(game);
    expect(report.result.success, isFalse);
    final expected = -(GameConfig.questReputation[QuestTier.d]! * GameConfig.failReputationRate).round() -
        report.result.deaths.length * GameConfig.deathReputationLoss;
    expect(report.reputation, expected);
    expect(game.reputation, 100 + expected);

    final fresh = GameState(random: Random(5));
    final q2 = soloQuest(QuestTier.d, difficulty: 5000);
    fresh.quests.add(q2);
    fresh.dispatch(q2, [fresh.hunters.first]);
    runUntilReturn(fresh);
    expect(fresh.reputation, 0);
  });

  test('chữa ngay hunter nguy kịch được cộng danh tiếng, bị thương nhẹ thì không', () {
    final game = GameState(random: Random(1));
    final [critical, light, ...] = game.hunters;
    critical.hp = critical.maxHp * 0.1;
    light.hp = light.maxHp * 0.6;
    game.healNow(light);
    expect(game.reputation, 0);
    game.healNow(critical);
    expect(game.reputation, GameConfig.rescueReputation);
  });

  test('thanh lý hàng tồn: đồ, bình máu, nguyên liệu đổi ra vàng cho guild', () {
    final game = GameState(random: Random(1));
    final item = Equipment.standard(id: 800, type: ItemType.sword, grade: ItemGrade.basic);
    game.shopStock.add(item);
    game.materials[(Resource.ore, ItemGrade.basic)] = 4;
    final potionPrice = game.potionSellPrice(Potion.small);
    final orePrice = game.materialSellPrice(Resource.ore, ItemGrade.basic);
    expect(game.liquidationValue, item.tradeInValue + potionPrice * GameConfig.startingSmallPotions + orePrice * 4);

    final before = game.gold;
    game.sellStock(item);
    game.sellPotion(Potion.small);
    game.sellMaterial(Resource.ore, ItemGrade.basic);
    expect(game.shopStock, isEmpty);
    expect(game.potionStock[Potion.small], GameConfig.startingSmallPotions - 1);
    expect(game.materialCount(Resource.ore, ItemGrade.basic), 0);
    expect(game.gold, before + item.tradeInValue + potionPrice + orePrice * 4);
  });

  test('phá sản: hết tiền và không còn gì bán đủ 1 giấy mời thì thua cuối buổi', () {
    final game = GameState(random: Random(1))
      ..gold = GameConfig.invitationCost - 1
      ..potionStock.clear();
    expect(game.atRisk, isTrue);
    final report = game.advancePhase();
    expect(report.gameOver, GameOverReason.bankrupt);
    expect(game.gameOver, GameOverReason.bankrupt);
    expect(game.advancePhase, throwsStateError);

    // Còn hàng thanh lý được thì chưa thua.
    final saved = GameState(random: Random(1))..gold = GameConfig.invitationCost - 1;
    expect(saved.liquidationValue, greaterThan(0));
    expect(saved.atRisk, isFalse);
    expect(saved.advancePhase().gameOver, isNull);
  });

  test('thị trấn hoang phế: không còn hunter và không đủ tiền chiêu mộ lại', () {
    final game = GameState(random: Random(1))
      ..hunters.clear()
      ..potionStock.clear()
      ..gold = GameConfig.invitationCost + Rarity.common.joinFee - 1;
    expect(game.checkGameOver(), GameOverReason.abandoned);

    // Đủ tiền phát giấy mời + nhận 1 hunter Thường thì vẫn chơi tiếp.
    game.gold++;
    expect(game.checkGameOver(), isNull);

    // Hoặc có sẵn ứng viên nhận được.
    game
      ..gold = Rarity.common.joinFee
      ..candidates.add(_hunter(HunterClass.tank));
    expect(game.checkGameOver(), isNull);
    expect(game.advancePhase().gameOver, isNull);
  });

  test('danh tiếng và game over được lưu', () {
    final game = GameState(random: Random(1))
      ..reputation = 321
      ..gameOver = GameOverReason.abandoned;
    final loaded = GameState.fromJson(jsonDecode(jsonEncode(game.toJson())) as Map<String, dynamic>);
    expect(loaded.reputation, 321);
    expect(loaded.rank, TownRank.b);
    expect(loaded.gameOver, GameOverReason.abandoned);
  });

  // ---------------- Quest thu thập ----------------

  test('quest thu thập: ít EXP, thưởng và độ khó hơn quest săn', () {
    final generator = QuestGenerator(Random(9));
    final quests = [for (var i = 0; i < 2000; i++) generator.generate(i)];
    final gathering = quests.where((q) => q.isGathering).toList();
    expect(gathering.length / quests.length, closeTo(GameConfig.gatheringQuestChance, 0.04));
    for (final q in gathering.take(50)) {
      final hunt = quests.firstWhere((h) => !h.isGathering && h.tier == q.tier && h.isGroup == q.isGroup);
      expect(q.exp, lessThan(hunt.exp));
      expect(q.title, contains(q.location.label));
      // Độ khó/thưởng đã nhân hệ số thu thập (dao động ±15% vẫn thấp hơn mức chuẩn).
      expect(q.difficulty, lessThan(q.tier.difficulty * (q.isGroup ? q.minParty + 0.5 : 1)));
      expect(q.gold, lessThan(q.tier.gold * (q.isGroup ? q.minParty + 0.5 : 1)));
    }
    final json = gathering.first.toJson();
    expect(Quest.fromJson(json).isGathering, isTrue);
    expect(Quest.fromJson(json..remove('isGathering')).isGathering, isFalse); // bản lưu cũ
  });

  test('quest thu thập mang về nhiều nguyên liệu của khu hơn quest săn', () {
    Quest make({required bool gathering}) => Quest(
          id: 1,
          location: Location.mine,
          tier: QuestTier.d,
          monster: MonsterType.golem,
          isHorde: false,
          isGroup: false,
          minParty: 1,
          maxParty: 1,
          difficulty: 5,
          gold: 10,
          exp: 10,
          isGathering: gathering,
        );
    int total(Map<Resource, int> bag) => bag.values.fold(0, (a, b) => a + b);

    var huntTotal = 0, gatherTotal = 0;
    for (var seed = 0; seed < 30; seed++) {
      final hunter = leveled(HunterClass.warrior, 10);
      final hunt = QuestResolver(Random(seed)).resolve(make(gathering: false), [hunter]);
      huntTotal += total(hunt.loot[hunter] ?? {});

      final gatherer = leveled(HunterClass.warrior, 10);
      final gather = QuestResolver(Random(seed)).resolve(make(gathering: true), [gatherer]);
      final bag = gather.loot[gatherer]!;
      expect(Location.mine.gatherables, containsAll(bag.keys));
      gatherTotal += total(bag);
    }
    expect(gatherTotal, greaterThan(huntTotal * 2));
  });

  test('lô nguyên liệu quá hạn: hunter tự bán chỗ khác với nửa giá', () {
    // Kho trống để hunter không tiêu mất tiền lúc mua sắm buổi sáng.
    final game = GameState(random: Random(1))..potionStock.clear();
    final h = game.hunters.first..gold = 0;
    final lot = MaterialLot(hunter: h, resource: Resource.ore, grade: ItemGrade.basic, quantity: 4, day: 1);
    game.materialLots.add(lot);
    while (game.day <= GameConfig.materialLotDays) {
      game.advancePhase();
      game.shopStock.clear(); // bỏ hàng nhập các đêm đầu
    }
    expect(game.materialLots, isNot(contains(lot)));
    expect(h.gold, (lot.price * GameConfig.expiredLotSellRate).round());
  });

  // ---------------- Hạng hunter ----------------

  test('hạng hunter: mỗi lần lên hạng cần gấp đôi fame lần trước, SSS là tối đa', () {
    final base = GameConfig.hunterRankBaseFame;
    expect([for (final t in QuestTier.values) Hunter.fameForRank(t)], [
      0,
      base,
      base + base * 2,
      base + base * 2 + base * 4,
      base + base * 2 + base * 4 + base * 8,
      base + base * 2 + base * 4 + base * 8 + base * 16,
    ]);

    final h = _hunter(HunterClass.warrior);
    expect(h.rank, QuestTier.d);
    expect(h.maxQuestTier, QuestTier.c);
    // Fame chạm mốc thì dừng lại, chưa tự lên hạng.
    h.gainFame(base - 1);
    expect(h.canPromote, isFalse);
    h.gainFame(50);
    expect(h.fame, base);
    expect(h.canPromote, isTrue);
    expect(h.rank, QuestTier.d);
    h.promote();
    expect(h.rank, QuestTier.c);
    expect(h.canPromote, isFalse);

    h
      ..rank = QuestTier.sss
      ..fame = 5000;
    h.gainFame(10);
    expect(h.fame, 5010); // SSS không giới hạn fame
    expect(h.canPromote, isFalse);
    expect(h.nextRank, isNull);
    expect(h.maxQuestTier, QuestTier.sss);
  });

  test('hunter chỉ nhận quest tới 1 tier trên hạng mình', () {
    Quest q(QuestTier tier) => Quest(
          id: 1,
          location: Location.grassland,
          tier: tier,
          monster: MonsterType.beast,
          isHorde: false,
          isGroup: false,
          minParty: 1,
          maxParty: 1,
          difficulty: 10,
          gold: 10,
          exp: 10,
        );
    final h = leveled(HunterClass.warrior, QuestTier.b.minLevel);
    expect(QuestResolver.validateParty(q(QuestTier.c), [h]), isNull);
    expect(QuestResolver.validateParty(q(QuestTier.b), [h]), contains('hạng D'));
    h.rank = QuestTier.c;
    expect(QuestResolver.validateParty(q(QuestTier.b), [h]), isNull);
  });

  test('fame theo tier quest, chỉ khi thành công; quest thu thập được một nửa (làm tròn lên)', () {
    Quest q({required double difficulty, bool gathering = false}) => Quest(
          id: 1,
          location: Location.grassland,
          tier: QuestTier.c,
          monster: MonsterType.beast,
          isHorde: false,
          isGroup: false,
          minParty: 1,
          maxParty: 1,
          difficulty: difficulty,
          gold: 10,
          exp: 10,
          isGathering: gathering,
        );
    final winner = leveled(HunterClass.warrior, 20);
    final win = QuestResolver(Random(1)).resolve(q(difficulty: 5), [winner]);
    expect(win.fameEach, GameConfig.questFame[QuestTier.c]);
    expect(winner.fame, GameConfig.questFame[QuestTier.c]);

    final gatherer = leveled(HunterClass.warrior, 20);
    final gather = QuestResolver(Random(1)).resolve(q(difficulty: 5, gathering: true), [gatherer]);
    expect(gather.fameEach, (GameConfig.questFame[QuestTier.c]! * GameConfig.gatheringReputationRate).ceil());

    final loser = leveled(HunterClass.mage, 5)..fame = 7;
    final lose = QuestResolver(Random(1)).resolve(q(difficulty: 5000), [loser]);
    expect(lose.success, isFalse);
    expect(lose.fameEach, 0);
    expect(loser.fame, 7);

    // Quest thường không tự lên hạng, chỉ đầy fame.
    final nearRankUp = leveled(HunterClass.warrior, 20)..fame = GameConfig.hunterRankBaseFame - 1;
    final up = QuestResolver(Random(1)).resolve(q(difficulty: 5), [nearRankUp]);
    expect(up.rankUps, isEmpty);
    expect(nearRankUp.canPromote, isTrue);
  });

  test('fame được lưu; bản lưu cũ xếp hạng theo cấp', () {
    final h = leveled(HunterClass.tank, 13)..fame = 55;
    final json = jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>;
    expect(Hunter.fromJson(json).fame, 55);
    final old = Hunter.fromJson(json
      ..remove('fame')
      ..remove('rank'));
    expect(old.rank, QuestTier.b); // cấp 13 >= cấp tối thiểu quest B
  });

  // ---------------- Quest thăng hạng ----------------

  test('quest thăng hạng hợp với lớp: pháp sư/đỡ đòn gặp bầy quái, thợ săn/hồi máu gặp đầu lĩnh', () {
    final generator = QuestGenerator(Random(1));
    for (final (c, horde) in [
      (HunterClass.mage, true),
      (HunterClass.tank, true),
      (HunterClass.ranger, false),
      (HunterClass.healer, false),
    ]) {
      final h = leveled(c, 5)..fame = GameConfig.hunterRankBaseFame;
      final q = generator.generatePromotion(1, h);
      expect(q.isHorde, horde, reason: c.label);
      expect(q.tier, QuestTier.c);
      expect(q.isGroup, isFalse);
      expect(q.promotionFor, h.id);
      expect(q.location.supports(q.tier), isTrue);
      final rate = GameConfig.promotionDifficultyRate[c]!;
      expect(q.difficulty, inInclusiveRange(QuestTier.c.difficulty * rate * 0.95, QuestTier.c.difficulty * rate * 1.05));
    }
    final warriorKinds = {
      for (var i = 0; i < 30; i++) generator.generatePromotion(i, leveled(HunterClass.warrior, 5)).isHorde,
    };
    expect(warriorKinds, {true, false}); // chiến binh cân bằng: gặp cả hai
  });

  test('quest thăng hạng: chỉ chủ nhân làm được; thắng lên hạng, thua mất 20% fame', () {
    final owner = leveled(HunterClass.warrior, 20)..fame = GameConfig.hunterRankBaseFame;
    final other = leveled(HunterClass.ranger, 20);
    Quest trial({required double difficulty}) => Quest(
          id: 1,
          location: Location.grassland,
          tier: QuestTier.c,
          monster: MonsterType.beast,
          isHorde: false,
          isGroup: false,
          minParty: 1,
          maxParty: 1,
          difficulty: difficulty,
          gold: 10,
          exp: 10,
          promotionFor: owner.id,
        );
    expect(QuestResolver.validateParty(trial(difficulty: 5), [other]), contains('riêng'));
    expect(QuestResolver.validateParty(trial(difficulty: 5), [owner]), isNull);

    final win = QuestResolver(Random(1)).resolve(trial(difficulty: 5), [owner]);
    expect(win.success, isTrue);
    expect(win.rankUps[owner], QuestTier.c);
    expect(owner.rank, QuestTier.c);
    expect(win.fameEach, 0);

    final loser = leveled(HunterClass.mage, 20)..fame = GameConfig.hunterRankBaseFame; // 20 = trần hạng D
    final lossQuest = Quest.fromJson(trial(difficulty: 5000).toJson()..['promotionFor'] = loser.id);
    final lose = QuestResolver(Random(1)).resolve(lossQuest, [loser]);
    expect(lose.success, isFalse);
    if (!lose.deaths.contains(loser)) {
      expect(lose.fameLost[loser], 4);
      expect(loser.fame, 16);
      expect(loser.rank, QuestTier.d);
    }
  });

  test('game tạo quest thăng hạng khi fame chạm trần, không bị làm mới mất, bỏ khi hunter chết', () {
    final game = GameState(random: Random(1))..gold = 10000;
    final h = game.hunters.first..fame = GameConfig.hunterRankBaseFame;
    final report = game.advancePhase();
    expect(report.newPromotions, [h]);
    final trial = game.promotionQuestOf(h)!;
    expect(trial.tier, QuestTier.c);
    expect(game.quests.where((q) => !q.isPromotion).length, GameConfig.boardSize);

    game.refreshQuests();
    expect(game.promotionQuestOf(h), trial);
    expect(game.advancePhase().newPromotions, isEmpty); // không tạo trùng

    game.hunters.remove(h);
    game.advancePhase();
    expect(game.quests.any((q) => q.isPromotion), isFalse);
  });

  test('hạng hunter được lưu', () {
    final h = leveled(HunterClass.tank, 3)
      ..fame = 5
      ..rank = QuestTier.b;
    final loaded = Hunter.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect(loaded.rank, QuestTier.b);
    expect(loaded.fame, 5);
  });

  testWidgets('chọn slot trống -> game mới với đủ hunter khởi đầu', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const HunterGuildApp());
    await tester.pumpAndSettle();
    expect(find.text('Slot trống'), findsNWidgets(SaveService.slotCount));

    await tester.tap(find.text('Game mới').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('N1 · Sáng'), findsOneWidget);
    // Danh sách cuộn: có thể không hiện hết mọi hunter trên màn hình test.
    expect(find.textContaining('Lv 1 ·'), findsWidgets);
  });

  testWidgets('màn dọc: chuyển buổi, sang sáng thì bảng tổng kết tự hiện trước báo cáo buổi sáng', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const HunterGuildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Game mới').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (final (button, phase) in [('Sang trưa', 'N1 · Trưa'), ('Sang đêm', 'N1 · Đêm')]) {
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      expect(find.byType(DailySummaryDialog), findsNothing);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text(phase), findsOneWidget);
    }

    await tester.tap(find.text('Sáng mai'));
    await tester.pumpAndSettle();
    expect(find.text('Tổng kết ngày 1'), findsOneWidget);
    await tester.tap(find.text('Bắt đầu ngày mới'));
    await tester.pumpAndSettle();
    expect(find.byType(PhaseReportDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('N2 · Sáng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Luôn có tư tế trong phe quái.
class _HealerEngine extends CombatEngine {
  _HealerEngine(super.random);

  @override
  List<Combatant> buildEnemies(Quest quest, {bool? withHealer}) => super.buildEnemies(quest, withHealer: true);
}

/// Không bao giờ có tư tế.
class _NoHealerEngine extends CombatEngine {
  _NoHealerEngine(super.random);

  @override
  List<Combatant> buildEnemies(Quest quest, {bool? withHealer}) => super.buildEnemies(quest, withHealer: false);
}

void _hunterScreensLayoutTests() {
  Future<void> pumpPhone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pump();
  }

  GameState richGame() {
    final game = GameState(random: Random(7));
    final h = Hunter(
      id: 999,
      name: 'Nguyễn Văn Tên Rất Dài Của Hunter',
      hunterClass: HunterClass.tank,
      rarity: Rarity.legendary,
      age: 25,
      stats: GameConfig.classBaseStats[HunterClass.tank]!,
    )
      ..gold = 123456
      ..fame = 15;
    game.hunters.insert(0, h);
    h.equip(Equipment.standard(id: 900, type: ItemType.sword, grade: ItemGrade.divine));
    h.stash.add(Equipment.standard(id: 901, type: ItemType.shield, grade: ItemGrade.master));
    game.hunters[1].inHospital = true;
    return game;
  }

  testWidgets('danh sách hunter vừa màn điện thoại dọc, lọc được theo trạng thái', (tester) async {
    final game = richGame();
    await pumpPhone(tester, HunterListScreen(game: game));
    expect(tester.takeException(), isNull);
    expect(find.byType(HunterRosterCard), findsWidgets);
    await tester.ensureVisible(find.textContaining('Nằm viện 1'));
    await tester.tap(find.textContaining('Nằm viện 1'));
    await tester.pump();
    expect(find.byType(HunterRosterCard), findsOneWidget);
  });

  testWidgets('bảng nhiệm vụ & chi tiết quest vừa màn dọc ở cả 3 buổi; đêm không giao được', (tester) async {
    final game = richGame();
    final quest = game.quests.first;
    final solo = Quest(
      id: 777,
      location: game.quests.first.location,
      tier: QuestTier.d,
      monster: MonsterType.beast,
      isHorde: false,
      isGroup: false,
      minParty: 1,
      maxParty: 1,
      difficulty: 1,
      gold: 10,
      exp: 1,
    );
    game.quests.add(solo);
    game.dispatch(solo, [game.hunters.last]);
    for (final phase in DayPhase.values) {
      expect(game.phase, phase);
      await pumpPhone(tester, QuestBoardScreen(game: game));
      expect(tester.takeException(), isNull);
      expect(find.text('Ngày ${game.day} · ${phase.label}'), findsOneWidget);
      expect(find.byType(ExpeditionCard), game.expeditions.isEmpty ? findsNothing : findsOneWidget);
      expect(find.text(phase == DayPhase.night ? '⛔ Nghỉ đêm' : '✅ Giao được'), findsOneWidget);
      if (game.quests.contains(quest)) {
        tester.view.physicalSize = const Size(360, 780);
        await tester.pumpWidget(MaterialApp(home: QuestDetailScreen(game: game, quest: quest)));
        expect(tester.takeException(), isNull);
        expect(find.text('Xuất phát'), findsOneWidget);
      }
      game.advancePhase();
    }
  });

  testWidgets('sàn chứng khoán vừa màn dọc; mở bảng giao dịch, mua được', (tester) async {
    final game = GameState(random: Random(4))..gold = 2000;
    for (var i = 0; i < 3; i++) {
      game.advancePhase();
    }
    await pumpPhone(tester, StockMarketScreen(game: game));
    expect(tester.takeException(), isNull);
    expect(find.text('Bảng giá'), findsOneWidget);
    await tester.tap(find.text(Company.temple.label));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('+10'));
    await tester.pump();
    await tester.tap(find.text('Mua'));
    await tester.pumpAndSettle();
    expect(game.stocks.sharesOf(Company.temple), 11);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hộp tổng kết ngày vừa màn dọc', (tester) async {
    final game = GameState(random: Random(1));
    game.advancePhase();
    game.advancePhase();
    final morning = game.advancePhase();
    await pumpPhone(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => DailySummaryDialog(today: morning.daily!, yesterday: morning.yesterday),
          ),
          child: const Text('mở'),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Tổng kết ngày 1'), findsOneWidget);
    await tester.tap(find.text('Bắt đầu ngày mới'));
    await tester.pumpAndSettle();
    expect(find.text('Tổng kết ngày 1'), findsNothing);
  });

  testWidgets('chi tiết hunter: 3 tab đều hiển thị không tràn trên màn dọc', (tester) async {
    final game = richGame();
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: HunterDetailScreen(game: game, hunter: game.hunters.first)));
    expect(tester.takeException(), isNull);
    for (final tab in ['Kỹ năng', 'Đồ đạc', 'Chỉ số']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Kỹ năng'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nội tại'), findsOneWidget);
  });
}
