import 'package:flutter/material.dart';

import '../logic/game_config.dart';
import '../logic/game_state.dart';
import '../models/crafting.dart';
import '../models/equipment.dart';
import '../widgets/confirm_sell.dart';
import '../widgets/equipment_tile.dart';
import '../widgets/material_storage.dart';
import '../widgets/visuals.dart';

class BlacksmithScreen extends StatelessWidget {
  const BlacksmithScreen({super.key, required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: ListenableBuilder(
        listenable: game,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: Text('Nhà rèn · 🪙 ${game.gold}'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Hàng bán'),
                Tab(text: 'Chế tạo'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _StockTab(game: game),
              _CraftingTab(game: game),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockTab extends StatelessWidget {
  const _StockTab({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Hàng đến từ Thương đoàn (cử nhân viên đi chợ các khu khác), thương nhân lang thang, hoặc tự chế tạo '
            '(cần bản vẽ đúng cấp). Mỗi sáng hunter ở thị trấn tự mua '
            'món nâng cấp nếu đủ tiền; đồ cũ được thu lại ${percent(GameConfig.tradeInRate)} giá '
            '(theo độ bền còn lại).\n'
            'Mỗi món có 2 chỉ số song song:\n'
            '🔧 Tình trạng: mòn nhanh sau mỗi trận, về 0 thì hỏng (mất chỉ số) và phải sửa về 100% mới dùng '
            'lại được; hunter tự mang đến sửa khi tình trạng dưới ${percent(GameConfig.repairThreshold)}.\n'
            '🛡 Độ bền: giảm chậm, dưới 100% vẫn dùng bình thường, không sửa được; về 0 là vỡ vụn, mất luôn.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text('Hàng đang bán (${game.shopStock.length})', style: Theme.of(context).textTheme.titleSmall),
        ),
        if (game.shopStock.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Kho trống.')),
        if (game.shopStock.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('Chạm vào 1 món để bán thanh lý cho thương lái khi guild cần tiền gấp.'),
          ),
        for (final item in game.shopStock)
          EquipmentTile(
            item: item,
            onTap: () async {
              if (await confirmSell(context, item.name, item.tradeInValue)) game.sellStock(item);
            },
          ),
      ],
    );
  }
}

class _CraftingTab extends StatefulWidget {
  const _CraftingTab({required this.game});

  final GameState game;

  @override
  State<_CraftingTab> createState() => _CraftingTabState();
}

class _CraftingTabState extends State<_CraftingTab> {
  var _grade = ItemGrade.basic;

  GameState get game => widget.game;

  void _craft(Recipe recipe) {
    final made = game.craft(recipe, _grade);
    if (made == null) return;
    final where = recipe.item == null ? 'tiệm thuốc' : 'hàng bán';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã chế $made, bày ở $where.')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: MaterialStorageView(game: game),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<ItemGrade>(
            segments: [for (final g in ItemGrade.values) ButtonSegment(value: g, label: Text(g.label))],
            selected: {_grade},
            onSelectionChanged: (s) => setState(() => _grade = s.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Dùng nguyên liệu cấp ${_grade.label}. Chỉ số đồ chế ra ngẫu nhiên như hàng nhập.\n'
            '📜 Bản vẽ ${_grade.label} đang có: ${[
              for (final b in BlueprintInfo.ofGrade(_grade))
                if (game.blueprints.contains(b)) b.type.label,
            ].join(', ').ifEmpty('chưa có')}.\n'
            'Mỗi loại đồ mỗi cấp cần bản vẽ riêng (bản vẽ Khiên không chế được Kiếm). Có bản vẽ từ Thương đoàn '
            '(chợ các khu, thương nhân nước ngoài), thương nhân lang thang, hoặc rơi từ quest tier B trở lên; '
            'bình máu không cần.',
          ),
        ),
        for (final recipe in Recipe.values)
          Card(
            child: ListTile(
              leading: Icon(recipe.item?.icon ?? Icons.local_drink),
              title: Text(recipe.item == null ? Recipe.potionFor(_grade).label : '${recipe.label} ${_grade.label}'),
              subtitle: Text(
                recipe.ingredients.entries
                        .map((e) => '${e.key.label} ${game.materialCount(e.key, _grade)}/${e.value}')
                        .join(' + ') +
                    (game.hasBlueprintFor(recipe, _grade) ? '' : '\n🔒 Cần bản vẽ ${recipe.label} ${_grade.label}'),
              ),
              trailing: FilledButton(
                onPressed: game.canCraft(recipe, _grade) ? () => _craft(recipe) : null,
                child: const Text('Chế'),
              ),
            ),
          ),
      ],
    );
  }
}
