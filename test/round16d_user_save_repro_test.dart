/// 第16轮D · 用户真实存档复现测试
///
/// 用户报告：生成剧情过程中卡死崩溃；重进点「继续冒险」卡死闪退；无崩溃日志。
/// 本测试直接加载用户导出的 auto_save.json（v2 / 12回合 / 一年级8月开局 / 未分院），
/// 走「读档 → 继续冒险（选第一个选项）」真实路径，看是否抛异常或死循环。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 用户存档 fixture 含玩家隐私，不提交仓库；本地放 test/fixtures_auto_save.json
  // 时运行，CI/他人 clone 时自动跳过（复现专用）。
  final hasFixture = File('test/fixtures_auto_save.json').existsSync();

  group('用户存档复现（第16轮D）', () {

    Future<GameProvider> loadUserSave() async {
      SharedPreferences.setMockInitialValues({});
      final app = AppProvider();
      await app.loadSettings();
      final gp = GameProvider(app);
      app.setOfflineQuickMode(true);
      final raw = File('test/fixtures_auto_save.json').readAsStringSync();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      gp.applySaveData(data);
      return gp;
    }

    test('读档：用户存档 applySaveData 完整加载不抛异常', () async {
      if (!hasFixture) return;
      final gp = await loadUserSave();
      expect(gp.player, isNotNull);
      expect(gp.player!.house, isNull, reason: '该档未分院（8月开局）');
      expect(gp.player!.grade, 1);
      expect(gp.worldState, isNotNull);
      expect(gp.npcRegistry.length, greaterThan(20));
      expect(gp.currentNarrative, isNotEmpty);
      expect(gp.choices, isNotEmpty);
      expect(gp.isLoading, isFalse);
    });

    test('继续冒险：选第一个选项推进 3 回合不卡死不抛异常', () async {
      if (!hasFixture) return;
      final gp = await loadUserSave();
      for (var i = 0; i < 3; i++) {
        final cs = gp.choices;
        expect(cs, isNotEmpty, reason: '第 $i 回合应有可用选项');
        gp.processChoice(cs.first);
        await Future.delayed(const Duration(milliseconds: 5));
        expect(gp.player, isNotNull);
        expect(gp.isLoading, isFalse, reason: '回合 $i 后不应卡在加载态');
      }
      expect(gp.turnCount, greaterThan(0));
    });

    test('继续冒险：连续 15 回合稳定性（防死循环）', () async {
      if (!hasFixture) return;
      final gp = await loadUserSave();
      for (var i = 0; i < 15; i++) {
        final cs = gp.choices;
        if (cs.isEmpty) break; // 若某回合无选项说明流程结束，正常退出
        gp.processChoice(cs.first);
        await Future.delayed(const Duration(milliseconds: 3));
        expect(gp.isLoading, isFalse);
      }
    });

    test('读档后序列化往返：applySaveData(parse(toJson())) 不崩', () async {
      if (!hasFixture) return;
      final gp = await loadUserSave();
      final p = gp.player!;
      final roundTrip = {
        'save_version': 2,
        'player': p.toJson(),
        'world_state': gp.worldState.toJson(),
        'npc_registry':
            gp.npcRegistry.map((k, v) => MapEntry(k, v.toJson())),
        'narrative': gp.currentNarrative,
        'choices': gp.choices
            .map((c) => {'text': c.text, 'action': c.action})
            .toList(),
        'turn_count': gp.turnCount,
      };
      gp.applySaveData(roundTrip);
      expect(gp.player, isNotNull);
      expect(gp.player!.name, p.name);
    });
  });
}
