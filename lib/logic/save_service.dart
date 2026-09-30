import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/day.dart';
import 'game_state.dart';

/// Tóm tắt một slot để hiện ở màn hình chọn slot (không cần đọc cả game).
class SaveSlotInfo {
  const SaveSlotInfo({
    required this.day,
    required this.phase,
    required this.gold,
    required this.hunterCount,
    required this.savedAt,
  });

  final int day;
  final DayPhase phase;
  final int gold;
  final int hunterCount;
  final DateTime savedAt;
}

class SaveService {
  static const slotCount = 3;

  /// Tăng khi đổi định dạng bản lưu; bản lưu khác phiên bản sẽ không đọc.
  static const _version = 2;

  String _key(int slot) => 'save_slot_$slot';

  Map<String, dynamic>? _read(SharedPreferences prefs, int slot) {
    final raw = prefs.getString(_key(slot));
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return data['version'] == _version ? data : null;
    } on FormatException {
      return null;
    }
  }

  /// Thông tin 3 slot; null = slot trống (hoặc bản lưu hỏng).
  Future<List<SaveSlotInfo?>> listSlots() async {
    final prefs = await SharedPreferences.getInstance();
    return [
      for (var slot = 0; slot < slotCount; slot++)
        if (_read(prefs, slot)?['summary'] case final Map<String, dynamic> s)
          SaveSlotInfo(
            day: s['day'] as int,
            phase: DayPhase.values.byName(s['phase'] as String),
            gold: s['gold'] as int,
            hunterCount: s['hunterCount'] as int,
            savedAt: DateTime.parse(s['savedAt'] as String),
          )
        else
          null,
    ];
  }

  Future<void> save(int slot, GameState game) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(slot),
      jsonEncode({
        'version': _version,
        'summary': {
          'day': game.day,
          'phase': game.phase.name,
          'gold': game.gold,
          'hunterCount': game.hunters.length,
          'savedAt': DateTime.now().toIso8601String(),
        },
        'game': game.toJson(),
      }),
    );
  }

  Future<GameState?> load(int slot) async {
    final prefs = await SharedPreferences.getInstance();
    final data = _read(prefs, slot);
    if (data == null) return null;
    return GameState.fromJson(data['game'] as Map<String, dynamic>);
  }

  Future<void> delete(int slot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(slot));
  }
}
