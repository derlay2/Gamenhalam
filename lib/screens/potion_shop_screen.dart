import 'package:flutter/material.dart';

import '../logic/game_config.dart';
import '../logic/game_state.dart';
import '../models/potion.dart';
import '../widgets/confirm_sell.dart';
import '../widgets/visuals.dart';

class PotionShopScreen extends StatelessWidget {
  const PotionShopScreen({super.key, required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text('Tiệm thuốc · 🪙 ${game.gold}')),
        body: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Hunter tự mua bình máu mỗi sáng sau khi mua đồ, dùng tối đa '
                '${percent(GameConfig.potionBudgetRate)} tiền còn lại trong ví, mang tối đa '
                '${GameConfig.maxPotions} bình. Sau trận, nếu máu dưới ${percent(GameConfig.hospitalThreshold)} '
                'hunter sẽ tự uống (bình nhỏ trước) để tránh nhập viện.\n'
                'Bình máu phải chế ở Nhà rèn (Máu + Lõi); cấp nguyên liệu càng cao, bình càng lớn.',
              ),
            ),
            for (final p in Potion.values)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.local_drink, color: Colors.red),
                  title: Text(p.label),
                  subtitle: Text('Hồi ${percent(p.healPercent)} máu tối đa · ${p.price} 🪙'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Còn ${game.potionStock[p] ?? 0}'),
                      IconButton(
                        tooltip: 'Bán thanh lý (${game.potionSellPrice(p)} 🪙)',
                        icon: const Icon(Icons.sell),
                        onPressed: (game.potionStock[p] ?? 0) == 0
                            ? null
                            : () async {
                                if (await confirmSell(context, p.label, game.potionSellPrice(p))) game.sellPotion(p);
                              },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
