/// v5 批次36 玩法意图路由测试（P7「自然语言 → 完整玩法系统」）。
///
/// 覆盖三件事：
///  - `tryRouteGameplayIntent`：把「去打魁地奇 / 进禁林 / 找XX决斗 / 陪宠物玩」
///    这类自然语言路由到完整玩法系统（写叙事、结算资源、写好选项）；
///  - 匹配纪律：宁可漏判（交回 P6 数值后果），不可误判劫持——
///    「切磋功课」不算决斗、「买宠物」不算互动、「无宠物」不路由宠物；
///  - `buildGameplayOptions` 上下文门控 + 自动推进跳过玩法入口：
///    玩法选项只在「此刻真的能玩」时出现，且不会被「推进」按钮顺手带走。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/mixins/mixin_play.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameProvider> makeProvider() async {
    return makeGame(offlineQuickMode: true);
  }

  /// 往 registry 里塞一个指定的在读 NPC（默认已登场、一年级、在校）。
  void seedNpc(GameProvider gp, String id, String name,
      {int affection = 0, bool introduced = true}) {
    gp.npcRegistry[id] = NPC(
      id: id,
      name: name,
      affection: affection,
      introduced: introduced,
    );
  }

  /// 把玩家摆到「城堡内 + 装备扫帚 + 满状态」的默认玩法就绪态。
  void setupReady(GameProvider gp, {bool withBroom = true, bool withPet = false}) {
    final p = gp.player!;
    gp.worldState.currentLocation = '霍格沃茨';
    if (withBroom) p.equipped['broom'] = '飞天扫帚·横扫';
    p.energy = 100;
    p.satiety = 100;
    if (withPet) {
      p.petId = 'owl';
      p.petName = '雪鸮';
      p.petInteractDay = -1; // 今日未互动
    }
  }

  List<String> actionsOf(List<GameChoice> choices) =>
      choices.map((c) => c.action).toList();

  group('意图路由：命中 → 完整玩法系统', () {
    test('「去打魁地奇」命中：写比赛叙事、结算次数与精力', () async {
      final gp = await makeProvider();
      setupReady(gp);
      final p = gp.player!;
      final q0 = p.qMatches;
      final e0 = p.energy;

      final routed = gp.tryRouteGameplayIntent('去球场打一场魁地奇');

      expect(routed, isTrue, reason: '魁地奇关键词应命中路由');
      expect(gp.currentNarrative, contains('魁地奇比赛'));
      expect(gp.currentNarrative, contains('最终比分'));
      expect(p.qMatches, q0 + 1, reason: '完整玩法系统应结算比赛次数');
      expect(p.energy, lessThan(e0), reason: '比赛消耗精力');
      expect(gp.choices, isNotEmpty, reason: '玩法函数应写好后续选项');
    });

    test('「进禁林」命中：写探险叙事并结算', () async {
      final gp = await makeProvider();
      setupReady(gp);
      final p = gp.player!;
      final g0 = p.galleons;
      final inv0 = p.inventory.length;

      final routed = gp.tryRouteGameplayIntent('去禁林边缘探险采集材料');

      expect(routed, isTrue, reason: '禁林关键词应命中路由');
      expect(gp.currentNarrative, contains('禁林探险'));
      expect(gp.currentNarrative, isNot(contains('你向球场走去')),
          reason: '不该退回泛化兜底叙事');
      // 探险结算后饱食/精力下降或加隆/物品变化，至少一项发生
      final progressed = p.energy < 100 ||
          p.satiety < 100 ||
          p.galleons > g0 ||
          p.inventory.length > inv0;
      expect(progressed, isTrue, reason: '完整探险应产生可见结算');
    });

    test('「找哈利决斗」命中且点名目标', () async {
      final gp = await makeProvider();
      setupReady(gp);
      seedNpc(gp, 'harry', '哈利·波特');

      final routed = gp.tryRouteGameplayIntent('找哈利·波特决斗');

      expect(routed, isTrue, reason: '决斗关键词应命中路由');
      expect(gp.currentNarrative, contains('巫师决斗'));
      expect(gp.currentNarrative, contains('哈利·波特'),
          reason: '点名目标时决斗对象应为该 NPC');
    });

    test('未点名时决斗随机挑一位在读学生（一年级新生的对手池）', () async {
      final gp = await makeProvider();
      setupReady(gp);
      // 清空默认注册表，只留一名低威胁一年级 → 随机池唯一且稳定，
      // 避免撞上默认池里的高年级强者触发「一年级打不过」的防崩坏拒绝。
      gp.npcRegistry.clear();
      seedNpc(gp, 'weak_student', '莱昂内尔·洛维特');

      final routed = gp.tryRouteGameplayIntent('去决斗场地切磋一场');

      expect(routed, isTrue, reason: '决斗意图应命中路由');
      expect(gp.currentNarrative, contains('巫师决斗'));
      expect(gp.currentNarrative, contains('莱昂内尔·洛维特'),
          reason: '随机目标从在读学生池中产生，进入完整决斗叙事');
    });

    test('「陪宠物玩」命中：有宠物才路由并结算羁绊', () async {
      final gp = await makeProvider();
      setupReady(gp, withPet: true);
      final p = gp.player!;
      final b0 = p.petBond;
      final day = gp.worldState.time.absoluteDayIndex;

      final routed = gp.tryRouteGameplayIntent('陪雪鸮玩耍互动');

      expect(routed, isTrue);
      expect(gp.currentNarrative, contains('宠物互动'));
      expect(p.petInteractDay, day, reason: '互动应记录当日');
      expect(p.petBond, greaterThanOrEqualTo(b0));
    });

    test('「喂宠物」路由到喂食分支', () async {
      final gp = await makeProvider();
      setupReady(gp, withPet: true);
      final p = gp.player!;
      final day = gp.worldState.time.absoluteDayIndex;

      final routed = gp.tryRouteGameplayIntent('给雪鸮喂点吃的');

      expect(routed, isTrue);
      expect(gp.currentNarrative, contains('宠物互动'));
      expect(p.petLastFedDay, day, reason: '喂食应记录当日');
    });
  });

  group('匹配纪律：宁可漏判，不可误判', () {
    test('空串与纯空白不路由', () async {
      final gp = await makeProvider();
      expect(gp.tryRouteGameplayIntent(''), isFalse);
      expect(gp.tryRouteGameplayIntent('   '), isFalse);
    });

    test('「切磋功课」是学习语境，不劫持进决斗', () async {
      final gp = await makeProvider();
      setupReady(gp);
      seedNpc(gp, 'harry', '哈利·波特');

      final routed = gp.tryRouteGameplayIntent('找哈利切磋功课');

      expect(routed, isFalse, reason: '学习语境应漏判回 P6 后果引擎');
    });

    test('「买宠物」是购物意图，不路由宠物互动', () async {
      final gp = await makeProvider();
      setupReady(gp, withPet: true);

      final routed = gp.tryRouteGameplayIntent('去对角巷买一只宠物');

      expect(routed, isFalse, reason: '购买/商店意图不应误判为互动');
    });

    test('无宠物时宠物互动不路由（不误判成"喂食动作"）', () async {
      final gp = await makeProvider();
      setupReady(gp, withPet: false);

      final routed = gp.tryRouteGameplayIntent('喂宠物吃东西');

      expect(routed, isFalse, reason: '没有宠物时不该路由宠物玩法');
    });

    test('普通自由行动（学习/社交）不路由，保持原有叙事路径', () async {
      final gp = await makeProvider();
      setupReady(gp);
      seedNpc(gp, 'hermione', '赫敏·格兰杰');

      expect(gp.tryRouteGameplayIntent('去图书馆复习魔咒'), isFalse);
      expect(gp.tryRouteGameplayIntent('和赫敏·格兰杰聊聊天'), isFalse);
      expect(gp.tryRouteGameplayIntent('回宿舍睡一觉'), isFalse);
    });
  });

  group('buildGameplayOptions 上下文门控', () {
    test('不在霍格沃茨（开局家中）不出现任何玩法选项', () async {
      final gp = await makeProvider();
      // fixture 开局在出生地（伦敦家中），未挪到城堡
      expect(gp.buildGameplayOptions(), isEmpty,
          reason: '家中不应出现魁地奇/决斗/禁林入口');
    });

    test('城堡内 + 有扫帚 → 出现魁地奇入口', () async {
      final gp = await makeProvider();
      setupReady(gp, withBroom: true);
      expect(actionsOf(gp.buildGameplayOptions()),
          contains('${kGameplayActionPrefix}quidditch'));
    });

    test('没有扫帚 → 不出现魁地奇入口', () async {
      final gp = await makeProvider();
      setupReady(gp, withBroom: false);
      expect(actionsOf(gp.buildGameplayOptions()),
          isNot(contains('${kGameplayActionPrefix}quidditch')));
    });

    test('本周已赛（qLastWeek == gameWeek）→ 不出现魁地奇入口', () async {
      final gp = await makeProvider();
      setupReady(gp);
      gp.player!.qLastWeek = gp.gameWeek;
      expect(actionsOf(gp.buildGameplayOptions()),
          isNot(contains('${kGameplayActionPrefix}quidditch')));
    });

    test('精力不足 15 → 决斗与禁林都不出现', () async {
      final gp = await makeProvider();
      setupReady(gp);
      gp.player!.energy = 14;
      final actions = actionsOf(gp.buildGameplayOptions());
      expect(actions, isNot(contains('${kGameplayActionPrefix}duel')));
      expect(actions, isNot(contains('${kGameplayActionPrefix}forest')));
    });

    test('精力 15 但饱食不足 → 禁林不出现，决斗仍在', () async {
      final gp = await makeProvider();
      setupReady(gp);
      gp.player!.energy = 30;
      gp.player!.satiety = 10;
      final actions = actionsOf(gp.buildGameplayOptions());
      expect(actions, contains('${kGameplayActionPrefix}duel'));
      expect(actions, isNot(contains('${kGameplayActionPrefix}forest')));
    });

    test('今日次数已满 → 对应玩法入口不出现', () async {
      final gp = await makeProvider();
      setupReady(gp);
      // 刷满今日决斗次数：recordDailyActivity 走同一套跨天滚动
      for (var i = 0; i < gp.dailyLimitOf('duel'); i++) {
        gp.recordDailyActivity('duel');
      }
      expect(actionsOf(gp.buildGameplayOptions()),
          isNot(contains('${kGameplayActionPrefix}duel')));
    });

    test('有宠物且今日未互动 → 出现宠物互动入口（宠物是唯一可玩项）', () async {
      final gp = await makeProvider();
      // 低精力 + 无扫帚：魁地奇/决斗/禁林门控全关，只剩宠物可玩 → 验证宠物门控本身
      setupReady(gp, withBroom: false, withPet: true);
      gp.player!.energy = 14;
      final actions = actionsOf(gp.buildGameplayOptions());
      expect(actions, contains('${kGameplayActionPrefix}pet_play'));
      expect(actions, isNot(contains('${kGameplayActionPrefix}quidditch')));
      expect(actions, isNot(contains('${kGameplayActionPrefix}duel')));
    });

    test('今日已互动 → 宠物互动入口消失', () async {
      final gp = await makeProvider();
      setupReady(gp, withPet: true);
      gp.player!.petInteractDay = gp.worldState.time.absoluteDayIndex;
      expect(actionsOf(gp.buildGameplayOptions()),
          isNot(contains('${kGameplayActionPrefix}pet_play')));
    });

    test('无宠物 → 不出现宠物互动入口', () async {
      final gp = await makeProvider();
      setupReady(gp, withPet: false);
      expect(actionsOf(gp.buildGameplayOptions()),
          isNot(contains('${kGameplayActionPrefix}pet_play')));
    });

    test('全就绪时最多 2 条玩法入口，绝不挤占承接选项', () async {
      final gp = await makeProvider();
      setupReady(gp, withPet: true);
      final opts = gp.buildGameplayOptions();
      expect(opts.length, lessThanOrEqualTo(2), reason: '玩法入口上限 2 条');
      for (final o in opts) {
        expect(o.action, startsWith(kGameplayActionPrefix),
            reason: '玩法入口必须带专用标记');
      }
    });
  });

  group('自动推进跳过玩法入口', () {
    test('pickAutoAdvanceChoice 不会选中 @@gameplay: 选项', () async {
      final gp = await makeProvider();
      setupReady(gp);
      // 构造一个「只有玩法入口」的极端选项面板：推进按钮必须回落到兜底选项
      gp.choices = [
        const GameChoice(
            text: '去魁地奇球场参加训练赛',
            action: '${kGameplayActionPrefix}quidditch'),
        const GameChoice(
            text: '去禁林边缘探险',
            action: '${kGameplayActionPrefix}forest'),
      ];

      final picked = gp.pickAutoAdvanceChoice();

      expect(picked.action, isNot(startsWith(kGameplayActionPrefix)),
          reason: '玩法是玩家主动选择的出口，推进按钮不代选');
      expect(picked.action, isNotEmpty);
    });
  });

  group('回合入口整链路（processChoice → 离线玩法回合）', () {
    test('自然语言魁地奇：整回合交给玩法系统并推进回合', () async {
      final gp = await makeProvider();
      setupReady(gp);
      final t0 = gp.turnCount;

      await gp.processChoice(const GameChoice(
          text: '去打魁地奇', action: '去球场参加一场魁地奇训练赛'));

      expect(gp.turnCount, t0 + 1, reason: '玩法回合也应推进回合计数');
      expect(gp.currentNarrative, contains('魁地奇比赛'));
      expect(gp.currentNarrative, contains('最终比分'));
    });

    test('选项面板玩法入口（@@gameplay:quidditch）点击后解析为完整比赛', () async {
      final gp = await makeProvider();
      setupReady(gp);
      final t0 = gp.turnCount;

      await gp.processChoice(const GameChoice(
          text: '去魁地奇球场参加训练赛，为学院争取胜利',
          action: '${kGameplayActionPrefix}quidditch'));

      expect(gp.turnCount, t0 + 1);
      // 标记被解析成自然文本后走同一套关键词路由 → 完整比赛叙事
      expect(gp.currentNarrative, contains('魁地奇比赛'));
      expect(gp.currentNarrative, contains('最终比分'));
      expect(gp.currentNarrative, isNot(contains(kGameplayActionPrefix)),
          reason: '标记绝不出现在叙事里');
    });
  });
}
