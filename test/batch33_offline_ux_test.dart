// v4 批次33 离线与体验层:Q4 / Q11 / Q13 行为测试。
//
// 覆盖三件事:
//  - Q11:NpcChatService 连发计数接近本地限流上限时判定降级本地模板,
//        不再让玩家干等「等待窗口滑出」;计数可复位。
//  - Q13:本地兜底叙事事件种子池按地点/时间分池,通用池随 seed 轮转,
//        长会话不撞句;深夜与普通时段返回不同句子。
//  - Q4:summary prompt 对超长的累积前情做分层压缩,只塞最新一段,
//        摘要输入 token 不再随局龄线性膨胀;短局不受影响。
import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/mixins/mixin_narrative.dart';
import 'package:hogwarts_life_simulator/prompts/summary_prompts.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/services/npc_chat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Q11 NPC 聊天连发保护', () {
    late NpcChatService service;
    setUp(() {
      service = NpcChatService(appProvider: AppProvider());
      service.resetRpmWindowForTest();
    });

    test('未到上限时判定不降级', () {
      expect(service.shouldDegradeLocalForTest(), isFalse);
    });

    test('记录接近上限次数的调用后判定降级', () {
      for (var i = 0; i < NpcChatService.kMaxRpmWindow; i++) {
        service.recordAiCallForTest();
      }
      expect(service.shouldDegradeLocalForTest(), isTrue);
    });

    test('降级判定只关心窗口内的计数', () {
      // 记录 18 次不掉出窗口 → 应判定降级
      for (var i = 0; i < NpcChatService.kMaxRpmWindow; i++) {
        service.recordAiCallForTest();
      }
      expect(service.shouldDegradeLocalForTest(), isTrue);
      // 复位后恢复
      service.resetRpmWindowForTest();
      expect(service.shouldDegradeLocalForTest(), isFalse);
    });
  });

  group('Q13 本地兜底叙事事件种子池', () {
    test('普通时段按地点分池：禁林与图书馆返回不同池', () {
      final forest = GameNarrativeMixin.localEventLinesFor(
          location: '禁林', hour: 14, seed: 1);
      final library = GameNarrativeMixin.localEventLinesFor(
          location: '图书馆', hour: 14, seed: 1);
      expect(forest, isNotEmpty);
      expect(library, isNotEmpty);
      // 专属池内句子各不相同（同一句话同时属于两个池不合逻辑）
      expect(forest.first, isNot(equals(library.first)));
    });

    test('深夜(hour<6 或 >=21)返回深夜专属池', () {
      final nightLines = GameNarrativeMixin.localEventLinesFor(
          location: '礼堂', hour: 23, seed: 0);
      expect(nightLines, isNotEmpty);
      final dayLines = GameNarrativeMixin.localEventLinesFor(
          location: '礼堂', hour: 12, seed: 0);
      // 深夜池不包含白天的礼堂句子
      expect(nightLines.contains(dayLines.first), isFalse);
    });

    test('无专属池地点走通用池，且随 seed 轮转不撞句', () {
      final s0 = GameNarrativeMixin.localEventLinesFor(
          location: '某未知角落', hour: 12, seed: 0);
      final s10 = GameNarrativeMixin.localEventLinesFor(
          location: '某未知角落', hour: 12, seed: 10);
      expect(s0, isNotEmpty);
      expect(s10, isNotEmpty);
      // seed 步长跨了不同通用子池 → 句子池不同，长会话不重复
      expect(s10.first, isNot(equals(s0.first)));
    });
  });

  group('Q4 摘要前情分层压缩', () {
    // 短前情（<=1400字）不受影响——保持原样
    test('短前情原样保留', () {
      const shortPrev = '开局遇到罗恩，结为朋友。';
      final p = buildSummaryPrompt(
        limit: 800,
        previousSummary: shortPrev,
        newChunk: '今天上了魔咒课。',
        relSnapshot: '罗恩:友好/10',
        coreFacts: '',
      );
      expect(p, contains(shortPrev));
    });

    // 超长前情：只保留最近一段 + 头部省略提示，不再线性全量喂给模型
    test('超长前情只保留最近一段，输入有上限', () {
      final longPrev = StringBuffer();
      // 构造远超 1400 字的前情
      for (var i = 0; i < 60; i++) {
        longPrev.write('第$i段摘要：与赫敏好感上升、与马尔福交恶、击败巨怪、前往图书馆查看禁书区的链锁书。\n');
      }
      final prevStr = longPrev.toString();
      expect(prevStr.length, greaterThan(kMaxPreviousChars));

      final p = buildSummaryPrompt(
        limit: 800,
        previousSummary: prevStr,
        newChunk: '今天上了魔咒课。',
        relSnapshot: '罗恩:友好/10',
        coreFacts: '',
      );
      // 分层后：包含「省略提示」头部，且完整前情已不逐字出现在 prompt 里
      expect(p, contains('早期剧情已有'));
      expect(p, contains('省略'));
      // 最老的第一段不再完整注入
      expect(p, isNot(contains('第0段摘要')));
      // 最新的接缝段仍保留
      expect(p, contains('第59段摘要'));
      // prompt 总长受控（不再有 40 段全量）
      expect(p.length, lessThan(4000));
    });

    test('恰好等于上限的前情不做分层', () {
      final exact = 'a' * kMaxPreviousChars;
      final p = buildSummaryPrompt(
        limit: 800,
        previousSummary: exact,
        newChunk: 'x',
        relSnapshot: '',
        coreFacts: '',
      );
      expect(p, contains(exact));
      expect(p, isNot(contains('早期剧情已有')));
    });
  });
}