import '../logic/quest_resolver.dart';
import 'enums.dart';
import 'hunter.dart';
import 'day.dart';
import 'trade.dart';

/// Sự kiện ngẫu nhiên mỗi đầu tuần.
enum WeeklyEventType {
  siege(
    '🚨 Quái vật bao vây',
    'Quái từ rừng tràn ra tấn công cổng thành. Hãy cử hunter rảnh rỗi ra thủ thành; '
        'thất bại thì công trình hư hại (tốn tiền sửa) và danh tiếng giảm.',
    weight: 18,
  ),
  plague(
    '🚨 Dịch bệnh tràn lan',
    'Cả tuần: hunter nằm viện hồi phục chậm gấp 3, chữa ngay đắt gấp 3.',
    weight: 14,
  ),
  weather(
    '🌨 Thời tiết cực đoan',
    'Bão tuyết / hạn hán cả tuần: hunter đi đường chậm hơn 30% (quest giao trong tuần mất thêm thời gian). '
        'Quán ăn cạn nguyên liệu, mỗi sáng hunter ở thị trấn phải tự trả tiền nhu yếu phẩm đắt đỏ.',
    weight: 12,
  ),
  inflation(
    '📈 Lạm phát thị trường',
    'Trong 1–2 ngày, giá thu mua nguyên liệu ở Trạm thu mua tăng gấp đôi. Cân nhắc tạm ngừng rèn đồ, '
        'hoặc chấp nhận bù lỗ để giữ nguồn hàng.',
    weight: 10,
  ),
  rumor(
    '🐉 Tin đồn thất thiệt',
    'Tin đồn "Thị trấn sắp bị rồng tấn công" lan khắp nơi: danh tiếng giảm tạm thời (có thể tụt hạng), '
        'hunter hiếm tìm đến giảm 50% cho tới hết tuần.',
    weight: 8,
  ),
  merchant(
    '💰 Thương nhân lang thang',
    'Chỉ hôm nay: bán nguyên liệu Thần khí, trang bị độc quyền và bản vẽ với giá cắt cổ.',
    weight: 20,
  ),
  immigration(
    '💰 Làn sóng nhập cư',
    'Một nhóm tân binh trẻ vừa đến Hiệp hội; phát giấy mời miễn phí cả tuần.',
    weight: 18,
  ),
  royalAid(
    '👑 Yêu cầu viện trợ từ vương quốc',
    'Đức Vua cần 3 hunter mạnh nhất của bạn đi viễn chinh 3 ngày.',
    weight: 8,
    optionA: 'Gửi 3 hunter mạnh nhất đi viễn chinh: thị trấn mất lực lượng, nhưng thắng thì được danh tiếng '
        'khổng lồ và vũ khí Thần khí độc quyền.',
    optionB: 'Từ chối: không mất gì nhưng bị trừ chút danh tiếng vì "thiếu trung thành".',
  ),
  experiment(
    '🧪 Thí nghiệm cấm của Pháp sư',
    'Một pháp sư điên muốn thử bùa chú lên quái vật vùng lân cận.',
    weight: 8,
    optionA: 'Chấp nhận: đến hết tuần, quái ngoài bản đồ biến dị — mạnh hơn 50% nhưng thưởng EXP và vàng gấp đôi.',
    optionB: 'Từ chối: pháp sư bỏ sang thị trấn khác.',
  ),
  traitor(
    '🗡 Hunter sa ngã',
    'Có tin báo một hunter lén trộm tài nguyên của guild và cấu kết với quái vật.',
    weight: 8,
    optionA: 'Trục xuất ngay: an toàn cho thị trấn nhưng mất chiến lực; kẻ bị đuổi có thể quay lại làm boss phụ.',
    optionB: 'Tha thứ và theo dõi: 50% cải tà quy chính (tăng chỉ số), 50% dắt quái về công thành.',
  );

  const WeeklyEventType(this.label, this.description, {required this.weight, this.optionA, this.optionB});
  final String label;
  final String description;
  final int weight;

  /// Sự kiện có lựa chọn: mô tả phương án A / B (null nếu không phải chọn).
  final String? optionA;
  final String? optionB;
  bool get hasChoice => optionA != null;

