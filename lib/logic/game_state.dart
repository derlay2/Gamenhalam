import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/crafting.dart';
import '../models/day.dart';
import '../models/enums.dart';
import '../models/equipment.dart';
import '../models/events.dart';
import '../models/hunter.dart';
import '../models/potion.dart';
import '../models/quest.dart';
import '../models/stock.dart';
import '../models/town.dart';
import '../models/trade.dart';
import '../models/world_map.dart';
import 'game_config.dart';
import 'hunter_factory.dart';
import 'market.dart';
import 'quest_generator.dart';
import 'quest_resolver.dart';
import 'random_utils.dart';
import 'shopping.dart';
import 'stock_market.dart';

class GameState extends ChangeNotifier {
  GameState({Random? random}) : _random = random ?? Random() {
    map = WorldMap.generate(_random);
    for (var i = 0; i < GameConfig.startingHunters; i++) {
      hunters.add(_hunterFactory.create(_nextId++, rarity: Rarity.common));
    }
    _fillBoard();
    _restockMarkets();
    _restockForeign();
  }

  /// Khôi phục game từ bản lưu.
  GameState.fromJson(Map<String, dynamic> j, {Random? random}) : _random = random ?? Random() {
    List<Map<String, dynamic>> list(String key) => (j[key] as List).cast<Map<String, dynamic>>();

    _nextId = j['nextId'] as int;
    map = WorldMap.fromJson(j['map'] as Map<String, dynamic>);
    gold = j['gold'] as int;
    day = j['day'] as int;
    phase = DayPhase.values.byName(j['phase'] as String);
    hunters.addAll(list('hunters').map(Hunter.fromJson));
    fallen.addAll(list('fallen').map(Hunter.fromJson));
    candidates.addAll(list('candidates').map(Hunter.fromJson));

    final byId = {
      for (final h in [...hunters, ...fallen, ...candidates]) h.id: h,
    };
    Hunter hunterById(int id) => byId[id]!;

    quests.addAll(list('quests').map(Quest.fromJson));
    expeditions.addAll(list('expeditions').map((e) => Expedition.fromJson(e, hunterById)));
    dailyReports.addAll(list('dailyReports').map(DailyReport.fromJson));
    shopStock.addAll(list('shopStock').map(Equipment.fromJson));
    for (final m in list('materials')) {
      materials[(Resource.values.byName(m['resource'] as String), ItemGrade.values.byName(m['grade'] as String))] =
          m['count'] as int;
    }
    materialLots.addAll(list('materialLots').map((l) => MaterialLot.fromJson(l, hunterById)));
    potionStock
      ..clear()
      ..addAll({
        for (final MapEntry(key: name, value: count) in (j['potionStock'] as Map<String, dynamic>).entries)
          Potion.values.byName(name): count as int,
      });
    _today = _DayTracker.fromJson(j['today'] as Map<String, dynamic>);
    reputation = j['reputation'] as int? ?? 0;
    if (j['gameOver'] case final String reason) gameOver = GameOverReason.values.byName(reason);
    // Bản lưu trước khi có bản vẽ: tặng sẵn bản vẽ Sơ cấp. Bản lưu có bản vẽ theo cấp (chưa tách loại đồ):
    // quy đổi thành bản vẽ mọi loại đồ của cấp đó.
    for (final key in j['blueprints'] as List? ?? ['basic']) {
      final k = key as String;
      k.contains(':')
          ? blueprints.add(BlueprintInfo.parse(k))
          : blueprints.addAll(BlueprintInfo.ofGrade(ItemGrade.values.byName(k)));
    }
    if (j['foreignMarkets'] case final Map<String, dynamic> m) {
      for (final MapEntry(key: country, value: offers) in m.entries) {
        foreignMarkets[Country.values.byName(country)] = [
          for (final o in offers as List) MarketOffer.fromJson(o as Map<String, dynamic>),
        ];
      }
    } else {
      _restockForeign();
    }
    if (j['markets'] case final Map<String, dynamic> m) {
      for (final MapEntry(key: location, value: offers) in m.entries) {
        markets[Location.values.byName(location)] = [
          for (final o in offers as List) MarketOffer.fromJson(o as Map<String, dynamic>),
        ];
      }
    } else {
      _restockMarkets();
    }
    caravans.addAll([for (final c in j['caravans'] as List? ?? const []) CaravanTrip.fromJson(c as Map<String, dynamic>)]);
    if (j['event'] case final Map<String, dynamic> e) event = WeeklyEvent.fromJson(e);
    exiles.addAll([for (final h in j['exiles'] as List? ?? const []) Hunter.fromJson(h as Map<String, dynamic>)]);
    if (j['stocks'] case final Map<String, dynamic> s) stocks = StockMarket.fromJson(s);
  }

  Map<String, dynamic> toJson() => {
    'nextId': _nextId,
    'map': map.toJson(),
    'gold': gold,
    'day': day,
    'phase': phase.name,
    'hunters': [for (final h in hunters) h.toJson()],
    'fallen': [for (final h in fallen) h.toJson()],
    'candidates': [for (final h in candidates) h.toJson()],
    'quests': [for (final q in quests) q.toJson()],
    'expeditions': [for (final e in expeditions) e.toJson()],
    'dailyReports': [for (final r in dailyReports) r.toJson()],
    'shopStock': [for (final e in shopStock) e.toJson()],
    'materials': [
      for (final MapEntry(key: (resource, grade), value: count) in materials.entries)
        if (count > 0) {'resource': resource.name, 'grade': grade.name, 'count': count},
    ],
    'materialLots': [for (final l in materialLots) l.toJson()],
    'potionStock': {for (final MapEntry(key: p, value: count) in potionStock.entries) p.name: count},
    'today': _today.toJson(),
    'reputation': reputation,
    'gameOver': gameOver?.name,
    'blueprints': [for (final b in blueprints) b.key],
    'foreignMarkets': {
      for (final MapEntry(key: country, value: offers) in foreignMarkets.entries)
        country.name: [for (final o in offers) o.toJson()],
    },
    'markets': {
      for (final MapEntry(key: location, value: offers) in markets.entries)
        location.name: [for (final o in offers) o.toJson()],
    },
    'caravans': [for (final c in caravans) c.toJson()],
    'event': event?.toJson(),
    'exiles': [for (final h in exiles) h.toJson()],
    'stocks': stocks.toJson(),
  };

  final Random _random;
  late final _hunterFactory = HunterFactory(_random);
  late final _questGenerator = QuestGenerator(_random);
  late final _resolver = QuestResolver(_random);
  late final _equipmentFactory = EquipmentFactory(_random);
  int _nextId = 1;

  int gold = GameConfig.startingGold;
  int day = 1;
  DayPhase phase = DayPhase.morning;

  /// Thời điểm hiện tại tính bằng số buổi (xem [phaseIndex]).
  int get now => phaseIndex(day, phase);

  /// Bản đồ của lượt chơi này (ngẫu nhiên mỗi game mới).
  late WorldMap map;
  final hunters = <Hunter>[];
  final fallen = <Hunter>[];

