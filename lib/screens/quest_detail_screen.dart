import 'package:flutter/material.dart';

import '../logic/game_config.dart';
import '../logic/game_state.dart';
import '../logic/quest_resolver.dart';
import '../models/day.dart';
import '../models/hunter.dart';
import '../models/quest.dart';
import '../widgets/hunter_roster_card.dart';
import '../widgets/visuals.dart';
import 'quest_board_screen.dart';

class QuestDetailScreen extends StatefulWidget {
  const QuestDetailScreen({super.key, required this.game, required this.quest});

  final GameState game;
  final Quest quest;

  @override
  State<QuestDetailScreen> createState() => _QuestDetailScreenState();
}

class _QuestDetailScreenState extends State<QuestDetailScreen> {
  final _party = <Hunter>[];

  Quest get quest => widget.quest;
  GameState get game => widget.game;

  void _toggle(Hunter h) {
    setState(() {
      if (_party.remove(h)) return;
      if (_party.length >= quest.maxParty) {
        if (quest.maxParty != 1) return;
        _party.clear(); // Solo: chọn người khác thì thay luôn.
      }
      _party.add(h);
    });
  }

  void _depart() {
    final e = game.dispatch(quest, List.of(_party));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đội đã xuất phát tới ${quest.location.label}, '
          'tới nơi ${describePhase(e.arriveAt)}, trở về ${describePhase(e.returnAt)}.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  /// Vì sao hunter này không đi được quest này (null = đi được).
  String? _blocker(Hunter h) {
    if (h.inHospital) return '🏥 Đang nằm viện';
    if (h.onQuest) return '🚶 Đang đi quest';
    if (game.accused == h) return '⚖ Đang bị điều tra';
    if (quest.promotionFor case final id? when id != h.id) return 'Quest thăng hạng của người khác';
    if (h.level < quest.tier.minLevel) return 'Cần Lv ${quest.tier.minLevel}';
    if (h.maxQuestTier.index < quest.tier.index) return 'Hạng ${h.rank.label} chưa nhận được tier ${quest.tier.label}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final error = game.dispatchError(quest, _party);
    final estimate = QuestResolver.estimate(quest, _party);
    final hunters = [...game.hunters]
      ..sort((a, b) {
        final free = (_blocker(a) == null ? 0 : 1).compareTo(_blocker(b) == null ? 0 : 1);
        return free != 0 ? free : b.level.compareTo(a.level);
      });
    final travel = game.travelTime(quest.location);

    return Scaffold(
      appBar: AppBar(title: Text('[${quest.tier.label}] ${quest.title}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
        children: [
          QuestCard(quest: quest, map: game.map, travel: travel, now: game.canDispatchNow ? game.now : null),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Chọn đội',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  quest.minParty == quest.maxParty
                      ? '${_party.length}/${quest.maxParty} người'
                      : '${_party.length} (cần ${quest.minParty}-${quest.maxParty})',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          for (final h in hunters)
            _PickTile(
              hunter: h,
              blocker: _blocker(h),
              selected: _party.contains(h),
              deathRisk: estimate.deathRisk[h],
              onTap: () => _toggle(h),
            ),
        ],
      ),
      bottomNavigationBar: _DepartBar(
        game: game,
        error: error,
        winRate: _party.isEmpty ? null : estimate.winRate,
        arriveAt: game.now + travel,
        returnAt: game.now + travel * 2,
        onDepart: error == null ? _depart : null,
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.hunter,
    required this.blocker,
    required this.selected,
    required this.deathRisk,
    required this.onTap,
  });

  final Hunter hunter;
  final String? blocker;
  final bool selected;
  final double? deathRisk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final h = hunter;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final enabled = blocker == null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 3),
        color: selected ? colors.primaryContainer : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? colors.primary : Colors.transparent, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled || selected ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            child: Row(
              children: [
                HunterAvatar(hunter: h, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          RankBadge(hunter: h),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              h.name,
                              style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Lv ${h.level} · ${h.hunterClass.label} · 💪${h.power.round()} · 🧪${h.potions.length}',
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      if (blocker case final reason?)
                        Text(reason, style: text.labelSmall?.copyWith(color: colors.error))
                      else
                        HpBar(hunter: h),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(value: selected, onChanged: enabled || selected ? (_) => onTap() : null),
                    if (selected && deathRisk != null)
                      Text('☠ ${percent(deathRisk!)}', style: text.labelSmall?.copyWith(color: Colors.red)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thanh dưới: tỉ lệ thắng (màu theo độ an toàn), giờ về, nút xuất phát.
class _DepartBar extends StatelessWidget {
  const _DepartBar({
    required this.game,
    required this.error,
    required this.winRate,
    required this.arriveAt,
    required this.returnAt,
    required this.onDepart,
  });

  final GameState game;
  final String? error;
  final double? winRate;
  final int arriveAt;
  final int returnAt;
  final VoidCallback? onDepart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rate = winRate;
    final rateColor = rate == null
        ? Colors.grey
        : rate >= 0.8
        ? Colors.green
        : rate >= 0.5
        ? Colors.orange
        : Colors.red;
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rate != null) ...[
                Row(
                  children: [
                    Text('Tỉ lệ thắng', style: text.labelMedium),
                    const Spacer(),
                    Text(
                      percent(rate),
                      style: text.titleMedium?.copyWith(color: rateColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: rate, minHeight: 8, color: rateColor),
                ),
                Text('Mô phỏng ${GameConfig.estimateRuns} trận', style: text.labelSmall),
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  Expanded(
                    child: error != null
                        ? Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
                        : Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              PhaseTag(at: arriveAt, prefix: '⚔', today: game.day),
                              PhaseTag(at: returnAt, prefix: '🏠 Về', today: game.day),
                            ],
                          ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onDepart,
                    icon: const Icon(Icons.flag),
                    label: const Text('Xuất phát'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
