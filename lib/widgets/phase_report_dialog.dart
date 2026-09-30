import 'package:flutter/material.dart';

import '../logic/game_config.dart';
import '../models/crafting.dart';
import '../logic/shopping.dart';
import '../models/day.dart';
import '../models/equipment.dart';
import '../models/events.dart';
import '../models/hunter.dart';
import 'visuals.dart';

class PhaseReportDialog extends StatelessWidget {
  const PhaseReportDialog({super.key, required this.report});

  final PhaseReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final titleStyle = Theme.of(context).textTheme.titleSmall;
    final isEmpty =
        r.returns.isEmpty &&
        r.healed.isEmpty &&
        r.purchases.isEmpty &&
        !r.rankChanged &&
        r.gameOver == null &&
        r.newEvent == null &&
        r.siege == null &&
        r.caravans.isEmpty &&
        r.newPromotions.isEmpty &&
        r.eventOutcome == null;

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: r.phase.color,
            child: Icon(r.phase.icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('Ngày ${r.day} · ${r.phase.label}', style: TextStyle(color: r.phase.color))),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.gameOver case final reason?)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.dangerous),
                    title: Text('💀 Game over: ${reason.label}'),
                    subtitle: Text(reason.description),
                  ),
                ),
              if (r.rankChanged && r.rankAfter != null && r.rankBefore != null)
                Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: Icon(r.rankAfter!.index > r.rankBefore!.index ? Icons.trending_up : Icons.trending_down),
                    title: Text(
                      r.rankAfter!.index > r.rankBefore!.index
                          ? '🏅 Thị trấn lên hạng ${r.rankAfter!.label}!'
                          : '⚠ Thị trấn bị hạ xuống hạng ${r.rankAfter!.label}',
                    ),
                    subtitle: Text(
                      'Bảng nhiệm vụ giờ có quest tới tier ${r.rankAfter!.maxQuestTier.label} '
                      '(áp dụng cho quest mới).',
                    ),
                  ),
                ),
              if (isEmpty) const Text('Không có gì mới.'),
              if (r.healed.isNotEmpty) ...[
                Text('🏥 Bệnh viện', style: titleStyle),
                for (final MapEntry(key: h, value: amount) in r.healed.entries)
                  Text(
                    '${h.name}: +${amount.round()} HP'
                    '${r.discharged.contains(h) ? ' · xuất viện' : ' (${h.hp.round()}/${h.maxHp.round()})'}',
                  ),
                const SizedBox(height: 12),
              ],
              if (r.newEvent case final e?)
                Card(
                  color: e.type.isDanger
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: Icon(e.type.isDanger ? Icons.warning_amber : Icons.celebration),
                    title: Text('Sự kiện tuần này: ${e.type.label}'),
                    subtitle: Text(
                      e.type == WeeklyEventType.siege
                          ? '${e.type.description}\nQuái tấn công vào đêm ngày ${e.siegeDay}. '
                                'Cử hunter thủ thành ở tab Thị trấn.'
                          : e.type.hasChoice
                          ? '${e.type.description}\n⚠ Vào tab Thị trấn để quyết định trước sáng mai (không chọn = B).'
                          : e.type.description,
                    ),
                  ),
                ),
              if (r.eventOutcome case final outcome?)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.gavel),
                    title: const Text('Bạn không quyết định kịp, sự kiện tự chọn B'),
                    subtitle: Text(outcome),
                  ),
                ),
              if (r.siege case final s?) ...[
                Text('🏰 Thủ thành', style: titleStyle),
                Text(
                  s.defenders.isEmpty
                      ? '❌ Không có hunter nào thủ thành!'
                      : '${s.won ? '✅ Đẩy lùi' : '❌ Thất thủ trước'} bầy quái · '
                            '${s.defenders.map((h) => h.name).join(', ')}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (s.repairCost > 0) Text('Công trình hư hại: sửa mất ${s.repairCost} 🪙'),
                Text('Danh tiếng thị trấn ${s.reputation >= 0 ? '+' : ''}${s.reputation}'),
                if (s.result case final result?)
                  for (final MapEntry(key: h, value: taken) in result.damageTaken.entries)
                    Text('${h.name}: -${taken.round()} HP${h.inHospital ? ' · 🏥 nhập viện' : ''}'),
                for (final h in s.result?.deaths ?? const [])
                  Text('☠ ${h.name} đã hy sinh', style: const TextStyle(color: Colors.red)),
                for (final estate in s.estates) EstateLine(estate: estate),
                const SizedBox(height: 12),
              ],
              for (final c in r.caravans)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping),
                    title: Text('🚚 Nhân viên đi ${c.placeLabel} đã về'),
                    subtitle: Text(c.goods.map((o) => o.label).join(', ')),
                  ),
                ),
              for (final h in r.newPromotions)
                Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.military_tech),
                    title: Text('⭐ ${h.name} đủ fame lên hạng ${h.nextRank!.label}'),
                    subtitle: const Text('Có quest thăng hạng riêng trên bảng nhiệm vụ. Fame sẽ dừng lại tới khi vượt qua.'),
                  ),
                ),
              if (r.returns.isNotEmpty) ...[
                Text('🚩 Đội trở về', style: titleStyle),
                for (final e in r.returns) ExpeditionResultView(report: e),
              ],
              if (r.newLotCount > 0) ...[
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2),
                    title: Text('📦 ${r.newLotCount} lô nguyên liệu mới ở Trạm thu mua'),
                    subtitle: const Text('Giữ ${GameConfig.materialLotDays} ngày, sau đó hunter sẽ bán chỗ khác.'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (r.provisions > 0) ...[
                Text('🌨 Thời tiết xấu: hunter trả ${r.provisions} 🪙 nhu yếu phẩm (tiền ra khỏi thị trấn)'),
                const SizedBox(height: 12),
              ],
              if (r.stocks case final s?) ...[
                Text('📈 Sàn chứng khoán', style: titleStyle),
                Text(
                  'Tăng mạnh nhất ${s.topGainer.key.ticker} ${_pct(s.topGainer.value)} · '
                  'giảm mạnh nhất ${s.topLoser.key.ticker} ${_pct(s.topLoser.value)}',
                ),
                for (final n in s.news) Text('📰 ${n.company.ticker}: ${n.text} (${_pct(n.change)})'),
                if (s.dividendTotal > 0)
                  Text(
                    '💰 Cổ tức tuần: +${s.dividendTotal} 🪙 '
                    '(${s.dividends.entries.map((e) => '${e.key.ticker} ${e.value}').join(', ')})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 12),
              ],
              if (r.purchases.isNotEmpty) ...[
                Text('🛒 Hunter mua sắm', style: titleStyle),
                PurchasesView(purchases: r.purchases),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
    );
  }
}