  /// Hunter bị trục xuất (có thể quay lại làm boss phụ).
  final exiles = <Hunter>[];
  final quests = <Quest>[];

  /// Các đội đang đi làm nhiệm vụ.
  final expeditions = <Expedition>[];

  /// Tổng kết các ngày đã qua (mới nhất ở cuối).
  final dailyReports = <DailyReport>[];

  /// Hunter đã đến thị trấn nhờ giấy mời, chờ được nhận.
  final candidates = <Hunter>[];

  /// Kho nguyên liệu của guild.
  final materials = <(Resource, ItemGrade), int>{};

  /// Nguyên liệu hunter mang về đang chờ thu mua (hết hạn sáng hôm sau).
  final materialLots = <MaterialLot>[];

  /// Bình máu đang bày bán ở tiệm thuốc.
  final potionStock = <Potion, int>{Potion.small: GameConfig.startingSmallPotions};

  _DayTracker _today = _DayTracker(GameConfig.startingGold);

  // ---------------- Danh tiếng & kết thúc game ----------------

  /// Danh tiếng thị trấn (không âm); quyết định [rank].
  int reputation = 0;

  /// Danh tiếng bị tin đồn trừ tạm thời (0 nếu không có).
  int get reputationPenalty => event?.type == WeeklyEventType.rumor && event!.activeOn(day) ? event!.reputationPenalty : 0;

  /// Danh tiếng thực tế đang có hiệu lực (sau khi trừ tin đồn).
  int get effectiveReputation => max(0, reputation - reputationPenalty);

  TownRank get rank => TownRank.of(effectiveReputation);

  /// Tỉ lệ hunter Hiếm trở lên tìm đến (giảm khi có tin đồn).
  double get rareRate => reputationPenalty > 0 ? GameConfig.rumorRareRate : 1;

  void _addReputation(int amount) => reputation = max(0, reputation + amount);

  /// Khác null khi đã thua; game không thể chơi tiếp.
  GameOverReason? gameOver;

  /// Tổng số vàng guild thu được nếu thanh lý hết hàng tồn.
  int get liquidationValue =>
      stocks.liquidationValue +
      shopStock.fold<int>(0, (sum, item) => sum + item.tradeInValue) +
      potionStock.entries.fold<int>(0, (sum, e) => sum + potionSellPrice(e.key) * e.value) +
      materials.entries.fold<int>(0, (sum, e) => sum + materialSellPrice(e.key.$1, e.key.$2) * e.value);

  /// Vàng tối thiểu để chiêu mộ lại khi không còn hunter: nhận 1 ứng viên đang chờ,
  /// hoặc phát giấy mời + phí nhập của hunter Thường.
  int get recruitCost =>
      [GameConfig.invitationCost + Rarity.common.joinFee, for (final c in candidates) c.rarity.joinFee].reduce(min);

  /// Kiểm tra điều kiện thua (xét cả tiền thanh lý được).
  GameOverReason? checkGameOver() {
    final funds = gold + liquidationValue;
    if (funds < GameConfig.invitationCost) return GameOverReason.bankrupt;
    if (hunters.isEmpty && funds < recruitCost) return GameOverReason.abandoned;
    return null;
  }

  /// Nguy cơ thua nếu kết thúc buổi ngay bây giờ.
  bool get atRisk => checkGameOver() != null;

  // ---------------- Bảng nhiệm vụ ----------------

  bool get canRefresh => gold >= GameConfig.refreshCost;

  void refreshQuests() {
    if (!canRefresh) return;
    gold -= GameConfig.refreshCost;
    quests.removeWhere((q) => !q.isSpecial);
    _fillBoard();
    notifyListeners();
  }

  /// Giao nhiệm vụ được vào buổi sáng và buổi trưa.
  bool get canDispatchNow => phase != DayPhase.night;

  /// Lý do không thể giao quest lúc này, hoặc null nếu được.
  String? dispatchError(Quest quest, List<Hunter> party) {
    if (!canDispatchNow) return 'Ban đêm không giao nhiệm vụ, chờ sáng mai';
    if (accused case final h? when party.contains(h)) return '${h.name} đang bị điều tra, chờ bạn quyết định';
    return QuestResolver.validateParty(quest, party);
  }

  /// Giao quest cho đội; kết quả sẽ có khi đội trở về.
  Expedition dispatch(Quest quest, List<Hunter> party) {
    final error = dispatchError(quest, party);
    if (error != null) throw StateError(error);

    // Đi tới khu quest, đánh ngay buổi tới nơi, rồi quay về theo đường cũ.
    final travel = travelTime(quest.location);
    final expedition = Expedition(
      quest: quest,
      party: List.unmodifiable(party),
      route: map.path(Location.town, quest.location),
      departAt: now,
      arriveAt: now + travel,
      returnAt: now + travel * 2,
    );
    for (final h in party) {
      h.onQuest = true;
    }
    expeditions.add(expedition);
    quests.remove(quest);
    notifyListeners();
    return expedition;
  }

  /// Sang buổi tiếp theo: Sáng -> Trưa -> Đêm -> Sáng hôm sau.
  /// Cuối mỗi buổi (sau khi các đội về và hunter mua sắm) kiểm tra điều kiện thua.
  PhaseReport advancePhase() {
    if (gameOver != null) throw StateError('Game đã kết thúc');
    final rankBefore = rank;
    final report = switch (phase) {
      DayPhase.morning => _startNoon(),
      DayPhase.noon => _startNight(),
      DayPhase.night => _startMorning(),
    };
    final arrived = _returnCaravans();
    final promotions = _updatePromotions();
    gameOver = checkGameOver();
    notifyListeners();
    return PhaseReport(
      day: report.day,
      phase: report.phase,
      returns: report.returns,
      healed: report.healed,
      discharged: report.discharged,
      purchases: report.purchases,
      daily: report.daily,
      yesterday: report.yesterday,
      rankBefore: rankBefore,
      rankAfter: rank,
      gameOver: gameOver,
      newPromotions: promotions,
      caravans: arrived,
      newEvent: report.newEvent,
      siege: report.siege,
      provisions: report.provisions,
      eventOutcome: report.eventOutcome,
      stocks: report.stocks,
    );
  }

  PhaseReport _startNoon() {
    phase = DayPhase.noon;
    return PhaseReport(day: day, phase: phase, returns: _returnExpeditions());
  }

  PhaseReport _startNight() {
    phase = DayPhase.night;
    final returns = _returnExpeditions();
    // Quái tấn công sau khi các đội trong ngày đã về.
    final siege = event?.type == WeeklyEventType.siege && event!.siegeDay == day && !event!.siegeResolved
        ? _resolveSiege()
        : null;
    return PhaseReport(day: day, phase: phase, returns: returns, siege: siege);
  }

