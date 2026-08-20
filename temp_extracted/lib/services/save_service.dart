import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SaveService {
  static const String _keyPrefix = 'hogwarts_save_';
  static const String _metaKey = 'hogwarts_save_meta';
  final _uuid = const Uuid();

  Future<String> saveGame({
    required Map<String, dynamic> player,
    required Map<String, dynamic> worldState,
    required Map<String, dynamic> npcRegistry,
    required String narrative,
    required List<dynamic> choices,
    required int turnCount,
    String? slotName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final slotId = slotName ?? _uuid.v4().substring(0, 8);
    final key = '$_keyPrefix$slotId';

    final saveData = {
      'save_version': 2,
      'player': player,
      'world_state': worldState,
      'npc_registry': npcRegistry,
      'narrative': narrative,
      'choices': choices,
      'turn_count': turnCount,
      'saved_at': DateTime.now().toIso8601String(),
      'slot_name': slotName ?? '自动存档',
    };

    await prefs.setString(key, jsonEncode(saveData));
    await _updateMeta(prefs, slotId, slotName ?? '自动存档', DateTime.now());
    return slotId;
  }

  Future<Map<String, dynamic>?> loadGame(String slotId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('$_keyPrefix$slotId');
    if (data == null) return null;
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listSaves() async {
    final prefs = await SharedPreferences.getInstance();
    final meta = prefs.getString(_metaKey);
    if (meta == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(meta));
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteSave(String slotId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$slotId');
    final meta = await listSaves();
    final updated = meta.where((s) => s['id'] != slotId).toList();
    await prefs.setString(_metaKey, jsonEncode(updated));
    return true;
  }

  Future<void> _updateMeta(SharedPreferences prefs, String id, String name, DateTime savedAt) async {
    final existing = await listSaves();
    final entry = {
      'id': id,
      'name': name,
      'saved_at': savedAt.toIso8601String(),
      'turn_count': 0,
    };
    final index = existing.indexWhere((s) => s['id'] == id);
    if (index >= 0) {
      existing[index] = entry;
    } else {
      existing.add(entry);
    }
    await prefs.setString(_metaKey, jsonEncode(existing));
  }
}
