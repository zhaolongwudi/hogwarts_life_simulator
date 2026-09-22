/// 批次 S2 / S3 / S12 减法专项测试。
///
/// 这三项的共同点是「删东西」——删掉的都是每回合必经链路上的重复内容。
/// 减法最难验证的地方在于：删多了不会编译失败，只会让 AI 慢慢变差，
/// 几周后才有人发现「它又开始原地打转了」。所以这里把**删了什么、
/// 保留了什么**都钉成断言。
///
/// 断言分三类：
///  1. **重复项确已删除** —— 同一句话不再出现两遍（token 省下来了）；
///  2. **关键约束确实保留** —— 减法是删冗余，不是删规则。删错一条
///     （比如把「不生成选项」删成一条不剩）会让 BUG-H 复发；
///  3. **数字口径锁死** —— T3 条数、锚点上限这类常量被改动时立刻可见。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/prompts/narrative_prompts.dart';

/// 统计 [haystack] 里 [needle] 出现的次数。
int _countOf(String haystack, String needle) {
  var count = 0;
  var idx = haystack.indexOf(needle);
  while (idx != -1) {
    count++;
    idx = haystack.indexOf(needle, idx + needle.length);
  }
  return count;
}

void main() {
  group('S2 · 删除重复规则段', () {
    test('「600-800字」在叙事规则里只出现一次（原先两处重叠）', () {
      // 原先 kWorldRulesFused 的「叙事风格 1」与 kNarrativeRulesCore 的
      // 「写作要求 1」各写一遍。现在只保留在 kWorldRulesFused（system prompt，
      // 权重更高），叙事规则侧不再重复。
      expect(kNarrativeRulesCore.contains('600-800字'), isFalse,
          reason: 'kWorldRulesFused 已声明 600-800 字，T0 不该再说一遍');
    });

    test('「每段必须推动剧情」不再与 system prompt 重复', () {
      expect(kNarrativeRulesCore.contains('每段必须推动剧情'), isFalse);
      // 但「有实质性进展」这条场景推进铁律必须留着——它不是重复，
      // 而是防原地打转的独立约束（对应 BUG：同一房间反复施法）。
      expect(kNarrativeRulesCore, contains('剧情必须每回合有实质性进展'));
    });

    test('「空洞的环境描写」禁令不再重复（system prompt 已覆盖）', () {
      expect(kNarrativeRulesCore.contains('空洞的环境描写'), isFalse);
      // 但「反复描写同一感受」是另一条约束（针对重复，不是针对空洞），保留。
      expect(kNarrativeRulesCore, contains('反复描写同一感受'));
    });

    test('T0 内部「不生成选项」只保留开头一处', () {
      // 原先第 1 行与末尾各说一遍。末尾那句（在【声望变化】格式说明之后）
      // 距离相关语境最远、权重最低，删的是它。
      expect(_countOf(kNarrativeRulesCore, '选项'), greaterThan(0),
          reason: '「不生成选项」的约束必须还在，否则 BUG-H 复发');
      expect(kNarrativeRulesCore, contains('选项将由独立步骤生成'));
      expect(kNarrativeRulesCore.contains('不需要生成选项'), isFalse,
          reason: '末尾重复句应已删除');
    });

    test('语言铁律只在 system prompt 侧保留一份', () {
      // 中文/禁外语这条在 kWorldRulesFused 的【语言铁律】里已经写了，
      // T0 再写一遍属于纯重复。
      expect(kNarrativeRulesCore.contains('严禁出现韩文、日文、英文'), isFalse);
    });

    test('减法后 T0 体积确实下降（防有人又把删掉的加回来）', () {
      // 原 2133 字符。留出余量：只要不涨回 2000 以上即可。
      expect(kNarrativeRulesCore.length, lessThan(2000),
          reason: 'S2 减法后应明显小于原来的 2133 字符');
    });
  });

  group('S3 · 上下文条数下调', () {
    final src =
        File('lib/mixins/mixin_narrative.dart').readAsStringSync();

    test('T3 世界事件降到 12 + 3 = 15 条', () {
      expect(src, contains('recentEvents.take(12)'));
      expect(src, contains('oldEvents.take(3)'));
      expect(src.contains('recentEvents.take(30)'), isFalse,
          reason: '旧的 30 条口径应已移除');
      expect(src.contains('oldEvents.take(10)'), isFalse);
    });

    test('世界锚点上限统一为 6（原先 12 与 16 两处不一致）', () {
      expect(src, contains('worldAnchors.length >= 6'));
      expect(src.contains('worldAnchors.length >= 12'), isFalse);
      expect(src.contains('worldAnchors.length >= 16'), isFalse);
    });
  });

  group('S12 · 选项端 T0 缩减', () {
    final src = File('lib/mixins/mixin_response.dart').readAsStringSync();

    test('降到 identity 4 + recent 5 = 9 条', () {
      expect(src, contains('identity.take(4)'));
      expect(src, contains('recent.take(5)'));
      expect(src.contains('identity.take(5)'), isFalse);
      expect(src.contains('recent.take(9)'), isFalse);
    });

    test('T0 注入本身保留（不能全删——两次调用不共享上下文）', () {
      // 这是本次减法里最容易被后人「优化掉」的一条：看到叙事端已有 T0，
      // 就把选项端整块删掉。那样会复活「向已订婚对象再表白」这类矛盾选项。
      expect(src, contains('【T0 核心事实（选项不能违背）】'),
          reason: '选项端 T0 必须保留：它与叙事端是两次独立 API 调用');
      expect(src, contains('topFactsForChoices'));
    });
  });
}