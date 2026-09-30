import 'package:flutter/material.dart';

import '../logic/game_config.dart';
import '../logic/game_state.dart';
import '../widgets/hunter_card.dart';
import '../widgets/visuals.dart';

class HospitalScreen extends StatelessWidget {
  const HospitalScreen({super.key, required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final patients = game.hunters.where((h) => h.inHospital).toList();
        final injured = game.hunters.where((h) => h.isAvailable && !h.isFullHp).toList();
        final titleStyle = Theme.of(context).textTheme.titleSmall;
        return Scaffold(
          appBar: AppBar(title: Text('Bệnh viện · 🪙 ${game.gold}')),
          body: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Hunter về với máu dưới ${percent(GameConfig.hospitalThreshold)} sẽ tự nhập viện. '
                  'Mỗi sáng hồi ${percent(GameConfig.hospitalHealPerDay)} máu, đầy máu thì xuất viện.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Đang điều trị', style: titleStyle),
              ),
              if (patients.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Không có bệnh nhân.')),
              for (final h in patients)
                HunterCard(
                  hunter: h,
                  trailing: FilledButton(
                    onPressed: game.gold >= game.healNowCost(h) ? () => game.healNow(h) : null,
                    child: Text('Chữa ngay\n${game.healNowCost(h)} 🪙 (guild trả)', textAlign: TextAlign.center),
                  ),
                ),
              if (injured.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Bị thương nhẹ', style: titleStyle),
                ),
                for (final h in injured)
                  HunterCard(
                    hunter: h,
                    trailing: OutlinedButton(onPressed: () => game.admit(h), child: const Text('Nhập viện')),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