  PhaseReport _startMorning() {
    // Hết đêm: chốt tổng kết cả ngày (gồm trận thủ thành ban đêm) trước khi sang ngày mới.
    final daily = _today.finish(day: day, goldEnd: gold, hunterCount: hunters.length, reputation: reputation);
    final yesterday = dailyReports.lastOrNull;
    final gathered = _today.gatherSucceeded;
    dailyReports.add(daily);
    day++;
    phase = DayPhase.morning;
    _today = _DayTracker(gold);
    final newEvent = _startWeek();
    final autoOutcome = _autoChoose();
    final stockReport = _stockSession(gathered);
    if ((day - 1) % GameConfig.foreignRestockDays == 0) _restockForeign();
    // Lô nguyên liệu để quá hạn chưa mua đã được hunter bán chỗ khác (rẻ hơn giá guild).
    for (final lot in materialLots.where((lot) => lot.daysLeft(day) <= 0)) {
      lot.hunter.gold += (lot.price * GameConfig.expiredLotSellRate).round();
    }
    materialLots.removeWhere((lot) => lot.daysLeft(day) <= 0);

    final healed = <Hunter, double>{};
    final discharged = <Hunter>[];
    for (final h in hunters.where((h) => h.inHospital)) {
      final before = h.hp;
      h.heal(h.maxHp * GameConfig.hospitalHealPerDay * (isPlague ? GameConfig.plagueRecoveryRate : 1));
      healed[h] = h.hp - before;
      if (h.isFullHp) {
        h.inHospital = false;
        discharged.add(h);
      }
    }
    final returns = _returnExpeditions();
    _fillBoard();
    // Hunter ở thị trấn (kể cả người vừa về) đi mua sắm với hàng đang có.
    final provisions = _payProvisions();
    final purchases = _hunterShopping();
    return PhaseReport(
      day: day,
      phase: phase,
      returns: returns,
      healed: healed,
      discharged: discharged,
      purchases: purchases,
      newEvent: newEvent,
      eventOutcome: autoOutcome,
      provisions: provisions,
      daily: daily,
      yesterday: yesterday,
      stocks: stockReport,
    );
  }

  // ---------------- Chứng khoán ----------------

  StockMarket stocks = StockMarket();

  /// Sàn mở cửa buổi sáng và trưa.
  bool get stockMarketOpen => phase != DayPhase.night;

  /// Lý do không mua/bán được, hoặc null nếu được.
  String? stockTradeError(Company c, int shares, {required bool buy}) {
    if (!stockMarketOpen) return 'Sàn đóng cửa ban đêm';
    if (shares <= 0) return 'Chọn số cổ phiếu';
    if (buy && stocks.buyCost(c, shares) > gold) return 'Không đủ vàng';
    if (!buy && stocks.sharesOf(c) < shares) return 'Không đủ cổ phiếu để bán';
    return null;
  }

  void buyShares(Company c, int shares) {
    if (stockTradeError(c, shares, buy: true) case final error?) throw StateError(error);
    final cost = stocks.buyCost(c, shares);
    gold -= cost;
    _today.stocks -= cost;
    stocks.recordBuy(c, shares, cost);
    notifyListeners();
  }

  void sellShares(Company c, int shares) {
    if (stockTradeError(c, shares, buy: false) case final error?) throw StateError(error);
    final proceeds = stocks.sellProceeds(c, shares);
    gold += proceeds;
    _today.stocks += proceeds;
    stocks.recordSell(c, shares);
    notifyListeners();
  }

  /// Ngày trả cổ tức: ngày đầu mỗi tuần (trừ tuần đầu).
  bool get isDividendDay => day > 1 && (day - 1) % GameConfig.weekDays == 0;

  /// Phiên sáng: cập nhật giá theo sự kiện tuần, trả cổ tức nếu tới ngày.
  StockDayReport _stockSession(int gathered) {
    final changes = stocks.tick(_random, event: event, day: day, gatherSuccesses: gathered);
    final dividends = isDividendDay ? stocks.payDividends() : const <Company, int>{};
    final total = dividends.values.fold(0, (a, b) => a + b);
    gold += total;
    _today.stocks += total;
    return StockDayReport(changes: changes, news: List.of(stocks.news), dividends: dividends);
  }

  /// Hậu quả chung của 1 trận (quest hay thủ thành): người chết, nhập viện, lô nguyên liệu.
  /// Trả về việc xử lý đồ của người hy sinh.
  List<EstateSale> _applyBattle(Quest quest, QuestResult result) {
    hunters.removeWhere(result.deaths.contains);
    fallen.addAll(result.deaths);
    final estates = [for (final h in result.deaths) settleEstate(h)];
    for (final h in result.levelUps.keys) {
      if (h.hpRatio < GameConfig.hospitalThreshold) h.inHospital = true;
    }
    for (final MapEntry(key: h, value: bag) in result.loot.entries) {
      for (final MapEntry(key: resource, value: quantity) in bag.entries) {
        // Thị trấn hạng cao: lô có chút cơ hội rơi cao hơn 1 cấp.
        var grade = quest.tier.materialGrade;
        if (grade.index + 1 < ItemGrade.values.length && _random.nextDouble() < rank.lootUpgradeChance) {
          grade = ItemGrade.values[grade.index + 1];
        }
        materialLots.add(MaterialLot(hunter: h, resource: resource, grade: grade, quantity: quantity, day: day));
      }
    }
    return estates;
  }

  // ---------------- Trang bị rơi & kho riêng của hunter ----------------

  /// Hunter bán 1 món cho guild ([GameConfig.lootSellRate] giá); guild không đủ tiền thì bán cho thương lái.
  GearDrop _sellGear(Hunter h, Equipment item) {
    final price = (item.price * GameConfig.lootSellRate).round();
    h.gold += price;
    if (gold >= price) {
      gold -= price;
      shopStock.add(item);
      return GearDrop(hunter: h, item: item, outcome: GearOutcome.soldToGuild, price: price);
    }
    return GearDrop(hunter: h, item: item, outcome: GearOutcome.soldElsewhere, price: price);
  }

  /// Kho riêng quá [GameConfig.maxStashPerSlot] món 1 ô thì bán bớt món yếu nhất cho guild.
  List<GearDrop> _trimStash(Hunter h) {
    final sold = <GearDrop>[];
    for (final slot in EquipSlot.values) {
      final items = h.stash.where((e) => e.type.slot == slot).toList()
        ..sort((a, b) => ShoppingAdvisor.statValue(a.bonus).compareTo(ShoppingAdvisor.statValue(b.bonus)));
      for (final item in items.take(max(0, items.length - GameConfig.maxStashPerSlot))) {
        h.stash.remove(item);
        sold.add(_sellGear(h, item));
      }
    }
    return sold;
  }

  /// Mặc món tốt hơn có trong kho riêng (miễn phí); đồ thay ra cất lại vào kho. Trả về các món đã mặc.
  List<Equipment> _equipFromStash(Hunter h) {
    final worn = <Equipment>[];
    while (true) {
      Equipment? best;
      var bestValue = 0.0;
      for (final item in h.stash) {
        if (h.equipError(item) != null) continue;
        final value = ShoppingAdvisor.upgradeValue(h, item);
        if (value > bestValue) (best, bestValue) = (item, value);
      }
      if (best == null) return worn;
      h.stash.remove(best);
      h.stash.addAll(h.equip(best));
      worn.add(best);
    }
  }

