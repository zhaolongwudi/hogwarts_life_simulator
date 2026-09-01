/// 第16轮C · 崩溃复现测试：模拟「生成剧情 → 存档 → 读档 → 继续冒险」全链路
///
/// 用户报告：生成剧情过程中卡死崩溃；重进点「继续冒险」直接卡死闪退；无崩溃日志
/// （疑似 ANR/OOM，非 Dart 异常）。本测试覆盖最近 3 轮改动涉及的高危路径。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

GameChoice gc(String action) => GameChoice(text: action, action: action);

Future<GameProvider> makeGame() async {
  SharedPreferences.setMockInitialValues({});
  final app = AppProvider();
  await app.loadSettings();
  final gp = GameProvider(app);
  app.setOfflineQuickMode(true); // 无 AI key 也走本地快速模式（模拟真实回合推进）
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

/// 构造一份与 writeSave 同构的存档 JSON（不落盘）
Map<String, dynamic> buildSaveJson(GameProvider gp) {
  final p = gp.player!;
  return {
    'save_version': 2,
    'player': p.toJson(),
    'world_state': gp.worldState.toJson(),
    'npc_registry': gp.npcRegistry.map((k, v) => MapEntry(k, v.toJson())),
    'narrative': gp.currentNarrative,
    'choices': gp.choices.map((c) => {'text': c.text, 'action': c.action}).toList(),
    'turn_count': gp.turnCount,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('崩溃复现（第16轮C）', () {
    test('离线快速模式连续 20 回合不卡死（生成剧情路径）', () async {
      final gp = await makeGame();
      for (var i = 0; i < 20; i++) {
        gp.processChoice(gc('去图书馆看书'));
        await Future.delayed(const Duration(milliseconds: 5));
        expect(gp.player, isNotNull);
      }
      expect(gp.turnCount, greaterThan(0));
    });

    test('存档 JSON 构造-解析循环 20 次不崩不卡（读档路径）', () async {
      final gp = await makeGame();
      for (var i = 0; i < 20; i++) {
        gp.processChoice(gc('和同学聊天'));
        await Future.delayed(const Duration(milliseconds: 3));
        final json = buildSaveJson(gp);
        expect(json['player'], isNotNull);
        expect(json['npc_registry'], isNotNull);
        // 模拟读档
        gp.applySaveData(json);
        expect(gp.player, isNotNull, reason: '读档后 player 不应为空');
        expect(gp.isLoading, isFalse);
      }
    });

    test('保存-读档-继续冒险循环 10 次（模拟反复进出）', () async {
      final gp = await makeGame();
      for (var i = 0; i < 10; i++) {
        gp.processChoice(gc('去食堂吃饭'));
        await Future.delayed(const Duration(milliseconds: 3));
        final json = buildSaveJson(gp);
        gp.applySaveData(json);
        expect(gp.player, isNotNull);
        gp.processChoice(gc('继续探索'));
        await Future.delayed(const Duration(milliseconds: 3));
        expect(gp.isLoading, isFalse, reason: '继续冒险后不应卡在加载态');
      }
    });
  });
}
