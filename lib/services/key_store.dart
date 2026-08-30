import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 安全存储服务：使用系统级加密存储保存 API Key。
///
/// iOS 使用 Keychain，Android 使用 Keystore/EncryptedSharedPreferences，
/// 避免将密钥明文写入 SharedPreferences 被 root 设备或反编译直接读取。
///
/// 读取失败（如测试环境无原生实现）时优雅返回 null，由调用方回退到旧版
/// SharedPreferences 迁移逻辑，保证健壮性而非直接崩溃。
/// 单个提供商的多 key 数量上限。
///
/// 纯粹是防御：多 key 是玩家手动加的，正常撑死几个。设个上限，万一哪天
/// 终止条件写错也不会变成死循环。
const int kMaxKeysPerProvider = 100;

class KeyStore {
  KeyStore._();

  static final KeyStore instance = KeyStore._();

  static const String _prefix = 'api_key_';

  final FlutterSecureStorage _storage = FlutterSecureStorage();

  /// 写入指定提供商的 API Key
  Future<void> writeKey(String provider, String key) async {
    try {
      await _storage.write(key: '$_prefix$provider', value: key);
    } catch (e) {
      debugPrint('⚠️ KeyStore 写入失败($provider): $e');
    }
  }

  /// 读取指定提供商的 API Key；失败返回 null
  Future<String?> readKey(String provider) async {
    try {
      return await _storage.read(key: '$_prefix$provider');
    } catch (e) {
      debugPrint('⚠️ KeyStore 读取失败($provider): $e');
      return null;
    }
  }

  /// 删除指定提供商的 API Key
  Future<void> deleteKey(String provider) async {
    try {
      await _storage.delete(key: '$_prefix$provider');
    } catch (e) {
      debugPrint('⚠️ KeyStore 删除失败($provider): $e');
    }
  }
  /// 读取指定提供商的所有 API Key（返回列表，按索引排序）
  Future<List<String>> readKeys(String provider) async {
    final keys = <String>[];
    for (int i = 0; i < kMaxKeysPerProvider; i++) {
      final key = await readKey('${provider}_$i');
      if (key == null || key.isEmpty) break;
      keys.add(key);
    }
    return keys;
  }

  /// 写入指定提供商的所有 API Key（覆盖写入，会清理旧 key）
  Future<void> writeKeys(String provider, List<String> keys) async {
    // 先清理旧的多 key
    await _deleteAllForProvider(provider);
    // 写入新 key
    for (int i = 0; i < keys.length; i++) {
      await writeKey('${provider}_$i', keys[i]);
    }
  }
  /// 删除指定提供商的所有 key：带索引的多 key **和**不带索引的旧单 key。
  ///
  /// 终止条件必须用 read 判空，不能靠 delete 抛异常：
  /// Android 端 delete 的实现是 `editor.remove(key); editor.apply();`，删一个
  /// 不存在的 key 静默成功、永不抛异常，于是老写法 `for (int i = 0;; i++)`
  /// 在 Android 上永远出不来——玩家每次保存/修改 API Key 都卡在 writeKeys
  /// 里，界面直接冻住。（iOS 的 Keychain 碰巧会对找不到的项报错，所以在
  /// iOS 上"能跑"，问题只在真机上才暴露。）
  ///
  /// 以前只删带索引的，不带索引的 `api_key_<p>`（老玩家经明文迁移留下来的）
  /// 一律保留。于是"删光全部 key"只删掉了索引副本，下次启动 readKeys 为空、
  /// 回退到 readKey(p) 又把那份旧单 key 读回来——玩家以为清空了，key 却复活。
  Future<void> _deleteAllForProvider(String provider) async {
    for (int i = 0; i < kMaxKeysPerProvider; i++) {
      final key = '$_prefix${provider}_$i';
      final existing = await readKey('${provider}_$i');
      if (existing == null || existing.isEmpty) break;
      try {
        await _storage.delete(key: key);
      } catch (_) {
        break;
      }
    }
    // 不带索引的旧单 key 一并清掉，否则它就是"删不掉的备份"。
    await deleteKey(provider);
  }
}