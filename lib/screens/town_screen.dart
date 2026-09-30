import 'package:flutter/material.dart';

import '../logic/game_config.dart';
import '../logic/game_state.dart';
import '../widgets/visuals.dart';
import 'association_screen.dart';
import '../models/equipment.dart';
import 'blacksmith_screen.dart';
import 'caravan_screen.dart';
import 'event_screen.dart';
import 'chapel_screen.dart';
import 'hospital_screen.dart';
import 'potion_shop_screen.dart';
import 'stock_market_screen.dart';
import 'trading_post_screen.dart';

class TownScreen extends StatelessWidget {
  const TownScreen({super.key, required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final patients = game.hunters.where((h) => h.inHospital).length;
        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            TownRankCard(game: game),
            if (game.event != null) EventCard(game: game),
            _Building(
              icon: Icons.mail,
              title: 'Hiệp hội thợ săn',
              subtitle: 'Phát giấy mời, nhận hunter mới vào thị trấn · ${game.candidates.length} người đang chờ',
              onTap: () => open(AssociationScreen(game: game)),
            ),
            _Building(
              icon: Icons.local_hospital,
              title: 'Bệnh viện',
              subtitle: 'Hồi phục thương tích · $patients bệnh nhân',
              onTap: () => open(HospitalScreen(game: game)),
            ),
            _Building(
              icon: Icons.hardware,
              title: 'Nhà rèn',
              subtitle:
                  'Chế tạo & bán trang bị · ${game.shopStock.length} món đang bán · '
                  '📜 ${game.blueprints.length}/${ItemGrade.values.length * ItemType.values.length} bản vẽ',
              onTap: () => open(BlacksmithScreen(game: game)),
            ),
            _Building(
              icon: Icons.local_shipping,
              title: 'Thương đoàn',
              subtitle:
                  'Cử nhân viên đi chợ các khu mua trang bị & bản vẽ · '
                  '${game.caravans.length}/${GameConfig.maxCaravans} đang đi',
              onTap: () => open(CaravanScreen(game: game)),
            ),
            _Building(
              icon: Icons.storefront,
              title: 'Trạm thu mua',
              subtitle: 'Mua nguyên liệu hunter mang về · ${game.materialLots.length} lô đang chào bán',
              onTap: () => open(TradingPostScreen(game: game)),
            ),
            _Building(
              icon: Icons.candlestick_chart,
              title: 'Sàn chứng khoán',
              subtitle: [
                '${game.stockMarketOpen ? 'Mở cửa' : 'Đóng cửa ban đêm'} · 6 công ty',
                if (game.stocks.holdings.isNotEmpty) 'đang giữ ${game.stocks.portfolioValue} 🪙',
              ].join(' · '),
              onTap: () => open(StockMarketScreen(game: game)),
            ),
            _Building(
              icon: Icons.local_drink,
              title: 'Tiệm thuốc',
              subtitle:
                  'Hunter tự mua bình máu mỗi sáng · '
                  'còn ${game.potionStock.values.fold(0, (a, b) => a + b)} bình',
              onTap: () => open(PotionShopScreen(game: game)),
            ),
            _Building(
              icon: Icons.church,
              title: 'Nhà cầu nguyện',
              subtitle: 'Cầu nguyện hồi sinh hunter đã ngã xuống · ${game.fallen.length} linh hồn',
              onTap: () => open(ChapelScreen(game: game)),
            ),
          ],
        );
      },
    );
  }
}

/// Hạng thị trấn, tiến độ danh tiếng và những gì đã mở khóa.
class TownRankCard extends StatelessWidget {
  const TownRankCard({super.key, required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    final rank = game.rank;
    final next = rank.next;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🏅 Thị trấn hạng ${rank.label} · Danh tiếng ${game.effectiveReputation}'
              '${game.reputationPenalty > 0 ? ' (🐉 tin đồn -${game.reputationPenalty})' : ''}', style: textTheme.titleMedium),
            const SizedBox(height: 6),
            if (next != null) ...[
              LinearProgressIndicator(
                value: (game.effectiveReputation - rank.minReputation) / (next.minReputation - rank.minReputation),
              ),
              const SizedBox(height: 4),
              Text('Còn ${next.minReputation - game.effectiveReputation} danh tiếng để lên hạng ${next.label}'),
            ] else
              const Text('Đã đạt hạng cao nhất.'),
            const SizedBox(height: 6),
            Text(
              'Quest tới tier ${rank.maxQuestTier.label} · '
              'Hunter Sử thi/Huyền thoại +${percent(rank.rareHunterBonus)} · '
              'Nguyên liệu rơi cao hơn 1 cấp ${percent(rank.lootUpgradeChance)}',
              style: textTheme.bodySmall,
            ),
            Text(
              'Tăng: quest thành công (tier càng cao càng nhiều), chữa ngay hunter nguy kịch '
              '(dưới ${percent(GameConfig.rescueHpRatio)} máu), hồi sinh thành công. '
              'Giảm: quest thất bại, hunter hy sinh. Tụt danh tiếng có thể bị hạ hạng.',
              style: textTheme.bodySmall,
            ),
            if (game.atRisk) ...[
              const SizedBox(height: 6),
              Text(
                '⚠ Guild sắp thua: nếu cuối buổi vẫn thế này, game sẽ kết thúc '
                '(cần tối thiểu ${GameConfig.invitationCost} 🪙 kể cả hàng thanh lý được'
                '${game.hunters.isEmpty ? ', hoặc ${game.recruitCost} 🪙 để chiêu mộ lại' : ''}).',
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Building extends StatelessWidget {
  const _Building({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
