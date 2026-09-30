import 'dart:math';

import 'package:flutter/material.dart';

import '../logic/game_config.dart';
import '../logic/game_state.dart';
import '../models/crafting.dart';
import '../models/day.dart';
import '../models/enums.dart';
import '../models/quest.dart';
import '../models/world_map.dart';
import '../widgets/visuals.dart';
import 'quest_detail_screen.dart';

enum _QuestFilter {
  all('Tất cả'),
  hunt('Săn'),
  gather('Thu thập'),
  solo('Solo'),
  group('Nhóm'),
  special('Đặc biệt');

  const _QuestFilter(this.label);
  final String label;

  bool matches(Quest q) => switch (this) {
    _QuestFilter.all => true,
    _QuestFilter.hunt => !q.isGathering,
    _QuestFilter.gather => q.isGathering,
    _QuestFilter.solo => !q.isGroup,
    _QuestFilter.group => q.isGroup,
    _QuestFilter.special => q.isSpecial || q.isRoyal,
  };
}

class QuestBoardScreen extends StatefulWidget {
  const QuestBoardScreen({super.key, required this.game});

  final GameState game;

  @override
  State<QuestBoardScreen> createState() => _QuestBoardScreenState();
}

class _QuestBoardScreenState extends State<QuestBoardScreen> {
  var _filter = _QuestFilter.all;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final quests = game.quests.where(_filter.matches).toList()
          ..sort((a, b) {
            // Quest đặc biệt lên đầu, rồi tier cao trước.
            final special = (b.isSpecial ? 1 : 0).compareTo(a.isSpecial ? 1 : 0);
            return special != 0 ? special : b.tier.index.compareTo(a.tier.index);
          });
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: PhaseBanner(game: game)),
              if (game.expeditions.isNotEmpty) ...[
                _header(context, '🚶 Đang làm nhiệm vụ (${game.expeditions.length})'),
                SliverList.list(
                  children: [
                    for (final e in [...game.expeditions]..sort((a, b) => a.returnAt.compareTo(b.returnAt)))
                      ExpeditionCard(expedition: e, game: game),
                  ],
                ),
              ],
              _header(context, '📋 Bảng nhiệm vụ (${game.quests.length})'),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      for (final f in _QuestFilter.values)
                        if (f != _QuestFilter.special || game.quests.any(f.matches))
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text('${f.label} ${game.quests.where(f.matches).length}'),
                              selected: _filter == f,
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) => setState(() => _filter = f),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              if (quests.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Không có quest nào ở mục này.'))),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 88),
                sliver: SliverList.builder(
                  itemCount: quests.length,
                  itemBuilder: (context, i) {
                    final q = quests[i];
                    return QuestCard(
                      quest: q,
                      map: game.map,
                      now: game.canDispatchNow ? game.now : null,
                      owner: game.hunters.where((h) => h.id == q.promotionFor).firstOrNull?.name,
                      travel: game.travelTime(q.location),
                      onTap: () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute<void>(builder: (_) => QuestDetailScreen(game: game, quest: q))),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: game.canRefresh ? game.refreshQuests : null,
            icon: const Icon(Icons.refresh),
            label: const Text('Làm mới (${GameConfig.refreshCost} 🪙)'),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, String text) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
    ),
  );
}

