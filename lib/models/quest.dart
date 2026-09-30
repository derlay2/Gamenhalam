import '../logic/game_config.dart';
import 'enums.dart';
import 'world_map.dart';

class Quest {
  const Quest({
    required this.id,
    required this.location,
    required this.tier,
    required this.monster,
    required this.isHorde,
    required this.isGroup,
    required this.minParty,
    required this.maxParty,
    required this.difficulty,
    required this.gold,
    required this.exp,
    this.isGathering = false,
    this.promotionFor,
    this.isRoyal = false,
    this.isMutated = false,
    this.renegadeId,
    this.renegadeName,
  });

  factory Quest.fromJson(Map<String, dynamic> j) => Quest(
    id: j['id'] as int,
    location: Location.values.byName(j['location'] as String),
    tier: QuestTier.values.byName(j['tier'] as String),
    monster: MonsterType.values.byName(j['monster'] as String),
    isHorde: j['isHorde'] as bool,
    isGroup: j['isGroup'] as bool,
    minParty: j['minParty'] as int,
    maxParty: j['maxParty'] as int,
    difficulty: (j['difficulty'] as num).toDouble(),
    gold: j['gold'] as int,
    exp: j['exp'] as int,
    isGathering: j['isGathering'] as bool? ?? false,
    promotionFor: j['promotionFor'] as int?,
    isRoyal: j['isRoyal'] as bool? ?? false,
    isMutated: j['isMutated'] as bool? ?? false,
    renegadeId: j['renegadeId'] as int?,
    renegadeName: j['renegadeName'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'location': location.name,
    'tier': tier.name,
    'monster': monster.name,
    'isHorde': isHorde,
    'isGroup': isGroup,
    'minParty': minParty,
    'maxParty': maxParty,
    'difficulty': difficulty,
    'gold': gold,
    'exp': exp,
    'isGathering': isGathering,
    'promotionFor': promotionFor,
    'isRoyal': isRoyal,
    'isMutated': isMutated,
    'renegadeId': renegadeId,
    'renegadeName': renegadeName,
  };

  /// Bản quái biến dị (thí nghiệm của pháp sư điên): mạnh hơn, thưởng vàng & EXP nhiều hơn.
  Quest mutate() => isMutated
      ? this
      : Quest(
          id: id,
          location: location,
          tier: tier,
          monster: monster,
          isHorde: isHorde,
          isGroup: isGroup,
          minParty: minParty,
          maxParty: maxParty,
          difficulty: difficulty * GameConfig.mutationStrength,
          gold: (gold * GameConfig.mutationReward).round(),
          exp: (exp * GameConfig.mutationReward).round(),
          isGathering: isGathering,
          promotionFor: promotionFor,
          isRoyal: isRoyal,
          isMutated: true,
          renegadeId: renegadeId,
          renegadeName: renegadeName,
        );

  final int id;

  /// Khu trên bản đồ nơi có quest.
  final Location location;
  final QuestTier tier;
  final MonsterType monster;

  /// true = quái đông, false = quái ít.
  final bool isHorde;
  final bool isGroup;
  final int minParty;
  final int maxParty;
  final double difficulty;
  final int gold;

  /// EXP mỗi hunter nhận được khi thành công.
  final int exp;

  /// Quest thu thập: quái canh giữ yếu hơn, ít EXP/thưởng hơn nhưng nhặt được nhiều nguyên liệu của khu.
  final bool isGathering;

  /// Quest thăng hạng riêng của hunter có id này (lên hạng [tier]); null = quest thường.
  final int? promotionFor;
  bool get isPromotion => promotionFor != null;

  /// Viễn chinh cho Đức Vua (sự kiện viện trợ vương quốc).
  final bool isRoyal;

  /// Quái đã biến dị (thí nghiệm cấm của pháp sư).
  final bool isMutated;

  /// Boss phụ: hunter bị trục xuất quay lại báo thù.
  final int? renegadeId;
  final String? renegadeName;
  bool get isRenegade => renegadeId != null;

  /// Quest đặc biệt: không tính vào bảng thường, không bị làm mới mất.
  bool get isSpecial => isPromotion || isRenegade;

  String get title {
    final base = isRenegade
        ? '⚔ Kẻ phản bội $renegadeName quay lại'
        : isRoyal
        ? '👑 Viễn chinh cho Đức Vua'
        : isPromotion
        ? '⭐ Thăng hạng ${tier.label}: ${isHorde ? 'Bầy ${monster.label}' : '${monster.label} đầu lĩnh'}'
        : isGathering
        ? 'Thu thập ở ${location.label}'
        : (isHorde ? 'Bầy ${monster.label}' : '${monster.label} đầu lĩnh');
    return isMutated ? '☣ $base (biến dị)' : base;
  }
}