  /// Hunter nhặt được [item]: mặc luôn nếu tốt hơn, không thì cất kho riêng; lớp không dùng được thì bán cho guild.
  @visibleForTesting
  List<GearDrop> receiveGear(Hunter h, Equipment item) {
    if (!item.type.classes.contains(h.hunterClass)) return [_sellGear(h, item)];
    h.stash.add(item);
    final worn = _equipFromStash(h);
    final outcome = worn.contains(item) ? GearOutcome.equipped : GearOutcome.stashed;
    final overflow = _trimStash(h);
    // Chính món vừa nhặt có thể bị bán luôn nếu kho đầy và nó yếu nhất.
    if (overflow.any((d) => d.item == item)) return overflow;
    return [GearDrop(hunter: h, item: item, outcome: outcome), ...overflow];
  }

  /// Quest thành công: mỗi hunter sống sót có chút cơ hội nhặt 1 món trang bị (cấp theo tier).
  List<GearDrop> _rollGearDrops(Quest quest, QuestResult result) {
    if (!result.success) return const [];
    final drops = <GearDrop>[];
    for (final h in result.levelUps.keys) {
      if (_random.nextDouble() >= GameConfig.equipmentDropChance[quest.tier]!) continue;
      final type = ItemType.values[_random.nextInt(ItemType.values.length)];
      drops.addAll(receiveGear(h, _equipmentFactory.make(_nextId++, type, quest.tier.materialGrade)));
    }
    return drops;
  }

  /// Hunter hy sinh: đồ đang mặc hư luôn; guild mua lại đồ trong kho riêng với 80% giá (đủ tiền tới đâu mua tới đó).
  @visibleForTesting
  EstateSale settleEstate(Hunter h) {
    final destroyed = h.equipment.values.toList();
    h.equipment.clear();
    final bought = <Equipment>[];
    final lost = <Equipment>[];
    var paid = 0;
    for (final item in h.stash) {
      final price = (item.price * GameConfig.estateBuybackRate).round();
      if (gold >= price) {
        gold -= price;
        paid += price;
        shopStock.add(item);
        bought.add(item);
      } else {
        lost.add(item);
      }
    }
    h.stash.clear();
    return EstateSale(hunter: h, destroyed: destroyed, bought: bought, paid: paid, lost: lost);
  }

  List<ExpeditionReport> _returnExpeditions() {
    final due = expeditions.where((e) => e.returnAt <= now).toList();
    final reports = <ExpeditionReport>[];
    for (final e in due) {
      expeditions.remove(e);
      final result = _resolver.resolve(e.quest, e.party);
      final survivors = result.levelUps.keys.toList();
      final guildShare = (result.gold * GameConfig.questTaxRate).round();
      final hunterShareEach = survivors.isEmpty ? 0 : (result.gold - guildShare) ~/ survivors.length;
      gold += guildShare;
      for (final h in survivors) {
        h.gold += hunterShareEach;
      }
      final questReputation = GameConfig.questReputation[e.quest.tier]! *
          (e.quest.isGathering ? GameConfig.gatheringReputationRate : 1);
      final reputationChange =
          (result.success ? questReputation : -questReputation * GameConfig.failReputationRate).round() -
          result.deaths.length * GameConfig.deathReputationLoss +
          (e.quest.isRoyal && result.success ? GameConfig.royalReputation : 0);
      _addReputation(reputationChange);
      final blueprint = result.success ? _rollBlueprintDrop(e.quest.tier) : null;
      for (final h in e.party) {
        h.onQuest = false;
      }
      final estates = _applyBattle(e.quest, result);
      // Hạ được kẻ phản bội: hắn không quay lại nữa.
      if (e.quest.isRenegade && result.success) exiles.removeWhere((h) => h.id == e.quest.renegadeId);
      final report = ExpeditionReport(
        blueprint: blueprint,
        quest: e.quest,
        party: e.party,
        result: result,
        guildShare: guildShare,
        hunterShareEach: hunterShareEach,
        reputation: reputationChange,
        gearDrops: [
          ..._rollGearDrops(e.quest, result),
          if (e.quest.isRoyal && result.success) ..._royalReward(result),
        ],
        estates: estates,
      );
      _today.record(report);
      reports.add(report);
    }
    return reports;
  }

  /// Quest tier B trở lên có tỉ lệ rơi bản vẽ (loại đồ guild chưa có, cấp theo tier); đội mang về cho guild.
  Blueprint? _rollBlueprintDrop(QuestTier tier) {
    final chance = GameConfig.blueprintDropChance[tier] ?? 0;
    if (_random.nextDouble() >= chance) return null;
    final missing = BlueprintInfo.ofGrade(tier.materialGrade).where((b) => !blueprints.contains(b)).toList();
    if (missing.isEmpty) return null;
    final b = missing[_random.nextInt(missing.length)];
    blueprints.add(b);
    return b;
  }

  /// Quest thăng hạng: tạo cho hunter vừa chạm trần fame, bỏ quest của hunter đã chết.
  /// Trả về những hunter vừa có quest thăng hạng mới.
  List<Hunter> _updatePromotions() {
    final alive = {for (final h in hunters) h.id: h};
    quests.removeWhere((q) => q.isPromotion && !(alive[q.promotionFor]?.canPromote ?? false));
    final pending = {for (final q in [...quests, ...expeditions.map((e) => e.quest)]) ?q.promotionFor};
    final created = <Hunter>[];
    for (final h in hunters) {
      if (!h.canPromote || pending.contains(h.id)) continue;
      quests.insert(0, _questGenerator.generatePromotion(_nextId++, h));
      created.add(h);
    }
    return created;
  }

  /// Quest thăng hạng đang chờ của hunter này (nếu có).
  Quest? promotionQuestOf(Hunter h) => quests.where((q) => q.promotionFor == h.id).firstOrNull;

  void _fillBoard() {
    while (quests.where((q) => !q.isSpecial).length < GameConfig.boardSize) {
      final q = _questGenerator.generate(_nextId++, maxTier: rank.maxQuestTier);
      quests.add(isMutation ? q.mutate() : q);
    }
  }

  // ---------------- Hiệp hội ----------------

  /// Giá phát giấy mời (miễn phí trong tuần có làn sóng nhập cư).
  int get invitationCost => freeInvitations ? 0 : GameConfig.invitationCost;

  bool get canInvite => gold >= invitationCost;

  /// Phát giấy mời: một nhóm hunter mới đến thị trấn, thay nhóm cũ.
  void sendInvitations() {
    if (!canInvite) return;
    gold -= invitationCost;
    candidates
      ..clear()
      ..addAll([
        for (var i = 0; i < GameConfig.invitationSize; i++)
          _hunterFactory.create(_nextId++, rareBonus: rank.rareHunterBonus, rareRate: rareRate),
      ]);
    notifyListeners();
  }

  bool canHire(Hunter candidate) => gold >= candidate.rarity.joinFee;

  void hire(Hunter candidate) {
    if (!candidates.contains(candidate) || !canHire(candidate)) return;
    gold -= candidate.rarity.joinFee;
    candidates.remove(candidate);
    hunters.add(candidate);
    notifyListeners();
  }

