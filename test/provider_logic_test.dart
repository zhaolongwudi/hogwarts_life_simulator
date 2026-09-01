/// P1-7：核心 mixin 功能测试（此前 14 个 mixin 仅 mixin_response 被测试 import）。
///
/// 用轻量 GameProvider 实例（不跑 AI、不走网络）直接驱动主逻辑：
///  - 时间系统：fastForwardTime/fastForwardDays 等价推进、天数上限（P0-3 收敛回归）
///  - 指令系统：/计划 学习 属性真实增长（S4 回归）、/新NPC 参数语义（S5 回归）
///  - 数值规则：好感落地区间与压缩函数一致（P0-2 回归）
library;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hogwarts_life_simulator/data/balance_constants.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

GameChoice cmd(String action) => GameChoice(text: action, action: action);

Future<GameProvider> makeGame() async {
  // AppProvider.loadSettings 读 SharedPreferences，测试环境需要 mock
  SharedPreferences.setMockInitialValues({});
  final app = AppProvider();
  await app.loadSettings();
  final gp = GameProvider(app);
  await gp.initializeGame(
    name: '测试巫师',
    bloodStatus: '混血',
    birthLocation: '伦敦',
    personalityTraits: const ['勇敢', '善良'],
    gender: '男',
    attributes: const {
      'spell_understanding': 50,
      'transfiguration': 50,
      'potions': 50,
      'herbology': 50,
      'theory': 50,
      'memory': 50,
      'courage': 50,
      'wisdom': 50,
      'loyalty': 50,
      'ambition': 50,
      'social': 50,
      'flying': 50,
      'reaction_time': 50,
    },
    houseDimensions: const {
      'courage': 50,
      'wisdom': 50,
      'loyalty': 50,
      'ambition': 50,
    },
    openingScene: 'letter',
  );
  return gp;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('时间系统（P0-3 收敛回归）', () {
    test('fastForwardTime 推进指定天数，旧实现漏掉的结算现在发生', () async {
      final gp = await makeGame();
      final t0 = gp.worldState.time.absoluteDayIndex;
      gp.fastForwardTime(7);
      final t1 = gp.worldState.time.absoluteDayIndex;
      expect(t1 - t0, 7, reason: 'fastForwardTime(7) 应推进整整 7 天');
      expect(gp.gameWeek, greaterThanOrEqualTo(1), reason: '游戏周应随跨周推进');
      expect(
        gp.npcRegistry.values.any((n) => n.currentLocation.isNotEmpty),
        isTrue,
        reason: 'NPC 位置应随时钟刷新（旧实现漏掉，prompt 里【在场】永远为空）',
      );
    });

    test('fastForwardDays 返回快进期间的通知列表', () async {
      final gp = await makeGame();
      expect(gp.fastForwardDays(7), isA<List<String>>());
    });

    test('resolveFastForwardDays 上限 365、非法输入回退 7 天', () async {
      final gp = await makeGame();
      expect(gp.resolveFastForwardDays('999999'), 365);
      expect(gp.resolveFastForwardDays('7'), 7);
      expect(gp.resolveFastForwardDays(''), 7);
      expect(gp.resolveFastForwardDays('abc'), 7);
    });
  });

  group('/计划 学习 属性加成（S4 回归）', () {
    test('学习计划真实增长属性，不再被 ?? 优先级吞掉', () async {
      final gp = await makeGame();
      const pool = [
        'spell_understanding',
        'transfiguration',
        'potions',
        'herbology',
        'theory',
        'memory',
      ];
      final before = {
        for (final k in pool) k: gp.player!.attributes[k] ?? 50,
      };
      await gp.processChoice(cmd('/计划 学习'));
      // 每项 60% 概率 +1~+3，6 项至少中 1 项的概率 > 99%
      final grew = pool.any((k) =>
          (gp.player!.attributes[k] ?? 50) > (before[k] ?? 50));
      expect(grew, isTrue,
          reason: '属性没有任何一项增长（S4 修复前恒为假）：'
              '${pool.map((k) => '${before[k] ?? 50}→${gp.player!.attributes[k] ?? 50}').join(',')}');
      expect(gp.currentNarrative.contains('时间推进一周'), isTrue);
    });
  });

  group('/新NPC 参数语义（S5 回归）', () {
    test('/新NPC（无参数）只列列表，不自动生成', () async {
      final gp = await makeGame();
      final before = gp.npcRegistry.values.where((n) => n.isGenerated).length;
      await gp.processChoice(cmd('/新NPC'));
      final after = gp.npcRegistry.values.where((n) => n.isGenerated).length;
      expect(after, before, reason: '/新NPC 列表模式不应生成新 NPC');
      // 列表进独立面板（panel 标记生效，剧情不覆盖），此处只验证无副作用
    });

    test('/新NPC 生成 只生成 1 位', () async {
      final gp = await makeGame();
      final before = gp.npcRegistry.values.where((n) => n.isGenerated).length;
      await gp.processChoice(cmd('/新NPC 生成'));
      final after = gp.npcRegistry.values.where((n) => n.isGenerated).length;
      expect(after, before + 1);
    });

    test('/新NPC 生成 3 生成 3 位（先重置学年配额）', () async {
      final gp = await makeGame();
      final before = gp.npcRegistry.values.where((n) => n.isGenerated).length;
      // 开局已自动生成 2 位（每学年限 4 次），先走作弊路径重置配额并生成 1 位
      await gp.processChoice(cmd('/cheat 新NPC 生成'));
      final afterCheat =
          gp.npcRegistry.values.where((n) => n.isGenerated).length;
      expect(afterCheat, before + 1, reason: '作弊生成应强制 +1');
      await gp.processChoice(cmd('/新NPC 生成 3'));
      final after3 =
          gp.npcRegistry.values.where((n) => n.isGenerated).length;
      expect(after3, afterCheat + 3, reason: '配额重置后 /新NPC 生成 3 应 +3');
    });
  });

  group('好感落地区间（P0-2 回归）', () {
    test('压缩函数边界：分段映射稳定', () {
      expect(Balance.compressAffectionDelta(5), 5);
      expect(Balance.compressAffectionDelta(8), 6);
      expect(Balance.compressAffectionDelta(10), 7);
      expect(Balance.compressAffectionDelta(20), 9);
      expect(Balance.compressAffectionDelta(30), 10);
      expect(Balance.compressAffectionDelta(-15), -8);
      expect(Balance.compressAffectionDelta(-30), -10);
    });

    test('affectionLandingFor 与压缩函数一致（prompt 教什么落地什么）', () {
      expect(Balance.affectionLandingFor('中等事件（帮助/共同冒险）'), '4~6');
      expect(Balance.affectionLandingFor('重大事件（救命之恩）'), '7~9');
      expect(Balance.affectionLandingFor('极端事件（生死与共）'), '9~10');
      expect(Balance.affectionLandingFor('背叛/欺骗'), '-10~-8');
    });

    test('world_rules 注入文本引用落地区间，旧数值不回潮', () {
      final src = File('lib/data/world_rules.dart').readAsStringSync();
      expect(src.contains('affectionLandingFor'), isTrue,
          reason: 'prompt 必须动态引用落地区间');
      expect(src.contains('救命+10~+20'), isFalse,
          reason: '旧硬编码数值（与落地不符）不得回潮');
      expect(src.contains('背叛-15~-30'), isFalse);
    });
  });
}
