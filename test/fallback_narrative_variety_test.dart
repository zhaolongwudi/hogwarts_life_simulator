/// 离线兜底叙事与兜底选项的**多样性**测试。
///
/// 【这一层测什么】
/// 兜底叙事是"AI 不可用时的最后一道体面"——它的正确性不是"能不能生成一段字"，
/// 而是"连续几十个回合之后玩家还会不会觉得在看同一段字"。本文件把这件事
/// 拆成可断言的性质：
///
///   1. **永久可用**：任何地点/天气/年级组合都不返回空串、不抛异常；
///   2. **地点专属**：禁林里不该出现礼堂的南瓜汁，图书馆里不该出现湖面；
///   3. **帧不早循环**：8 个帧循环，整轮内不重复；
///   4. **选项池够厚**：每个已知地点的选项数 ≥ 4，保证轮换周期不短于 4；
///   5. **选项与地点匹配**：在霍格莫德不该出现"去教室上课"。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 造一个已初始化好的 GameProvider。
  Future<GameProvider> makeGameProvider() async {
    final gp = await makeGame(offlineQuickMode: true);
    gp.openingScene = 'letter';
    return gp;
  }

  group('F · 离线兜底叙事的多样性', () {
    test('常见地点都不返回空叙事，且文案随地点变化', () async {
      final gp = await makeGameProvider();

      const locations = [
        '霍格沃茨',
        '大礼堂',
        '图书馆',
        '霍格莫德村',
        '对角巷',
        '禁林',
        '黑湖边',
        '球场',
      ];

      final seen = <String, String>{};
      for (final loc in locations) {
        gp.worldState.currentLocation = loc;
        // 帧是轮转的，连打几回合取并集——不是每一帧都会写出地点名
        // （帧 4~8 故意只给氛围，这是设计，不是缺陷）。
        final texts = <String>[];
        for (var i = 0; i < 8; i++) {
          texts.add(gp.generateFallbackNarrative());
        }
        final joined = texts.join('\n');
        expect(
          texts.every((t) => t.trim().isNotEmpty),
          isTrue,
          reason: '$loc 的兜底叙事里出现了空串',
        );
        expect(joined, contains(loc), reason: '$loc 的兜底叙事里没提到地点');
        seen[loc] = joined;
      }

      // 至少一半地点的文案互不相同（帧相位不同 + 事件池不同）
      final distinct = seen.values.toSet().length;
      expect(
        distinct,
        greaterThanOrEqualTo(4),
        reason: '兜底叙事在不同地点之间重复度过高（只有 $distinct 种）',
      );
    });

    test('未知地点也能兜住（退回通用池，不崩不空）', () async {
      final gp = await makeGameProvider();
      gp.worldState.currentLocation = '某个不存在的地方';
      final texts = <String>[];
      for (var i = 0; i < 8; i++) {
        texts.add(gp.generateFallbackNarrative());
      }
      expect(texts.every((t) => t.trim().isNotEmpty), isTrue);
      expect(texts.join('\n'), contains('某个不存在的地方'));
    });

    test('禁林不会出现礼堂的南瓜汁（地点专属种子生效）', () async {
      final gp = await makeGameProvider();
      gp.worldState.currentLocation = '禁林';

      // 多跑几轮把种子池走一遍
      final all = <String>[];
      for (var i = 0; i < 40; i++) {
        all.add(gp.generateFallbackNarrative());
      }
      final joined = all.join('\n');

      expect(
        joined,
        isNot(contains('南瓜汁')),
        reason: '禁林里出现了大礼堂专属的事件种子',
      );
      expect(
        joined,
        isNot(contains('礼堂飘来')),
        reason: '禁林里出现了大礼堂专属的事件种子',
      );
    });

    test('连续 8 回合的叙事帧不重复（不早循环）', () async {
      final gp = await makeGameProvider();
      gp.worldState.currentLocation = '霍格沃茨';

      // 帧由 turnCount 决定；这里直接连打 8 次，检查首句各不相同。
      final heads = <String>[];
      for (var i = 0; i < 8; i++) {
        final t = gp.generateFallbackNarrative();
        // 取正文第一段（跳过日期行）
        final parts = t.split('\n').where((l) => l.trim().isNotEmpty).toList();
        heads.add(parts.length > 1 ? parts[1] : t);
      }
      expect(
        heads.toSet().length,
        8,
        reason: '8 个叙事帧在 8 回合内出现了重复：$heads',
      );
    });

    test('每个已知地点的兜底选项 >= 4 条，且文案不重复', () async {
      final gp = await makeGameProvider();

      const locations = [
        '霍格沃茨',
        '大礼堂',
        '图书馆',
        '霍格莫德村',
        '对角巷',
        '禁林',
        '黑湖边',
        '球场',
        '未知地点',
      ];

      for (final loc in locations) {
        gp.worldState.currentLocation = loc;
        // 转几圈看选项池是否够厚：收集 8 回合内出现过的所有文案。
        // 生产里每回合都会先出叙事（推进帧序号）再出选项，这里照做，
        // 否则轮换索引不动、8 回合只能看到同一组。
        final texts = <String>{};
        for (var i = 0; i < 8; i++) {
          gp.generateFallbackNarrative();
          for (final c in gp.generateFallbackChoices()) {
            texts.add(c.text);
          }
        }
        expect(
          texts.length,
          greaterThanOrEqualTo(4),
          reason: '$loc 的兜底选项池太薄（8 回合内只出现了 ${texts.length} 种）',
        );
      }
    });

    test('兜底选项永远是 3 条，且 action 非空', () async {
      final gp = await makeGameProvider();
      for (final loc in ['霍格沃茨', '禁林', '未知地点', '']) {
        gp.worldState.currentLocation = loc;
        final choices = gp.generateFallbackChoices();
        expect(choices.length, 3, reason: '$loc 的兜底选项不是 3 条');
        for (final c in choices) {
          expect(c.text.trim(), isNotEmpty);
          expect(c.action.trim(), isNotEmpty);
        }
      }
    });

    test('霍格莫德不出现"去教室上课"（选项与地点匹配）', () async {
      final gp = await makeGameProvider();
      gp.worldState.currentLocation = '霍格莫德村';

      final texts = <String>{};
      for (var i = 0; i < 8; i++) {
        gp.generateFallbackNarrative();
        texts.addAll(gp.generateFallbackChoices().map((c) => c.text));
      }
      expect(
        texts.any((t) => t.contains('教室')),
        isFalse,
        reason: '在霍格莫德村出现了"去教室上课"这类校园专属选项',
      );
      expect(
        texts.any((t) => t.contains('三把扫帚') || t.contains('糖果店')),
        isTrue,
        reason: '霍格莫德的选项里没有任何该地点的专属动作',
      );
    });

    test('恶劣天气下叙事仍然完整（天气只影响种子池，不影响成文）', () async {
      final gp = await makeGameProvider();
      gp.worldState.currentLocation = '霍格沃茨';

      // 天气只参与种子池挑选，不保证出现在正文里（帧 4~8 不写天气）。
      // 这里断言的是"任何天气都不产生空叙事/坏内容"，而不是"正文必含天气"。
      for (final w in ['雨', '雷雨', '雪', '雾', '阴', '晴朗']) {
        gp.worldState.weather = w;
        final texts = <String>[];
        for (var i = 0; i < 8; i++) {
          texts.add(gp.generateFallbackNarrative());
        }
        expect(
          texts.every((t) => t.trim().isNotEmpty),
          isTrue,
          reason: '天气 $w 下出现了空叙事',
        );
        expect(
          texts.join('\n'),
          contains(w),
          reason: '天气 $w 在 8 帧内一次都没出现在抬头里',
        );
      }
    });
  });
}