/// Dải màu theo buổi: đang là buổi nào, có giao nhiệm vụ được không, 3 buổi trong ngày.
class PhaseBanner extends StatelessWidget {
  const PhaseBanner({super.key, required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    final phase = game.phase;
    final color = phase.color;
    final hint = switch (phase) {
      DayPhase.morning => 'Giao nhiệm vụ được. Đội đi gần có thể về ngay trong đêm nay.',
      DayPhase.noon => 'Vẫn giao được nhiệm vụ, nhưng đội sẽ về muộn hơn đi từ sáng 1 buổi.',
      DayPhase.night => 'Ban đêm không giao nhiệm vụ. Sang sáng mai sẽ có tổng kết ngày và quest mới.',
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.25)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(phase.icon, color: Colors.white, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ngày ${game.day} · ${phase.label}',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: game.canDispatchNow ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    game.canDispatchNow ? '✅ Giao được' : '⛔ Nghỉ đêm',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(hint, style: const TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final p in DayPhase.values) ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: p == phase ? Colors.white : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(p.icon, size: 14, color: p == phase ? p.color : Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            p.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: p == phase ? p.color : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (p != DayPhase.values.last) const SizedBox(width: 6),
                ],
              ],
            ),
            if (game.rank.next case final next?) ...[
              const SizedBox(height: 8),
              Text(
                '🏅 Thị trấn hạng ${game.rank.label}: quest tới tier ${game.rank.maxQuestTier.label} · '
                'lên ${next.label} cần ${game.effectiveReputation}/${next.minReputation} danh tiếng',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Đội đang đi: tiến độ chuyến đi và mốc tới nơi / trở về tô màu theo buổi.
class ExpeditionCard extends StatelessWidget {
  const ExpeditionCard({super.key, required this.expedition, required this.game});

  final Expedition expedition;
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final e = expedition;
    final now = game.now;
    final stage = e.stageAt(now);
    final progress = ((now - e.departAt) / max(1, e.returnAt - e.departAt)).clamp(0.0, 1.0);
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TierBadge(quest: e.quest, size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.quest.title, style: text.titleSmall, overflow: TextOverflow.ellipsis),
                      Text(
                        '${stage.label} ${e.quest.location.label} · ${e.party.map((h) => h.name).join(', ')}',
                        style: text.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: stage == ExpeditionStage.returning ? Colors.green : game.phase.color,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                PhaseTag(at: e.arriveAt, prefix: '⚔', today: game.day),
                PhaseTag(at: e.returnAt, prefix: '🏠 Về', today: game.day),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ô vuông tier, có biểu tượng loại quest.
class TierBadge extends StatelessWidget {
  const TierBadge({super.key, required this.quest, this.size = 44});

  final Quest quest;
  final double size;

  @override
  Widget build(BuildContext context) {
    final q = quest;
    final icon = q.isPromotion
        ? Icons.military_tech
        : q.isRenegade
        ? Icons.person_off
        : q.isRoyal
        ? Icons.workspace_premium
        : q.isGathering
        ? Icons.hardware
        : q.isHorde
        ? Icons.groups
        : Icons.pets;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: q.tier.color, borderRadius: BorderRadius.circular(size * 0.22)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            q.tier.label,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.34, height: 1),
          ),
          Icon(icon, color: Colors.white, size: size * 0.32),
        ],
      ),
    );
  }
}

class QuestCard extends StatelessWidget {
  const QuestCard({super.key, required this.quest, required this.map, this.onTap, this.owner, this.travel, this.now});

  final Quest quest;
  final WorldMap map;
  final VoidCallback? onTap;

  /// Tên hunter được làm quest thăng hạng này.
  final String? owner;

  /// Số buổi đi nếu xuất phát bây giờ (thời tiết có thể làm chậm); null = theo bản đồ.
  final int? travel;

  /// Nếu có: hiện mốc tới nơi / trở về khi xuất phát lúc này.
  final int? now;

  @override
  Widget build(BuildContext context) {
    final q = quest;
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final normal = map.travelTime(Location.town, q.location);
    final days = travel ?? normal;
    final special = q.isPromotion
        ? '⭐ Quest thăng hạng${owner == null ? '' : ' của $owner'} · thắng: lên hạng ${q.tier.label} · '
              'thua: mất ${percent(GameConfig.promotionFailFameLoss)} fame'
        : q.isGathering
        ? '⛏ Thu thập ${q.location.gatherables.map((r) => r.label).join(', ')} (${q.tier.materialGrade.label}) · '
              'nhiều nguyên liệu, ít EXP'
        : null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: q.isSpecial ? colors.tertiaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: q.tier.color, width: 4))),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TierBadge(quest: q),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q.title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          '📍 ${q.location.label} · đi $days buổi'
                          '${days > normal ? ' (🌨 chậm)' : ''}',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${q.gold} 🪙', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text('guild +${(q.gold * GameConfig.questTaxRate).round()}', style: text.labelSmall),
                      Text('${q.exp} EXP', style: text.labelSmall),
                    ],
                  ),
                ],
              ),
              if (special != null) ...[
                const SizedBox(height: 6),
                Text(special, style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _Tag(q.isGroup ? '👥 Nhóm ${q.minParty}-${q.maxParty}' : '👤 Solo'),
                  _Tag(q.isHorde ? '🐺 Quái đông' : '👹 Quái ít'),
                  _Tag('${q.monster.attack == DamageType.physical ? '🗡' : '🔮'} Đánh ${q.monster.attack.label}'),
                  _Tag('Lv ≥ ${q.tier.minLevel}'),
                  _Tag('Hạng ≥ ${QuestTier.values[max(0, q.tier.index - GameConfig.hunterRankQuestReach)].label}'),
                  if (q.monster.physRes > 0) _Tag('Kháng VL ${percent(q.monster.physRes)}'),
                  if (q.monster.magicRes > 0) _Tag('Kháng phép ${percent(q.monster.magicRes)}'),
                ],
              ),
              if (now case final start?) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Đi ngay:', style: text.labelSmall),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          PhaseTag(at: start + days, prefix: '⚔', today: phaseAt(start).$1),
                          PhaseTag(at: start + days * 2, prefix: '🏠 Về', today: phaseAt(start).$1),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: const TextStyle(fontSize: 11)),
  );
}
