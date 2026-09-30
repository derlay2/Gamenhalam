import 'package:flutter/material.dart';

import '../logic/game_config.dart';
import '../logic/game_state.dart';
import '../models/hunter.dart';
import '../widgets/visuals.dart';

class ChapelScreen extends StatelessWidget {
  const ChapelScreen({super.key, required this.game});

  final GameState game;

  void _pray(BuildContext context, Hunter h) {
    final revived = game.pray(h);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(revived ? '✨ ${h.name} đã hồi sinh! (đang nằm viện)' : 'Lời cầu nguyện chưa được đáp lại...'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text('Nhà cầu nguyện · 🪙 ${game.gold}')),
        body: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Mỗi lần cầu nguyện có ${percent(GameConfig.reviveChance)} cơ hội hồi sinh. '
                'Không thể hồi sinh hunter trên ${GameConfig.reviveMaxAge} tuổi.',
              ),
            ),
            if (game.fallen.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Chưa có hunter nào ngã xuống.')),
              ),
            for (final h in game.fallen)
              Card(
                child: ListTile(
                  leading: Icon(h.hunterClass.icon, color: h.rarity.color),
                  title: Text('${h.name} · Lv ${h.level}'),
                  subtitle: Text('${h.hunterClass.label} ${h.rarity.label} · ${h.age} tuổi'),
                  trailing: game.canRevive(h)
                      ? FilledButton(
                          onPressed: game.gold >= game.prayerCost(h) ? () => _pray(context, h) : null,
                          child: Text('Cầu nguyện\n${game.prayerCost(h)} 🪙', textAlign: TextAlign.center),
                        )
                      : const Text('Quá tuổi\nhồi sinh', textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