  bool get isDanger => this != merchant && this != immigration && !hasChoice;
}

class WeeklyEvent {
  WeeklyEvent({
    required this.type,
    required this.startDay,
    this.siegeDay = 0,
    this.siegeMonster = MonsterType.beast,
    List<MarketOffer>? merchantOffers,
    Set<int>? defenderIds,
    this.siegeResolved = false,
    int? endDay,
    this.reputationPenalty = 0,
    this.drought = false,
    this.choice,
    this.targetId,
    this.outcome,
  }) : merchantOffers = merchantOffers ?? [],
       defenderIds = defenderIds ?? {},
       endDay = endDay ?? startDay + 6;

  factory WeeklyEvent.fromJson(Map<String, dynamic> j) => WeeklyEvent(
    type: WeeklyEventType.values.byName(j['type'] as String),
    startDay: j['startDay'] as int,
    siegeDay: j['siegeDay'] as int,
    siegeMonster: MonsterType.values.byName(j['siegeMonster'] as String),
    merchantOffers: [for (final o in j['merchantOffers'] as List) MarketOffer.fromJson(o as Map<String, dynamic>)],
    defenderIds: {for (final id in j['defenderIds'] as List) id as int},
    siegeResolved: j['siegeResolved'] as bool,
    endDay: j['endDay'] as int?,
    reputationPenalty: j['reputationPenalty'] as int? ?? 0,
    drought: j['drought'] as bool? ?? false,
    choice: j['choice'] as bool?,
    targetId: j['targetId'] as int?,
    outcome: j['outcome'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'startDay': startDay,
    'siegeDay': siegeDay,
    'siegeMonster': siegeMonster.name,
    'merchantOffers': [for (final o in merchantOffers) o.toJson()],
    'defenderIds': defenderIds.toList(),
    'siegeResolved': siegeResolved,
    'endDay': endDay,
    'reputationPenalty': reputationPenalty,
    'drought': drought,
    'choice': choice,
    'targetId': targetId,
    'outcome': outcome,
  };

  /// Sự kiện có lựa chọn: true = A, false = B, null = chưa chọn.
  bool? choice;
  bool get awaitingChoice => type.hasChoice && choice == null;

  /// Kẻ phản bội: id hunter bị tố giác.
  final int? targetId;

  /// Kết quả sau khi chọn (để hiện lại trên thẻ sự kiện).
  String? outcome;

  final WeeklyEventType type;
  final int startDay;

  /// Ngày cuối (tính cả ngày đó) sự kiện còn hiệu lực.
  final int endDay;
  bool activeOn(int day) => day >= startDay && day <= endDay;

  /// Tin đồn: danh tiếng bị trừ tạm thời trong lúc sự kiện diễn ra.
  final int reputationPenalty;

  /// Thời tiết: hạn hán (true) hay bão tuyết (false) — chỉ khác tên gọi.
  final bool drought;
  String get weatherLabel => drought ? '☀ Hạn hán' : '🌨 Bão tuyết';

  /// Bao vây: quái tấn công vào đêm ngày này.
  final int siegeDay;
  final MonsterType siegeMonster;

  /// Thương nhân: hàng bày bán (chỉ trong ngày [startDay]).
  final List<MarketOffer> merchantOffers;

  /// Bao vây: hunter được cử thủ thành (chỉ ai còn ở thị trấn, không nằm viện lúc quái đến mới đánh).
  final Set<int> defenderIds;
  bool siegeResolved;
}

/// Kết quả trận thủ thành.
class SiegeReport {
  const SiegeReport({
    required this.defenders,
    required this.result,
    required this.repairCost,
    required this.reputation,
    this.estates = const [],
  });

  /// Đồ của hunter hy sinh khi thủ thành.
  final List<EstateSale> estates;

  final List<Hunter> defenders;

  /// null nếu không có ai thủ thành (thua luôn).
  final QuestResult? result;
  bool get won => result?.success ?? false;

  /// Vàng guild bỏ ra sửa công trình (0 nếu thắng).
  final int repairCost;
  final int reputation;
}
