import 'package:flutter/material.dart';

import '../logic/combat.dart';
import '../logic/game_config.dart';
import '../logic/game_state.dart';
import '../models/equipment.dart';
import '../models/hunter.dart';
import '../models/skill.dart';
import '../widgets/equipment_tile.dart';
import '../widgets/hunter_roster_card.dart';
import '../widgets/visuals.dart';

class HunterDetailScreen extends StatelessWidget {
  const HunterDetailScreen({super.key, required this.game, required this.hunter});

  final GameState game;
  final Hunter hunter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(title: Text(hunter.name)),
          body: Column(
            children: [
              _Header(game: game, hunter: hunter),
              const TabBar(
                tabs: [
                  Tab(text: 'Chỉ số'),
                  Tab(text: 'Kỹ năng'),
                  Tab(text: 'Đồ đạc'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _StatsTab(hunter: hunter),
                    _SkillsTab(hunter: hunter),
                    _GearTab(hunter: hunter),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phần đầu luôn hiện: ai, ở đâu, máu, EXP, tiền.
class _Header extends StatelessWidget {
  const _Header({required this.game, required this.hunter});

  final GameState game;
  final Hunter hunter;

  @override
  Widget build(BuildContext context) {
    final h = hunter;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          Row(
            children: [
              HunterAvatar(hunter: h, radius: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        RankBadge(hunter: h),
                        const SizedBox(width: 6),
                        Text('Lv ${h.level}', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        StatusChip(game: game, hunter: h),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${h.hunterClass.label} (${h.damageType.label}) · ${h.rarity.label} · ${h.age} tuổi',
                      style: text.bodySmall?.copyWith(color: h.rarity.color, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          HpBar(hunter: h),
          const SizedBox(height: 4),
          _Bar(
            icon: '✦',
            value: h.exp / h.expToNext,
            color: Colors.blue,
            label: 'EXP ${h.exp}/${h.expToNext}',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Money(icon: '🪙', value: '${h.gold}', label: 'Ví riêng'),
              _Money(icon: '🎒', value: '${gearValue(h)}', label: 'Giá trị đồ'),
              _Money(icon: '🧪', value: '${h.potions.length}/${GameConfig.maxPotions}', label: 'Bình máu'),
              _Money(icon: '📜', value: '${h.questsDone}', label: 'Quest xong'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.icon, required this.value, required this.color, required this.label});

  final String icon;
  final double value;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(icon, style: TextStyle(fontSize: 12, color: color)),
      const SizedBox(width: 4),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: 6, color: color),
        ),
      ),
      const SizedBox(width: 6),
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 64),
        child: Text(label, textAlign: TextAlign.end, style: Theme.of(context).textTheme.labelSmall),
      ),
    ],
  );
}

class _Money extends StatelessWidget {
  const _Money({required this.icon, required this.value, required this.label});

  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text('$icon $value', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
  );
}

// ---------------------------------------------------------------- Chỉ số

class _StatsTab extends StatelessWidget {
  const _StatsTab({required this.hunter});

  final Hunter hunter;

  @override
  Widget build(BuildContext context) {
    final h = hunter;
    final gear = h.equipmentBonus;
    String bonus(double v, {int digits = 0}) => v > 0 ? '+${v.toStringAsFixed(digits)} từ đồ' : 'chưa có đồ cộng';
    final tiles = [
      _StatTile('💪', 'Sức mạnh', h.power.round().toString(), bonus(gear.power)),
      _StatTile('❤', 'Máu tối đa', h.maxHp.round().toString(), bonus(gear.maxHp)),
      _StatTile(
        '🛡',
        'Kháng vật lý',
        h.physRes.round().toString(),
        'giảm ${percent(damageReduction(h.physRes))} s.thương',
      ),
      _StatTile(
        '🔮',
        'Kháng phép',
        h.magicRes.round().toString(),
        'giảm ${percent(damageReduction(h.magicRes))} s.thương',
      ),
      _StatTile('💨', 'Nhanh nhẹn', h.agility.toStringAsFixed(1), bonus(gear.agility, digits: 1)),
      _StatTile('🌀', 'Né tránh', percent(h.evasion), 'tốc độ ${h.speed.toStringAsFixed(1)}'),
    ];
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 84,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          children: tiles,
        ),
        const _SectionTitle('Hạng & danh tiếng'),
        _RankCard(hunter: h),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.icon, this.label, this.value, this.note);

  final String icon;
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$icon $label', style: text.labelSmall),
          Text(value, style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold, height: 1.1)),
          Text(note, style: text.labelSmall?.copyWith(color: Theme.of(context).hintColor), maxLines: 1),
        ],
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.hunter});

  final Hunter hunter;

