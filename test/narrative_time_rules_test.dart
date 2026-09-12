import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/narrative_time_rules.dart';
import 'package:hogwarts_life_simulator/data/time_cost_rules.dart';

void main() {
  // ------------------------------------------------------------ 时间戳解析
  group('解析 AI 自报的日期', () {
    test('完整版时间戳', () {
      final ts = parseAiTimestamp(
          '【时间戳】📅 1991年9月1日，星期日，上午 9:00\n【地点】霍格沃茨特快列车');
      expect(ts.year, 1991);
      expect(ts.month, 9);
      expect(ts.day, 1);
      expect(ts.isComplete, isTrue);
    });

    test('精简版时间戳（无年份）缺年即视为不完整', () {
      final ts = parseAiTimestamp('📅 9月3日 傍晚\n正文');
      expect(ts.month, 9);
      expect(ts.day, 3);
      expect(ts.year, isNull);
      expect(ts.isComplete, isFalse);
    });

    test('没有时间戳行时返回空壳', () {
      final ts = parseAiTimestamp('你推开魔药课教室的门。');
      expect(ts.isComplete, isFalse);
    });
  });

  // ------------------------------------------------------------ 时间跳跃词
  group('时间跳跃词', () {
    test('常见快进写法都能抓到', () {
      for (final phrase in [
        '三天后',
        '一周过去',
        '一个月过去了',
        '一年后',
        '日子一天天过去',
        '十年后',
      ]) {
        final report = checkNarrativeTime('就这样，$phrase，你回到了宿舍。',
            year: 1991, month: 9, day: 1);
        expect(report.issue, NarrativeTimeIssue.jumpPhrase,
            reason: '「$phrase」应被判为时间跳跃');
        expect(report.needsRewrite, isTrue);
      }
    });

    test('正常叙事不误伤', () {
      final report = checkNarrativeTime(
        '你推开魔药课教室的门，斯内普抬眼看了你一下，'
            '又低头去搅那锅咕嘟作响的溶液。教室里弥漫着一股刺鼻的草药味。',
        year: 1991,
        month: 9,
        day: 1,
      );
      expect(report.hasProblem, isFalse);
    });
  });

  // -------------------------------------------------------------- 日期比对
  group('日期与系统日历比对', () {
    NarrativeTimeReport check(String narrative) =>
        checkNarrativeTime(narrative, year: 1991, month: 9, day: 1);

    test('同日 → 没问题', () {
      final r = check('【时间戳】📅 1991年9月1日，星期日，下午 3:00\n正文');
      expect(r.issue, NarrativeTimeIssue.none);
      expect(r.hasProblem, isFalse);
    });

    test('倒流 → critical，要重写', () {
      final r = check('【时间戳】📅 1991年8月31日，星期六，上午 9:00\n正文');
      expect(r.issue, NarrativeTimeIssue.regression);
      expect(r.deltaDays, -1);
      expect(r.needsRewrite, isTrue);
    });

    test('跨天超过一天 → critical，要重写', () {
      final r = check('【时间戳】📅 1991年9月4日，星期三，上午 9:00\n正文');
      expect(r.issue, NarrativeTimeIssue.jump);
      expect(r.deltaDays, 3);
      expect(r.needsRewrite, isTrue);
    });

    test('只跨一天 → 放行（深夜延续不算越界）', () {
      final r = check('【时间戳】📅 1991年9月2日，星期一，凌晨 1:00\n正文');
      expect(r.issue, NarrativeTimeIssue.overnight);
      expect(r.hasProblem, isTrue);
      expect(r.needsRewrite, isFalse,
          reason: '深夜聊到凌晨是合理的，不该为它浪费一轮重写');
    });

    test('跨月边界按真实天数算，不会被月份差骗', () {
      // 9月30日 → 10月1日只差一天，不是"跨了一个月"。
      final r = checkNarrativeTime('📅 1991年10月1日 清晨\n正文',
          year: 1991, month: 9, day: 30);
      expect(r.issue, NarrativeTimeIssue.overnight);
      expect(r.deltaDays, 1);
    });

    test('跨年边界', () {
      final r = checkNarrativeTime('📅 1992年1月1日 清晨\n正文',
          year: 1991, month: 12, day: 31);
      expect(r.deltaDays, 1);
      expect(r.issue, NarrativeTimeIssue.overnight);
    });

    test('闰年 2 月 29 日也能算对', () {
      // 1992 是闰年：2月28日 → 3月1日 中间隔着 2月29日，差 2 天。
      final r = checkNarrativeTime('📅 1992年3月1日 清晨\n正文',
          year: 1992, month: 2, day: 28);
      expect(r.deltaDays, 2);
      expect(r.issue, NarrativeTimeIssue.jump);
    });

    test('AI 没写日期时不判越界', () {
      final r = check('你走进大礼堂，四处张望。');
      expect(r.issue, NarrativeTimeIssue.none);
    });
  });

  // ---------------------------------------------------- 缺年时间戳（P1-7）
  group('缺年时间戳（P1-7）', () {
    NarrativeTimeReport check(String narrative) =>
        checkNarrativeTime(narrative, year: 1991, month: 9, day: 1);

    test('「📅 9月3日」缺年 → 判为跳跃，不再静默放行', () {
      final r = check('📅 9月3日 傍晚\n正文');
      expect(r.issue, NarrativeTimeIssue.jump,
          reason: 'AI 只写月日不写年时，以前直接 return none，跳跃检测整体失效');
      expect(r.needsRewrite, isTrue);
    });

    test('缺年但写的正是今天 → 通过', () {
      final r = check('📅 9月1日 傍晚\n正文');
      expect(r.issue, NarrativeTimeIssue.none,
          reason: 'AI 照抄了当前日期只是省略年份，不该误伤');
    });

    test('缺年写的昨天 → 倒流', () {
      final r = check('📅 8月31日 傍晚\n正文');
      expect(r.issue, NarrativeTimeIssue.regression);
      expect(r.needsRewrite, isTrue);
    });

    test('缺年写的明天 → 放行（深夜延续）', () {
      final r = check('📅 9月2日 凌晨\n正文');
      expect(r.issue, NarrativeTimeIssue.overnight);
      expect(r.needsRewrite, isFalse);
    });

    test('缺年写「1月1日」从「12月31日」→ 按次年解释只差一天', () {
      final r = checkNarrativeTime('📅 1月1日 凌晨\n正文',
          year: 1991, month: 12, day: 31);
      expect(r.issue, NarrativeTimeIssue.overnight,
          reason: '跨年夜的凌晨叙事按「次年1月1日」解释只差一天，不该判成回归');
    });
  });

  // -------------------------------------------------------------- 时间戳回填
  group('时间戳回填', () {
    const systemTs = '📅 1991年9月1日，星期日，上午 9:00';

    test('替换【时间戳】整行', () {
      final out = backfillTimestamp(
        '【时间戳】📅 1991年9月4日，星期三，下午 3:00\n【地点】图书馆\n\n正文在这里，字数足够长。',
        systemTs,
      );
      expect(out, startsWith('【时间戳】📅 1991年9月1日，星期日，上午 9:00'));
      expect(out, isNot(contains('9月4日')));
    });

    test('替换精简版的裸 📅 行', () {
      final out = backfillTimestamp('📅 1991年9月4日 下午\n\n正文在这里，字数足够长。', systemTs);
      expect(out, startsWith('📅 1991年9月1日，星期日，上午 9:00'));
    });

    test('没有时间戳行时不凭空造一行', () {
      const text = '你走在走廊上，两边的肖像在低声议论。';
      expect(backfillTimestamp(text, systemTs), text);
    });

    test('系统时间戳为空时原样返回', () {
      const text = '【时间戳】📅 1991年9月4日\n正文';
      expect(backfillTimestamp(text, ''), text);
    });

    test('回填后【地点】等其它头部不受影响', () {
      final out = backfillTimestamp(
        '【时间戳】📅 1991年9月4日\n【地点】霍格沃茨·图书馆\n\n正文正文正文。',
        systemTs,
      );
      expect(out, contains('【地点】霍格沃茨·图书馆'));
    });
  });

  // ------------------------------------------------------------ prompt 注入
  group('时间预算注入 prompt', () {
    test('说明行带上本回合实际耗时', () {
      final line = timeBudgetPromptLine(resolveActionCost('去图书馆自习'));
      expect(line, contains('120'));
      expect(line, contains('时间预算'));
    });

    test('说明行明令禁止跨天', () {
      final line = timeBudgetPromptLine(60);
      expect(line, contains('三天后'));
      expect(line, contains('严禁'));
      expect(line, contains('日历'));
    });

    test('长耗时会换算成小时，不堆分钟数', () {
      expect(timeBudgetPromptLine(480), contains('8 小时'));
      expect(timeBudgetPromptLine(30), contains('30 分钟'));
    });
  });

  // ------------------------------------------------------- 防止接线掉回去
  group('生产代码确实接上了', () {
    test('连续性检查用上了 checkNarrativeTime', () {
      final src = File('lib/mixins/mixin_narrative_continuity.dart')
          .readAsStringSync();
      expect(src.contains('checkNarrativeTime'), isTrue);
      // 旧的只判倒流的粗校验应当已被替换掉
      expect(src.contains('R1_time_regression'), isTrue);
      expect(src.contains('R4_time_jump'), isTrue);
      expect(src.contains('R4_time_jump_phrase'), isTrue);
    });

    test('叙事 prompt 注入了时间预算', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      expect(src.contains('timeBudgetPromptLine'), isTrue);
      expect(src.contains('resolveActionCost'), isTrue);
    });

    test('回填被接到叙事落定的位置', () {
      final src = File('lib/mixins/mixin_response.dart').readAsStringSync();
      expect(src.contains('backfillTimestamp'), isTrue);
    });

    test('世界规则里写明了时间由系统独占', () {
      final src = File('lib/data/world_rules.dart').readAsStringSync();
      expect(src.contains('时间由系统独占'), isTrue);
      expect(src.contains('照抄'), isTrue);
      // 不能再留一个写死的示例日期当模板，否则 AI 会照抄示例
      expect(src.contains('📅 1991年9月1日，星期日，上午 9:00'), isFalse);
    });
  });
}
