import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/forbidden_words.dart';
import 'package:hogwarts_life_simulator/prompts/narrative_prompts.dart';
import 'package:hogwarts_life_simulator/data/world_rules.dart';

void main() {
  // ==================== 违和词表 ====================
  // 这张表原先写死在 mixin 方法里：既没法单测（要先搭 GameProvider），
  // 也拿不到时代信息——于是 2020 战后时代的玩家写「掏出手机」也会被判
  // critical，强制重生成最多 3 次。

  group('违和词表 时代门', () {
    test('1991 时代写现代物品仍然要拦', () {
      final hits = detectForbiddenWords('他从口袋里掏出手机看了一眼。', eraKey: 'harry_same');
      expect(hits.any((h) => h.category == 'modern' && h.severity == 'critical'),
          isTrue,
          reason: '子世代出现「手机」必须判 critical');
    });

    test('2020 战后时代放行现代物品', () {
      for (final w in ['手机', '电视', '飞机', '电脑', '地铁']) {
        final hits = detectForbiddenWords('他掏出$w。', eraKey: 'post_war');
        expect(hits.where((h) => h.category == 'modern'), isEmpty,
            reason: '2020 时代出现「$w」是日常，不该触发重生成');
      }
    });

    test('跨 IP 在任何时代都要拦，包括 2020', () {
      final hits = detectForbiddenWords('路飞从走廊那头跑过来。', eraKey: 'post_war');
      expect(hits.any((h) => h.category == 'cross_ip' && h.severity == 'critical'),
          isTrue,
          reason: '跨 IP 角色不该因为时代门被一起放行');
    });

    test('eraKey 省略时按保守处理（不放大现代物品）', () {
      final hits = detectForbiddenWords('他掏出手机。');
      expect(hits.any((h) => h.category == 'modern'), isTrue,
          reason: '拿不到时代信息时应该照旧拦，不能默认放行');
    });
  });

  group('违和词表 不再误伤正常用词', () {
    // 原文是 `final lower = text;` —— 变量名叫 lower 却没转小写。
    // 于是 'switch' 这种小写条目会误伤英文正常用词。
    test('英文单词里的 app / switch 不算违和', () {
      for (final s in [
        'She took a bite of the apple.',
        'Something happened last night.',
        'He approached the door.',
        'The witch switched seats.',
      ]) {
        final hits = detectForbiddenWords(s, eraKey: 'harry_same');
        expect(hits.where((h) => h.category == 'modern'), isEmpty,
            reason: '「$s」被误判成现代物品了');
      }
    });

    test('独立成词的 app / Switch 仍然要拦', () {
      expect(
        detectForbiddenWords('He opened an app on his device.', eraKey: 'harry_same')
            .any((h) => h.category == 'modern'),
        isTrue,
      );
      // 大写也要能命中——没转小写时 'Switch' 这条永远匹配不上
      expect(
        detectForbiddenWords('A Switch console lay on the desk.', eraKey: 'harry_same')
            .any((h) => h.category == 'modern'),
        isTrue,
      );
    });

    test('数字梗按整段数字匹配，不会从更长的数字里切出来', () {
      // 「1233 加隆」里含 233，但它是四位数的一部分
      expect(
        detectForbiddenWords('他付了 1233 加隆。', eraKey: 'harry_same')
            .where((h) => h.category == 'slang'),
        isEmpty,
        reason: '不该从 1233 里切出一个 233',
      );
      expect(
        detectForbiddenWords('第 2334 页。', eraKey: 'harry_same')
            .where((h) => h.category == 'slang'),
        isEmpty,
      );
      expect(
        detectForbiddenWords('他在墙上写了 666。', eraKey: 'harry_same')
            .any((h) => h.category == 'slang'),
        isTrue,
      );
    });

    test('「逻辑」不再是违和词（曾经把「罗辑」误写成「逻辑」）', () {
      expect(detectForbiddenWords('这个逻辑说不通。', eraKey: 'harry_same'), isEmpty);
    });
  });

  // ==================== 选项生成的口径 ====================
  // BUG-H 的根因：system prompt 要 AI 输出【可选行动】A/B/C/D，
  // 而每回合的 user prompt 说「选项由独立步骤生成，本轮不要输出」。
  // 两条指令打架，模型随机二选一，命中就整段重生成两次。

  group('prompt 里「是否输出选项」只有一个说法', () {
    // 「【可选行动】」这四个字允许出现——禁令里要点名它。
    // 要拦的是把它当成**输出格式要求**列出来（带示例或缩写清单）。
    bool asksForChoiceBlock(String prompt) =>
        RegExp(r'【可选行动】\s*\n?\s*A[.、]').hasMatch(prompt) ||
        prompt.contains('【可选行动】A/B/C');

    test('完整版系统提示词明令本轮不输出选项', () {
      expect(kWorldRulesFused, contains('本轮不输出选项'));
      expect(asksForChoiceBlock(kWorldRulesFused), isFalse,
          reason: 'system prompt 又把【可选行动】当成输出格式要求了，'
              '它和 user prompt 的「选项由独立步骤生成」直接打架');
    });

    test('精简版系统提示词同样不输出选项', () {
      expect(kWorldRulesFusedCompact, contains('本轮不输出任何选项'));
      expect(asksForChoiceBlock(kWorldRulesFusedCompact), isFalse);
    });

    test('每回合的写作要求不要求输出选项', () {
      expect(kNarrativeWritingRules, contains('选项将由独立步骤生成'));
      expect(asksForChoiceBlock(kNarrativeWritingRules), isFalse);
    });

    test('开场 prompt 也不再要求输出选项（它以前是矛盾的另一半）', () {
      final opening = buildOpeningNarrativePrompt(
        profileLine: '姓名：测试',
        startPoint: '车站',
        wandDetail: '枫木·凤凰羽毛·11英寸',
        wandSourceLine: '奥利凡德',
      );
      expect(asksForChoiceBlock(opening), isFalse);
      expect(opening, isNot(contains('A/B/C（具体动作）')));
      expect(opening, isNot(contains('【自由行动】')));
      expect(opening, contains('不要生成任何选项'));
    });

    test('开场叙事会补一次独立选项生成', () {
      final src = File('lib/mixins/mixin_init.dart').readAsStringSync();
      final body = src.substring(src.indexOf('_generateOpeningScene'));
      expect(body, contains('generateChoicesSeparately'),
          reason: '开场 prompt 已经不要求选项了，这里必须补一次独立生成，'
              '否则开局只剩本地兜底选项');
    });
  });

  // ==================== 玩家可见文案不含内部术语 ====================

  group('玩家看得见的地方不出现内部术语', () {
    final libFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    test('loadingStage 不暴露内部校验机制', () {
      // 「请求失败，正在重试」是有效的网络层提示，可以留；
      // 要禁的是让玩家意识到"有个校验器在给 AI 打分"的说法。
      final offenders = <String>[];
      for (final f in libFiles) {
        final src = f.readAsStringSync();
        for (final m in RegExp(r"loadingStage = '([^']*)'").allMatches(src)) {
          final text = m.group(1)!;
          if (text.contains('违规') ||
              text.contains('节点') ||
              text.contains('模型') ||
              text.contains('校验')) {
            offenders.add('${f.path}: $text');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'loadingStage 是玩家能看到的，不能出现内部术语：$offenders');
    });

    test('通知文案里没有「节点=xxx」这种变量名', () {
      final offenders = <String>[];
      for (final f in libFiles) {
        for (final m in RegExp(r"notifications\.add\('([^']*)'\)")
            .allMatches(f.readAsStringSync())) {
          if (m.group(1)!.contains('=')) offenders.add('${f.path}: ${m.group(1)}');
        }
      }
      expect(offenders, isEmpty, reason: '通知里印了内部变量：$offenders');
    });
  });

  // ==================== 翻页边界 ====================

  group('剧情回顾翻页', () {
    test('start 和 end 都做了 clamp（只 clamp end 会抛 RangeError）', () {
      final src = File('lib/screens/story_history_screen.dart').readAsStringSync();
      expect(src, contains('final start = (page * _turnsPerPage).clamp'),
          reason: 'start 没 clamp：回合数变少后 sublist(start, end) 会崩');
      expect(src, contains('final end = (start + _turnsPerPage).clamp'),
          reason: 'end 没 clamp');
      expect(src, contains('final page = _currentPage.clamp'),
          reason: '页码本身也要钳回合法范围，否则会显示成「第 8 / 3 页」');
    });
  });

  // ==================== 死文件 ====================

  group('仓库里没有 0 字节的 dart 文件', () {
    test('曾经有一个空的 models/hogwarts_house.dart', () {
      final empties = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.lengthSync() == 0)
          .map((f) => f.path)
          .toList();
      expect(empties, isEmpty, reason: '这些 dart 文件是空的：$empties');
    });
  });
}
