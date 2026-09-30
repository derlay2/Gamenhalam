import 'dart:math';

import '../models/equipment.dart';
import '../models/hunter.dart';
import '../models/stats.dart';
import 'random_utils.dart';

/// Một lần hunter mua hàng.
class Purchase {
  const Purchase({required this.hunter, required this.itemName, required this.price});

  final Hunter hunter;
  final String itemName;
  final int price;
}

/// Sinh món đồ ngẫu nhiên cho lượt nhập hàng buổi sáng.
class EquipmentFactory {
  EquipmentFactory(this._random);

  final Random _random;

  Equipment roll(int id) => make(
    id,
    ItemType.values[_random.nextInt(ItemType.values.length)],
    pickWeighted(ItemGrade.values, (g) => g.offerWeight, _random),
  );

  /// Làm 1 món loại [type], cấp [grade] với chỉ số ngẫu nhiên.
  Equipment make(int id, ItemType type, ItemGrade grade) {
    final base = Equipment.standardBonus(type, grade);

    // Mỗi chỉ số dao động riêng ±25%; giá theo chất lượng trung bình.
    final rolls = <double>[];
    double roll(double value) {
      if (value == 0) return 0;
      final factor = randomBetween(_random, 0.75, 1.25);
      rolls.add(factor);
      return value * factor;
    }

    final bonus = Stats(
      power: roll(base.power),
      maxHp: roll(base.maxHp),
      physRes: roll(base.physRes),
      magicRes: roll(base.magicRes),
      agility: roll(base.agility),
    );
    final quality = rolls.reduce((a, b) => a + b) / rolls.length;
    return Equipment(
      id: id,
      type: type,
      grade: grade,
      bonus: bonus,
      quality: quality,
      price: (grade.price * quality).round(),
    );
  }
}

/// Cách hunter đánh giá trang bị khi tự mua sắm.
abstract final class ShoppingAdvisor {
  static double statValue(Stats s) => s.power + s.maxHp * 0.2 + (s.physRes + s.magicRes) * 0.75 + s.agility * 1.5;

  /// Các món hunter sẽ phải tháo ra nếu mặc [item].
  static List<Equipment> replacedBy(Hunter h, Equipment item) => [
    ?h.equipment[item.type.slot],
    if (item.type.twoHanded) ?h.equipment[EquipSlot.offHand],
    if (item.type.slot == EquipSlot.offHand && (h.equipment[EquipSlot.mainHand]?.type.twoHanded ?? false))
      h.equipment[EquipSlot.mainHand]!,
  ];

  /// Chỉ số tăng thêm nếu mặc [item] (âm nghĩa là tệ hơn).
  static double upgradeValue(Hunter h, Equipment item) =>
      statValue(item.bonus) - replacedBy(h, item).fold(0.0, (sum, e) => sum + statValue(e.effectiveBonus));

  /// Món đáng mua nhất trong kho mà hunter dùng được và đủ tiền, hoặc null.
  static Equipment? bestUpgrade(Hunter h, List<Equipment> stock) {
    Equipment? best;
    var bestValue = 0.0;
    for (final item in stock) {
      if (h.equipError(item) != null || h.gold < item.price) continue;
      final value = upgradeValue(h, item);
      if (value > bestValue) {
        best = item;
        bestValue = value;
      }
    }
    return best;
  }
}
