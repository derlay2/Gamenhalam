import 'package:flutter/material.dart';

import '../logic/game_state.dart';
import '../models/enums.dart';
import '../widgets/hunter_card.dart';

class AssociationScreen extends StatelessWidget {
  const AssociationScreen({super.key, required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text('Hiệp hội thợ săn · 🪙 ${game.gold}')),
        body: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Phí nhập thị trấn: ${Rarity.values.map((r) => '${r.label} ${r.joinFee}').join(' · ')} vàng.\n'
                'Phát giấy mời mới sẽ thay nhóm hunter đang chờ.',
              ),
            ),
            if (game.candidates.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Chưa có hunter nào đến. Hãy phát giấy mời!')),
              ),
            for (final c in game.candidates)
              HunterCard(
                hunter: c,
                trailing: FilledButton(
                  onPressed: game.canHire(c) ? () => game.hire(c) : null,
                  child: Text('Nhận\n${c.rarity.joinFee} 🪙', textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: game.canInvite ? game.sendInvitations : null,
          icon: const Icon(Icons.mail),
          label: Text(game.freeInvitations ? 'Phát giấy mời (miễn phí tuần này)' : 'Phát giấy mời (${game.invitationCost} vàng)'),
        ),
      ),
    );
  }
}
