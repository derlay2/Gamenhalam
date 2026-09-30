import '../logic/quest_resolver.dart';
import '../logic/shopping.dart';
import 'hunter.dart';
import 'quest.dart';
import 'stock.dart';
import 'equipment.dart';
import 'events.dart';
import 'town.dart';
import 'trade.dart';
import 'world_map.dart';

enum DayPhase {
  morning('Sáng'),
  noon('Trưa'),
  night('Đêm');

  const DayPhase(this.label);
  final String label;
}

/// Thời điểm tính bằng số buổi kể từ sáng ngày 1 (0 = Ngày 1 · Sáng).
int phaseIndex(int day, DayPhase phase) => (day - 1) * DayPhase.values.length + phase.index;

(int, DayPhase) phaseAt(int index) =>
    (index ~/ DayPhase.values.length + 1, DayPhase.values[index % DayPhase.values.length]);

String describePhase(int index) {
  final (day, phase) = phaseAt(index);
  return 'Ngày $day · ${phase.label}';
}

enum ExpeditionStage {
  outbound('Đang đi tới'),
  fighting('Đang chiến đấu ở'),
  returning('Đang trở về từ');

  const ExpeditionStage(this.label);
  final String label;
}

/// Một đội đang đi làm nhiệm vụ: đi theo [route] tới khu quest, đánh 1 buổi, rồi quay về.
class Expedition {
  const Expedition({
    required this.quest,
    required this.party,
    required this.route,
    required this.departAt,
    required this.arriveAt,
    required this.returnAt,
  });

  factory Expedition.fromJson(Map<String, dynamic> j, Hunter Function(int id) hunterById) => Expedition(
    quest: Quest.fromJson(j['quest'] as Map<String, dynamic>),
    party: List.unmodifiable([for (final id in j['party'] as List) hunterById(id as int)]),
    route: [for (final name in j['route'] as List) Location.values.byName(name as String)],
    departAt: j['departAt'] as int,
    arriveAt: j['arriveAt'] as int,
    returnAt: j['returnAt'] as int,
  );

  Map<String, dynamic> toJson() => {
    'quest': quest.toJson(),
    'party': [for (final h in party) h.id],
    'route': [for (final l in route) l.name],
    'departAt': departAt,
    'arriveAt': arriveAt,
    'returnAt': returnAt,
  };

  final Quest quest;
  final List<Hunter> party;

  /// Đường đi từ thị trấn tới khu quest.
  final List<Location> route;

  /// Mốc thời gian (xem [phaseIndex]): xuất phát, tới nơi & chiến đấu, về tới thị trấn.
  final int departAt;
  final int arriveAt;
  final int returnAt;

  int get travelTime => arriveAt - departAt;

  ExpeditionStage stageAt(int now) => now < arriveAt
      ? ExpeditionStage.outbound
      : now == arriveAt
      ? ExpeditionStage.fighting
      : ExpeditionStage.returning;

  /// Số buổi đã đi được dọc theo [route] tính từ thị trấn.
  double distanceAlongRoute(int now) => switch (stageAt(now)) {
    ExpeditionStage.outbound => (now - departAt).toDouble(),
    ExpeditionStage.fighting => travelTime.toDouble(),
    ExpeditionStage.returning => (travelTime - (now - arriveAt)).toDouble(),
  };

  String statusAt(int now) {
    final stage = stageAt(now);
    final left = stage == ExpeditionStage.outbound ? arriveAt - now : returnAt - now;
    return '${stage.label} ${quest.location.label}'
        '${stage == ExpeditionStage.fighting ? '' : ' (còn $left buổi)'} · về ${describePhase(returnAt)}';
  }
}

/// Kết quả một đội trở về.
class ExpeditionReport {
  const ExpeditionReport({
    required this.quest,
    required this.party,
    required this.result,
    required this.guildShare,
    required this.hunterShareEach,
    this.reputation = 0,
    this.blueprint,
    this.gearDrops = const [],
    this.estates = const [],
  });

  /// Trang bị hunter nhặt được và đã xử lý thế nào.
  final List<GearDrop> gearDrops;

  /// Đồ của hunter hy sinh.
  final List<EstateSale> estates;

  /// Bản vẽ đội nhặt được mang về cho guild (quest tier B trở lên).
  final Blueprint? blueprint;

  final Quest quest;
  final List<Hunter> party;
  final QuestResult result;

  /// Phần guild thu (20%).
  final int guildShare;

  /// Phần mỗi hunter sống sót nhận vào ví.
  final int hunterShareEach;

  /// Danh tiếng thị trấn thay đổi do chuyến này.
  final int reputation;
}

/// Tổng kết cuối ngày.
class DailyReport {
  const DailyReport({
    required this.day,
    required this.goldStart,
    required this.goldEnd,
    required this.income,
    required this.hunterEarnings,
    required this.sales,
    required this.succeeded,
    required this.failed,
    required this.deaths,
    required this.levelUps,
    required this.hunterCount,
    this.reputation = 0,
    this.stocks = 0,
  });

