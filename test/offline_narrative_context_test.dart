/// 离线叙事个性化增强测试（P0）。
///
/// 【这一层测什么】
/// `OfflineNarrativeContext` 与 `generateFallbackNarrative` 的帧尾染色句：
///
///   1. 存档里有恋爱对象时，离线叙事会引用那个名字；
///   2. 存档里有登记关系时，离线叙事会引用那个 NPC 的名字；
///   3. 默认存档（只有性格特征）至少不空、且带一条性格底色句；
///   4. 增强句不得破坏既有兜底叙事的核心不变量（地点名仍在、帧不重复）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/models/player.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 造一个已初始化好的离线 GameProvider。
  Future<GameProvider> makeGameProvider() async {
    return makeGame(offlineQuickMode: true);
  }

  group('P0 · 离线叙事个性化增强', () {
    test('有恋爱对象时，离线叙事会引用对象名字', () async {
      final gp = await makeGameProvider();
      final p = gp.player!;

      // 隔离：只留下恋爱钩子这一路个性化数据。
      p.loveState.partnerName = '卢娜';
      p.loveState.consideringNpcName = null;
      p.relationships.clear();

      final joined = <String>[];
      for (var i = 0; i < 6; i++) {
        joined.add(gp.generateFallbackNarrative());
      }
      expect(
        joined.join('\n'),
        contains('卢娜'),
        reason: '离线叙事没有引用恋爱对象的名字',
      );
    });

    test('有登记关系时，离线叙事会引用该 NPC 名字', () async {
      final gp = await makeGameProvider();
      final p = gp.player!;

      // 隔离：只留下关系钩子这一路。
      p.loveState.partnerName = null;
      p.loveState.consideringNpcName = null;
      p.relationships.clear();
      p.relationships['hermione'] = Relationship(
        targetId: 'hermione',
        targetName: '赫敏·格兰杰',
        relationType: '挚友',
        level: 90,
      );

      final joined = <String>[];
      for (var i = 0; i < 6; i++) {
        joined.add(gp.generateFallbackNarrative());
      }
      expect(
        joined.join('\n'),
        contains('赫敏·格兰杰'),
        reason: '离线叙事没有引用登记关系里的 NPC 名字',
      );
    });

    test('默认存档（仅性格特征）叙事不空，且带性格底色句', () async {
      final gp = await makeGameProvider();
      final p = gp.player!;

      // 保证只有性格钩子这条个性化路是确定存在的。
      p.loveState.partnerName = null;
      p.loveState.consideringNpcName = null;
      p.relationships.clear();
      gp.npcRegistry.clear();
      p.petName = null;

      // makeGame 默认性格 = ['勇敢','善良']。染色句按钩子轮转，
      // 连打多回合取并集，确保性格底色句一定出现（不受其它钩子干扰）。
      final joined = <String>[];
      for (var i = 0; i < 12; i++) {
        final t = gp.generateFallbackNarrative();
        expect(t.trim(), isNotEmpty, reason: '离线叙事返回了空串');
        joined.add(t);
      }
      final all = joined.join('\n');
      expect(all, contains('勇敢'), reason: '没出现性格底色句');
      expect(all, contains('善良'), reason: '没出现性格底色句');
    });

    test('染色句不破坏既有不变量：地点名仍在、第二段帧不重复', () async {
      final gp = await makeGameProvider();
      final p = gp.player!;
      p.loveState.partnerName = '卢娜';
      p.loveState.consideringNpcName = null;
      p.relationships.clear();

      // 让一个地点里连打 8 回合。既有 8 帧里第 2、7 帧本就不写地点名
      //（多样性测试按回合并集断言地点），这里同样用并集；帧体第二段
      // 则必须 8 回合各不相同——这两条是既有不变量，染色句不得破坏。
      gp.worldState.currentLocation = '霍格沃茨';
      final heads = <String>{};
      final joined = <String>[];
      for (var i = 0; i < 8; i++) {
        final t = gp.generateFallbackNarrative();
        joined.add(t);
        final parts =
            t.split('\n').where((l) => l.trim().isNotEmpty).toList();
        heads.add(parts.length > 1 ? parts[1] : t);
      }
      expect(joined.join('\n'), contains('霍格沃茨'),
          reason: '染色句让整轮叙事都不提地点了');
      expect(heads.length, 8, reason: '染色句破坏了帧不重复不变量');
    });
  });
}