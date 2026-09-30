import 'package:flutter/material.dart';

import '../logic/game_config.dart';
import '../logic/game_state.dart';
import '../logic/market.dart';
import '../models/trade.dart';
import '../models/world_map.dart';
import '../widgets/visuals.dart';

/// Cử nhân viên guild đi chợ các khu hoặc sang nước khác mua trang bị và bản vẽ.
class CaravanScreen extends StatefulWidget {
  const CaravanScreen({super.key, required this.game});

  final GameState game;

  @override
  State<CaravanScreen> createState() => _CaravanScreenState();
}

class _CaravanScreenState extends State<CaravanScreen> {
  /// Món đang chọn theo từng nơi (Location hoặc Country).
  final _selected = <Object, Set<MarketOffer>>{};

  GameState get game => widget.game;

  void _sent(CaravanTrip trip, Object place) {
    setState(() => _selected.remove(place));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nhân viên lên đường: ${trip.statusAt(game.now)}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: ListenableBuilder(
        listenable: game,
        builder: (context, _) {
          final regions = Location.regions.toList()
            ..sort((a, b) => game.map.travelTime(Location.town, a).compareTo(game.map.travelTime(Location.town, b)));
          return Scaffold(
            appBar: AppBar(
              title: Text('Thương đoàn · 🪙 ${game.gold}'),
              bottom: const TabBar(tabs: [Tab(text: 'Chợ các khu'), Tab(text: 'Thương nhân nước ngoài')]),
            ),
            body: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    _intro(
                      'Cử nhân viên guild tới chợ các khu trên bản đồ. Giá '
                      '${percent(GameConfig.marketPriceMin)}–${percent(GameConfig.marketPriceMax)} giá thường, phí đi lại '
                      '${GameConfig.caravanFeePerPhase} 🪙 mỗi buổi đường (cả đi lẫn về). Khu càng nguy hiểm, hàng càng '
                      'cao cấp; thỉnh thoảng có bản vẽ. Chợ nhập hàng mới mỗi đầu tuần.',
                    ),
                    ..._trips(context),
                    for (final l in regions)
                      _market(
                        place: l,
                        title: l.label,
                        info:
                            'Đi ${game.map.travelTime(Location.town, l)} buổi · phí ${game.caravanFee(l)} 🪙 · '
                            'hàng ${MarketGenerator.gradesAt(l).map((g) => g.label).join('/')}',
                        offers: game.markets[l] ?? const [],
                        fee: game.caravanFee(l),
                        error: (goods) => game.caravanError(l, goods),
                        send: (goods) => game.sendCaravan(l, goods),
                      ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    _intro(
                      'Cử nhân viên sang nước khác mua hàng thương nhân nước ngoài. Đường xa (tính bằng ngày) nên phí đi '
                      'lại cao (${GameConfig.foreignFeePerDay} 🪙 mỗi ngày đường, cả đi lẫn về), nhưng giá chỉ '
                      '${percent(GameConfig.foreignPriceMin)}–${percent(GameConfig.foreignPriceMax)} và luôn có bản vẽ. '
                      'Nước càng xa hàng càng cao cấp. Hàng đổi mới mỗi ${GameConfig.foreignRestockDays} ngày '
                      '(lần tới: sáng ngày ${game.nextForeignRestock}).',
                    ),
                    ..._trips(context),
                    for (final c in Country.values)
                      _market(
                        place: c,
                        title: c.label,
                        info:
                            'Đi ${c.travelDays} ngày, về sau ${c.travelDays * 2} ngày · phí ${game.foreignFee(c)} 🪙 · '
                            'hàng ${c.grades.map((g) => g.label).join('/')}',
                        offers: game.foreignMarkets[c] ?? const [],
                        fee: game.foreignFee(c),
                        error: (goods) => game.foreignError(c, goods),
                        send: (goods) => game.sendForeignCaravan(c, goods),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _intro(String text) => Padding(padding: const EdgeInsets.all(8), child: Text(text));

  List<Widget> _trips(BuildContext context) => [
    Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        'Đang đi (${game.caravans.length}/${GameConfig.maxCaravans})',
        style: Theme.of(context).textTheme.titleSmall,
      ),
    ),
    if (game.caravans.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Không có ai đang đi.')),
    for (final c in game.caravans)
      Card(
        child: ListTile(
          leading: const Icon(Icons.local_shipping),
          title: Text(c.goods.map((o) => o.label).join(', ')),
          subtitle: Text(c.statusAt(game.now)),
        ),
      ),
    const Divider(),
  ];

  Widget _market({
    required Object place,
    required String title,
    required String info,
    required List<MarketOffer> offers,
    required int fee,
    required String? Function(List<MarketOffer>) error,
    required CaravanTrip Function(List<MarketOffer>) send,
  }) {
    final selected = _selected[place] ??= {};
    selected.removeWhere((o) => !offers.contains(o));
    final total = selected.fold(0, (s, o) => s + o.price) + fee;
    final problem = error(selected.toList());
    return Card(
      child: ExpansionTile(
        title: Text(title),
        subtitle: Text('$info · ${offers.length} món'),
        children: [
          if (offers.isEmpty) const ListTile(title: Text('Đã hết hàng, chờ đợt hàng mới.')),
          for (final o in offers)
            CheckboxListTile(
              value: selected.contains(o),
              onChanged: (v) => setState(() => v! ? selected.add(o) : selected.remove(o)),
              title: Text(o.label),
              subtitle: Text(
                [
                  if (o.item case final item?) describeStats(item.bonus),
                  if (o.blueprint case final b?) 'Mở khóa chế ${b.type.label} ${b.grade.label}',
                  if (o.blueprint case final b? when game.blueprints.contains(b)) '(đã có)',
                ].join(' '),
              ),
              secondary: Text('${o.price} 🪙'),
            ),
          if (offers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(child: Text(problem ?? 'Tổng $total 🪙 (gồm phí đi lại $fee)')),
                  FilledButton(
                    onPressed: problem == null ? () => _sent(send(selected.toList()), place) : null,
                    child: const Text('Gửi nhân viên'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