  // ---------------- Bệnh viện ----------------

  int healNowCost(Hunter h) =>
      ((h.maxHp - h.hp) * GameConfig.healNowGoldPerHp * (isPlague ? GameConfig.plagueHealCostMultiplier : 1)).ceil();

  void admit(Hunter h) {
    if (h.isFullHp || h.onQuest) return;
    h.inHospital = true;
    notifyListeners();
  }

  /// Thị trấn bỏ tiền ra chữa ngay cho hunter.
  void healNow(Hunter h) {
    final cost = healNowCost(h);
    if (gold < cost || h.onQuest) return;
    gold -= cost;
    // Cứu kịp thời hunter đang nguy kịch.
    if (h.hpRatio < GameConfig.rescueHpRatio) _addReputation(GameConfig.rescueReputation);
    h.hp = h.maxHp;
    h.inHospital = false;
    notifyListeners();
  }

  // ---------------- Nhà rèn & tiệm thuốc ----------------

  /// Hàng đang bày bán ở nhà rèn.
  final shopStock = <Equipment>[];

  // ---------------- Thương đoàn & bản vẽ ----------------

  /// Bản vẽ guild đã có: mỗi loại đồ mỗi cấp 1 bản vẽ riêng.
  final blueprints = <Blueprint>{};

  /// Hàng đang bày ở chợ từng khu (nhập mới mỗi tuần).
  final markets = <Location, List<MarketOffer>>{};

  /// Hàng của thương nhân các nước (đổi mới mỗi [GameConfig.foreignRestockDays] ngày).
  final foreignMarkets = <Country, List<MarketOffer>>{};

  /// Nhân viên guild đang đi chợ.
  final caravans = <CaravanTrip>[];

  late final _marketGenerator = MarketGenerator(_random);

  void _restockMarkets() {
    for (final l in Location.regions) {
      markets[l] = _marketGenerator.region(l, () => _nextId++);
    }
  }

  void _restockForeign() {
    for (final c in Country.values) {
      foreignMarkets[c] = _marketGenerator.foreign(c, () => _nextId++);
    }
  }

  /// Ngày hàng nước ngoài đổi mới lần tới.
  int get nextForeignRestock =>
      day + GameConfig.foreignRestockDays - (day - 1) % GameConfig.foreignRestockDays;

  /// Phí đi lại cho nhân viên tới khu [l] và về.
  int caravanFee(Location l) => map.travelTime(Location.town, l) * 2 * GameConfig.caravanFeePerPhase;

  /// Phí đi lại tới nước [c] và về (tính theo ngày đường).
  int foreignFee(Country c) => c.travelDays * 2 * GameConfig.foreignFeePerDay;

  String? _tripError(List<MarketOffer>? stock, List<MarketOffer> goods, int fee) {
    if (goods.isEmpty) return 'Chưa chọn món nào';
    if (caravans.length >= GameConfig.maxCaravans) return 'Tối đa ${GameConfig.maxCaravans} nhân viên đi cùng lúc';
    if (goods.any((o) => !(stock?.contains(o) ?? false))) return 'Hàng không còn ở chợ';
    final total = goods.fold(0, (s, o) => s + o.price) + fee;
    if (gold < total) return 'Cần $total 🪙 (gồm phí đi lại $fee)';
    return null;
  }

  /// Lý do không gửi được nhân viên đi mua [goods] ở [l], hoặc null nếu được.
  String? caravanError(Location l, List<MarketOffer> goods) => _tripError(markets[l], goods, caravanFee(l));

  String? foreignError(Country c, List<MarketOffer> goods) =>
      _tripError(foreignMarkets[c], goods, foreignFee(c));

  CaravanTrip _sendTrip(CaravanTrip trip, List<MarketOffer> stock) {
    gold -= trip.goods.fold(0, (s, o) => s + o.price) + trip.fee;
    stock.removeWhere(trip.goods.contains);
    caravans.add(trip);
    notifyListeners();
    return trip;
  }

  /// Trả tiền trước, nhân viên đi mua; hàng về kho khi nhân viên quay lại.
  CaravanTrip sendCaravan(Location l, List<MarketOffer> goods) {
    final error = caravanError(l, goods);
    if (error != null) throw StateError(error);
    final travel = map.travelTime(Location.town, l);
    return _sendTrip(
      CaravanTrip(
        destination: l,
        goods: List.unmodifiable(goods),
        route: map.path(Location.town, l),
        departAt: now,
        returnAt: now + travel * 2,
        fee: caravanFee(l),
      ),
      markets[l]!,
    );
  }

  /// Cử nhân viên sang nước [c] mua hàng thương nhân nước ngoài.
  CaravanTrip sendForeignCaravan(Country c, List<MarketOffer> goods) {
    final error = foreignError(c, goods);
    if (error != null) throw StateError(error);
    return _sendTrip(
      CaravanTrip(
        country: c,
        goods: List.unmodifiable(goods),
        route: const [],
        departAt: now,
        returnAt: now + c.travelDays * 2 * DayPhase.values.length,
        fee: foreignFee(c),
      ),
      foreignMarkets[c]!,
    );
  }

  List<CaravanTrip> _returnCaravans() {
    final due = caravans.where((c) => c.returnAt <= now).toList();
    for (final trip in due) {
      caravans.remove(trip);
      trip.goods.forEach(_receive);
    }
    return due;
  }

  /// Nhận hàng vào kho: đồ lên nhà rèn, bản vẽ vào sổ, nguyên liệu vào kho.
  void _receive(MarketOffer o) {
    if (o.item case final item?) shopStock.add(item);
    if (o.blueprint case final b?) blueprints.add(b);
    if (o.material case (final resource, final grade, final quantity)?) {
      materials[(resource, grade)] = materialCount(resource, grade) + quantity;
    }
  }

  // ---------------- Sự kiện đầu tuần ----------------

  /// Sự kiện của tuần hiện tại (null nếu tuần này yên bình).
  WeeklyEvent? event;

  bool get isPlague => event?.type == WeeklyEventType.plague;
  bool get isWeather => event?.type == WeeklyEventType.weather && event!.activeOn(day);
  bool get isInflation => event?.type == WeeklyEventType.inflation && event!.activeOn(day);

  /// Số buổi hunter đi từ thị trấn tới [l] nếu xuất phát bây giờ (thời tiết cực đoan làm chậm 30%).
  int travelTime(Location l) {
    final base = map.travelTime(Location.town, l);
    return isWeather ? (base / (1 - GameConfig.weatherSlowdown)).ceil() : base;
  }

  /// Giá guild trả cho 1 lô nguyên liệu lúc này (lạm phát làm tăng giá).
  int lotPrice(MaterialLot lot) => lot.price * (isInflation ? GameConfig.inflationPriceMultiplier : 1);

  /// Thời tiết cực đoan: tiền nhu yếu phẩm mỗi sáng của 1 hunter.
  int provisionCost(Hunter h) => GameConfig.weatherProvisionBase + h.level * GameConfig.weatherProvisionPerLevel;

