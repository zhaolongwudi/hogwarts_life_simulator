/// 第 16 轮遗留项修复的行为测试：
///  1. 穿越者记忆等级（框架2 §11）：各档文案 + 世界线高偏离时"记忆不可靠"警告
///  2. 世界线 NPC 本地联动（框架2 §93）：塔楼干预 → 邓布利多存活标记
///  3. 恋爱声望面板叠加规则说明（/声望 恋爱 封顶注）
///
/// 测试纪律：注入与生产同侧、断言性质不锁细节。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hogwarts_life_simulator/data/transmemory.dart';
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

  group('穿越者记忆等级（框架2 §11）', () {
    test('五档文案各不相同且都带穿越者标记', () {
      final texts = {
        for (final l in TransmemoryLevel.values)
          l: transmemoryPromptLine(l, 0.1),
      };
      expect(
        texts.values.toSet().length,
        TransmemoryLevel.values.length,
        reason: '每档应有独立描述',
      );
      for (final t in texts.values) {
        expect(t, contains('穿越者'), reason: '应标明身份模式');
      }
    });

    test('vivid 档说明可作行动依据，endingOnly 档只剩一句话记忆', () {
      expect(
        transmemoryPromptLine(TransmemoryLevel.vivid, 0.1),
        contains('非常熟悉'),
      );
      expect(
        transmemoryPromptLine(TransmemoryLevel.endingOnly, 0.1),
        contains('伏地魔最后会失败'),
      );
      expect(
        transmemoryPromptLine(TransmemoryLevel.errors, 0.1),
        contains('错误'),
      );
    });

    test('世界线变动率高时追加"记忆不可靠"警告', () {
      final normal = transmemoryPromptLine(TransmemoryLevel.partial, 0.1);
      final drifted = transmemoryPromptLine(TransmemoryLevel.partial, 0.6);
      expect(normal, isNot(contains('不可靠')));
      expect(drifted, contains('不可靠'));
      expect(drifted, contains('60.0%'), reason: '警告应带当前变动率');
    });

    test('穿越者开局掷档并写入 Player（老档缺省兼容）', () async {
      final gp = await makeGame();
      final p = gp.player!;
      // 默认原住民：记忆等级为 null
      expect(p.transmemoryLevel, isNull);
      // magazine 显示模式下禁止穿越者（app_provider 铁律），先切显示模式
      gp.appProvider.setDisplayMode(DisplayMode.compact);
      // 切到穿越者并触发系统提示词构建 → 掷档
      gp.appProvider.setIdentityMode(IdentityMode.transmigration);
      gp.buildSystemPrompt();
      expect(p.transmemoryLevel, isNotNull, reason: '穿越者首次构建系统提示词时应掷档写档');
      expect(
        TransmemoryLevel.values.map((l) => l.name),
        contains(p.transmemoryLevel),
      );
      // 序列化往返
      final back = Player.fromJson(p.toJson());
      expect(back.transmemoryLevel, p.transmemoryLevel);
    });
  });

  group('世界线 NPC 本地联动（框架2 §93）', () {
    test('塔楼干预后邓布利多存活并被标记', () async {
      final gp = await makeGame();
      // 确保 dumbledore NPC 存在（子世代原典角色）
      if (!gp.npcRegistry.containsKey('dumbledore')) {
        gp.npcRegistry['dumbledore'] = _dumbledoreNpc();
      }
      final dumbledore = gp.npcRegistry['dumbledore']!;
      dumbledore.isAlive = false; // 原著塔楼之夜后死亡
      final beforeEvents = dumbledore.recentEvents.length;

      final result = gp.resolveCausalChoice(
        'g6_jun_headmaster_fall',
        'intervene',
      );
      expect(result, isNotEmpty, reason: '应返回抉择后果文本');
      expect(dumbledore.isAlive, isTrue, reason: '干预后邓布利多应存活');
      expect(
        dumbledore.recentEvents.length,
        greaterThan(beforeEvents),
        reason: '应有 RecentEvent 标记',
      );
      expect(dumbledore.recentEvents.first, contains('活了下来'));
    });

    test('旁观选项不触发 NPC 联动', () async {
      final gp = await makeGame();
      if (!gp.npcRegistry.containsKey('dumbledore')) {
        gp.npcRegistry['dumbledore'] = _dumbledoreNpc();
      }
      final dumbledore = gp.npcRegistry['dumbledore']!;
      dumbledore.isAlive = false;
      gp.resolveCausalChoice('g6_jun_headmaster_fall', 'standAside');
      expect(dumbledore.isAlive, isFalse, reason: '旁观=世界回原典，邓布利多仍死');
    });

    test('npcRegistry 缺失的 id 静默忽略不崩', () async {
      final gp = await makeGame();
      // 用不存在 npcEffects 的选项（如 O.W.L. 试题，无 NPC 联动）直接调用不崩
      final result = gp.resolveCausalChoice('g5_jun_owls', 'intervene');
      expect(result, isNotEmpty);
    });
  });
}

/// 测试用邓布利多 NPC（最小实体）
NPC _dumbledoreNpc() => NPC(
  id: 'dumbledore',
  name: '阿不思·邓布利多',
  house: 'Gryffindor',
  grade: 0,
  isCanon: true,
);
