import 'package:flutter/material.dart';

import '../logic/game_state.dart';
import '../logic/save_service.dart';
import '../models/day.dart';
import '../widgets/phase_report_dialog.dart';
import '../widgets/visuals.dart';
import 'hunter_list_screen.dart';
import 'map_screen.dart';
import 'quest_board_screen.dart';
import 'town_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.game, required this.slot, required this.saves});

  final GameState game;

  /// Slot đang chơi; game tự lưu vào đây mỗi lần chuyển buổi.
  final int slot;
  final SaveService saves;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var _tab = 0;

  GameState get _game => widget.game;

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }

  String get _nextPhaseLabel => switch (_game.phase) {
    DayPhase.morning => 'Sang trưa',
    DayPhase.noon => 'Sang đêm',
    DayPhase.night => 'Sáng mai',
  };

  Future<void> _save({bool notify = false}) async {
    await widget.saves.save(widget.slot, _game);
    if (notify && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã lưu vào slot ${widget.slot + 1}.')));
    }
  }

  Future<void> _advance() async {
    final report = _game.advancePhase();
    if (report.gameOver != null) {
      // Thua: xoá slot để không tiếp tục được, xem báo cáo lần cuối rồi về màn chọn slot.
      await widget.saves.delete(widget.slot);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PhaseReportDialog(report: report),
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await _save();
    if (!mounted) return;
    // Đêm -> sáng: tổng kết ngày vừa qua tự hiện trước, rồi mới tới tin buổi sáng.
    if (report.daily case final daily?) {
      await showDialog<void>(
        context: context,
        builder: (_) => DailySummaryDialog(today: daily, yesterday: report.yesterday),
      );
      if (!mounted) return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => PhaseReportDialog(report: report),
    );
  }

  Future<void> _backToSlots() async {
    if (_game.gameOver == null) await _save();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToSlots();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 12,
          toolbarHeight: 60,
          title: ListenableBuilder(
            listenable: _game,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _game.phase.color, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_game.phase.icon, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'N${_game.day} · ${_game.phase.label}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '🪙 ${_game.gold} · 🏅${_game.rank.label}${_game.atRisk ? ' ⚠' : ''}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _game.atRisk ? Theme.of(context).colorScheme.error : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          actions: [
            ListenableBuilder(
              listenable: _game,
              builder: (context, _) => FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _game.phase.next.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: _advance,
                icon: Icon(_game.phase.next.icon, size: 18),
                label: Text(_nextPhaseLabel),
              ),
            ),
            PopupMenuButton<VoidCallback>(
              onSelected: (action) => action(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MapScreen(game: _game))),
                  child: const ListTile(leading: Icon(Icons.map), title: Text('Bản đồ'), dense: true),
                ),
                PopupMenuItem(value: () => _save(notify: true), child: Text('Lưu (slot ${widget.slot + 1})')),
                PopupMenuItem(value: _backToSlots, child: const Text('Lưu & về chọn slot')),
              ],
            ),
          ],
        ),
        body: IndexedStack(
          index: _tab,
          children: [
            HunterListScreen(game: _game),
            QuestBoardScreen(game: _game),
            TownScreen(game: _game),
          ],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: _game,
          builder: (context, _) => NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.groups), label: 'Hunter'),
              const NavigationDestination(icon: Icon(Icons.assignment), label: 'Nhiệm vụ'),
              NavigationDestination(
                // Nhắc có nguyên liệu đang chờ thu mua.
                icon: Badge(
                  isLabelVisible: _game.materialLots.isNotEmpty,
                  label: Text('📦${_game.materialLots.length}'),
                  child: const Icon(Icons.location_city),
                ),
                label: 'Thị trấn',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
