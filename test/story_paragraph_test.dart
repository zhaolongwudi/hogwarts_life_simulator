import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/utils/story_text_renderer.dart';

/// v3.7 正文段落分类与段落级样式测试。
void main() {
  group('ParagraphKind 分类（classifyParagraphs）', () {
    test('时间戳段 → timestamp', () {
      final ps = StoryTextRenderer.classifyParagraphs('【时间戳】1991年9月1日 星期天');
      expect(ps.single.kind, ParagraphKind.timestamp);
    });

    test('📅 前缀同样识别', () {
      final ps = StoryTextRenderer.classifyParagraphs('📅 1991年9月2日');
      expect(ps.single.kind, ParagraphKind.timestamp);
    });

    test('时间戳前缀后跟长正文 → 降级为叙述（防整段被吞）', () {
      final ps = StoryTextRenderer.classifyParagraphs(
          '【时间戳】1991年9月1日。这一天，猫头鹰送来了霍格沃茨的信。');
      expect(ps.single.kind, ParagraphKind.narration);
    });

    test('引号台词段 → dialogue', () {
      final ps = StoryTextRenderer.classifyParagraphs('"你说得对，我们去图书馆吧。"');
      expect(ps.single.kind, ParagraphKind.dialogue);
    });

    test('「说话人：」台词段 → dialogue', () {
      final ps =
          StoryTextRenderer.classifyParagraphs('赫敏："你已经落后进度了，得补课。"');
      expect(ps.single.kind, ParagraphKind.dialogue);
    });

    test('整段括号包裹 → innerVoice', () {
      final ps = StoryTextRenderer.classifyParagraphs('（也许我真的该相信他。）');
      expect(ps.single.kind, ParagraphKind.innerVoice);
    });

    test('心想关键词 → innerVoice', () {
      final ps = StoryTextRenderer.classifyParagraphs('我心想，这件事恐怕没那么简单。');
      expect(ps.single.kind, ParagraphKind.innerVoice);
    });

    test('普通叙述 → narration', () {
      final ps = StoryTextRenderer.classifyParagraphs(
          '清晨的霍格沃茨被薄雾笼罩，城堡的尖顶在阳光中若隐若现。');
      expect(ps.single.kind, ParagraphKind.narration);
    });

    test('多段落各自分类（空行拆分）', () {
      final ps = StoryTextRenderer.classifyParagraphs(
          '清晨的薄雾笼罩着城堡。\n\n'
          '"早啊，你昨晚睡得好吗？"\n\n'
          '（她看起来心事重重。）');
      expect(ps.length, 3);
      expect(ps[0].kind, ParagraphKind.narration);
      expect(ps[1].kind, ParagraphKind.dialogue);
      expect(ps[2].kind, ParagraphKind.innerVoice);
    });

    test('空文本安全', () {
      expect(StoryTextRenderer.classifyParagraphs(''), isEmpty);
    });
  });

  group('段落级样式（parseParagraphStyled / parseAffectionLine）', () {
    test('叙述段带首行缩进', () {
      final spans = StoryTextRenderer.parseParagraphStyled(
          const StoryParagraph(ParagraphKind.narration, '一段叙述。'));
      expect(spans.first.text, '　　');
    });

    test('对话段顶格不缩进', () {
      final spans = StoryTextRenderer.parseParagraphStyled(
          const StoryParagraph(ParagraphKind.dialogue, '"你好。"'));
      expect(spans.first.text, isNot('　　'));
    });

    test('内心独白统一斜体浅紫', () {
      final spans = StoryTextRenderer.parseParagraphStyled(
          const StoryParagraph(ParagraphKind.innerVoice, '（我有点紧张。）'));
      expect(spans, isNotEmpty);
      for (final s in spans) {
        expect(s.style?.fontStyle, FontStyle.italic);
        expect(s.style?.color, const Color(0xFFB8A6E3));
      }
    });

    test('时间戳去掉前缀标记词', () {
      final spans = StoryTextRenderer.parseParagraphStyled(
          const StoryParagraph(ParagraphKind.timestamp, '【时间戳】1991年9月1日 星期天'));
      expect(spans.single.text, '1991年9月1日 星期天');
      expect(spans.single.style?.fontWeight, FontWeight.w700);
    });

    test('好感变化行数值正绿负红', () {
      final spans =
          StoryTextRenderer.parseAffectionLine('赫敏：+5（一起上课很开心）');
      final texts = spans.map((s) => s.text).join();
      expect(texts, contains('+5'));
      final plus = spans.firstWhere((s) => s.text == '+5');
      expect(plus.style?.color, const Color(0xFF7EE787));

      final minus = StoryTextRenderer.parseAffectionLine('马尔福：-3（发生争执）');
      final minusSpan = minus.firstWhere((s) => s.text == '-3');
      expect(minusSpan.style?.color, const Color(0xFFFF7B72));
    });
  });

  group('stripTimestampPrefix', () {
    test('清理各类时间戳前缀', () {
      expect(StoryTextRenderer.stripTimestampPrefix('【时间戳】1991年9月1日'),
          '1991年9月1日');
      expect(StoryTextRenderer.stripTimestampPrefix('📅 1991年9月2日'),
          '1991年9月2日');
      expect(StoryTextRenderer.stripTimestampPrefix('⏳新学年'), '新学年');
      expect(StoryTextRenderer.stripTimestampPrefix('无前缀文本'), '无前缀文本');
    });
  });
}