String _pct(double v) => '${v >= 0 ? '+' : ''}${(v * 100).toStringAsFixed(1)}%';

class ExpeditionResultView extends StatelessWidget {
  const ExpeditionResultView({super.key, required this.report});

  final ExpeditionReport report;

  @override
  Widget build(BuildContext context) {
    final e = report;
    final r = e.result;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${r.success ? '✅' : '❌'} [${e.quest.tier.label}] ${e.quest.title} '
            '(${percent(r.successChance)})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text('⚔ ${e.quest.title} · ${r.rounds} chu kỳ'),
                  content: SizedBox(
                    width: 480,
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final line in r.battleLog)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(line, style: Theme.of(context).textTheme.bodySmall),
                          ),
                      ],
                    ),
                  ),
                  actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Đóng'))],
                ),
              ),
              icon: const Icon(Icons.sports_martial_arts, size: 16),
              label: Text('Xem trận đánh (${r.rounds} chu kỳ)'),
            ),
          ),
          if (r.gold > 0)
            Text('Thưởng ${r.gold}: guild +${e.guildShare} · mỗi hunter sống sót +${e.hunterShareEach} vào ví'),
          if (e.blueprint case final b?)
            Text('🎁 Nhặt được ${b.label}, đã mang về cho guild!', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            '+${r.expEach} EXP · +${r.fameEach} fame mỗi hunter · '
            'Danh tiếng thị trấn ${e.reputation >= 0 ? '+' : ''}${e.reputation}',
          ),
          for (final MapEntry(key: h, value: rank) in r.rankUps.entries)
            Text('⭐ ${h.name} vượt thử thách, lên hạng ${rank.label}!', style: const TextStyle(fontWeight: FontWeight.bold)),
          for (final MapEntry(key: h, value: lost) in r.fameLost.entries)
            Text(
              '⭐ ${h.name} thua quest thăng hạng: -$lost fame, phải cày lại',
              style: const TextStyle(color: Colors.red),
            ),
          for (final MapEntry(key: h, value: levels) in r.levelUps.entries)
            Text(
              [
                '${h.name}: -${r.damageTaken[h]!.round()} HP',
                if ((r.healed[h] ?? 0) > 0) '+${r.healed[h]!.round()} HP (healer)',
                if (r.potionsUsed[h] case final potions?) 'uống ${potions.map((p) => p.label).join(', ')}',
                if (levels > 0) '⬆ Lv ${h.level}',
                for (final item in r.brokenItems[h] ?? const []) '🔧 ${item.name} hỏng, cần sửa',
                for (final item in r.destroyedItems[h] ?? const []) '💥 ${item.name} hết độ bền, vỡ vụn',
                if (r.loot[h] case final bag?)
                  '🎒 ${bag.entries.map((e) => '${e.value} ${e.key.label}').join(', ')} '
                      '(${e.quest.tier.materialGrade.label})',
                if (h.inHospital) '🏥 nhập viện',
              ].join(' · '),
            ),
          for (final h in r.deaths) Text('☠ ${h.name} đã hy sinh', style: const TextStyle(color: Colors.red)),
          for (final d in e.gearDrops) GearDropLine(drop: d),
          for (final s in e.estates) EstateLine(estate: s),
        ],
      ),
    );
  }
}

