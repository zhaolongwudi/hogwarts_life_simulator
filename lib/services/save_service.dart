import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class SaveService {
  static const String _savesDir = 'saves';
  static const String _metaFileName = 'save_meta.json';
  static const String autoSaveSlotId = 'auto_save';
  final _uuid = const Uuid();

  /// 串行化所有写操作，避免并发写同一文件导致损坏
  Future<void> _writeChain = Future.value();

  Future<T> _serialized<T>(Future<T> Function() task) {
    final result = _writeChain.then((_) => task());
    _writeChain = result.then((_) {}, onError: (_) {});
    return result;
  }

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

  Future<String> _getBackupPath(String slotId) async {
    return '${await _getSavesDir()}/$slotId.backup.json';
  }

  /// 原子写入：先写临时文件，再 rename 覆盖目标。
  /// rename 在同一文件系统上是原子操作，避免写一半崩溃导致存档损坏。
  Future<void> _atomicWrite(String targetPath, String content) async {
    final tmpPath = '$targetPath.tmp';
    final tmpFile = File(tmpPath);
    await tmpFile.writeAsString(content, encoding: utf8);
    await tmpFile.rename(targetPath);
  }

  /// 写入前备份：把当前存档复制为 .backup.json（仅保留最近一份）
  Future<void> _backupBeforeWrite(String slotId) async {
    try {
      final savePath = await _getSavePath(slotId);
      final saveFile = File(savePath);
      if (!await saveFile.exists()) return;
      final backupPath = await _getBackupPath(slotId);
      await saveFile.copy(backupPath);
    } catch (e) {
      debugPrint('⚠️ 存档备份失败(不影响写入): $e');
    }
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
    await _atomicWrite(path, jsonEncode(meta));
  }

  /// 核心写入逻辑（原子 + 备份 + 校验）
  Future<String> _writeSave({
    required String slotId,
    required String slotName,
    required Map<String, dynamic> saveData,
  }) async {
    return _serialized(() async {
      await _backupBeforeWrite(slotId);
      final content = jsonEncode(saveData);
      // 写入前自检：确保序列化结果可被解析，避免写入损坏数据
      jsonDecode(content);
      final savePath = await _getSavePath(slotId);
      await _atomicWrite(savePath, content);
      await _updateMeta(slotId, slotName, DateTime.now());
      return slotId;
    });
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
    return _writeSave(
      slotId: slotId,
      slotName: slotName ?? '自动存档',
      saveData: saveData,
    );
  }

  Future<Map<String, dynamic>?> loadGame(String slotId) async {
    final path = await _getSavePath(slotId);
    final file = File(path);
    if (!await file.exists()) return _tryLoadBackup(slotId);
    try {
      final content = await file.readAsString(encoding: utf8);
      final data = jsonDecode(content) as Map<String, dynamic>;
      // 基本完整性校验
      if (!data.containsKey('player') || !data.containsKey('world_state')) {
        throw const FormatException('存档缺少关键字段');
      }
      return data;
    } catch (e) {
      debugPrint('⚠️ 存档 $slotId 损坏，尝试读取备份: $e');
      return _tryLoadBackup(slotId);
    }
  }

  /// 主存档损坏时回滚到备份
  Future<Map<String, dynamic>?> _tryLoadBackup(String slotId) async {
    try {
      final backupPath = await _getBackupPath(slotId);
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) return null;
      final content = await backupFile.readAsString(encoding: utf8);
      final data = jsonDecode(content) as Map<String, dynamic>;
      if (!data.containsKey('player') || !data.containsKey('world_state')) {
        return null;
      }
      debugPrint('✅ 已从备份恢复存档 $slotId');
      // 用备份修复主存档，避免下次仍然读到损坏文件
      try {
        final savePath = await _getSavePath(slotId);
        await _atomicWrite(savePath, content);
      } catch (_) {}
      return data;
    } catch (e) {
      debugPrint('❌ 备份存档也不可用: $e');
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
      final backupPath = await _getBackupPath(slotId);
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        await backupFile.delete();
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
    return _writeSave(slotId: slotId, slotName: '自动存档', saveData: saveData);
  }

  Future<Map<String, dynamic>?> loadAutoSave() async {
    return loadGame(autoSaveSlotId);
  }

  Future<void> clearAutoSave() async {
    await deleteSave(autoSaveSlotId);
  }
}
