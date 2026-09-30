import 'package:flutter/material.dart';

import '../logic/game_state.dart';
import '../models/hunter.dart';
import '../widgets/hunter_roster_card.dart';
import 'hunter_detail_screen.dart';

enum _Filter {
  all('Tất cả'),
  idle('Rảnh'),
  quest('Đi quest'),
  hospital('Nằm viện');

  const _Filter(this.label);
  final String label;

  bool matches(Hunter h) => switch (this) {
    _Filter.all => true,
    _Filter.idle => h.isAvailable,
    _Filter.quest => h.onQuest,
    _Filter.hospital => h.inHospital,
  };
}

enum _Sort {
  rank('Hạng'),
  level('Cấp'),
  hunterClass('Char'),
  gold('Tiền'),
  hp('Máu');

  const _Sort(this.label);
  final String label;

  int compare(Hunter a, Hunter b) => switch (this) {
    _Sort.rank => b.rank.index.compareTo(a.rank.index) != 0
        ? b.rank.index.compareTo(a.rank.index)
        : b.fame.compareTo(a.fame),
    _Sort.level => b.level.compareTo(a.level),
    _Sort.hunterClass => a.hunterClass.index.compareTo(b.hunterClass.index) != 0
        ? a.hunterClass.index.compareTo(b.hunterClass.index)
        : b.level.compareTo(a.level),
    _Sort.gold => b.gold.compareTo(a.gold),
    _Sort.hp => a.hpRatio.compareTo(b.hpRatio),
  };
}

class HunterListScreen extends StatefulWidget {
  const HunterListScreen({super.key, required this.game});

  final GameState game;

  @override
  State<HunterListScreen> createState() => _HunterListScreenState();
}

class _HunterListScreenState extends State<HunterListScreen> {
  var _filter = _Filter.all;
  var _sort = _Sort.rank;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        if (game.hunters.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Guild chưa có hunter nào. Hãy ghé Hiệp hội trong Thị trấn!', textAlign: TextAlign.center),
            ),
          );
        }
        final shown = game.hunters.where(_filter.matches).toList()..sort(_sort.compare);
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Summary(game: game)),
            SliverToBoxAdapter(child: _controls(context, game)),
            if (shown.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Không có hunter nào ở mục này.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                sliver: SliverList.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, i) => HunterRosterCard(
                    game: game,
                    hunter: shown[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => HunterDetailScreen(game: game, hunter: shown[i])),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _controls(BuildContext context, GameState game) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
    child: Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _Filter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('${f.label} ${game.hunters.where(f.matches).length}'),
                      selected: _filter == f,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
        ),
        PopupMenuButton<_Sort>(
          tooltip: 'Sắp xếp',
          initialValue: _sort,
          onSelected: (s) => setState(() => _sort = s),
          itemBuilder: (_) => [for (final s in _Sort.values) PopupMenuItem(value: s, child: Text('Theo ${s.label}'))],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [const Icon(Icons.sort, size: 18), const SizedBox(width: 2), Text(_sort.label)],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Dải tổng quan đầu danh sách.
class _Summary extends StatelessWidget {
  const _Summary({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    final hunters = game.hunters;
    final colors = Theme.of(context).colorScheme;
    Widget cell(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      color: colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            cell('${hunters.length}', 'Hunter'),
            cell('${hunters.where((h) => h.isAvailable).length}', '🏠 Rảnh'),
            cell('${hunters.where((h) => h.onQuest).length}', '🚶 Đi quest'),
            cell('${hunters.where((h) => h.inHospital).length}', '🏥 Nằm viện'),
            cell('${hunters.fold(0, (s, h) => s + h.gold)}', '🪙 Tổng ví'),
          ],
        ),
      ),
    );
  }
}
