import 'package:flutter/material.dart';

import '../logic/game_config.dart';
import '../logic/game_state.dart';
import '../models/crafting.dart';
import '../widgets/material_storage.dart';
import '../widgets/visuals.dart';

class TradingPostScreen extends StatelessWidget {
  const TradingPostScreen({super.key, required this.game});

  final GameState game;

  void _buyAll() {
    for (final lot in List.of(game.materialLots)) {
      if (!game.buyLot(lot)) break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final total = game.materialLots.fold(0, (sum, l) => sum + game.lotPrice(l));
        final titleStyle = Theme.of(context).textTheme.titleSmall;
        return Scaffold(
          appBar: AppBar(title: Text('Trạm thu mua · 🪙 ${game.gold}')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Hunter mang nguyên liệu từ quái về bán. Guild trả tiền vào ví hunter. '
                  'Mỗi lô được giữ ${GameConfig.materialLotDays} ngày, quá hạn chưa mua sẽ bị hunter bán chỗ khác '
                  '(với ${(GameConfig.expiredLotSellRate * 100).round()}% giá).\n'
                  'Quest thu thập ⛏ mang về nhiều nguyên liệu hơn hẳn quest săn.\n'
                  'Nguyên liệu có cấp theo tier quest (D/C: Sơ cấp, B: Tinh luyện, A: Bậc thầy, S/SSS: Thần khí); '
                  'chế tạo cần nguyên liệu cùng cấp và cho ra đồ đúng cấp đó.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Đang chào bán', style: titleStyle),
              ),
              if (game.materialLots.isEmpty)
                const Padding(padding: EdgeInsets.all(8), child: Text('Chưa có hunter nào mang hàng về.')),
              for (final lot in game.materialLots) _LotTile(game: game, lot: lot),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Kho nguyên liệu', style: titleStyle),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: MaterialStorageView(game: game, sellable: true),
              ),
            ],
          ),
          floatingActionButton: game.materialLots.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: game.gold >= total ? _buyAll : null,
                  icon: const Icon(Icons.shopping_basket),
                  label: Text('Mua tất cả ($total 🪙)'),
                ),
        );
      },
    );
  }
}

class _LotTile extends StatelessWidget {
  const _LotTile({required this.game, required this.lot});

  final GameState game;
  final MaterialLot lot;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.inventory_2, color: lot.grade.color),
        title: Text(lot.label),
        subtitle: Text(
          'Từ ${lot.hunter.name} · ${lot.resource.unitPrice(lot.grade)} 🪙/cái · '
          '${lot.daysLeft(game.day) == 1 ? 'hôm nay là ngày cuối' : 'còn ${lot.daysLeft(game.day)} ngày'}',
          style: TextStyle(color: lot.daysLeft(game.day) == 1 ? Colors.orange : null),
        ),
        trailing: FilledButton(
          onPressed: game.gold >= game.lotPrice(lot) ? () => game.buyLot(lot) : null,
          child: Text('Mua ${game.lotPrice(lot)} 🪙${game.isInflation ? " 📈" : ""}'),
        ),
      ),
    );
  }
}
