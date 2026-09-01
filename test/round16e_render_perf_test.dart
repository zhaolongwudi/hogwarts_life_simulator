/// 第16轮E · 用户叙事文本渲染性能测试
///
/// 用户报告「生成剧情过程中卡死、无崩溃日志」——疑似主线程正则/渲染慢路径。
/// 用用户真实存档的 narrative 文本（1017字、含中文引号对话、专有名词）跑
/// 渲染热路径，测耗时是否异常（>500ms 即为风险）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/utils/story_text_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('叙事渲染性能（第16轮E）', () {
    late String narrative;

    setUpAll(() {
      final raw = File('test/fixtures_auto_save.json').readAsStringSync();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      narrative = data['narrative'] as String;
    });

    test('用户 narrative 渲染耗时 < 500ms（每段解析）', () {
      final sw = Stopwatch()..start();
      final paras = StoryTextRenderer.classifyParagraphs(narrative);
      for (final p in paras) {
        StoryTextRenderer.parseParagraphStyled(p);
      }
      sw.stop();
      // ignore: avoid_print
      print(
        '用户叙事 ${narrative.length} 字 → ${paras.length} 段，渲染耗时 ${sw.elapsedMilliseconds}ms',
      );
      expect(
        sw.elapsedMilliseconds,
        lessThan(500),
        reason: '渲染应在 500ms 内完成，否则主线程卡顿',
      );
    });

    test('恶意重复文本（防 ReDoS 灾难回溯）渲染 < 2s', () {
      // 构造极端输入：超长连续符号 + 中文引号对话 + 星号，试探正则回溯
      final evil = ('“你说什么？”他冷笑了一声。**强调** ！（）【】' * 500);
      final sw = Stopwatch()..start();
      final paras = StoryTextRenderer.classifyParagraphs(evil);
      for (final p in paras) {
        StoryTextRenderer.parseParagraphStyled(p);
      }
      sw.stop();
      // ignore: avoid_print
      print(
        '恶意文本 ${evil.length} 字 → ${paras.length} 段，渲染耗时 ${sw.elapsedMilliseconds}ms',
      );
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('超长叙事 20k 字渲染 < 3s（长局文本累积场景）', () {
      final long = (narrative + '\n\n') * 10; // ~10k 字
      final sw = Stopwatch()..start();
      final paras = StoryTextRenderer.classifyParagraphs(long);
      for (final p in paras) {
        StoryTextRenderer.parseParagraphStyled(p);
      }
      sw.stop();
      // ignore: avoid_print
      print('10k 字叙事 → ${paras.length} 段，渲染耗时 ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(3000));
    });
  });

  group('死循环回归（第16轮D根因：叙述：“台词 无限循环）', () {
    test('单行 「汉字×10：”左引号」 渲染 < 500ms（曾经死循环 ANR）', () {
      final sw = Stopwatch()..start();
      StoryTextRenderer.parse('汉汉汉汉汉汉汉汉汉汉：“');
      sw.stop();
      expect(
        sw.elapsedMilliseconds,
        lessThan(500),
        reason: '「叙述：“」单行曾因 tokenize colon 扫描 continue 跳过行推进而无限循环',
      );
    });

    test('用户存档行7「…声音沙哑：“阁楼。」渲染 < 500ms', () {
      const line =
          '哈利抬起头，眼神里带着一丝警惕，似乎怀疑你是否在故意揭他的伤疤。'
          '但他很快意识到了你语气中的认真，那是一种平等的、近乎痛苦的共鸣。'
          '他深吸一口气，像是在压抑某种长期积压的情绪，然后开口了，声音沙哑：“阁楼。';
      final sw = Stopwatch()..start();
      StoryTextRenderer.parse(line);
      sw.stop();
      expect(
        sw.elapsedMilliseconds,
        lessThan(500),
        reason: 'AI 高频输出「叙述：”台词”」模式，曾触发同一死循环',
      );
    });

    test('多段混合（含多行：”台词）渲染 < 1s', () {
      final buf = StringBuffer();
      for (var i = 0; i < 20; i++) {
        buf.writeln(
          '他深吸一口气，声音沙哑：“阁楼。你说得对。”哈利低声回应，'
          '眼神里带着一丝警惕。',
        );
        buf.writeln('“那你打算怎么办？”你追问。');
      }
      final sw = Stopwatch()..start();
      final paras = StoryTextRenderer.classifyParagraphs(buf.toString());
      for (final p in paras) {
        StoryTextRenderer.parseParagraphStyled(p);
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });
}
