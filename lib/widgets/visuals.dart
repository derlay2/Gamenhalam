import 'package:flutter/material.dart';

import '../logic/game_config.dart';
import '../models/day.dart';
import '../models/enums.dart';
import '../models/equipment.dart';
import '../models/stats.dart';
import '../models/world_map.dart';

extension HunterClassVisuals on HunterClass {
  IconData get icon => switch (this) {
    HunterClass.mage => Icons.auto_fix_high,
    HunterClass.ranger => Icons.gps_fixed,
    HunterClass.warrior => Icons.sports_martial_arts,
    HunterClass.healer => Icons.healing,
    HunterClass.tank => Icons.shield,
  };
}

/// Màu riêng từng buổi: sáng = cam bình minh, trưa = xanh trời, đêm = tím chàm.
extension DayPhaseVisuals on DayPhase {
  Color get color => switch (this) {
    DayPhase.morning => const Color(0xFFF57C00),
    DayPhase.noon => const Color(0xFF0288D1),
    DayPhase.night => const Color(0xFF3949AB),
  };

  IconData get icon => switch (this) {
    DayPhase.morning => Icons.wb_twilight,
    DayPhase.noon => Icons.wb_sunny,
    DayPhase.night => Icons.nightlight_round,
  };

  DayPhase get next => DayPhase.values[(index + 1) % DayPhase.values.length];
}

/// Nhãn thời điểm có màu theo buổi, ví dụ "🌙 N2 · Đêm".
class PhaseTag extends StatelessWidget {
  const PhaseTag({super.key, required this.at, this.prefix, this.today});

  /// Mốc thời gian (xem [phaseIndex]).
  final int at;
  final String? prefix;

  /// Ngày hiện tại: cùng ngày thì ghi "hôm nay", hôm sau ghi "mai".
  final int? today;

  @override
  Widget build(BuildContext context) {
    final (day, phase) = phaseAt(at);
    final dayLabel = switch (today) {
      final t? when t == day => 'Hôm nay',
      final t? when t + 1 == day => 'Mai',
      _ => 'N$day',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: phase.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: phase.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(phase.icon, size: 12, color: phase.color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '${prefix == null ? '' : '$prefix '}$dayLabel · ${phase.label}',
              style: TextStyle(fontSize: 11, color: phase.color, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

extension RarityVisuals on Rarity {
  Color get color => switch (this) {
    Rarity.common => Colors.grey,
    Rarity.rare => Colors.blue,
    Rarity.epic => Colors.purple,
    Rarity.legendary => Colors.orange,
  };
}

extension QuestTierVisuals on QuestTier {
  Color get color => switch (this) {
    QuestTier.d => Colors.blueGrey,
    QuestTier.c => Colors.green,
    QuestTier.b => Colors.blue,
    QuestTier.a => Colors.purple,
    QuestTier.s => Colors.orange,
    QuestTier.sss => Colors.red,
  };
}

extension ItemTypeVisuals on ItemType {
  IconData get icon => switch (this) {
    ItemType.staff => Icons.auto_fix_normal,
    ItemType.sword => Icons.colorize,
    ItemType.bow => Icons.gps_not_fixed,
    ItemType.shield => Icons.shield_outlined,
    ItemType.dagger => Icons.content_cut,
    ItemType.clothArmor || ItemType.leatherArmor || ItemType.steelArmor => Icons.checkroom,
  };
}

extension ItemGradeVisuals on ItemGrade {
  Color get color => switch (this) {
    ItemGrade.basic => Colors.blueGrey,
    ItemGrade.fine => Colors.green,
    ItemGrade.master => Colors.purple,
    ItemGrade.divine => Colors.orange,
  };
}

/// Mô tả tình trạng & độ bền, ví dụ "🔧 Tình trạng 72/100 · 🛡 Độ bền 95/100".
String describeDurability(Equipment item) {
  const max = GameConfig.maxDurability;
  final condition = item.isBroken ? '🔧 HỎNG – cần sửa' : '🔧 Tình trạng ${item.condition.ceil()}/$max';
  return '$condition · 🛡 Độ bền ${item.durability.ceil()}/$max';
}

extension LocationVisuals on Location {
  IconData get icon => switch (this) {
    Location.town => Icons.location_city,
    Location.grassland => Icons.grass,
    Location.goblinCave => Icons.landslide,
    Location.beach => Icons.beach_access,
    Location.mine => Icons.construction,
    Location.elfForest => Icons.forest,
    Location.rockyCanyon => Icons.terrain,
    Location.monsterForest => Icons.park,
    Location.snowMountain => Icons.ac_unit,
    Location.dungeon => Icons.castle,
    Location.empire => Icons.account_balance,
  };

  /// Xanh (an toàn) -> đỏ (nguy hiểm).
  Color get dangerColor => this == Location.town ? Colors.teal : Color.lerp(Colors.green, Colors.red, danger)!;
}

String percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

String describeStats(Stats s) => [
  if (s.power > 0) 'Sức mạnh +${s.power.round()}',
  if (s.maxHp > 0) 'Máu +${s.maxHp.round()}',
  if (s.physRes > 0) 'Kháng VL +${s.physRes.round()}',
  if (s.magicRes > 0) 'Kháng phép +${s.magicRes.round()}',
  if (s.agility > 0) 'Nhanh nhẹn +${s.agility.toStringAsFixed(1)}',
].join(' · ');

extension EmptyFallback on String {
  /// Chuỗi này, hoặc [fallback] nếu rỗng.
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
