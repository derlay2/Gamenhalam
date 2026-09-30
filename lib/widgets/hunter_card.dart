import 'package:flutter/material.dart';

import '../models/hunter.dart';
import 'visuals.dart';

class HunterCard extends StatelessWidget {
  const HunterCard({super.key, required this.hunter, this.trailing, this.onTap, this.enabled = true});

  final Hunter hunter;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final h = hunter;
    final textTheme = Theme.of(context).textTheme;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Card(
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: h.rarity.color.withValues(alpha: 0.2),
                  foregroundColor: h.rarity.color,
                  child: Icon(h.hunterClass.icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: h.rank.color, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              h.rank.label,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(child: Text('${h.name} · Lv ${h.level}', style: textTheme.titleMedium)),
                        ],
                      ),
                      Text(
                        '${h.hunterClass.label} (${h.damageType.label}) · '
                        '${h.rarity.label} · ${h.age} tuổi · ✨ ${h.personalSkill.name} · '
                        'ví ${h.gold} 🪙 · 🧪${h.potions.length}',
                        style: textTheme.bodySmall?.copyWith(color: h.rarity.color),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sức mạnh ${h.power.round()} · Máu ${h.maxHp.round()} · '
                        'Kháng VL ${h.physRes.round()} / Phép ${h.magicRes.round()} · '
                        'Nhanh nhẹn ${h.agility.round()} (né ${percent(h.evasion)})',
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: h.hpRatio, color: h.hpRatio < 0.8 ? Colors.red : Colors.green),
                      Text(
                        'HP ${h.hp.round()}/${h.maxHp.round()}'
                        '${h.inHospital ? ' · 🏥 Đang nằm viện' : ''}'
                        '${h.onQuest ? ' · 🚶 Đang làm nhiệm vụ' : ''}',
                        style: textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: h.exp / h.expToNext),
                      Text('EXP ${h.exp}/${h.expToNext}', style: textTheme.labelSmall),
                      Text(
                        switch (h.nextRank) {
                          final next? when h.canPromote =>
                            '⭐ Fame đầy! Vượt quest thăng hạng để lên ${next.label} · '
                                'nhận quest tới tier ${h.maxQuestTier.label}',
                          final next? => '⭐ Fame ${h.fame}/${Hunter.fameForRank(next)} lên hạng ${next.label} · '
                              'nhận quest tới tier ${h.maxQuestTier.label}',
                          null => '⭐ Fame ${h.fame} · hạng tối đa',
                        },
                        style: textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
