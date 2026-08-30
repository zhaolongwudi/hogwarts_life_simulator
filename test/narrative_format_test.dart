/// 剧情输出排版优化（小说式段落排版）行为测试
///
/// 纪律同前：纯函数断言守性质（拆段规则、缩进存在、高亮不丢），
/// 源码检查只验接线，不锁像素。
///
/// 覆盖：
///  1. splitParagraphs 拆段规则（空行拆、单换行不拆、空白过滤）
///  2. parseParagraph 首行缩进 + 高亮规则与 parse 一致
///  3. 渲染层真的接上了（_buildNarrationBody / 逐段动画）
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/utils/story_text_renderer.dart';

void main() {
  group('splitParagraphs 拆段规则', () {
    test('空行拆段，单换行不拆', () {
      final ps = StoryTextRenderer.splitParagraphs('第一段。\n段内折行。\n\n第二段。');
      expect(ps.length, 2);
      expect(ps[0], contains('段内折行'));
      expect(ps[1], '第二段。');
    });

    test('多个空行视为一个分隔，空白段落被过滤', () {
      final ps = StoryTextRenderer.splitParagraphs('甲。\n\n\n\n乙。');
      expect(ps, ['甲。', '乙。']);
    });

    test('整段无空行时原样返回单段', () {
      final ps = StoryTextRenderer.splitParagraphs('没有空行的一大段。');
      expect(ps.length, 1);
    });

    test('空文本返回空列表', () {
      expect(StoryTextRenderer.splitParagraphs(''), isEmpty);
      expect(StoryTextRenderer.splitParagraphs('\n\n  \n'), isEmpty);
    });
  });

  group('parseParagraph 首行缩进', () {
    test('默认段首有两个全角字符的缩进', () {
      final spans = StoryTextRenderer.parseParagraph('你推开大门。');
      expect(spans.first.text, '　　');
    });

    test('indent: false 时不缩进（气泡等特殊场景可关）', () {
      final spans =
          StoryTextRenderer.parseParagraph('你推开大门。', indent: false);
      expect(spans.first.text, isNot('　　'));
    });

    test('缩进不破坏实体高亮：角色名仍按角色色渲染', () {
      final spans = StoryTextRenderer.parseParagraph('赫敏走进了图书馆。');
      // 缩进 span 之后，应有一个 span 的内容是「赫敏」且颜色是角色金（0xFFE3B341）
      final hermione = spans.where((s) => s.text == '赫敏');
      expect(hermione.length, 1);
      expect(hermione.first.style?.color, const Color(0xFFDDB54A));
      expect(hermione.first.style?.fontWeight, FontWeight.w600);
    });

    test('缩进 span 用叙述色（不会比正文更显眼）', () {
      final spans = StoryTextRenderer.parseParagraph('你推开大门。');
      expect(spans.first.style?.color, const Color(0xFFD0D7DE));
      expect(spans.first.style?.fontWeight, isNull,
          reason: '缩进不该加粗——它只是留白，不是内容');
    });
  });

  group('渲染层接线', () {
    final src =
        File('lib/screens/game/game_narrative_tab.dart').readAsStringSync();

    test('叙述段走小说式排版方法', () {
      expect(src.contains('_buildNarrationBody(segments[i].text)'), isTrue);
      expect(src.contains('StoryTextRenderer.parseParagraph('), isTrue);
      expect(src.contains('StoryTextRenderer.splitParagraphs('), isTrue);
    });

    test('叙述段与对话气泡同款淡入动画（页面质感统一）', () {
      // 叙述段动画 300ms，气泡 350ms——同一节奏家族，不锁死数值，
      // 但必须存在 TweenAnimationBuilder 包裹叙述段
      expect(src.contains('TweenAnimationBuilder<double>'), isTrue);
    });

    test('对话气泡渲染路径未被误伤', () {
      expect(src.contains('_buildDialogueSegment(gp, segments[i])'), isTrue);
    });
  });
}
