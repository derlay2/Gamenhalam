import '../logic/game_config.dart';
import 'enums.dart';
import 'equipment.dart';
import 'hunter.dart';
import 'potion.dart';
import 'world_map.dart';

/// Nguyên liệu hunter thu thập từ quái.
enum Resource {
  hide('Da', baseValue: 8),
  tooth('Răng', baseValue: 8),
  core('Lõi', baseValue: 12),
  blood('Máu', baseValue: 10),
  ore('Quặng', baseValue: 10),
  wood('Gỗ', baseValue: 6),
  fur('Lông', baseValue: 8);

  const Resource(this.label, {required this.baseValue});
  final String label;

  /// Giá thu mua 1 đơn vị cấp Sơ cấp.
  final int baseValue;

  int unitPrice(ItemGrade grade) => (baseValue * grade.materialValueMultiplier).round();
}

extension MonsterLoot on MonsterType {
  /// Nguyên liệu có thể rơi từ loại quái này.
  List<Resource> get drops => switch (this) {
    MonsterType.beast => const [Resource.hide, Resource.fur, Resource.tooth, Resource.blood],
    MonsterType.golem => const [Resource.ore, Resource.core, Resource.wood],
    MonsterType.spirit => const [Resource.core, Resource.blood, Resource.wood],
    MonsterType.demon => const [Resource.tooth, Resource.core, Resource.blood, Resource.ore],
    MonsterType.goblin => const [Resource.tooth, Resource.ore, Resource.hide],
    MonsterType.seaBeast => const [Resource.blood, Resource.core, Resource.tooth],
    MonsterType.harpy => const [Resource.fur, Resource.tooth],
    MonsterType.yeti => const [Resource.fur, Resource.hide, Resource.blood],
    MonsterType.soldier => const [Resource.ore, Resource.hide, Resource.wood],
  };
}

extension LocationGathering on Location {
  /// Nguyên liệu khai thác được ở khu này (quest thu thập).
  List<Resource> get gatherables => switch (this) {
    Location.town => const [],
    Location.grassland => const [Resource.hide, Resource.fur, Resource.wood],
    Location.goblinCave => const [Resource.ore, Resource.tooth, Resource.hide],
    Location.beach => const [Resource.blood, Resource.core, Resource.wood],
    Location.mine => const [Resource.ore, Resource.core],
    Location.elfForest => const [Resource.wood, Resource.core, Resource.fur],
    Location.rockyCanyon => const [Resource.ore, Resource.core, Resource.tooth],
    Location.monsterForest => const [Resource.wood, Resource.fur, Resource.blood],
    Location.snowMountain => const [Resource.fur, Resource.hide, Resource.ore],
    Location.dungeon => const [Resource.core, Resource.ore, Resource.blood],
    Location.empire => const [Resource.ore, Resource.wood, Resource.hide],
  };
}

extension QuestTierMaterialGrade on QuestTier {
  /// Cấp nguyên liệu rơi ra từ quest tier này.
  ItemGrade get materialGrade => switch (this) {
    QuestTier.d || QuestTier.c => ItemGrade.basic,
    QuestTier.b => ItemGrade.fine,
    QuestTier.a => ItemGrade.master,
    QuestTier.s || QuestTier.sss => ItemGrade.divine,
  };
}

/// Một lô nguyên liệu hunter mang về, chờ guild thu mua.
class MaterialLot {
  const MaterialLot({
    required this.hunter,
    required this.resource,
    required this.grade,
    required this.quantity,
    required this.day,
  });

  factory MaterialLot.fromJson(Map<String, dynamic> j, Hunter Function(int id) hunterById) => MaterialLot(
    hunter: hunterById(j['hunter'] as int),
    resource: Resource.values.byName(j['resource'] as String),
    grade: ItemGrade.values.byName(j['grade'] as String),
    quantity: j['quantity'] as int,
    day: j['day'] as int? ?? 1,
  );

  Map<String, dynamic> toJson() => {
    'hunter': hunter.id,
    'resource': resource.name,
    'grade': grade.name,
    'quantity': quantity,
    'day': day,
  };

  final Hunter hunter;
  final Resource resource;
  final ItemGrade grade;
  final int quantity;

  /// Ngày hunter mang lô này về.
  final int day;

  /// Số ngày còn lại trước khi hunter đem bán chỗ khác (tính cả hôm nay).
  int daysLeft(int today) => day + GameConfig.materialLotDays - today;

  int get price => resource.unitPrice(grade) * quantity;
  String get label => '$quantity ${resource.label} ${grade.label}';
}

enum Recipe {
  sword('Kiếm', item: ItemType.sword, ingredients: {Resource.ore: 3, Resource.wood: 1}),
  shield('Khiên', item: ItemType.shield, ingredients: {Resource.ore: 2, Resource.wood: 2}),
  dagger('Dao', item: ItemType.dagger, ingredients: {Resource.ore: 1, Resource.tooth: 2}),
  staff('Gậy phép', item: ItemType.staff, ingredients: {Resource.wood: 2, Resource.core: 2}),
  bow('Cung', item: ItemType.bow, ingredients: {Resource.fur: 1, Resource.wood: 3}),
  clothArmor('Giáp vải', item: ItemType.clothArmor, ingredients: {Resource.fur: 4}),
  leatherArmor('Giáp da', item: ItemType.leatherArmor, ingredients: {Resource.hide: 4}),
  steelArmor('Giáp thép', item: ItemType.steelArmor, ingredients: {Resource.ore: 4}),
  potion('Bình máu', ingredients: {Resource.blood: 2, Resource.core: 1});

  const Recipe(this.label, {this.item, required this.ingredients});

  final String label;

  /// Trang bị làm ra (null = công thức bình máu).
  final ItemType? item;
  final Map<Resource, int> ingredients;

  /// Bình máu làm ra tùy cấp nguyên liệu.
  static Potion potionFor(ItemGrade grade) => switch (grade) {
    ItemGrade.basic => Potion.small,
    ItemGrade.fine => Potion.medium,
    ItemGrade.master || ItemGrade.divine => Potion.large,
  };
}
