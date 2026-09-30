import 'package:flutter/material.dart';

import '../logic/game_state.dart';
import '../logic/save_service.dart';
import 'home_screen.dart';

/// Màn hình mở đầu: chọn 1 trong 3 slot để chơi mới hoặc chơi tiếp.
class SaveSlotsScreen extends StatefulWidget {
  const SaveSlotsScreen({super.key});

  @override
  State<SaveSlotsScreen> createState() => _SaveSlotsScreenState();
}

class _SaveSlotsScreenState extends State<SaveSlotsScreen> {
  final _saves = SaveService();
  late Future<List<SaveSlotInfo?>> _slots = _saves.listSlots();

  void _reload() => setState(() => _slots = _saves.listSlots());

  Future<void> _play(int slot, GameState game) async {
    await _saves.save(slot, game);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(game: game, slot: slot, saves: _saves),
      ),
    );
    _reload();
  }

  Future<void> _continue(int slot) async {
    final game = await _saves.load(slot);
    if (!mounted) return;
    if (game == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không đọc được bản lưu này.')));
      return;
    }
    await _play(slot, game);
  }

  Future<void> _delete(int slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Xoá slot ${slot + 1}?'),
        content: const Text('Tiến trình trong slot này sẽ mất vĩnh viễn.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Xoá')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _saves.delete(slot);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hunter Guild – Chọn slot')),
      body: FutureBuilder(
        future: _slots,
        builder: (context, snapshot) {
          final slots = snapshot.data;
          if (slots == null) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.all(8),
            children: [for (var slot = 0; slot < SaveService.slotCount; slot++) _slotCard(slot, slots[slot])],
          );
        },
      ),
    );
  }

  Widget _slotCard(int slot, SaveSlotInfo? info) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('${slot + 1}')),
        title: Text(info == null ? 'Slot trống' : 'Ngày ${info.day} · ${info.phase.label}'),
        subtitle: info == null
            ? null
            : Text('🪙 ${info.gold} · ${info.hunterCount} hunter · lưu lúc ${_formatTime(info.savedAt)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (info != null)
              IconButton(tooltip: 'Xoá', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(slot)),
            FilledButton(
              onPressed: () => info == null ? _play(slot, GameState()) : _continue(slot),
              child: Text(info == null ? 'Game mới' : 'Chơi tiếp'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)} ${two(t.day)}/${two(t.month)}/${t.year}';
  }
}