  @override
  Widget build(BuildContext context) {
    final h = hunter;
    final next = h.nextRank;
    final from = Hunter.fameForRank(h.rank);
    final to = next == null ? null : Hunter.fameForRank(next);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RankBadge(hunter: h),
                const SizedBox(width: 8),
                Expanded(child: Text('Nhận quest tới tier ${h.maxQuestTier.label}')),
                Text('⭐ ${h.fame}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            if (to != null) ...[
              _Bar(
                icon: '⭐',
                value: (h.fame - from) / (to - from),
                color: Colors.amber.shade700,
                label: '${h.fame}/$to → ${next!.label}',
              ),
              const SizedBox(height: 6),
              Text(
                h.canPromote
                    ? '⭐ Fame đã đầy! Vượt quest thăng hạng trên bảng nhiệm vụ để lên hạng ${next.label}.'
                    : 'Làm quest thành công để tích fame. Đầy fame sẽ mở quest thăng hạng.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              Text('Đã đạt hạng tối đa.', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Kỹ năng

class _SkillsTab extends StatelessWidget {
  const _SkillsTab({required this.hunter});

  final Hunter hunter;

  @override
  Widget build(BuildContext context) {
    final h = hunter;
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Card(
          margin: EdgeInsets.zero,
          color: colors.tertiaryContainer,
          child: ListTile(
            leading: Icon(Icons.stars, color: colors.onTertiaryContainer),
            title: Text(
              'Nội tại · ${h.hunterClass.passiveName}',
              style: TextStyle(fontWeight: FontWeight.bold, color: colors.onTertiaryContainer),
            ),
            subtitle: Text(h.hunterClass.passiveDescription, style: TextStyle(color: colors.onTertiaryContainer)),
          ),
        ),
        if (h.skillScale > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              '✨ Độ hiếm ${h.rarity.label}: mọi skill (trừ đánh thường) mạnh thêm '
              '${((h.skillScale - 1) * 100).round()}%.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: h.rarity.color),
            ),
          ),
        const _SectionTitle('Trong trận'),
        _SkillCard(kind: 'Đánh thường', icon: Icons.front_hand, skill: basicAttack),
        for (final (kind, icon, skill) in skillSlots(h))
          _SkillCard(
            kind: kind,
            icon: icon,
            skill: skill,
            highlight: skill == h.ultimate,
            note: skill == h.ultimate
                ? 'Tung khi năng lượng đầy ${GameConfig.maxEnergy.round()} '
                      '(+${GameConfig.energyPerAction.round()} mỗi lượt, +${GameConfig.energyWhenHit.round()} khi bị đánh)'
                : null,
          ),
      ],
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.kind, required this.icon, required this.skill, this.highlight = false, this.note});

  final String kind;
  final IconData icon;
  final Skill? skill;
  final bool highlight;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final s = skill;
    final text = Theme.of(context).textTheme;
    final color = highlight ? Colors.amber.shade800 : Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: highlight
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: color.withValues(alpha: 0.6)),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, size: 18, color: s == null ? Theme.of(context).disabledColor : color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(kind.toUpperCase(), style: text.labelSmall?.copyWith(color: color, letterSpacing: 0.5)),
                      ),
                      if (s != null && s.cooldown > 0)
                        Text('⏱ hồi ${s.cooldown} lượt', style: text.labelSmall),
                    ],
                  ),
                  Text(
                    s?.name ?? 'Chưa có',
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    s?.description ?? 'Cần cầm vũ khí còn dùng được (không hỏng).',
                    style: text.bodySmall,
                  ),
                  if (note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(note!, style: text.labelSmall?.copyWith(color: Theme.of(context).hintColor)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Đồ đạc

class _GearTab extends StatelessWidget {
  const _GearTab({required this.hunter});

  final Hunter hunter;

  @override
  Widget build(BuildContext context) {
    final h = hunter;
    final small = Theme.of(context).textTheme.bodySmall;
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        const _SectionTitle('Đang mặc (mua ở Nhà rèn)'),
        for (final slot in EquipSlot.values) _SlotCard(hunter: h, slot: slot),
        _SectionTitle('Kho riêng (${h.stash.length})'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Đồ nhặt được hoặc vừa thay ra. Mỗi sáng hunter tự mặc món tốt hơn; mỗi ô giữ tối đa '
            '${GameConfig.maxStashPerSlot} món, thừa thì bán món yếu nhất cho guild. Hunter hy sinh: guild mua lại '
            'kho riêng với ${percent(GameConfig.estateBuybackRate)} giá, đồ đang mặc hư luôn.',
            style: small,
          ),
        ),
        if (h.stash.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Trống.')),
        for (final item in h.stash) EquipmentTile(item: item),
        _SectionTitle('Bình máu (${h.potions.length}/${GameConfig.maxPotions}, mua ở Tiệm thuốc)'),
        if (h.potions.isEmpty)
          const Padding(padding: EdgeInsets.all(8), child: Text('Không có.'))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in h.potions)
                Chip(
                  avatar: const Icon(Icons.local_drink, color: Colors.red, size: 18),
                  label: Text('${p.label} · ${percent(p.healPercent)}'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            'Trong trận, máu dưới ${percent(GameConfig.battlePotionThreshold)} thì tự uống (không mất lượt).',
            style: small,
          ),
        ),
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.hunter, required this.slot});

  final Hunter hunter;
  final EquipSlot slot;

  @override
  Widget build(BuildContext context) {
    final item = hunter.equipment[slot];
    final text = Theme.of(context).textTheme;
    if (item == null) {
      final blocked = slot == EquipSlot.offHand && (hunter.equipment[EquipSlot.mainHand]?.type.twoHanded ?? false);
      return Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          dense: true,
          leading: Icon(Icons.crop_square, color: Theme.of(context).disabledColor),
          title: Text(slot.label),
          subtitle: Text(blocked ? 'Đang cầm vũ khí 2 tay' : 'Trống'),
        ),
      );
    }
    const max = GameConfig.maxDurability;
    final color = item.isBroken ? Colors.red : item.grade.color;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              foregroundColor: color,
              child: Icon(item.type.icon),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: text.titleSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text('${item.price} 🪙', style: text.labelMedium),
                    ],
                  ),
                  Text('${slot.label}${item.type.twoHanded ? ' (2 tay)' : ''}', style: text.labelSmall),
                  Text(describeStats(item.bonus), style: text.bodySmall),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(item.isBroken ? '🔧 HỎNG' : '🔧', style: text.labelSmall?.copyWith(color: color)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (item.condition / max).clamp(0, 1),
                            minHeight: 5,
                            color: item.condition / max < 0.3 ? Colors.red : Colors.teal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${item.condition.ceil()}/$max · bền ${item.durability.ceil()}',
                        style: text.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
