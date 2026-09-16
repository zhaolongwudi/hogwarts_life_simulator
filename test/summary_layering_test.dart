import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/prompts/summary_prompts.dart';

/// 前情摘要分层压缩（Q4）的守门测试。
///
/// 【背景·被修复的偏差放大】
/// 旧实现超限时**只保留尾部 1400 字**，头部仅一行计数。于是摘要 AI 看不到
/// 历史全貌，会把"最近发生的事"当成"整段历史"，产出偏重近期的摘要；
/// 这份摘要又会被 `_extractMemoryFromSummary` 固化成 9 分 T0 事实再注入 prompt，
/// 偏差因此一轮轮自我强化、随局龄单调加重。
///
/// 修复方式：**头尾双保**——头部 [kMaxPreviousHeadChars] 字锚住开局身份/初始关系
/// 这类"地基事实"，尾部 [kMaxPreviousChars] 字供新 chunk 缝合，中间压成一行提示。
void main() {
  group('分层压缩：未超限时原样输出（短局零影响）', () {
    test('短摘要不压缩', () {
      const s = '这是很短的一份摘要。';
      final r = layerPreviousSummary(s);
      expect(r.compressed, isFalse);
      expect(r.text, s);
      expect(r.elidedChars, 0);
    });

    test('恰好等于头+尾配额时不压缩（边界）', () {
      final s = 'x' * (kMaxPreviousHeadChars + kMaxPreviousChars);
      final r = layerPreviousSummary(s);
      expect(r.compressed, isFalse,
          reason: '等于阈值应视为"放得下"，不压缩');
      expect(r.text.length, s.length);
    });

    test('超出一字即压缩（边界）', () {
      final s = 'x' * (kMaxPreviousHeadChars + kMaxPreviousChars + 1);
      final r = layerPreviousSummary(s);
      expect(r.compressed, isTrue);
    });
  });

  group('分层压缩：头尾双保（原缺陷回归）', () {
    test('压缩后**同时**保留头部与尾部内容', () {
      const headMark = '开局身份是混血巫师';
      const tailMark = '最近与赫敏关系升温';
      final middle = '中段内容。' * 3000; // 远超配额
      final s = '$headMark$middle$tailMark';
      final r = layerPreviousSummary(s);
      expect(r.compressed, isTrue);
      expect(r.text.contains(headMark), isTrue,
          reason: '头部"地基事实"必须保留——旧实现把它整个丢掉了，'
              '这正是摘要看不到历史全貌、偏差自我强化的原因');
      expect(r.text.contains(tailMark), isTrue,
          reason: '尾部必须保留，新 chunk 靠它缝合');
    });

    test('压缩文本显著短于原文（输入 token 有上限）', () {
      final s = 'x' * 50000;
      final r = layerPreviousSummary(s);
      expect(r.text.length, lessThan(3000),
          reason: '压缩后应远小于原文，否则分层没有意义');
      expect(r.originalLength, 50000);
    });

    test('elidedChars 反映被省略的中间字数', () {
      final total = kMaxPreviousHeadChars + kMaxPreviousChars + 5000;
      final s = 'x' * total;
      final r = layerPreviousSummary(s);
      expect(r.elidedChars, 5000);
    });

    test('压缩文本包含省略提示，让 AI 知道中间被裁过', () {
      final s = 'x' * 50000;
      final r = layerPreviousSummary(s);
      expect(r.text.contains('省略'), isTrue,
          reason: '必须告诉 AI 中间有省略，否则它会把头尾当成连续历史');
    });
  });

  group('分层压缩：配额常量自洽', () {
    test('头部配额小于尾部配额', () {
      expect(kMaxPreviousHeadChars, lessThan(kMaxPreviousChars),
          reason: '头部只锚"地基事实"，信息密度高、篇幅需求低；'
              '尾部要供新 chunk 缝合，需要更多上下文');
    });

    test('头+尾配额不超过单份摘要的合理量级', () {
      expect(kMaxPreviousHeadChars + kMaxPreviousChars, lessThanOrEqualTo(2500),
          reason: '分层压缩的意义是给摘要输入一个上界；'
              '若配额接近未压缩长度，压缩就白做了');
    });
  });
}
