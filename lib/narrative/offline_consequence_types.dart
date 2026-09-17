/// P6 本地行动后果引擎的共享类型。
///
/// 【为什么单独一个文件】`OfflineConsequenceResult` 需要同时被
/// `GameProviderBase`（抽象声明）和 `GameOfflineConsequenceMixin`
/// （实现）引用。若把类型定义放在 mixin 文件里，基类导入 mixin 文件会
/// 形成循环导入（mixin 文件又导入基类）。纯数据文件谁都不依赖，两头导入
/// 都安全。与 `narrative/offline_narrative_context.dart` 同层放。
library;

/// 玩家行动可归属的类别（`none` = 无法归类，本次不结算）。
enum OfflineActivity { rest, work, study, practice, sport, social, explore, none }

/// 一次后果结算的结果：需要追加进叙事的行 + 需要进通知的提示。
class OfflineConsequenceResult {
  /// 追加进 `currentNarrative` 的完整句子（不含前缀，调用方统一加
  /// 「【行动结果】」段首）。
  final List<String> lines;

  /// 追加进 `notifications` 的提示（获得物品/加隆/好感这类值得提醒的）。
  final List<String> notes;

  const OfflineConsequenceResult({required this.lines, required this.notes});

  static const empty = OfflineConsequenceResult(lines: [], notes: []);
}
