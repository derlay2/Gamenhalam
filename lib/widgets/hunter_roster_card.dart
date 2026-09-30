import 'package:flutter/material.dart';

import '../logic/game_state.dart';
import '../models/day.dart';
import '../models/equipment.dart';
import '../models/hunter.dart';
import '../models/skill.dart';
import 'visuals.dart';

/// Thẻ hunter gọn cho màn hình dọc: nhìn một lượt biết hạng, máu, tiền, đồ đang mặc và skill.
class HunterRosterCard extends StatelessWidget {
  const HunterRosterCard({super.key, required this.game, required this.hunter, this.onTap});

  final GameState game;
  final Hunter hunter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final h = hunter;
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HunterAvatar(hunter: h),
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
                                style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Lv ${h.level} · ${h.hunterClass.label} · ${h.rarity.label}',
                          style: text.bodySmall?.copyWith(color: h.rarity.color, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(game: game, hunter: h),
                ],
              ),
              const SizedBox(height: 8),
              HpBar(hunter: h),
              const SizedBox(height: 6),
              Row(
                children: [
                  InfoPill(icon: '🪙', text: '${h.gold}'),
                  InfoPill(icon: '🧪', text: '${h.potions.length}'),
                  InfoPill(icon: '💪', text: '${h.power.round()}'),
                  InfoPill(icon: '💨', text: '${h.agility.round()}'),
                  if (h.canPromote) const InfoPill(icon: '⭐', text: 'Thăng hạng!', highlight: true),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final slot in EquipSlot.values) Expanded(child: GearSlotChip(hunter: h, slot: slot)),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  SkillChip(icon: Icons.auto_awesome, label: h.personalSkill.name),
                  if (h.weaponSkill case final s?) SkillChip(icon: Icons.colorize, label: s.name),
                  if (h.bonusSkill case final s?) SkillChip(icon: Icons.shield_moon, label: s.name),
                  SkillChip(icon: Icons.bolt, label: h.ultimate.name, color: Colors.amber.shade800),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HunterAvatar extends StatelessWidget {
  const HunterAvatar({super.key, required this.hunter, this.radius = 22});

  final Hunter hunter;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: hunter.rarity.color, width: 2),
    ),
    child: CircleAvatar(
      radius: radius,
      backgroundColor: hunter.rarity.color.withValues(alpha: 0.15),
      foregroundColor: hunter.rarity.color,
      child: Icon(hunter.hunterClass.icon, size: radius),
    ),
  );
}

class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.hunter});

  final Hunter hunter;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(color: hunter.rank.color, borderRadius: BorderRadius.circular(4)),
    child: Text(
      hunter.rank.label,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
    ),
  );
}

/// Hunter đang ở đâu: thị trấn, bệnh viện, hay đi quest (kèm giờ về).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.game, required this.hunter});

  final GameState game;
  final Hunter hunter;

  static (String, Color) describe(GameState game, Hunter h) {
    if (h.inHospital) return ('🏥 Nằm viện', Colors.red);
    if (h.onQuest) {
      final trip = game.expeditions.where((e) => e.party.contains(h)).firstOrNull;
      final (day, phase) = phaseAt(trip?.returnAt ?? game.now);
      return (trip == null ? '🚶 Đi quest' : '🚶 Về N$day ${phase.label}', Colors.indigo);
    }
    return ('🏠 Rảnh', Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = describe(game, hunter);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class HpBar extends StatelessWidget {
  const HpBar({super.key, required this.hunter});

  final Hunter hunter;

  @override
  Widget build(BuildContext context) {
    final h = hunter;
    final color = h.hpRatio >= 0.8
        ? Colors.green
        : h.hpRatio >= 0.4
        ? Colors.orange
        : Colors.red;
    return Row(
      children: [
        const Text('❤', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: h.hpRatio.clamp(0, 1), minHeight: 8, color: color),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 64,
          child: Text(
            '${h.hp.round()}/${h.maxHp.round()}',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.icon, required this.text, this.highlight = false});

  final String icon;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: Text(
      '$icon $text',
      style: TextStyle(
        fontSize: 12,
        fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
        color: highlight ? Colors.amber.shade800 : null,
      ),
    ),
  );
}

/// Ô trang bị nhỏ: icon + tên ngắn, màu theo cấp đồ; đỏ nếu hỏng, mờ nếu trống.
class GearSlotChip extends StatelessWidget {
  const GearSlotChip({super.key, required this.hunter, required this.slot});

  final Hunter hunter;
  final EquipSlot slot;

  @override
  Widget build(BuildContext context) {
    final item = hunter.equipment[slot];
    final blocked = slot == EquipSlot.offHand && (hunter.equipment[EquipSlot.mainHand]?.type.twoHanded ?? false);
    final color = item == null
        ? Theme.of(context).disabledColor
        : item.isBroken
        ? Colors.red
        : item.grade.color;
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(item?.type.icon ?? Icons.crop_square, size: 14, color: color),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              item == null
                  ? (blocked ? '2 tay' : slot.label)
                  : '${item.type.label}${item.isBroken ? ' ⚠' : ''}',
              style: TextStyle(fontSize: 11, color: color, fontWeight: item == null ? null : FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class SkillChip extends StatelessWidget {
  const SkillChip({super.key, required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: c)),
        ],
      ),
    );
  }
}

/// Tổng giá niêm yết của đồ đang mặc và trong kho riêng.
int gearValue(Hunter h) => [...h.equipment.values, ...h.stash].fold(0, (sum, e) => sum + e.price);

/// Bộ skill đầy đủ để hiển thị theo thứ tự trong trận.
List<(String, IconData, Skill?)> skillSlots(Hunter h) => [
  ('Skill bản thân', Icons.auto_awesome, h.personalSkill),
  ('Skill vũ khí', Icons.colorize, h.weaponSkill),
  if (h.bonusSkill case final s?) ('Đòn riêng của char', Icons.shield_moon, s),
  ('Tối thượng', Icons.bolt, h.ultimate),
];
