import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/debug_log.dart';

/// SharedPreferences 的唯一收口（审查 D4 / F16 / F36 / F37）。
///
/// 收口之前全库有 16 处直接 `SharedPreferences.getInstance()`，问题分三类：
///
/// 1. **fire-and-forget**（F16 / F36）：`SharedPreferences.getInstance()
///    .then((prefs) => prefs.setBool(...))` —— 不 await、不 catch。
///    写入失败（磁盘满、进程被杀）时**既不会重试也不会有任何痕迹**，
///    用户改了设置、下次打开又变回去，还以为是玄学。
/// 2. **每次都 getInstance**（D4）：虽然插件内部有缓存，但"取实例"这件事散落在
///    16 个地方，读代码的人无法判断"这里到底有没有初始化过"。
/// 3. **逐条写入**（F37）：`clearApiKeyFor` 里连着 `remove` 两个 key，
///    每次 remove 都是一次独立的提交。
///
/// 现在统一成三个方法：[init] 取实例、[write] 批量写并 await + catch、
/// [writeAsync] 给"这次写失败也不该阻塞 UI"的场景（内部照样 catch + 日志）。
///
/// 刻意**没有**做成"全局单例自动初始化"：初始化失败是有意义的信号，
/// 调用方需要看到它，静默吞掉只会让问题更难查。
class PrefsStore {
  PrefsStore._();
  static final PrefsStore instance = PrefsStore._();

  SharedPreferences? _prefs;

  /// 是否已经初始化。读取偏好前应确保为 true（启动流程里已 await [init]）。
  bool get ready => _prefs != null;

  /// 仅供测试：清掉缓存的实例，让下一次 [init] 重新取。
  ///
  /// 生产代码不该调它 —— 实例被清掉后所有 `getXxx` 会静默回退到 fallback。
  @visibleForTesting
  void resetForTest() => _prefs = null;

  /// 取实例（带缓存）。重复调用不会重复走 platform channel。
  Future<SharedPreferences> init() async {
    final cached = _prefs;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    return prefs;
  }

  /// 同步读：仅在 [ready] 为 true 时有效，未就绪返回 [fallback]。
  ///
  /// 只给"已经 await 过 [init] 的热路径"用。别在启动流程里赌它已就绪 ——
  /// 拿不到就走 fallback，比抛异常安全，但也别指望它一定准。
  bool getBool(String key, {bool fallback = false}) =>
      _prefs?.getBool(key) ?? fallback;

  int getInt(String key, {int fallback = 0}) => _prefs?.getInt(key) ?? fallback;

  String? getString(String key) => _prefs?.getString(key);

  /// 批量写入：一个闭包里可以写任意多个 key，只提交一次（F37）。
  ///
  /// [label] 用于失败日志——写偏好失败是静默的，没有 label 就只剩一句
  /// "SharedPreferences 写入失败"，看不出是哪个设置丢了。
  /// 返回是否成功，调用方可以据此决定是否提示用户。
  Future<bool> write(String label, void Function(SharedPreferences p) writes) async {
    try {
      final prefs = await init();
      writes(prefs);
      return true;
    } catch (e, st) {
      // F16/F36 的核心：不再是 fire-and-forget，写失败一定留痕。
      debugLog('[PrefsStore] 偏好写入失败($label): $e\n$st');
      return false;
    }
  }

  /// 不阻塞当前流程的写入。
  ///
  /// 与"裸 .then() 不 await"的区别：**仍然 catch 并记日志**。
  /// 设置项这类"写慢一点无所谓，但绝不能静默丢"的场景用它。
  void writeAsync(String label, void Function(SharedPreferences p) writes) {
    unawaited(write(label, writes));
  }
}
