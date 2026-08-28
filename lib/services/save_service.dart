import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 当前存档格式版本号。
///
/// 只有这一处定义。以前写入端（SaveService.saveGame）硬编码一个 2，读档端
/// （mixin_systems 的 _saveVersion）又定义了一个 2，两边互不知情：等哪天
/// 加了 v3 迁移，写档还是盖 v2 的章，于是新存的档每次读都要过一遍 v3 迁移
/// 逻辑——而迁移代码是按"老格式"写的，等于拿新档喂给它。
///
/// 升级流程：把这里 +1，并在 _migrateSave 里补上对应分支。
const int kSaveVersion = 2;

class SaveService {
  static const String _savesDir = 'saves';
  static const String _metaFileName = 'save_meta.json';
  static const String autoSaveSlotId = 'auto_save';
  /// 快速存档的固定槽位。必须保持 '快速存档' —— 槽位 id 直接当文件名用，
  /// 改了会让玩家已有的快速存档读不出来。
  static const String quickSaveSlotId = '快速存档';
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
      final turnCount = saveData['turn_count'] as int? ?? 0;
      await _updateMeta(slotId, slotName, DateTime.now(), turnCount);
      return slotId;
    });
  }

  /// 写入一个具名存档槽。
  ///
  /// [slotId] 缺省时由 [slotName] 派生（自动存档走固定的 autoSaveSlotId）。
  /// 自动存档以前走的是另一个方法（autoSave），除了槽位固定以外和这里一模
  /// 一样——两份并存的后果是改一处忘另一处。
  Future<String> saveGame({
    required Map<String, dynamic> player,
    required Map<String, dynamic> worldState,
    required Map<String, dynamic> npcRegistry,
    required String narrative,
    required List<dynamic> choices,
    required int turnCount,
    String? slotName,
    String? slotId,
    Map<String, dynamic>? extraData,
  }) async {
    final resolvedId = slotId ?? slotName ?? _uuid.v4().substring(0, 8);
    final resolvedName = slotName ?? '自动存档';
    final saveData = {
      'save_version': kSaveVersion,
      'player': player,
      'world_state': worldState,
      'npc_registry': npcRegistry,
      'narrative': narrative,
      'choices': choices,
      'turn_count': turnCount,
      'saved_at': DateTime.now().toIso8601String(),
      'slot_name': resolvedName,
      if (extraData != null) 'extra_data': extraData,
    };
    return _writeSave(
      slotId: resolvedId,
      slotName: resolvedName,
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

  Future<void> _updateMeta(String id, String name, DateTime savedAt, int turnCount) async {
    final existing = await _readMeta();
    final entry = {
      'id': id,
      'name': name,
      'saved_at': savedAt.toIso8601String(),
      'turn_count': turnCount,
    };
    final index = existing.indexWhere((s) => s['id'] == id);
    if (index >= 0) {
      existing[index] = entry;
    } else {
      existing.add(entry);
    }
    await _writeMeta(existing);
  }

  Future<Map<String, dynamic>?> loadAutoSave() async {
    return loadGame(autoSaveSlotId);
  }

  Future<void> clearAutoSave() async {
    await deleteSave(autoSaveSlotId);
  }

  /// 导出存档为 JSON 字符串（用于备份/跨设备迁移）
  /// 返回完整存档 JSON；存档不存在或损坏时返回 null
  Future<String?> exportSave(String slotId) async {
    final data = await loadGame(slotId);
    if (data == null) return null;
    return jsonEncode(data);
  }

  /// 从 JSON 字符串导入存档
  /// 校验关键字段后写入新存档槽，返回新槽 id；非法数据返回 null
  Future<String?> importSave(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      if (!data.containsKey('player') || !data.containsKey('world_state')) {
        debugPrint('❌ 导入失败：存档缺少关键字段');
        return null;
      }
      final slotId = _uuid.v4().substring(0, 8);
      final slotName = data['slot_name'] as String? ?? '导入存档';
      await _writeSave(slotId: slotId, slotName: slotName, saveData: data);
      return slotId;
    } catch (e) {
      debugPrint('❌ 导入存档失败: $e');
      return null;
    }
  }
}
