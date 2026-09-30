import 'dart:math';

import '../models/crafting.dart';
import '../models/equipment.dart';
import '../models/trade.dart';
import '../models/world_map.dart';
import 'game_config.dart';
import 'random_utils.dart';
import 'shopping.dart';

/// Sinh hàng cho chợ các khu và thương nhân lang thang.
class MarketGenerator {
  MarketGenerator(this._random) : _factory = EquipmentFactory(_random);

  final Random _random;
  final EquipmentFactory _factory;

  /// Cấp hàng ở chợ theo độ nguy hiểm của khu (giống cấp nguyên liệu rơi ở đó).
  static List<ItemGrade> gradesAt(Location l) =>
      ItemGrade.values.sublist(l.minTier.materialGrade.index, l.maxTier.materialGrade.index + 1);

  ItemGrade _grade(Location l) {
    final grades = gradesAt(l);
    return grades[_random.nextInt(grades.length)];
  }

  /// Đổi giá của món đồ thành giá bán (hunter mua lại ở nhà rèn đúng giá guild đã trả).
  Equipment _priced(Equipment e, int price) =>
      Equipment(id: e.id, type: e.type, grade: e.grade, bonus: e.bonus, quality: e.quality, price: price);

  MarketOffer _item(int Function() nextId, ItemGrade grade, double minRate, double maxRate, {double boost = 1}) {
    final type = ItemType.values[_random.nextInt(ItemType.values.length)];
    var base = _factory.make(nextId(), type, grade);
    if (boost != 1) {
      base = Equipment(
        id: base.id,
        type: type,
        grade: grade,
        bonus: base.bonus * boost,
        quality: base.quality * boost,
        price: (base.price * boost).round(),
      );
    }
    final price = (base.price * randomBetween(_random, minRate, maxRate)).round();
    return MarketOffer(id: nextId(), price: price, item: _priced(base, price));
  }

  /// Bản vẽ loại đồ ngẫu nhiên, cấp [grade].
  Blueprint randomBlueprint(ItemGrade grade) =>
      (type: ItemType.values[_random.nextInt(ItemType.values.length)], grade: grade);

  MarketOffer _blueprint(int Function() nextId, ItemGrade grade, double minRate, double maxRate) => MarketOffer(
    id: nextId(),
    price: (GameConfig.blueprintPrice[grade]! * randomBetween(_random, minRate, maxRate)).round(),
    blueprint: randomBlueprint(grade),
  );

  /// Thương nhân nước ngoài: giá 65–140%, luôn có vài bản vẽ; cấp hàng theo nước.
  List<MarketOffer> foreign(Country c, int Function() nextId) {
    const lo = GameConfig.foreignPriceMin, hi = GameConfig.foreignPriceMax;
    ItemGrade grade() => c.grades[_random.nextInt(c.grades.length)];
    return [
      for (var i = 0; i < GameConfig.foreignItemsPerCountry; i++) _item(nextId, grade(), lo, hi),
      for (var i = 0; i < GameConfig.foreignBlueprintsPerCountry; i++) _blueprint(nextId, grade(), lo, hi),
    ];
  }

  /// Hàng ở chợ 1 khu: vài món trang bị, đôi khi có bản vẽ; giá 90–190% giá thường.
  List<MarketOffer> region(Location l, int Function() nextId) {
    const lo = GameConfig.marketPriceMin, hi = GameConfig.marketPriceMax;
    return [
      for (var i = 0; i < GameConfig.marketItemsPerRegion; i++) _item(nextId, _grade(l), lo, hi),
      if (_random.nextDouble() < GameConfig.marketBlueprintChance) _blueprint(nextId, _grade(l), lo, hi),
    ];
  }

  /// Thương nhân lang thang: nguyên liệu Thần khí, trang bị độc quyền (mạnh hơn 25%), bản vẽ cao cấp; giá cắt cổ.
  List<MarketOffer> merchant(int Function() nextId) {
    const lo = GameConfig.merchantPriceMin, hi = GameConfig.merchantPriceMax;
    const grade = ItemGrade.divine;
    MarketOffer material() {
      final resource = Resource.values[_random.nextInt(Resource.values.length)];
      const quantity = 3;
      return MarketOffer(
        id: nextId(),
        price: (resource.unitPrice(grade) * quantity * randomBetween(_random, lo, hi)).round(),
        material: (resource, grade, quantity),
      );
    }

    return [
      material(),
      material(),
      _item(nextId, ItemGrade.master, lo, hi, boost: 1.25),
      _item(nextId, grade, lo, hi, boost: 1.25),
      _blueprint(nextId, _random.nextBool() ? ItemGrade.master : grade, lo, hi),
    ];
  }
}
