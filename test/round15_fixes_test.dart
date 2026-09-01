/// 第 15 轮审查修复的行为测试：
///  1. 坏结局二「自由尽失」（checkImprisonment）：触发/不触发边界 + 拦截文案
///  2. /查看 信息分级（框架2 §6/§125）：浅关系不泄露好感数值/心上事/声望
///  3. Player 新字段 isImprisoned/imprisonedOn 序列化往返（老档缺省兼容）
///  4. 恋爱声望落点（框架1 §13.3）：确立恋爱后学院声望变化、社交声望不变
///
/// 测试纪律：注入与生产同侧（GameProvider 真实构造）、断言性质不锁细节。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';
import 'package:hogwarts_life_simulator/models/player.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

Future<GameProvider> makeGame() async {
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

  group('坏结局二「自由尽失」（框架2 §118）', () {
    test('黑魔法声望压过道德底线且六年级以上 → 被捕入狱', () async {
      final gp = await makeGame();
      final p = gp.player!;
      p.grade = 7;
      p.playerReputation.setValue('dark', 85);
      p.playerReputation.setValue('moral', 25);
      gp.checkImprisonment();
      expect(p.isImprisoned, isTrue, reason: '罪证确凿应触发囚禁结局');
      expect(p.endingType, 'imprisoned');
      expect(p.imprisonedOn, isNotNull);
      expect(gp.choices, isNotEmpty, reason: '终章应给出可操作选项');
    });

    test('条件不足（dark 未过线）→ 不触发', () async {
      final gp = await makeGame();
      final p = gp.player!;
      p.grade = 7;
      p.playerReputation.setValue('dark', 60);
      p.playerReputation.setValue('moral', 25);
      gp.checkImprisonment();
      expect(p.isImprisoned, isFalse);
      expect(p.endingType, 'normal');
    });

    test('未成年（五年级及以下）→ 不触发', () async {
      final gp = await makeGame();
      final p = gp.player!;
      p.grade = 4;
      p.playerReputation.setValue('dark', 90);
      p.playerReputation.setValue('moral', 10);
      gp.checkImprisonment();
      expect(p.isImprisoned, isFalse, reason: '未成年巫师不直接判阿兹卡班');
    });

    test('无敌模式 → 不触发', () async {
      final gp = await makeGame();
      final p = gp.player!;
      p.grade = 7;
      p.cheatInvincible = true;
      p.playerReputation.setValue('dark', 95);
      p.playerReputation.setValue('moral', 5);
      gp.checkImprisonment();
      expect(p.isImprisoned, isFalse);
    });

    test('已死亡 → 不触发', () async {
      final gp = await makeGame();
      final p = gp.player!;
      p.grade = 7;
      p.isDead = true;
      p.playerReputation.setValue('dark', 95);
      p.playerReputation.setValue('moral', 5);
      gp.checkImprisonment();
      expect(p.isImprisoned, isFalse);
    });

    test('囚禁后行动被拦截，文案引导阿兹卡班', () async {
      final gp = await makeGame();
      final p = gp.player!;
      p.grade = 7;
      p.playerReputation.setValue('dark', 88);
      p.playerReputation.setValue('moral', 20);
      gp.checkImprisonment();
      expect(gp.blockActionIfDead(), isTrue, reason: '囚禁同死亡一样拦截行动');
      expect(gp.currentNarrative, contains('阿兹卡班'));
    });
  });

  group('/查看 信息分级（框架2 §6/§125 信息限制）', () {
    test('浅关系（同院未结识）→ 不泄露好感数值/心上事/声望', () async {
      final gp = await makeGame();
      final p = gp.player!;
      p.house = 'Gryffindor';
      // 同院 NPC：_isNPCVisible 放行，但无正式关系
      final npc = gp.npcRegistry.values.firstWhere(
        (n) => n.house == 'Gryffindor',
      );
      final dossier = gp.formatCharacterDossier(npc.name);
      expect(dossier, contains('Gryffindor'), reason: '基础信息应展示');
      expect(dossier, isNot(contains('好感 ')), reason: '浅关系不应露出精确好感');
      expect(dossier, isNot(contains('心上事')), reason: '浅关系不应露出个人目标');
      expect(dossier, isNot(contains('声望：')), reason: '浅关系不应露出声望数值');
    });

    test('深关系（朋友 Lv≥50）→ 展示好感数值与心上事', () async {
      final gp = await makeGame();
      final p = gp.player!;
      p.house = 'Gryffindor';
      final npc = gp.npcRegistry.values.firstWhere(
        (n) => n.house == 'Gryffindor',
      );
      p.relationships[npc.id] = Relationship(
        targetId: npc.id,
        targetName: npc.name,
        relationType: '朋友',
        level: 60,
      );
      npc.personalGoal = '想成为治疗师';
      final dossier = gp.formatCharacterDossier(npc.name);
      expect(dossier, contains('好感 '), reason: '深交应展示好感');
      expect(dossier, contains('心上事'), reason: '深交应展示个人目标');
    });
  });

  group('Player 新字段序列化（老档兼容）', () {
    test('isImprisoned/imprisonedOn 往返一致', () {
      final p = Player(
        name: '测试',
        birthYear: '1980',
        bloodType: 'muggleborn',
        birthLocation: '伦敦',
      );
      expect(p.isImprisoned, isFalse, reason: '新字段默认值必须 false（老档兼容）');
      p.isImprisoned = true;
      p.imprisonedOn = '1996年9月1日';
      final json = p.toJson();
      final back = Player.fromJson(json);
      expect(back.isImprisoned, isTrue);
      expect(back.imprisonedOn, '1996年9月1日');
      expect(back.endingType, 'normal');
    });

    test('老档缺 is_imprisoned 键 → 默认 false 不崩', () {
      final json = {
        'name': '测试',
        'birth_year': '1980',
        'birth_location': '伦敦',
        // 故意不给 is_imprisoned / imprisoned_on
      };
      final p = Player.fromJson(json);
      expect(p.isImprisoned, isFalse);
      expect(p.imprisonedOn, isNull);
    });
  });

  group('恋爱声望落点（框架1 §13.3 学院声望）', () {
    test('跨学院恋爱 → 学院声望下降、社交声望不变', () async {
      final gp = await makeGame();
      final p = gp.player!;
      p.house = 'Gryffindor';
      // 手动塞一个斯莱特林 NPC（开局同学可能全是本学院）
      gp.npcRegistry['sly_test'] = NPC(
        id: 'sly_test',
        name: '塞弗·诺特',
        house: 'Slytherin',
        grade: 3,
        isCanon: false,
      );
      final npc = gp.npcRegistry['sly_test']!;
      npc.affection = 90;
      npc.confessed = true;
      npc.isConsideringConfession = true;
      p.loveState.awaitingConfession = true;
      p.loveState.consideringNpcName = npc.name;

      final houseBefore = p.houseReputation;
      final socialBefore = p.playerReputation.social;
      gp.resolveConfession(true, npc.name);
      expect(p.playerReputation.social, socialBefore, reason: '恋爱声望不应再落到社交维度');
      expect(
        p.houseReputation,
        lessThan(houseBefore),
        reason: '跨学院恋爱应降低学院声望（框架1 §13.3）',
      );
    });
  });
}
