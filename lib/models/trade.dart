import 'crafting.dart';
import 'day.dart';
import 'equipment.dart';
import 'world_map.dart';

/// Một món hàng ở chợ khu vực hoặc của thương nhân lang thang:
/// đúng 1 trong 3 loại: trang bị, bản vẽ chế tạo, hoặc lô nguyên liệu.
class MarketOffer {
  const MarketOffer({required this.id, required this.price, this.item, this.blueprint, this.material});

  factory MarketOffer.fromJson(Map<String, dynamic> j) => MarketOffer(
    id: j['id'] as int,
    price: j['price'] as int,
    item: switch (j['item']) {
      final Map<String, dynamic> item => Equipment.fromJson(item),
      _ => null,
    },
    blueprint: switch (j['blueprint']) {
      // Bản lưu cũ: bản vẽ chỉ theo cấp -> coi như bản vẽ Kiếm cấp đó.
      final String key when !key.contains(':') => (type: ItemType.sword, grade: ItemGrade.values.byName(key)),
      final String key => BlueprintInfo.parse(key),
      _ => null,
    },
    material: switch (j['material']) {
      final Map<String, dynamic> m => (
        Resource.values.byName(m['resource'] as String),
        ItemGrade.values.byName(m['grade'] as String),
        m['quantity'] as int,
      ),
      _ => null,
    },
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'price': price,
    'item': item?.toJson(),
    'blueprint': blueprint?.key,
    'material': switch (material) {
      (final resource, final grade, final quantity) => {
        'resource': resource.name,
        'grade': grade.name,
        'quantity': quantity,
      },
      null => null,
    },
  };

  final int id;

  /// Giá guild phải trả.
  final int price;
  final Equipment? item;
  final Blueprint? blueprint;
  final (Resource, ItemGrade, int)? material;

  String get label => switch (this) {
    MarketOffer(item: final item?) => item.name,
    MarketOffer(blueprint: final b?) => b.label,
    MarketOffer(material: (final resource, final grade, final quantity)?) =>
      '$quantity ${resource.label} ${grade.label}',
    _ => '?',
  };
}

/// Nước ngoài có thương nhân: xa hơn (tính bằng ngày), phí đi lại cao nhưng giá rẻ hơn và luôn có bản vẽ.
/// Nước càng xa, hàng càng cao cấp.
enum Country {
  northKingdom('Vương quốc Tuyết Bắc', travelDays: 2, grades: [ItemGrade.basic, ItemGrade.fine]),
  portRepublic('Cộng hoà Thương cảng', travelDays: 3, grades: [ItemGrade.fine, ItemGrade.master]),
  desertDynasty('Vương triều Sa mạc', travelDays: 5, grades: [ItemGrade.master, ItemGrade.divine]);

  const Country(this.label, {required this.travelDays, required this.grades});
  final String label;

  /// Số ngày đi 1 chiều.
  final int travelDays;

  /// Cấp hàng bày bán.
  final List<ItemGrade> grades;
}

/// Nhân viên guild đi chợ khu khác hoặc nước khác: trả tiền trước, hàng về khi nhân viên quay lại.
class CaravanTrip {
  const CaravanTrip({
    this.destination,
    this.country,
    required this.goods,
    required this.route,
    required this.departAt,
    required this.returnAt,
    required this.fee,
  });

  factory CaravanTrip.fromJson(Map<String, dynamic> j) => CaravanTrip(
    destination: switch (j['destination']) {
      final String l => Location.values.byName(l),
      _ => null,
    },
    country: switch (j['country']) {
      final String c => Country.values.byName(c),
      _ => null,
    },
    goods: [for (final o in j['goods'] as List) MarketOffer.fromJson(o as Map<String, dynamic>)],
    route: [for (final l in j['route'] as List) Location.values.byName(l as String)],
    departAt: j['departAt'] as int,
    returnAt: j['returnAt'] as int,
    fee: j['fee'] as int,
  );

  Map<String, dynamic> toJson() => {
    'destination': destination?.name,
    'country': country?.name,
    'goods': [for (final o in goods) o.toJson()],
    'route': [for (final l in route) l.name],
    'departAt': departAt,
    'returnAt': returnAt,
    'fee': fee,
  };

  /// Khu trên bản đồ, hoặc null nếu đi nước ngoài ([country]).
  final Location? destination;
  final Country? country;

  String get placeLabel => destination?.label ?? country!.label;
  final List<MarketOffer> goods;
  final List<Location> route;
  final int departAt;
  final int returnAt;

  /// Phí đi lại đã trả cho nhân viên.
  final int fee;

  String statusAt(int now) => now < returnAt
      ? 'Đi mua ở $placeLabel · về lúc ${describePhase(returnAt)}'
      : 'Đã về';
}