  factory DailyReport.fromJson(Map<String, dynamic> j) => DailyReport(
    reputation: j['reputation'] as int? ?? 0,
    stocks: j['stocks'] as int? ?? 0,
    day: j['day'] as int,
    goldStart: j['goldStart'] as int,
    goldEnd: j['goldEnd'] as int,
    income: j['income'] as int,
    hunterEarnings: j['hunterEarnings'] as int,
    sales: j['sales'] as int,
    succeeded: j['succeeded'] as int,
    failed: j['failed'] as int,
    deaths: j['deaths'] as int,
    levelUps: j['levelUps'] as int,
    hunterCount: j['hunterCount'] as int,
  );

  Map<String, dynamic> toJson() => {
    'day': day,
    'goldStart': goldStart,
    'goldEnd': goldEnd,
    'income': income,
    'hunterEarnings': hunterEarnings,
    'sales': sales,
    'succeeded': succeeded,
    'failed': failed,
    'deaths': deaths,
    'levelUps': levelUps,
    'hunterCount': hunterCount,
    'reputation': reputation,
    'stocks': stocks,
  };

  final int day;
  final int goldStart;
  final int goldEnd;

  /// Phần 20% guild thu từ nhiệm vụ.
  final int income;

  /// Tổng vàng hunter nhận vào ví (80%).
  final int hunterEarnings;

  /// Doanh thu bán trang bị, bình máu, chữa trị cho hunter.
  final int sales;
  final int succeeded;
  final int failed;
  final int deaths;
  final int levelUps;
  final int hunterCount;

  /// Danh tiếng thị trấn cuối ngày.
  final int reputation;

  /// Dòng tiền ròng từ chứng khoán (bán + cổ tức − mua).
  final int stocks;

  /// Vàng guild chi ra (giấy mời, phí nhập thị trấn, cầu nguyện, làm mới bảng...).
  int get spent => goldStart + income + sales + stocks - goldEnd;
}

/// Những gì xảy ra khi chuyển sang một buổi mới.
class PhaseReport {
  const PhaseReport({
    required this.day,
    required this.phase,
    this.returns = const [],
    this.healed = const {},
    this.discharged = const [],
    this.purchases = const [],
    this.daily,
    this.yesterday,
    this.rankBefore,
    this.rankAfter,
    this.gameOver,
    this.newPromotions = const [],
    this.caravans = const [],
    this.newEvent,
    this.siege,
    this.provisions = 0,
    this.eventOutcome,
    this.stocks,
  });

  /// Phiên chứng khoán buổi sáng.
  final StockDayReport? stocks;

  /// Kết quả sự kiện khi bạn không kịp chọn (tự chọn B sáng hôm sau).
  final String? eventOutcome;

  /// Thời tiết cực đoan: tổng tiền nhu yếu phẩm hunter phải trả sáng nay.
  final int provisions;

  /// Nhân viên guild vừa đi chợ về.
  final List<CaravanTrip> caravans;

  /// Sự kiện tuần mới vừa bắt đầu.
  final WeeklyEvent? newEvent;

  /// Kết quả trận thủ thành đêm nay.
  final SiegeReport? siege;

  /// Hunter vừa chạm trần fame, có quest thăng hạng mới trên bảng.
  final List<Hunter> newPromotions;

  final int day;
  final DayPhase phase;
  final List<ExpeditionReport> returns;

  /// Hạng thị trấn đầu và cuối buổi (để báo lên/xuống hạng).
  final TownRank? rankBefore;
  final TownRank? rankAfter;
  bool get rankChanged => rankBefore != rankAfter;

  final GameOverReason? gameOver;

  /// Buổi sáng: máu bệnh viện đã hồi cho từng hunter.
  final Map<Hunter, double> healed;
  final List<Hunter> discharged;

  /// Số lô nguyên liệu mới các đội vừa mang về (mỗi hunter × mỗi loại là 1 lô).
  int get newLotCount => returns.fold(0, (sum, r) => sum + r.result.loot.values.fold(0, (s, bag) => s + bag.length));

  /// Buổi sáng: hunter ở thị trấn tự mua sắm.
  final List<Purchase> purchases;

  /// Sáng hôm sau: tổng kết ngày vừa qua và ngày trước đó (nếu có).
  final DailyReport? daily;
  final DailyReport? yesterday;
}

/// Hunter xử lý món đồ nhặt được hoặc thừa trong kho riêng thế nào.
enum GearOutcome {
  equipped('mặc luôn'),
  stashed('cất vào kho riêng'),
  soldToGuild('bán cho guild'),
  soldElsewhere('bán cho thương lái (guild không đủ tiền)');

  const GearOutcome(this.label);
  final String label;
}

class GearDrop {
  const GearDrop({required this.hunter, required this.item, required this.outcome, this.price = 0});

  final Hunter hunter;
  final Equipment item;
  final GearOutcome outcome;

  /// Tiền hunter nhận nếu bán.
  final int price;
}

/// Đồ của hunter hy sinh: đồ đang mặc hư luôn, kho riêng guild mua lại.
class EstateSale {
  const EstateSale({
    required this.hunter,
    required this.destroyed,
    required this.bought,
    required this.paid,
    required this.lost,
  });

  final Hunter hunter;
  final List<Equipment> destroyed;

  /// Guild mua lại (vào kho nhà rèn) với tổng giá [paid].
  final List<Equipment> bought;
  final int paid;

  /// Guild không đủ tiền mua nên mất.
  final List<Equipment> lost;
}