  /// Mỗi sáng thời tiết xấu, hunter ở thị trấn tự trả tiền ăn uống (tiền ra khỏi thị trấn). Trả về tổng đã trả.
  int _payProvisions() {
    if (!isWeather) return 0;
    var total = 0;
    for (final h in hunters.where((h) => !h.onQuest)) {
      final paid = min(h.gold, provisionCost(h));
      h.gold -= paid;
      total += paid;
    }
    return total;
  }
  bool get freeInvitations => event?.type == WeeklyEventType.immigration;

  /// Thương nhân chỉ ở lại đúng ngày đầu tuần.
  bool get merchantHere => event?.type == WeeklyEventType.merchant && event!.startDay == day;

  bool get isWeekStart => (day - 1) % GameConfig.weekDays == 0;

  /// Sáng đầu tuần: chợ các khu nhập hàng mới, bốc sự kiện (từ tuần thứ 2).
  WeeklyEvent? _startWeek() {
    if (!isWeekStart) return null;
    _restockMarkets();
    event = null;
    _renegadesReturn();
    if (day < GameConfig.firstEventDay) return null;
    // Chỉ bốc sự kiện đủ điều kiện (vd. cần đủ hunter rảnh để viễn chinh, có người để tố giác).
    final idle = hunters.where((h) => h.isAvailable).toList();
    final eligible = WeeklyEventType.values.where(
      (t) => switch (t) {
        WeeklyEventType.royalAid => idle.length >= GameConfig.royalPartySize,
        WeeklyEventType.traitor => idle.isNotEmpty,
        _ => true,
      },
    );
    final type = pickWeighted(eligible.toList(), (t) => t.weight, _random);
    final monsters = Location.monsterForest.monsters;
    final e = WeeklyEvent(
      targetId: type == WeeklyEventType.traitor ? idle[_random.nextInt(idle.length)].id : null,
      type: type,
      startDay: day,
      siegeDay: day + GameConfig.siegeDayOffset,
      siegeMonster: monsters[_random.nextInt(monsters.length)],
      merchantOffers: type == WeeklyEventType.merchant ? _marketGenerator.merchant(() => _nextId++) : null,
      // Lạm phát chỉ kéo dài 1–2 ngày; các sự kiện khác cả tuần.
      endDay: type == WeeklyEventType.inflation ? day + _random.nextInt(GameConfig.inflationMaxDays) : null,
      reputationPenalty: type == WeeklyEventType.rumor ? (reputation * GameConfig.rumorReputationLoss).round() : 0,
      drought: _random.nextBool(),
    );
    if (type == WeeklyEventType.immigration) {
      candidates
        ..clear()
        ..addAll([
          for (var i = 0; i < GameConfig.invitationSize; i++)
            _hunterFactory.create(_nextId++, rareBonus: rank.rareHunterBonus, rareRate: rareRate, young: true),
        ]);
    }
    event = e;
    return e;
  }

  // ---------------- Sự kiện có lựa chọn ----------------

  /// Quái đang biến dị (đã chấp nhận thí nghiệm của pháp sư, tới hết tuần).
  bool get isMutation => event?.type == WeeklyEventType.experiment && event!.choice == true && event!.activeOn(day);

  /// Hunter đang bị tố giác (chờ quyết định) — không được giao quest.
  Hunter? get accused => event?.type == WeeklyEventType.traitor && event!.awaitingChoice
      ? hunters.where((h) => h.id == event!.targetId).firstOrNull
      : null;

  /// Những hunter sẽ đi viễn chinh nếu chọn A: 3 người mạnh nhất đang rảnh.
  List<Hunter> get royalCandidates {
    final idle = hunters.where((h) => h.isAvailable).toList()..sort((a, b) => b.power.compareTo(a.power));
    return idle.take(GameConfig.royalPartySize).toList();
  }

  /// Lý do không chọn được phương án [a], hoặc null.
  String? eventChoiceError(bool a) {
    final e = event;
    if (e == null || !e.awaitingChoice) return 'Không có gì để chọn';
    if (a && e.type == WeeklyEventType.royalAid && royalCandidates.length < GameConfig.royalPartySize) {
      return 'Cần ${GameConfig.royalPartySize} hunter đang rảnh';
    }
    return null;
  }

  /// Chọn phương án A ([a] = true) hoặc B cho sự kiện tuần này. Trả về mô tả kết quả.
  String chooseEvent(bool a) {
    final error = eventChoiceError(a);
    if (error != null) throw StateError(error);
    final e = event!..choice = a;
    final outcome = switch (e.type) {
      WeeklyEventType.royalAid => a ? _sendRoyalExpedition() : _refuseKing(),
      WeeklyEventType.experiment => a ? _acceptExperiment() : 'Pháp sư điên bỏ sang thị trấn khác.',
      WeeklyEventType.traitor => a ? _expelTraitor() : _forgiveTraitor(),
      _ => '',
    };
    // Kẻ phản bội dắt quái về có thể đã thay sự kiện bằng trận công thành.
    (event ?? e).outcome = outcome;
    notifyListeners();
    return outcome;
  }

  String _refuseKing() {
    _addReputation(-GameConfig.royalRefusePenalty);
    return 'Bạn từ chối Đức Vua: danh tiếng -${GameConfig.royalRefusePenalty} vì "thiếu trung thành".';
  }

  String _sendRoyalExpedition() {
    final party = royalCandidates;
    final tier = rank.maxQuestTier;
    final quest = Quest(
      id: _nextId++,
      location: Location.empire,
      tier: tier,
      monster: Location.empire.monsters[_random.nextInt(Location.empire.monsters.length)],
      isHorde: false,
      isGroup: true,
      minParty: GameConfig.royalPartySize,
      maxParty: GameConfig.royalPartySize,
      difficulty: tier.difficulty * GameConfig.royalDifficultyFactor,
      gold: 0,
      exp: tier.exp * 2,
      isRoyal: true,
    );
    const duration = GameConfig.royalDays * 3; // 3 buổi mỗi ngày
    expeditions.add(
      Expedition(
        quest: quest,
        party: List.unmodifiable(party),
        route: map.path(Location.town, Location.empire),
        departAt: now,
        arriveAt: now + duration ~/ 2,
        returnAt: now + duration,
      ),
    );
    for (final h in party) {
      h.onQuest = true;
    }
    return '${party.map((h) => h.name).join(', ')} lên đường viễn chinh cho Đức Vua, về sau ${GameConfig.royalDays} ngày.';
  }

  /// Viễn chinh thắng (danh tiếng khổng lồ đã cộng lúc về) + 1 vũ khí Thần khí độc quyền cho người mạnh nhất còn sống.
  List<GearDrop> _royalReward(QuestResult result) {
    final survivors = result.levelUps.keys.toList()..sort((a, b) => b.power.compareTo(a.power));
    if (survivors.isEmpty) return const [];
    final h = survivors.first;
    final weapons = ItemType.values.where((t) => t.slot != EquipSlot.armor && t.classes.contains(h.hunterClass));
    final type = weapons.elementAt(_random.nextInt(weapons.length));
    final base = _equipmentFactory.make(_nextId++, type, ItemGrade.divine);
    final legendary = Equipment(
      id: base.id,
      type: type,
      grade: ItemGrade.divine,
      bonus: base.bonus * 1.25,
      quality: base.quality * 1.25,
      price: (base.price * 1.25).round(),
    );
    return receiveGear(h, legendary);
  }

