import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/locations.dart';
import 'package:hogwarts_life_simulator/data/scene_illustration_data.dart';

const _dataFile = 'lib/data/scene_illustration_data.dart';

void main() {
  // ---------------------------------------------------------------- 覆盖率
  group('场景库覆盖已知地点', () {
    test('地点表主名全部能命中专属场景，不落默认城堡', () {
      final missed = <String>[];
      for (final loc in kLocationNames) {
        final scene = resolveSceneIllustration(loc);
        if (identical(scene, kDefaultSceneIllustration)) missed.add(loc);
      }
      expect(
        missed,
        isEmpty,
        reason:
            '以下地点没有任何场景关键词命中，玩家会看到默认城堡横幅（含「伦敦」这类穿帮）: $missed',
      );
    });

    test('地点表别名也全部能命中专属场景', () {
      final missed = <String>[];
      for (final alias in allLocationAliases) {
        final scene = resolveSceneIllustration(alias);
        if (identical(scene, kDefaultSceneIllustration)) missed.add(alias);
      }
      expect(missed, isEmpty, reason: '落空的地点别名: $missed');
    });

    test('地窖与地牢两种叫法都归到魔药课教室', () {
      // 地点表写「地窖」，场景库原写「地牢」，两个词必须都接得住。
      for (final text in ['霍格沃茨·地窖', '斯莱特林地牢', '地下教室']) {
        expect(resolveSceneIllustration(text).title, '魔药课教室',
            reason: '$text 应归到魔药课教室');
      }
    });

    test('长关键词优先于短关键词', () {
      expect(resolveSceneIllustration('斯莱特林地牢深处').title, '魔药课教室');
      expect(resolveSceneIllustration('霍格沃茨·校长室').title, '校长办公室');
      expect(resolveSceneIllustration('霍格沃茨·盥洗室').title, '盥洗室');
      // 「破釜酒吧」是对角巷的入口，不能被「伦敦」抢走
      expect(resolveSceneIllustration('破釜酒吧').title, '对角巷');
      // 「黑湖」必须压过「场地」
      expect(resolveSceneIllustration('黑湖边').title, '黑湖');
    });

    test('归一化兜底排在直击之后，不会把精细场景糊成粗粒度地点', () {
      // 地点表粒度比场景库粗：黑湖和球场都被并进「霍格沃茨·场地」。
      // 归一化兜底必须排在第二优先，否则玩家到了黑湖会看到一片草地的横幅。
      expect(resolveSceneIllustration('黑湖').title, '黑湖');
      expect(resolveSceneIllustration('黑湖畔的礁石').title, '黑湖');
      expect(resolveSceneIllustration('霍格沃茨·场地').title, '城堡外的场地');
      expect(resolveSceneIllustration('魁地奇看台').title, '魁地奇球场');
      expect(resolveSceneIllustration('霍格沃茨·盥洗室').title, '盥洗室');
    });

    test('空值与空白回落到默认场景', () {
      expect(resolveSceneIllustration(null), kDefaultSceneIllustration);
      expect(resolveSceneIllustration(''), kDefaultSceneIllustration);
      expect(resolveSceneIllustration('   '), kDefaultSceneIllustration);
    });

    test('完全陌生的地点回落到默认场景', () {
      expect(resolveSceneIllustration('阿兹卡班牢房'), kDefaultSceneIllustration);
    });
  });

  // ------------------------------------------------------------- 数据自洽
  group('场景库数据自洽', () {
    test('关键词全局唯一，不存在歧义匹配', () {
      final seen = <String>[];
      final dup = <String>[];
      for (final s in kSceneIllustrations) {
        for (final kw in s.keywords) {
          if (seen.contains(kw)) {
            dup.add(kw);
          } else {
            seen.add(kw);
          }
        }
      }
      expect(dup, isEmpty,
          reason: '重复关键词会让匹配结果取决于排序，属于隐藏 bug: $dup');
    });

    test('每条场景的展示字段齐全', () {
      for (final s in kSceneIllustrations) {
        expect(s.keywords, isNotEmpty, reason: '${s.title} 没有关键词，永远无法命中');
        expect(s.title.trim(), isNotEmpty);
        expect(s.emoji, isNotNull,
            reason: '${s.title} 缺 emoji，横幅右上角会空一块');
        expect(s.gradient.length, greaterThanOrEqualTo(2),
            reason: '${s.title} 渐变色不足 2 个，无法构成渐变');
      }
    });

    test('默认场景自身也有完整展示字段', () {
      expect(kDefaultSceneIllustration.emoji, isNotNull);
      expect(kDefaultSceneIllustration.gradient.length, greaterThanOrEqualTo(2));
      expect(kDefaultSceneIllustration.title, isNotEmpty);
    });

    test('场景数量足够撑起一整局', () {
      expect(kSceneIllustrations.length, greaterThanOrEqualTo(20));
    });
  });

  // -------------------------------------------------- 防止再次变成死数据
  group('场景库确实被生产代码消费', () {
    /// 扫描 lib/ 下除数据文件自身以外的源码，统计 [symbol] 的调用次数。
    int countUsages(String symbol) {
      var n = 0;
      final dir = Directory('lib');
      for (final f in dir.listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.endsWith(_dataFile)) continue;
        n += symbol.allMatches(f.readAsStringSync()).length;
      }
      return n;
    }

    test('resolveSceneIllustration 被生产代码调用', () {
      expect(
        countUsages('resolveSceneIllustration'),
        greaterThan(0),
        reason:
            '没有任何 UI 调用 resolveSceneIllustration，'
            '场景库又变成死数据了。审查报告 R10 记录的就是这个状态，不要退回去。',
      );
    });

    test('SceneIllustrationBanner 被叙事页与历史回放页使用', () {
      // 少了任何一处，玩家就会在其中一个页面看不到场景横幅。
      for (final file in [
        'lib/screens/game/game_narrative_tab.dart',
        'lib/screens/story_history_screen.dart',
      ]) {
        final src = File(file).readAsStringSync();
        expect(src.contains('SceneIllustrationBanner'), isTrue,
            reason: '$file 没有使用 SceneIllustrationBanner');
      }
    });

    test('数据文件不重复展开候选表（每帧排序会拖慢列表）', () {
      final src = File(_dataFile).readAsStringSync();
      final open = RegExp(r'\bresolveSceneIllustration\s*\(').allMatches(src);
      // 定义 1 次；内部循环只消费预排序好的 _kSceneCandidates
      expect(open.length, 1);
      expect(
        src.indexOf('_kSceneCandidates'),
        lessThan(src.indexOf('SceneIllustration resolveSceneIllustration')),
        reason: '候选表应定义在函数之前，靠 top-level final 的惰性求值只算一次',
      );
      expect(src.contains('for (final c in _kSceneCandidates)'), isTrue);
    });
  });
}