/// Tự hiện khi chuyển từ đêm sang sáng: tổng kết ngày vừa qua.
class DailySummaryDialog extends StatelessWidget {
  const DailySummaryDialog({super.key, required this.today, this.yesterday});

  final DailyReport today;
  final DailyReport? yesterday;

  @override
  Widget build(BuildContext context) {
    final t = today;
    final text = Theme.of(context).textTheme;
    final net = t.goldEnd - t.goldStart;
    Widget big(String label, String value, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(value, style: text.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
            Text(label, style: text.labelSmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          gradient: LinearGradient(colors: [DayPhase.night.color, DayPhase.morning.color]),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_stories, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tổng kết ngày ${t.day}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  big('Vàng cuối ngày', '${t.goldEnd} 🪙', Colors.amber.shade800),
                  big('Lời / lỗ', '${net >= 0 ? '+' : ''}$net', net >= 0 ? Colors.green : Colors.red),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  big('Quest thắng', '✅ ${t.succeeded}', Colors.green),
                  big('Quest thua', '❌ ${t.failed}', t.failed > 0 ? Colors.red : Colors.grey),
                  big('Hy sinh', '☠ ${t.deaths}', t.deaths > 0 ? Colors.red : Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              DailySummaryView(today: t, yesterday: yesterday),
            ],
          ),
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Bắt đầu ngày mới'))],
    );
  }
}

class DailySummaryView extends StatelessWidget {
  const DailySummaryView({super.key, required this.today, this.yesterday});

  final DailyReport today;
  final DailyReport? yesterday;