  String _acceptExperiment() {
    for (var i = 0; i < quests.length; i++) {
      if (!quests[i].isSpecial) quests[i] = quests[i].mutate();
    }
    return 'Quái ngoài bản đồ biến dị tới hết ngày ${event!.endDay}: mạnh hơn '
        '${((GameConfig.mutationStrength - 1) * 100).round()}%, thưởng ×${GameConfig.mutationReward}.';
  }

  Hunter? get _traitor => hunters.where((h) => h.id == event!.targetId).firstOrNull;

  String _expelTraitor() {
    final h = _traitor;
    if (h == null) return 'Kẻ bị tố giác đã không còn ở thị trấn.';
    _exile(h);
    return '${h.name} (hạng ${h.rank.label}) bị trục xuất. Hắn có thể quay lại báo thù...';
  }

  void _exile(Hunter h) {
    hunters.remove(h);
    exiles.add(h);
    quests.removeWhere((q) => q.promotionFor == h.id);
  }

  String _forgiveTraitor() {
    final h = _traitor;
    if (h == null) return 'Kẻ bị tố giác đã không còn ở thị trấn.';
    if (_random.nextDouble() < GameConfig.traitorRedeemChance) {
      const k = GameConfig.traitorRedeemStatBoost;
      final ratio = h.hpRatio;
      h
        ..basePower *= k
        ..baseMaxHp *= k
        ..basePhysRes *= k
        ..baseMagicRes *= k
        ..baseAgility *= k;
      h.hp = h.maxHp * ratio;
      return '${h.name} cải tà quy chính! Chỉ số gốc +${((k - 1) * 100).round()}%.';
    }
    // Phản bội: bỏ trốn và dắt quái về công thành.
    _exile(h);
    final old = event!;
    final monsters = Location.monsterForest.monsters;
    event = WeeklyEvent(
      type: WeeklyEventType.siege,
      startDay: day,
      endDay: old.endDay,
      siegeDay: day + GameConfig.traitorSiegeDelay,
      siegeMonster: monsters[_random.nextInt(monsters.length)],
    );
    return '${h.name} phản bội, bỏ trốn và dắt quái về! Quái sẽ công thành vào đêm ngày ${event!.siegeDay}.';
  }

  /// Đầu tuần: kẻ bị trục xuất có thể quay lại làm boss phụ (quest đặc biệt trên bảng).
  void _renegadesReturn() {
    for (final h in exiles) {
      if (quests.any((q) => q.renegadeId == h.id) || expeditions.any((e) => e.quest.renegadeId == h.id)) continue;
      if (_random.nextDouble() >= GameConfig.renegadeReturnChance) continue;
      final tier = h.rank;
      final locations = Location.regions.where((l) => l.supports(tier)).toList();
      final location = locations[_random.nextInt(locations.length)];
      quests.insert(
        0,
        Quest(
          id: _nextId++,
          location: location,
          tier: tier,
          monster: MonsterType.demon,
          isHorde: false,
          isGroup: true,
          minParty: tier.index >= QuestTier.a.index ? 3 : 2,
          maxParty: GameConfig.maxParty,
          difficulty: tier.difficulty * GameConfig.renegadeDifficultyFactor,
          gold: (tier.gold * GameConfig.renegadeRewardFactor).round(),
          exp: tier.exp * 2,
          renegadeId: h.id,
          renegadeName: h.name,
        ),
      );
    }
  }

  /// Sáng hôm sau mà chưa chọn thì coi như chọn B. Trả về kết quả (nếu có).
  String? _autoChoose() {
    final e = event;
    if (e == null || !e.awaitingChoice || day <= e.startDay) return null;
    return chooseEvent(false);
  }

  void buyFromMerchant(MarketOffer o) {
    if (!merchantHere || !event!.merchantOffers.contains(o) || gold < o.price) return;
    gold -= o.price;
    event!.merchantOffers.remove(o);
    _receive(o);
    notifyListeners();
  }

  /// Cử / rút hunter khỏi đội thủ thành.
  void toggleDefender(Hunter h) {
    final e = event;
    if (e == null || e.type != WeeklyEventType.siege || e.siegeResolved) return;
    if (!e.defenderIds.remove(h.id)) e.defenderIds.add(h.id);
    notifyListeners();
  }

  /// Trận thủ thành: hunter được cử đang ở thị trấn (không đi quest, không nằm viện) đánh 1 bầy quái.
  SiegeReport _resolveSiege() {
    final e = event!..siegeResolved = true;
    final defenders = hunters.where((h) => e.defenderIds.contains(h.id) && h.isAvailable).toList();
    final tier = rank.maxQuestTier;
    final quest = Quest(
      id: _nextId++,
      location: Location.town,
      tier: tier,
      monster: e.siegeMonster,
      isHorde: true,
      isGroup: true,
      minParty: 1,
      maxParty: GameConfig.maxParty,
      difficulty: tier.difficulty * GameConfig.siegeDifficultyFactor,
      gold: 0,
      exp: tier.exp,
    );
    final result = defenders.isEmpty ? null : _resolver.resolve(quest, defenders);
    final estates = result == null ? const <EstateSale>[] : _applyBattle(quest, result);
    final won = result?.success ?? false;
    final repairCost = won ? 0 : min(gold, GameConfig.siegeRepairCostPerRank * (rank.index + 1));
    final reputationChange = won ? GameConfig.siegeWinReputation : -GameConfig.siegeFailReputation;
    gold -= repairCost;
    _addReputation(reputationChange);
    return SiegeReport(defenders: defenders, result: result, repairCost: repairCost, reputation: reputationChange,
      estates: estates,
    );
  }

  /// Hunter đang ở thị trấn tự mua đồ nâng cấp, rồi mua bình máu bằng một phần tiền còn lại.
  List<Purchase> _hunterShopping() {
    final purchases = <Purchase>[];
    final shoppers = hunters.where((h) => !h.onQuest).toList()..sort((a, b) => b.gold.compareTo(a.gold));
    for (final h in shoppers) {
      // Ưu tiên mặc đồ tốt hơn có sẵn trong kho riêng (không tốn tiền).
      for (final item in _equipFromStash(h)) {
        purchases.add(Purchase(hunter: h, itemName: 'Lấy từ kho riêng: ${item.name}', price: 0));
      }
      for (
        var item = ShoppingAdvisor.bestUpgrade(h, shopStock);
        item != null;
        item = ShoppingAdvisor.bestUpgrade(h, shopStock)
      ) {
        shopStock.remove(item);
        _sell(h, item.price);
        for (final old in h.equip(item)) {
          h.gold += old.tradeInValue;
        }
        purchases.add(Purchase(hunter: h, itemName: item.name, price: item.price));
      }

      for (final item in h.equipment.values) {
        if (!item.canRepair || item.conditionRatio >= GameConfig.repairThreshold) continue;
        final cost = item.repairCost;
        if (h.gold < cost) continue;
        _sell(h, cost);
        item.repair();
        purchases.add(Purchase(hunter: h, itemName: 'Sửa ${item.name}', price: cost));
      }

      var budget = (h.gold * GameConfig.potionBudgetRate).floor();
      while (h.potions.length < GameConfig.maxPotions) {
        final potion = Potion.values.where((p) => p.price <= budget && (potionStock[p] ?? 0) > 0).lastOrNull;
        if (potion == null) break;
        budget -= potion.price;
        _sell(h, potion.price);
        potionStock[potion] = potionStock[potion]! - 1;
        h.potions.add(potion);
        purchases.add(Purchase(hunter: h, itemName: potion.label, price: potion.price));
      }
    }
    return purchases;
  }

