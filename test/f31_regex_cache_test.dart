import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/utils/story_text_renderer.dart';

/// F31 / F33 回归护栏。
///
/// 背景：
/// - F31 把热路径上一批内联 `RegExp(...)` 收口为 `static final` 常量，
///   减少每次方法调用重复编译的浪费。这是纯重构，行为不得有任何变化。
/// - F33 要求全局解析缓存有上限（`_maxCacheSize=32`，满时淘汰最旧），
///   不能无限膨胀。
///
/// 这里逐条钉住被重构函数的可观察行为；并压测大量不同文本，
/// 确认解析缓存不会因无界增长引发问题（久跑不炸、结果仍正确）。
void main() {
  group('F31 重构后行为保持', () {
    test('stripInternalMetaMarkers：清掉「承接/SceneGraph」残留，正文不动', () {
      const meta =
          '（承接上回合剧情）—— 德拉科冷笑了一声。\n【时间戳】📅 清晨';
      final out = StoryTextRenderer.stripInternalMetaMarkers(meta);
      expect(out.contains('承接'), isFalse);
      // 正文「德拉科冷笑」必须保留
      expect(out.contains('德拉科冷笑'), isTrue);
      expect(out.trimLeft(), out); // 返回内容已 trimLeft
    });

    test('stripInternalMetaMarkers：清整行 SceneGraph debug 文本', () {
      const withGraph =
          '🧭 SceneGraph: id=42 anchor=hall\n\n赫敏走进礼堂。';
      final out = StoryTextRenderer.stripInternalMetaMarkers(withGraph);
      expect(out.contains('SceneGraph'), isFalse);
      expect(out.contains('赫敏走进礼堂'), isTrue);
    });

    test('stripMarkdownArtifacts：加粗/斜体/列表符被剥但正文保留', () {
      const md = '**重要**提示，__斜体__字。\n- 第一项\n1. 第二项';
      final out = StoryTextRenderer.stripMarkdownArtifacts(md);
      expect(out, contains('重要'));
      expect(out, contains('提示'));
      expect(out, contains('斜体'));
      expect(out.contains('**'), isFalse);
      expect(out.contains('__'), isFalse);
      // 列表符应被剥（-) 但列表文字在
      expect(out.contains('第一项'), isTrue);
      expect(out.contains('第二项'), isTrue);
    });

    test('extractAffectionSections：好感/声望区块被拆出，叙述为纯文本', () {
      const text =
          '罗恩给了你一块巧克力蛙。\n\n【好感度变化】\n罗恩：+5\n\n'
          '【声望变化】\n学院声望：+2';
      final r = StoryTextRenderer.extractAffectionSections(text);
      final narrative = r['narrative'] as String;
      final sections = (r['affectionSections'] as List).cast<String>();
      expect(narrative.contains('巧克力蛙'), isTrue);
      expect(narrative.contains('【好感度变化】'), isFalse);
      expect(narrative.contains('【声望变化】'), isFalse);
      expect(sections.any((s) => s.contains('罗恩：+5')), isTrue);
      expect(sections.any((s) => s.contains('学院声望：+2')), isTrue);
    });

    test('dedupeRepeatedParagraphs：整段复读只留第一条', () {
      const text = '第一段。\n\n复读句。\n\n复读句。';
      final out = StoryTextRenderer.dedupeRepeatedParagraphs(text);
      expect(out.split('\n\n').where((p) => p.contains('复读句')).length, 1);
      expect(out.contains('第一段'), isTrue);
    });

    test('splitParagraphs：双换行拆段，连着的对话行不误拆', () {
      const text = '哈利：走。\n罗恩：呀。\n\n赫敏：站住。';
      final paras = StoryTextRenderer.splitParagraphs(text);
      expect(paras.length, 2);
      expect(paras.first, contains('罗恩'));
      expect(paras.last, '赫敏：站住。');
    });

    test('autoParagraph：超长文本按句末标点分段，多余空行收敛为单双换行', () {
      final long = List.generate(10, (i) => '这是第${i + 1}个完整句子呀。').join('');
      final out = StoryTextRenderer.autoParagraph(long);
      // 没有三连以上空行
      expect(out.contains('\n\n\n'), isFalse);
      expect(out.isNotEmpty, isTrue);
    });

    test('stripTimestampPrefix：去掉【时间戳】/📅 前缀，保留时间正文', () {
      expect(StoryTextRenderer.stripTimestampPrefix('【时间戳】📅 清晨'),
          '清晨');
      expect(StoryTextRenderer.stripTimestampPrefix('📅 上午十点'), '上午十点');
      // 无前缀的普通段原样返回
      expect(StoryTextRenderer.stripTimestampPrefix('赫敏在看书'), '赫敏在看书');
    });

    test('parseAffectionLine：正负好感着色（+绿 -红）', () {
      final spans = StoryTextRenderer.parseAffectionLine('罗恩：+5（拿走了糖果）');
      final green = spans.firstWhere((s) => s.text == '+5');
      expect(green.style?.color, const Color(0xFF7EE787));
    });

    test('dialogue 解析：说话人 + 神态（括号）仍正确', () {
      // 说话人判定用的正则被常量替换，此处走 parse 验证冒号对话不回归
      const dialogueColor = Color(0xFF79C0FF);
      final spans = StoryTextRenderer.parse('德拉科（冷笑）：你逃不掉的。');
      final text = spans.map((s) => s.text ?? '').join();
      expect(text, isNotEmpty);
      expect(text, contains('你逃不掉的'));
      expect(
        spans.any((s) => s.style?.color == dialogueColor),
        isTrue,
      );
    });
  });

  group('F33 解析缓存压测', () {
    test('上千段不同叙事反复解析：久跑不炸、结果正确', () {
      var total = 0;
      for (var i = 0; i < 1500; i++) {
        final spans = StoryTextRenderer.parse('第${i}段：赫敏说这是第${i}次。');
        // 高亮应有名字/台词，不能因缓存淘汰返回空或错乱
        final text = spans.map((s) => s.text ?? '').join();
        expect(text, isNotEmpty);
        expect(text, contains('赫敏'));
        total += text.length;
      }
      expect(total, greaterThan(0)); // 避免空转
    });
  });
}