  @override
  Widget build(BuildContext context) {
    final t = today;
    final y = yesterday;
    final rows = <(String, int, int?, bool)>[
      // (tên, hôm nay, hôm qua, tăng là tốt?)
      ('Vàng cuối ngày', t.goldEnd, y?.goldEnd, true),
      ('Thu 20% từ nhiệm vụ', t.income, y?.income, true),
      ('Doanh thu bán hàng', t.sales, y?.sales, true),
      ('Chứng khoán (ròng)', t.stocks, y?.stocks, true),
      ('Guild chi ra', t.spent, y?.spent, false),
      ('Hunter nhận vào ví', t.hunterEarnings, y?.hunterEarnings, true),
      ('Quest thành công', t.succeeded, y?.succeeded, true),
      ('Quest thất bại', t.failed, y?.failed, false),
      ('Hunter hy sinh', t.deaths, y?.deaths, false),
      ('Lượt lên cấp', t.levelUps, y?.levelUps, true),
      ('Số hunter', t.hunterCount, y?.hunterCount, true),
      ('Danh tiếng', t.reputation, y?.reputation, true),
    ];
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chi tiết so với hôm trước', style: textTheme.titleSmall),
        const SizedBox(height: 4),
        Table(
          columnWidths: const {0: FlexColumnWidth(2), 1: IntrinsicColumnWidth(), 2: FlexColumnWidth()},
          children: [
            TableRow(
              children: [
                const SizedBox(),
                Text('Hôm nay', style: textTheme.labelSmall),
                Text('  so với hôm qua', style: textTheme.labelSmall),
              ],
            ),
            for (final (label, value, previous, higherIsBetter) in rows)
              TableRow(
                children: [
                  Text(label),
                  Text('$value', textAlign: TextAlign.right),
                  _Delta(value: value, previous: previous, higherIsBetter: higherIsBetter),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({required this.value, required this.previous, required this.higherIsBetter});

  final int value;
  final int? previous;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final p = previous;
    if (p == null) return const Text('  –');
    final diff = value - p;
    if (diff == 0) return const Text('  =');
    final good = (diff > 0) == higherIsBetter;
    return Text('  ${diff > 0 ? '▲ +' : '▼ '}$diff', style: TextStyle(color: good ? Colors.green : Colors.red));
  }
}

/// Hunter mua sắm buổi sáng, gom theo từng người.
class PurchasesView extends StatelessWidget {
  const PurchasesView({super.key, required this.purchases});

  final List<Purchase> purchases;

  @override
  Widget build(BuildContext context) {
    final byHunter = <Hunter, List<Purchase>>{};
    for (final p in purchases) {
      (byHunter[p.hunter] ??= []).add(p);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final MapEntry(key: h, value: list) in byHunter.entries)
          Text(
            '${h.name}: ${list.map((p) => '${p.itemName} (${p.price} 🪙)').join(', ')}',
          ),
        Text(
          'Guild thu ${purchases.fold(0, (s, p) => s + p.price)} 🪙',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

/// 1 món trang bị hunter nhặt được (hoặc bán bớt khỏi kho riêng).
class GearDropLine extends StatelessWidget {
  const GearDropLine({super.key, required this.drop});

  final GearDrop drop;

  @override
  Widget build(BuildContext context) {
    final d = drop;
    return Text(
      '🎁 ${d.hunter.name}: ${d.item.name} → ${d.outcome.label}${d.price > 0 ? ' (+${d.price} 🪙 vào ví)' : ''}',
      style: TextStyle(color: d.item.grade.color),
    );
  }
}

/// Đồ của hunter hy sinh.
class EstateLine extends StatelessWidget {
  const EstateLine({super.key, required this.estate});

  final EstateSale estate;

  @override
  Widget build(BuildContext context) {
    final s = estate;
    return Text(
      [
        if (s.destroyed.isNotEmpty) '💥 Đồ ${s.hunter.name} đang mặc hư hết: ${s.destroyed.map((e) => e.name).join(', ')}',
        if (s.bought.isNotEmpty)
          '📦 Guild mua lại kho riêng (${s.bought.map((e) => e.name).join(', ')}) giá ${s.paid} 🪙',
        if (s.lost.isNotEmpty) 'Không đủ tiền mua: ${s.lost.map((e) => e.name).join(', ')}',
      ].join('\n'),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
