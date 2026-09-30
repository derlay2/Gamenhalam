import 'package:flutter/material.dart';

import '../logic/game_state.dart';
import '../models/crafting.dart';
import '../models/equipment.dart';
import 'confirm_sell.dart';
import 'visuals.dart';

/// Kho nguyên liệu của guild, nhóm theo cấp.
class MaterialStorageView extends StatelessWidget {
  const MaterialStorageView({super.key, required this.game, this.sellable = false});

  final GameState game;

  /// Chạm vào 1 loại để bán thanh lý hết.
  final bool sellable;

  @override
  Widget build(BuildContext context) {
    final grades = ItemGrade.values.where((g) => Resource.values.any((r) => game.materialCount(r, g) > 0));
    if (grades.isEmpty) return const Text('Kho nguyên liệu trống. Hãy thu mua ở Trạm thu mua.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in grades)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  g.label,
                  style: TextStyle(color: g.color, fontWeight: FontWeight.bold),
                ),
                for (final r in Resource.values)
                  if (game.materialCount(r, g) case final count when count > 0)
                    sellable
                        ? ActionChip(
                            avatar: const Icon(Icons.sell, size: 16),
                            label: Text('${r.label} ×$count'),
                            onPressed: () async {
                              final price = game.materialSellPrice(r, g) * count;
                              if (await confirmSell(context, '$count ${r.label} ${g.label}', price)) {
                                game.sellMaterial(r, g);
                              }
                            },
                          )
                        : Chip(label: Text('${r.label} ×$count')),
              ],
            ),
          ),
        if (sellable)
          const Text('Chạm vào 1 loại để bán thanh lý hết số đó cho thương lái.', style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
