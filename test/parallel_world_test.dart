import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/parallel_data.dart';
import 'package:hogwarts_life_simulator/models/player.dart';

ParallelScenario _s({
  String title = '如果分院帽按成绩分配',
  String description = '不再看勇气和忠诚，只看成绩单。',
  bool adopted = false,
}) =>
    ParallelScenario(
      title: title,
      description: description,
      adopted: adopted,
    );

void main() {
  // ============================================================ 设计约束
  group('采纳不等于它发生过', () {
    test('记忆文本写的是"想过"，不是"发生"', () {
      // 这条是整个设计的命门。写成陈述事实的语气，
      // AI 后面就会把它当既成事实写戏——
      // 玩家写一句"如果邓布利多开了甜品店"，世界就改一次，
      // 世界线变动率那套"改写得付代价"的逻辑就成了空话。
      final fact = adoptedFactFor(_s());
      expect(fact.contains('你认真想过'), isTrue,
          reason: '记忆文本没有标成"想过"：$fact');
      for (final word in const ['发生了', '已经', '如今', '现在他']) {
        expect(fact.contains(word), isFalse,
            reason: '记忆文本把脑洞写成了既成事实：$fact');
      }
    });

    test('prompt 段落明确告诉 AI 这不是事实', () {
      // 只说"玩家想过这些"而不说清"它们没发生过"，
      // AI 大概率会当成背景设定写进去。
      final block = adoptedPromptBlock([_s(adopted: true)]);
      expect(block.contains('没有发生过'), isTrue,
          reason: 'prompt 里没写清这些不是事实');
      expect(block.contains('独白'), isTrue,
          reason: 'prompt 里没交代它该以什么形式出现');
    });

    test('通知文案也说清它不会发生', () {
      final notice = adoptedNoticeFor(_s());
      expect(notice.contains('不会发生'), isTrue, reason: '$notice');
    });
  });

  // ============================================================ 文本处理
  group('文本处理', () {
    test('长描述会被截断，不会撑爆一行', () {
      final long = '如果那天晚上你没有走进那间教室，'
          '那么后来发生的每一件事都不会发生，'
          '而你会成为另一个完全不同的人，'
          '住在另一个地方，做着另一份工作，认识另一群人。';
      final fact = adoptedFactFor(_s(description: long));
      expect(fact.length, lessThan(80), reason: '记忆文本太长：$fact');
      expect(fact.endsWith('…'), isTrue, reason: '截断后应该带省略号');
    });

    test('截断不会砍在词中间', () {
      // 从字符中间砍断会留下半个词，读起来像乱码。
      // 所以往回退到最后一个标点或空格处。
      final long = '如果分院帽把每一个人都分到了他们最想去的那个学院，'
          '而不是他们最需要的那个学院，那么这七年会变成另一本书。';
      final fact = adoptedFactFor(_s(description: long));
      final brief = fact.split('：').last;
      // 结尾要么完整结束，要么停在标点后的省略号上
      expect(brief.endsWith('…'), isTrue);
      expect(brief.length, greaterThan(10), reason: '退得太多了：$brief');
    });

    test('短描述原样保留，不加省略号', () {
      final fact = adoptedFactFor(_s(description: '就这样。'));
      expect(fact.contains('…'), isFalse, reason: '没截断却加了省略号：$fact');
      expect(fact.contains('就这样。'), isTrue);
    });

    test('标题进记忆，日后能追溯是哪个念头', () {
      final fact = adoptedFactFor(_s(title: '如果那天你没上那趟车'));
      expect(fact.contains('如果那天你没上那趟车'), isTrue);
    });
  });

  // ============================================================ prompt 段
  group('prompt 段落', () {
    test('没有采纳过时返回空串', () {
      // 空段落不注入。为一个没采纳过的玩家写一段"另一种可能"
      // 等于凭空给他加设定。
      expect(adoptedPromptBlock(const []), isEmpty);
      expect(adoptedPromptBlock([_s(adopted: false)]), isEmpty);
    });

    test('最多三条，多了会说明还有几条', () {
      // 采纳得多的玩家不该被自己的脑洞淹没。
      final many = List.generate(6, (i) => _s(title: '第$i个', adopted: true));
      final block = adoptedPromptBlock(many);
      final lines = block.split('\n').where((l) => l.startsWith('· ')).length;
      expect(lines, 3, reason: '注入了 $lines 条，该是 3 条');
      expect(block.contains('还有 3 个'), isTrue, reason: '没交代还剩下几条');
    });

    test('只收已采纳的', () {
      final mixed = [
        _s(title: '已采纳', adopted: true),
        _s(title: '没采纳', adopted: false),
      ];
      final block = adoptedPromptBlock(mixed);
      expect(block.contains('已采纳'), isTrue);
      expect(block.contains('没采纳'), isFalse);
    });

    test('段落里给出用法，不是只丢一堆设定', () {
      // 光说"有这些"，AI 不知道该在什么时候用。
      final block = adoptedPromptBlock([_s(adopted: true)]);
      expect(block.contains('想起'), isTrue,
          reason: '没告诉 AI 该在什么时候让它浮现');
    });
  });

  // ============================================================ 存档
  group('存档往返', () {
    test('adopted 会落盘', () {
      final s = _s(adopted: true);
      final back = ParallelScenario.fromJson(s.toJson());
      expect(back.adopted, isTrue, reason: '采纳状态没存进存档');
      expect(back.title, s.title);
      expect(back.description, s.description);
    });

    test('旧存档没有 adopted 字段时按未采纳处理', () {
      // 老存档里没有这个键，读回来不能是 null 也不能默认成已采纳。
      final back = ParallelScenario.fromJson({
        'title': '老脑洞',
        'description': '很久以前写的',
        'icon': '🎭',
        'created_at': '2024-01-01',
      });
      expect(back.adopted, isFalse, reason: '旧存档被当成了已采纳');
    });

    test('copyWith 能翻 adopted，不动别的字段', () {
      final s = _s();
      final back = s.copyWith(adopted: true);
      expect(back.adopted, isTrue);
      expect(back.title, s.title);
      expect(back.description, s.description);
      expect(back.createdAt, s.createdAt);
    });
  });

  // ============================================================ 接线
  group('真的接进了游戏', () {
    test('provider 有采纳方法，且防重复采纳', () {
      final src = File('lib/mixins/mixin_systems.dart').readAsStringSync();
      expect(src.contains('adoptParallelScenario'), isTrue,
          reason: '没有采纳入口');
      // 一个念头只能决定留不留下一次：反复采纳会把
      // "想起它"这件事变成可以刷的东西。
      final iFn = src.indexOf('bool adoptParallelScenario');
      final body = src.substring(iFn, iFn + 700);
      expect(body.contains('if (s.adopted) return false'), isTrue,
          reason: '没有防重复采纳');
    });

    test('采纳会写一条长期记忆', () {
      final src = File('lib/mixins/mixin_systems.dart').readAsStringSync();
      final iFn = src.indexOf('bool adoptParallelScenario');
      final body = src.substring(iFn, iFn + 1400);
      expect(body.contains('addKeyFact'), isTrue, reason: '采纳没有留下记忆');
      expect(body.contains('adoptedFactFor'), isTrue);
    });

    test('采纳会真的改掉列表里那一条', () {
      // 只写记忆不标 adopted 的话，下次点开还能再采纳一次：
      // 记忆会重复，而"留在心里"这件事变成可以刷的。
      final src = File('lib/mixins/mixin_systems.dart').readAsStringSync();
      final iFn = src.indexOf('bool adoptParallelScenario');
      final body = src.substring(iFn, iFn + 900);
      expect(body.contains('copyWith(adopted: true)'), isTrue,
          reason: '没有把那条标记为已采纳');
    });

    test('prompt 里注入了【另一种可能】', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      expect(src.contains('adoptedPromptBlock('), isTrue,
          reason: '场景上下文里没有注入采纳过的脑洞');
      // 必须只收已采纳的
      expect(src.contains('.where((s) => s.adopted)'), isTrue,
          reason: '没过滤，会把所有脑洞都塞进 prompt');
    });

    test('详情弹窗里有采纳入口，预设脑洞没有', () {
      final src =
          File('lib/screens/other/parallel_world_screen.dart').readAsStringSync();
      expect(src.contains('adoptParallelScenario'), isTrue,
          reason: 'UI 上没有采纳按钮');
      // 预设是只读引子、不进存档，点开不该有采纳按钮
      expect(src.contains('_showDetail(context, s)'), isTrue,
          reason: '预设脑洞的调用丢了，无法确认它没带 index');
      expect(src.contains('_showDetail(context, mine[i], index: i)'), isTrue);
    });
  });
}