  /// Chuyển tiền từ ví hunter sang guild.
  void _sell(Hunter h, int price) {
    h.gold -= price;
    gold += price;
    _today.sales += price;
  }

  // ---------------- Thu mua & chế tạo ----------------

  int materialCount(Resource resource, ItemGrade grade) => materials[(resource, grade)] ?? 0;

  /// Guild trả tiền vào ví hunter để lấy lô nguyên liệu.
  bool buyLot(MaterialLot lot) {
    final price = lotPrice(lot);
    if (!materialLots.contains(lot) || gold < price) return false;
    gold -= price;
    lot.hunter.gold += price;
    final key = (lot.resource, lot.grade);
    materials[key] = materialCount(lot.resource, lot.grade) + lot.quantity;
    materialLots.remove(lot);
    notifyListeners();
    return true;
  }

  /// Chế trang bị cần bản vẽ đúng cấp; bình máu thì không.
  bool hasBlueprintFor(Recipe recipe, ItemGrade grade) =>
      recipe.item == null || blueprints.contains((type: recipe.item!, grade: grade));

  bool canCraft(Recipe recipe, ItemGrade grade) =>
      hasBlueprintFor(recipe, grade) &&
      recipe.ingredients.entries.every((e) => materialCount(e.key, grade) >= e.value);

  /// Chế tạo: trang bị vào kho nhà rèn, bình máu vào tiệm thuốc.
  String? craft(Recipe recipe, ItemGrade grade) {
    if (!canCraft(recipe, grade)) return null;
    for (final MapEntry(key: resource, value: amount) in recipe.ingredients.entries) {
      materials[(resource, grade)] = materialCount(resource, grade) - amount;
    }
    final String made;
    if (recipe.item case final type?) {
      final item = _equipmentFactory.make(_nextId++, type, grade);
      shopStock.add(item);
      made = item.name;
    } else {
      final potion = Recipe.potionFor(grade);
      potionStock[potion] = (potionStock[potion] ?? 0) + 1;
      made = potion.label;
    }
    notifyListeners();
    return made;
  }

  // ---------------- Thanh lý ----------------

  int potionSellPrice(Potion p) => (p.price * GameConfig.potionSellRate).round();

  int materialSellPrice(Resource resource, ItemGrade grade) =>
      (resource.unitPrice(grade) * GameConfig.materialSellRate).round();

  /// Bán lại cho thương lái 1 món đang bày ở nhà rèn.
  void sellStock(Equipment item) {
    if (!shopStock.remove(item)) return;
    gold += item.tradeInValue;
    notifyListeners();
  }

  void sellPotion(Potion p) {
    final count = potionStock[p] ?? 0;
    if (count == 0) return;
    potionStock[p] = count - 1;
    gold += potionSellPrice(p);
    notifyListeners();
  }

  /// Bán hết nguyên liệu loại này trong kho.
  void sellMaterial(Resource resource, ItemGrade grade) {
    final count = materialCount(resource, grade);
    if (count == 0) return;
    materials.remove((resource, grade));
    gold += materialSellPrice(resource, grade) * count;
    notifyListeners();
  }

  // ---------------- Nhà cầu nguyện ----------------

  int prayerCost(Hunter h) => GameConfig.prayerBaseCost + h.level * GameConfig.prayerCostPerLevel;

  bool canRevive(Hunter h) => h.age <= GameConfig.reviveMaxAge;

  /// Cầu nguyện cho hunter đã chết. Trả về true nếu hồi sinh thành công.
  bool pray(Hunter h) {
    final cost = prayerCost(h);
    if (!fallen.contains(h) || !canRevive(h) || gold < cost) return false;
    gold -= cost;
    final revived = _random.nextDouble() < GameConfig.reviveChance;
    if (revived) {
      fallen.remove(h);
      hunters.add(h);
      h.hp = h.maxHp * GameConfig.reviveHpRatio;
      h.inHospital = true;
      _addReputation(GameConfig.reviveReputation);
    }
    notifyListeners();
    return revived;
  }
}

/// Gom số liệu trong ngày để tổng kết buổi đêm.
class _DayTracker {
  _DayTracker(this.goldStart);

  _DayTracker.fromJson(Map<String, dynamic> j)
    : goldStart = j['goldStart'] as int,
      income = j['income'] as int,
      hunterEarnings = j['hunterEarnings'] as int,
      sales = j['sales'] as int,
      stocks = j['stocks'] as int? ?? 0,
      gatherSucceeded = j['gatherSucceeded'] as int? ?? 0,
      succeeded = j['succeeded'] as int,
      failed = j['failed'] as int,
      deaths = j['deaths'] as int,
      levelUps = j['levelUps'] as int;

  Map<String, dynamic> toJson() => {
    'goldStart': goldStart,
    'income': income,
    'hunterEarnings': hunterEarnings,
    'sales': sales,
    'stocks': stocks,
    'gatherSucceeded': gatherSucceeded,
    'succeeded': succeeded,
    'failed': failed,
    'deaths': deaths,
    'levelUps': levelUps,
  };

  final int goldStart;
  int income = 0;
  int hunterEarnings = 0;
  int sales = 0;

  /// Dòng tiền ròng từ chứng khoán (bán + cổ tức − mua).
  int stocks = 0;
  int gatherSucceeded = 0;
  int succeeded = 0;
  int failed = 0;
  int deaths = 0;
  int levelUps = 0;

  void record(ExpeditionReport r) {
    income += r.guildShare;
    hunterEarnings += r.hunterShareEach * r.result.levelUps.length;
    r.result.success ? succeeded++ : failed++;
    if (r.result.success && r.quest.isGathering) gatherSucceeded++;
    deaths += r.result.deaths.length;
    levelUps += r.result.levelUps.values.fold(0, (a, b) => a + b);
  }

  DailyReport finish({required int day, required int goldEnd, required int hunterCount, required int reputation}) =>
      DailyReport(
        reputation: reputation,
        day: day,
        goldStart: goldStart,
        goldEnd: goldEnd,
        income: income,
        hunterEarnings: hunterEarnings,
        sales: sales,
        stocks: stocks,
        succeeded: succeeded,
        failed: failed,
        deaths: deaths,
        levelUps: levelUps,
        hunterCount: hunterCount,
      );
}
