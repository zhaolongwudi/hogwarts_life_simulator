import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class SaveService {
  static const String _savesDir = 'saves';
  static const String _metaFileName = 'save_meta.json';
  static const String autoSaveSlotId = 'auto_save';
  final _uuid = const Uuid();

  Future<String> _getSavesDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final savesDir = Directory('${dir.path}/$_savesDir');
    if (!await savesDir.exists()) {
      await savesDir.create(recursive: true);
    }
    return savesDir.path;
  }

  Future<String> _getMetaPath() async {
    return '${await _getSavesDir()}/$_metaFileName';
  }

  Future<String> _getSavePath(String slotId) async {
    return '${await _getSavesDir()}/$slotId.json';
  }

  Future<List<Map<String, dynamic>>> _readMeta() async {
    final path = await _getMetaPath();
    final file = File(path);
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString();
      return List<Map<String, dynamic>>.from(jsonDecode(content));
    } catch (e) {
      return [];
    }
  }

  Future<void> _writeMeta(List<Map<String, dynamic>> meta) async {
    final path = await _getMetaPath();
    final file = File(path);
    await file.writeAsString(jsonEncode(meta), encoding: utf8);
  }

  Future<String> saveGame({
    required Map<String, dynamic> player,
    required Map<String, dynamic> worldState,
    required Map<String, dynamic> npcRegistry,
    required String narrative,
    required List<dynamic> choices,
    required int turnCount,
    String? slotName,
    Map<String, dynamic>? extraData,
  }) async {
    final slotId = slotName ?? _uuid.v4().substring(0, 8);
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
      if (extraData != null) 'extra_data': extraData,
    };

    final savePath = await _getSavePath(slotId);
    await File(savePath).writeAsString(jsonEncode(saveData), encoding: utf8);

    await _updateMeta(slotId, slotName ?? '自动存档', DateTime.now());
    return slotId;
  }

  Future<Map<String, dynamic>?> loadGame(String slotId) async {
    final path = await _getSavePath(slotId);
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString(encoding: utf8);
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listSaves() async {
    return _readMeta();
  }

  Future<bool> deleteSave(String slotId) async {
    try {
      final path = await _getSavePath(slotId);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      final meta = await _readMeta();
      final updated = meta.where((s) => s['id'] != slotId).toList();
      await _writeMeta(updated);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _updateMeta(String id, String name, DateTime savedAt) async {
    final existing = await _readMeta();
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
    await _writeMeta(existing);
  }

  Future<String> autoSave({
    required Map<String, dynamic> player,
    required Map<String, dynamic> worldState,
    required Map<String, dynamic> npcRegistry,
    required String narrative,
    required List<dynamic> choices,
    required int turnCount,
    Map<String, dynamic>? extraData,
  }) async {
    const slotId = autoSaveSlotId;
    final saveData = {
      'save_version': 2,
      'player': player,
      'world_state': worldState,
      'npc_registry': npcRegistry,
      'narrative': narrative,
      'choices': choices,
      'turn_count': turnCount,
      'saved_at': DateTime.now().toIso8601String(),
      'slot_name': '自动存档',
      if (extraData != null) 'extra_data': extraData,
    };

    final savePath = await _getSavePath(slotId);
    await File(savePath).writeAsString(jsonEncode(saveData), encoding: utf8);
    await _updateMeta(slotId, '自动存档', DateTime.now());
    return slotId;
  }

  Future<Map<String, dynamic>?> loadAutoSave() async {
    return loadGame(autoSaveSlotId);
  }

  Future<void> clearAutoSave() async {
    await deleteSave(autoSaveSlotId);
  }
}
