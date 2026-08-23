import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/utils/story_text_renderer.dart';

/// 剧情文字着色渲染规则测试：
/// 冒号对话 / 叙述动词剥离 / 时间日期误判排除 / 未知说话人 / 选项行剥离
void main() {
  const narrationColor = Color(0xFFC9D1D9);
  const dialogueColor = Color(0xFF58A6FF);
  const speakerColor = Color(0xFFFFA657);
  const locationColor = Color(0xFF56D364);

  Color? colorOf(List<TextSpan> spans, String text) {
    for (final s in spans) {
      if (s.text == text) return s.style?.color;
    }
    return null;
  }

  bool hasColor(List<TextSpan> spans, Color color) {
    return spans.any((s) => s.style?.color == color);
  }

  String allText(List<TextSpan> spans) =>
      spans.map((s) => s.text ?? '').join();

  group('冒号对话', () {
    test('已知角色：名字橙色、冒号与台词蓝色', () {
      final spans = StoryTextRenderer.parse('赫敏：我们去图书馆吧。');
      expect(colorOf(spans, '赫敏'), speakerColor);
      expect(colorOf(spans, '：'), dialogueColor);
      expect(colorOf(spans, '我们去图书馆吧。'), dialogueColor);
    });

    test('带情绪修饰：整个「名字（情绪）」按说话人着色', () {
      final spans = StoryTextRenderer.parse('德拉科（冷笑）：何必自讨苦吃。');
      expect(colorOf(spans, '德拉科（冷笑）'), speakerColor);
      expect(colorOf(spans, '何必自讨苦吃。'), dialogueColor);
    });

    test('未知角色名（AI 生成的随机 NPC）也按说话人着色', () {
      final spans = StoryTextRenderer.parse('莉娜：你终于来了。');
      expect(colorOf(spans, '莉娜'), speakerColor);
      expect(colorOf(spans, '你终于来了。'), dialogueColor);
    });
  });

  group('叙述动词剥离', () {
    test('「罗恩说：」——「罗恩」橙色、「说：」叙述灰、台词蓝色', () {
      final spans = StoryTextRenderer.parse('罗恩说："等等我！"');
      expect(colorOf(spans, '罗恩'), speakerColor);
      expect(colorOf(spans, '说：'), narrationColor);
      expect(colorOf(spans, '"等等我！"'), dialogueColor);
    });

    test('未知名字+动词：动词同样归叙述', () {
      final spans = StoryTextRenderer.parse('莉娜问道：今晚要一起自习吗？');
      expect(colorOf(spans, '莉娜'), speakerColor);
      expect(colorOf(spans, '问道：'), narrationColor);
      expect(colorOf(spans, '今晚要一起自习吗？'), dialogueColor);
    });
  });

  group('误判排除', () {
    test('时钟时间不是对话（09:30）', () {
      final spans = StoryTextRenderer.parse('09:30，列车缓缓驶入霍格莫德车站。');
      expect(hasColor(spans, speakerColor), isFalse);
      expect(hasColor(spans, dialogueColor), isFalse);
      expect(colorOf(spans, '霍格莫德车站'), locationColor);
    });

    test('日期行与场景描写不是对话', () {
      final spans = StoryTextRenderer.parse(
          '📅 1991年9月1日 星期日\n清晨的霍格沃茨：雾气弥漫在塔楼之间。');
      expect(hasColor(spans, speakerColor), isFalse);
      expect(hasColor(spans, dialogueColor), isFalse);
      expect(colorOf(spans, '霍格沃茨'), locationColor);
    });

    test('状态标签不是说话人', () {
      final spans = StoryTextRenderer.parse('当前位置：图书馆');
      expect(hasColor(spans, speakerColor), isFalse);
      expect(hasColor(spans, dialogueColor), isFalse);
    });
  });

  group('选项行剥离', () {
    test('内嵌 A/B 选项行被剥离，正文保留', () {
      final spans = StoryTextRenderer.parse(
          '夜色渐深，你回到休息室。\n\nA. 去图书馆自习\nB. 找罗恩下巫师棋');
      final text = allText(spans);
      expect(text, contains('夜色渐深'));
      expect(text, isNot(contains('去图书馆自习')));
      expect(text, isNot(contains('找罗恩下巫师棋')));
    });

    test('以句号结尾的「A.」叙述句不误删', () {
      final spans = StoryTextRenderer.parse('A. 清晨的霍格莫德一片宁静。');
      expect(allText(spans), contains('清晨的霍格莫德一片宁静'));
    });

    test('紧跟正文行且不成块的选项样式行保留', () {
      final spans =
          StoryTextRenderer.parse('你走进礼堂。\nA. 环顾四周，寻找空位');
      expect(allText(spans), contains('环顾四周'));
    });
  });
}
