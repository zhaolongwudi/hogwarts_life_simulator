import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 安全存储服务：使用系统级加密存储保存 API Key。
///
/// iOS 使用 Keychain，Android 使用 Keystore/EncryptedSharedPreferences，
/// 避免将密钥明文写入 SharedPreferences 被 root 设备或反编译直接读取。
///
/// 读取失败（如测试环境无原生实现）时优雅返回 null，由调用方回退到旧版
/// SharedPreferences 迁移逻辑，保证健壮性而非直接崩溃。
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

  /// 读取所有已保存的 API Key（返回 provider -> key 的映射）
  Future<Map<String, String>> readAllKeys() async {
    try {
      final all = await _storage.readAll();
      final result = <String, String>{};
      all.forEach((key, value) {
        if (key.startsWith(_prefix)) {
          result[key.substring(_prefix.length)] = value;
        }
      });
      return result;
    } catch (e) {
      debugPrint('⚠️ KeyStore 批量读取失败: $e');
      return {};
    }
  }

  /// 删除所有 API Key
  Future<void> deleteAll() async {
    try {
      final all = await _storage.readAll();
      for (final key in all.keys) {
        if (key.startsWith(_prefix)) {
          await _storage.delete(key: key);
        }
      }
    } catch (e) {
      debugPrint('⚠️ KeyStore 批量删除失败: $e');
    }
  }
}