/// v5 批次35 离线行动后果引擎测试（P6 核心「做了的事有结果」）。
///
/// 覆盖 `GameOfflineConsequenceMixin`：
///  - 类别判定：行动文本 → 学习/练咒/运动/打工/探索/休息/社交/跳过；
///  - 属性成长与封顶：不超 100，魔力/精力/饱食扣减不越界；
///  - 打工/探索：加隆与物品入库，探索三档（加隆/物品/氛围句）；
///  - 社交叠加：行动里出现**已登场** NPC 名 → 好感增量，且与主类别叠加；
///  - 确定性随机：同一 seed 重放结果一致，测试可钉死数值；
///  - 未登场 NPC 不结算好感、重叠动作不双算。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/mixins/mixin_offline_consequences.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';
import 'package:hogwarts_life_simulator/narrative/offline_consequence_types.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameProvider> makeProvider() async {
    return makeGame(offlineQuickMode: true);
  }

  /// 往 registry 里塞一个指定名字的 NPC，可选 introduced。
  void seedNpc(GameProvider gp, String id, String name,
      {int affection = 0, bool introduced = true}) {
    gp.npcRegistry[id] = NPC(
      id: id,
      name: name,
      affection: affection,
      introduced: introduced,
    );
  }

  group('类别判定 classifyActivity', () {
    test('学习类', () {
      expect(GameOfflineConsequenceMixin.classifyActivity('去图书馆自习'),
          OfflineActivity.study);
      expect(GameOfflineConsequenceMixin.classifyActivity('做作业'),
          OfflineActivity.study);
      expect(GameOfflineConsequenceMixin.classifyActivity('阅读魔法理论课本'),
          OfflineActivity.study);
    });

    test('练咒类', () {
      expect(GameOfflineConsequenceMixin.classifyActivity('练习咒语'),
          OfflineActivity.practice);
      expect(GameOfflineConsequenceMixin.classifyActivity('挥动魔杖施法'),
          OfflineActivity.practice);
    });

    test('运动类', () {
      expect(GameOfflineConsequenceMixin.classifyActivity('去打魁地奇'),
          OfflineActivity.sport);
      expect(GameOfflineConsequenceMixin.classifyActivity('绕着操场跑步'),
          OfflineActivity.sport);
    });

    test('打工类', () {
      expect(GameOfflineConsequenceMixin.classifyActivity('去猪头酒吧打工'),
          OfflineActivity.work);
      expect(GameOfflineConsequenceMixin.classifyActivity('帮费尔奇干活'),
          OfflineActivity.work);
    });

    test('探索类', () {
      expect(GameOfflineConsequenceMixin.classifyActivity('去禁林探索'),
          OfflineActivity.explore);
      expect(GameOfflineConsequenceMixin.classifyActivity('在学校里转转'),
          OfflineActivity.explore);
    });

    test('休息类', () {
      expect(GameOfflineConsequenceMixin.classifyActivity('回房睡觉'),
          OfflineActivity.rest);
      expect(GameOfflineConsequenceMixin.classifyActivity('躺下小憩一会'),
          OfflineActivity.rest);
      // 「休息日」不是休息动作，避免误判
      expect(GameOfflineConsequenceMixin.classifyActivity('准备休息日的安排'),
          OfflineActivity.none);
    });

    test('空串与无关键词 → none', () {
      expect(GameOfflineConsequenceMixin.classifyActivity(''),
          OfflineActivity.none);
      expect(GameOfflineConsequenceMixin.classifyActivity('随便做了点什么'),
          OfflineActivity.none);
    });

    test('优先级：学习优先于练咒，打工优先于探索', () {
      // 「学习练习咒语」既有学习词又有练咒词 → 取优先级更高的学习（实现顺序：
      // 休息 > 打工 > 学习 > 练咒 > 运动 > 探索）
      expect(GameOfflineConsequenceMixin.classifyActivity('学习怎么练习咒语'),
          OfflineActivity.study);
      // 「打工时探索」→ 打工优先
      expect(GameOfflineConsequenceMixin.classifyActivity('打工之余探索四周'),
          OfflineActivity.work);
    });
  });

  group('学习类结算：属性成长+资源扣减', () {
    test('学习后某项属性上升，精力/饱食下降', () async {
      final gp = await makeProvider();
      final p = gp.player!;
      const attrKeys = {'spell_understanding', 'theory', 'potions'};
      final before = <String, int>{
        for (final k in attrKeys) k: p.attributes[k]!,
      };
      final e0 = p.energy, s0 = p.satiety;

      final res = gp.settleOfflineConsequences('去图书馆自习', seed: 1);

      expect(res.lines, isNotEmpty);
      expect(res.lines.first, contains('+'));
      // 恰好一个成长属性上升且范围在 [1,3]
      var grown = 0;
      for (final k in attrKeys) {
        final delta = p.attributes[k]! - before[k]!;
        if (delta > 0) {
          grown++;
          expect(delta, inInclusiveRange(1, 3));
        }
      }
      expect(grown, 1, reason: '学习应恰好成长一个属性');
      expect(p.energy, lessThan(e0), reason: '学习消耗精力');
      expect(p.satiety, lessThan(s0), reason: '学习消耗饱食');
    });

    test('属性封顶 100，不越界', () async {
      final gp = await makeProvider();
      final p = gp.player!;
      p.attributes['spell_understanding'] = 99;
      p.attributes['theory'] = 99;
      p.attributes['potions'] = 99;

      gp.settleOfflineConsequences('反复复习魔咒理论', seed: 1);

      expect(p.attributes['spell_understanding'], lessThanOrEqualTo(100));
      expect(p.attributes['theory'], lessThanOrEqualTo(100));
      expect(p.attributes['potions'], lessThanOrEqualTo(100));
    });
  });

  group('练咒/运动结算', () {
    test('练咒消耗魔力，魔法控制/魔咒理解上升', () async {
      final gp = await makeProvider();
      final p = gp.player!;
      // fixture 初始属性不含 magic_control，先补上再测
      p.attributes['magic_control'] = 50;
      final mc = p.attributes['magic_control']!;
      final su = p.attributes['spell_understanding']!;
      final m0 = p.magic;

      gp.settleOfflineConsequences('练习咒语', seed: 2);

      final grown = p.attributes['magic_control']! - mc +
          p.attributes['spell_understanding']! - su;
      expect(grown, greaterThan(0), reason: '练咒应带来属性成长');
      expect(p.magic, lessThan(m0), reason: '练咒消耗魔力');
    });

    test('运动成长 + 魁地奇技巧 +1（未满时）', () async {
      final gp = await makeProvider();
      final p = gp.player!;
      p.qSkill = 90;
      final q0 = p.qSkill;

      final res = gp.settleOfflineConsequences('去打魁地奇', seed: 3);

      expect(p.qSkill, q0 + 1, reason: '运动应提升魁地奇技巧');
      expect(res.lines.first, contains('魁地奇技巧 +1'));
    });

    test('运动时魁地奇技巧已满则不再 +1', () async {
      final gp = await makeProvider();
      final p = gp.player!;
      p.qSkill = 100;

      final res = gp.settleOfflineConsequences('去打魁地奇', seed: 3);

      expect(p.qSkill, 100);
      expect(res.lines.first, isNot(contains('魁地奇技巧 +1')));
    });
  });

  group('打工/探索结算', () {
    test('打工增加加隆，出通知', () async {
      final gp = await makeProvider();
      final p = gp.player!;
      final g0 = p.galleons;

      final res = gp.settleOfflineConsequences('去打工', seed: 4);

      expect(p.galleons, greaterThan(g0));
      expect(res.notes, isNotEmpty);
      expect(res.notes.first, contains('+'));
    });

    test('探索三档之一：拿到加隆或物品或氛围句', () async {
      final gp = await makeProvider();
      final g0 = gp.player!.galleons;
      final inv0 = gp.player!.inventory.length;
      // 命中三档之一即可，且不抛错、有叙事行。
      final res = gp.settleOfflineConsequences('去禁林寻找好东西', seed: 5);
      expect(res.lines, isNotEmpty);
      // 探索只产出加隆增量或物品入包或氛围句，三项必居其一
      final gotGold = gp.player!.galleons > g0;
      final gotItem = gp.player!.inventory.length > inv0;
      final gotFlavor = res.lines.first.contains('你');
      expect(gotGold || gotItem || gotFlavor, isTrue);
    });

    test('探索确定性：同一 seed 重放结果一致', () async {
      final gp = await makeProvider();
      final beforeG = gp.player!.galleons;
      final beforeInv = gp.player!.inventory.length;

      gp.settleOfflineConsequences('四处翻找些什么', seed: 7);
      final delta1 = gp.player!.galleons - beforeG;
      final inv1 = gp.player!.inventory.length - beforeInv;

      // 重置后再来一局（用新的 provider），同 seed 应同样变化
      final gp2 = await makeProvider();
      final beforeG2 = gp2.player!.galleons;
      final beforeInv2 = gp2.player!.inventory.length;
      gp2.settleOfflineConsequences('四处翻找些什么', seed: 7);
      final delta2 = gp2.player!.galleons - beforeG2;
      final inv2 = gp2.player!.inventory.length - beforeInv2;

      expect(delta2, delta1, reason: '同 seed 探索加隆应一致');
      expect(inv2, inv1, reason: '同 seed 探索物品应一致');
    });
  });

  group('休息结算', () {
    test('休息回复精神与饱食，且不越上限', () async {
      final gp = await makeProvider();
      final p = gp.player!;
      p.spirit = 60;
      p.satiety = 60;

      gp.settleOfflineConsequences('回房睡觉', seed: 8);

      expect(p.spirit, greaterThan(60));
      expect(p.satiety, greaterThan(60));
      expect(p.spirit, lessThanOrEqualTo(100));
      expect(p.satiety, lessThanOrEqualTo(100));
    });
  });

  group('社交叠加结算', () {
    test('行动里提到已登场 NPC → 好感 +N', () async {
      final gp = await makeProvider();
      seedNpc(gp, 'hermione', '赫敏·格兰杰', affection: 10);
      final before = gp.npcRegistry['hermione']!.affection;

      final res = gp.settleOfflineConsequences('去找赫敏·格兰杰聊聊', seed: 9);

      final after = gp.npcRegistry['hermione']!.affection;
      expect(after, greaterThan(before), reason: '社交应提升好感');
      expect(res.lines, contains(contains('好感 +')));
      expect(res.notes, contains(contains('赫敏·格兰杰')));
    });

    test('社交与主类别叠加：学习+社交都结算', () async {
      final gp = await makeProvider();
      seedNpc(gp, 'harry', '哈利·波特');
      final p = gp.player!;
      final attrSum = p.attributes.values.fold(0, (a, b) => a + b);
      final aff0 = gp.npcRegistry['harry']!.affection;

      final res = gp.settleOfflineConsequences('和哈利·波特一起去图书馆学习', seed: 10);

      // 主类别（学习）→ 属性上升
      final attrSumAfter = p.attributes.values.fold(0, (a, b) => a + b);
      expect(attrSumAfter, greaterThan(attrSum), reason: '主类别的成长仍在');
      // 社交 → 好感上升（叠加）
      expect(gp.npcRegistry['harry']!.affection, greaterThan(aff0));
      // 叙事里同时有成长句与好感句
      expect(res.lines.length, greaterThanOrEqualTo(2));
    });

    test('未登场 NPC 名字出现在行动里不结算好感', () async {
      final gp = await makeProvider();
      seedNpc(gp, 'luna', '卢娜·洛夫古德', introduced: false);

      final res = gp.settleOfflineConsequences('去找卢娜·洛夫古德', seed: 11);

      expect(gp.npcRegistry['luna']!.affection, 0, reason: '未登场不涨好感');
      // 没有独立社交句
      expect(res.lines.any((l) => l.contains('卢娜')), isFalse);
    });
  });

  group('边界与空档', () {
    test('无法归类且未提到 NPC → 返回空结果、不写状态', () async {
      final gp = await makeProvider();
      seedNpc(gp, 'ron', '罗恩·韦斯莱');
      final p = gp.player!;
      final attrSum = p.attributes.values.fold(0, (a, b) => a + b);
      final g0 = p.galleons, aff0 = gp.npcRegistry['ron']!.affection;

      final res = gp.settleOfflineConsequences('发呆发了一会儿', seed: 12);

      expect(res.lines, isEmpty);
      expect(res.notes, isEmpty);
      expect(p.attributes.values.fold(0, (a, b) => a + b), attrSum);
      expect(p.galleons, g0);
      expect(gp.npcRegistry['ron']!.affection, aff0);
    });

    test('确定性：同一行动同 seed 两局姿态一致', () async {
      final gp = await makeProvider();
      gp.player!.attributes['magic_control'] = 50;
      gp.settleOfflineConsequences('练习咒语', seed: 20);
      final mc1 = gp.player!.attributes['magic_control']!;
      final su1 = gp.player!.attributes['spell_understanding']!;

      final gp2 = await makeProvider();
      gp2.player!.attributes['magic_control'] = 50;
      gp2.settleOfflineConsequences('练习咒语', seed: 20);
      expect(gp2.player!.attributes['magic_control']!, mc1);
      expect(gp2.player!.attributes['spell_understanding']!, su1);
    });
  });

  group('类型载体', () {
    test('OfflineConsequenceResult.empty 不含行', () {
      expect(OfflineConsequenceResult.empty.lines, isEmpty);
      expect(OfflineConsequenceResult.empty.notes, isEmpty);
    });
  });
}