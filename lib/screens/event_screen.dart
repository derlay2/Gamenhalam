import 'package:flutter/material.dart';

import '../logic/game_config.dart';
import '../logic/game_state.dart';
import '../models/day.dart';
import '../models/events.dart';
import '../widgets/hunter_card.dart';
import '../widgets/visuals.dart';

/// Thẻ sự kiện tuần này ở tab Thị trấn.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    final e = game.event!;
    final colors = Theme.of(context).colorScheme;
    final detail = switch (e.type) {
      WeeklyEventType.siege when e.siegeResolved => 'Trận thủ thành đã diễn ra.',
      WeeklyEventType.siege =>
        'Quái (${e.siegeMonster.label}) tấn công vào ${describePhase(phaseIndex(e.siegeDay, DayPhase.night))} · '
            '${e.defenderIds.length} hunter được cử thủ thành',
      WeeklyEventType.merchant => game.merchantHere ? 'Thương nhân đang ở chợ, chỉ hôm nay!' : 'Thương nhân đã rời đi.',
      WeeklyEventType.plague => 'Đến hết tuần (ngày ${e.startDay + GameConfig.weekDays - 1}).',
      WeeklyEventType.immigration => 'Giấy mời miễn phí đến hết ngày ${e.startDay + GameConfig.weekDays - 1}.',
      WeeklyEventType.weather =>
        '${e.weatherLabel} đến hết ngày ${e.endDay} · nhu yếu phẩm ${GameConfig.weatherProvisionBase}+'
            '${GameConfig.weatherProvisionPerLevel}×cấp 🪙/hunter/ngày',
      WeeklyEventType.inflation =>
        game.isInflation ? 'Giá thu mua ×${GameConfig.inflationPriceMultiplier} đến hết ngày ${e.endDay}.' : 'Giá đã trở lại bình thường.',
      WeeklyEventType.rumor =>
        game.reputationPenalty > 0
            ? 'Danh tiếng -${e.reputationPenalty} đến hết ngày ${e.endDay} · hunter hiếm ×${GameConfig.rumorRareRate}'
            : 'Tin đồn đã lắng xuống.',
      WeeklyEventType.royalAid || WeeklyEventType.experiment || WeeklyEventType.traitor =>
        e.awaitingChoice
            ? '⚠ Cần quyết định trước sáng ngày ${e.startDay + 1} (không chọn = B).'
            : e.outcome ?? '',
    };
    final actionable =
        (e.type == WeeklyEventType.siege && !e.siegeResolved) ||
        (e.type == WeeklyEventType.merchant && game.merchantHere) ||
        e.awaitingChoice;
    return Card(
      color: e.type.isDanger ? colors.errorContainer : colors.secondaryContainer,
      child: ListTile(
        leading: Icon(e.type.isDanger ? Icons.warning_amber : Icons.celebration),
        title: Text(e.type.label),
        subtitle: Text('${e.type.description}\n$detail'),
        isThreeLine: true,
        trailing: actionable ? const Icon(Icons.chevron_right) : null,
        onTap: actionable
            ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EventScreen(game: game)))
            : null,
      ),
    );
  }
}

/// Thao tác cho sự kiện: chọn đội thủ thành hoặc mua hàng thương nhân.
class EventScreen extends StatelessWidget {
  const EventScreen({super.key, required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final e = game.event;
        return Scaffold(
          appBar: AppBar(title: Text('${e?.type.label ?? 'Sự kiện'} · 🪙 ${game.gold}')),
          body: switch (e?.type) {
            WeeklyEventType.siege => _siege(context, e!),
            WeeklyEventType.merchant => _merchant(context, e!),
            _ when e != null && e.type.hasChoice => _choice(context, e),
            _ => const Center(child: Text('Không có việc gì cần làm.')),
          },
        );
      },
    );
  }

  /// Sự kiện 2 lựa chọn A/B.
  Widget _choice(BuildContext context, WeeklyEvent e) {
    final details = switch (e.type) {
      WeeklyEventType.royalAid =>
        'Sẽ gửi: ${game.royalCandidates.map((h) => '${h.name} (Lv ${h.level})').join(', ')}. '
            'Đối thủ tier ${game.rank.maxQuestTier.label}; thắng: danh tiếng +${GameConfig.royalReputation} '
            'và 1 vũ khí Thần khí độc quyền. Từ chối: danh tiếng -${GameConfig.royalRefusePenalty}.',
      WeeklyEventType.traitor => switch (game.hunters.where((h) => h.id == e.targetId).firstOrNull) {
        final h? => 'Kẻ bị tố giác: ${h.name} — ${h.hunterClass.label} ${h.rarity.label}, hạng ${h.rank.label}, '
            'Lv ${h.level}. Trong lúc chờ quyết định, hunter này không được giao quest.',
        null => 'Kẻ bị tố giác đã không còn ở thị trấn.',
      },
      _ => '',
    };
    Future<void> choose(bool a) async {
      final outcome = game.chooseEvent(a);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(e.type.label),
          content: Text(outcome),
          actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK'))],
        ),
      );
      if (context.mounted) Navigator.of(context).pop();
    }

    Widget option(String label, String text, bool a) {
      final error = game.eventChoiceError(a);
      return Card(
        child: ListTile(
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(error == null ? text : '$text\n❌ $error'),
          isThreeLine: true,
          trailing: FilledButton(onPressed: error == null ? () => choose(a) : null, child: const Text('Chọn')),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Padding(padding: const EdgeInsets.all(8), child: Text('${e.type.description}\n$details')),
        option('A', e.type.optionA!, true),
        option('B', e.type.optionB!, false),
      ],
    );
  }

  Widget _siege(BuildContext context, WeeklyEvent e) {
    final repair = GameConfig.siegeRepairCostPerRank * (game.rank.index + 1);
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Bầy ${e.siegeMonster.label} (tier ${game.rank.maxQuestTier.label}) tấn công vào '
            '${describePhase(phaseIndex(e.siegeDay, DayPhase.night))}. Chỉ hunter được cử VÀ đang ở thị trấn '
            '(không đi quest, không nằm viện) lúc đó mới ra trận.\n'
            'Thắng: danh tiếng +${GameConfig.siegeWinReputation}, hunter nhận EXP. '
            'Thua hoặc không ai thủ: sửa công trình $repair 🪙, danh tiếng -${GameConfig.siegeFailReputation}.',
          ),
        ),
        for (final h in game.hunters)
          HunterCard(
            hunter: h,
            trailing: Checkbox(value: e.defenderIds.contains(h.id), onChanged: (_) => game.toggleDefender(h)),
          ),
      ],
    );
  }

  Widget _merchant(BuildContext context, WeeklyEvent e) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Hàng hiếm, giá cắt cổ. Mua là nhận ngay (đồ lên nhà rèn, nguyên liệu vào kho, bản vẽ vào sổ).'),
        ),
        if (e.merchantOffers.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Đã mua hết.')),
        for (final o in e.merchantOffers)
          Card(
            child: ListTile(
              title: Text(o.label),
              subtitle: Text([
                if (o.item case final item?) '✨ Độc quyền · ${describeStats(item.bonus)}',
                if (o.blueprint case final b?) 'Mở khóa chế ${b.type.label} ${b.grade.label}',
                if (o.blueprint case final b? when game.blueprints.contains(b)) '(đã có)',
              ].join(' ')),
              trailing: FilledButton(
                onPressed: game.gold >= o.price ? () => game.buyFromMerchant(o) : null,
                child: Text('${o.price} 🪙'),
              ),
            ),
          ),
      ],
    );
  }
}
