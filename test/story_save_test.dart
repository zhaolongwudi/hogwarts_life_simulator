/// 剧情模式存档与模式入口测试。
///
/// 【这一层测什么】
///   1. 存档往返：剧情进度（含 chosen/flags/effects/knowledge）经
///      `_saveExtraData → applySaveData` 一个来回后完整还原；
///      选项 action 里的剧情编码也必须原样穿过存档（这是风险 1 的核心防线）。
///   2. 老存档兼容：`extra_data` 里没有 `story_progress` key 时，
///      读进来必须是 inactive，且行为与从前一致。
///   3. 模式入口：`setStoryMode` 的持久化 + 开局接线（enterStoryMode）。
///
/// 【为什么用 buildSaveJson 同构 JSON 而不是真落盘】
/// `round16c_repro_test.dart` 建立的模式：走与 writeSave 相同的字段结构，
/// 再喂给 applySaveData——测的是序列化语义本身，不需要文件系统。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/story_progress.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_fixtures.dart';

/// 构造一份与 writeSave 同构的存档 JSON（含 extra_data 通道）。

/// 构造一个已进入剧情模式的 GameProvider（与 story_turn_test.dart 同款）。
///
/// `openingScene = 'letter'` 固定从第一章开始——批次 4 起，剧情开局
/// 会按开局场景跳章（见 `storyStartStepFor`），夹具不固定的话
/// 默认 station 会落到第三章，破坏本文件的存档往返用例。
Future<GameProvider> makeStoryGame() async {
  final gp = await makeGame(offlineQuickMode: true);
  gp.openingScene = 'letter';
  gp.enterStoryMode();
  return gp;
}

Map<String, dynamic> buildSaveJson(GameProvider gp) {
  final p = gp.player!;
  return {
    'save_version': 2,
    'player': p.toJson(),
    'world_state': gp.worldState.toJson(),
    'npc_registry': gp.npcRegistry.map((k, v) => MapEntry(k, v.toJson())),
    'narrative': gp.currentNarrative,
    'choices':
        gp.choices.map((c) => {'text': c.text, 'action': c.action}).toList(),
    'turn_count': gp.turnCount,
    // 与 mixin_systems.dart `_saveExtraData` 保持同构（仅取测试关心的 key）
    'extra_data': {
      'story_progress': gp.storyProgress.toJson(),
      'narrative_summary': '',
      'pending_summary': '',
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllStoryBooks);

  group('A · 老存档兼容（最高优先级）', () {
    test('extra_data 无 story_progress key → inactive', () async {
      final gp = await makeGame(offlineQuickMode: true);
      final oldSave = buildSaveJson(gp);
      (oldSave['extra_data'] as Map<String, dynamic>)
          .remove('story_progress');

      gp.applySaveData(oldSave);
      expect(gp.storyProgress.active, isFalse);
      expect(gp.storyProgress.isFinished, isFalse);
    });

    test('extra_data 整个缺失（更老的档）→ inactive，不崩', () async {
      final gp = await makeGame(offlineQuickMode: true);
      final oldest = buildSaveJson(gp)..remove('extra_data');
      gp.applySaveData(oldest);
      expect(gp.storyProgress.active, isFalse);
    });

    test('老存档读档后点选项仍走沙盒（不被误带进剧情）', () async {
      final gp = await makeGame(offlineQuickMode: true);
      final oldSave = buildSaveJson(gp);
      (oldSave['extra_data'] as Map<String, dynamic>).remove('story_progress');
      gp.applySaveData(oldSave);

      await gp.processChoice(const GameChoice(text: '四处看看', action: '四处看看'));
      expect(gp.storyProgress.active, isFalse);
      expect(gp.choices, isNotEmpty);
      for (final c in gp.choices) {
        expect(isStoryAction(c.action), isFalse);
      }
    });
  });

  group('B · 剧情存档往返', () {
    test('进度完整还原：stepId/chosen/flags/effects/knowledge/doneSteps', () async {
      final gp = await makeStoryGame();
      // 走一步，产生非空进度
      await gp.processChoice(
        GameChoice(
          text: 'x',
          action: encodeStoryAction('ps_ch1_letter', 'read_in_room'),
        ),
      );

      final json = buildSaveJson(gp);
      gp.applySaveData(json);

      final p = gp.storyProgress;
      expect(p.active, isTrue);
      expect(p.bookId, 'ps');
      expect(p.chapterId, 'ps_ch1');
      expect(p.stepId, 'ps_ch1_tell');
      expect(p.doneSteps, contains('ps_ch1_letter'));
      expect(p.chosen['ps_ch1_letter'], 'read_in_room');
      expect(p.flags, contains('ps_read_letter_first'));
      expect(p.knowledge, contains('knows_hogwarts_acceptance'));
      expect(p.effects['spirit'], isNotNull);
    });

    test('读档后的选项仍是剧情选项，点它能继续推进（风险 1 的验收）', () async {
      final gp = await makeStoryGame();
      await gp.processChoice(
        GameChoice(
          text: 'x',
          action: encodeStoryAction('ps_ch1_letter', 'read_in_room'),
        ),
      );
      gp.applySaveData(buildSaveJson(gp));

      // 读档后选项必须指向当前步
      expect(gp.choices, isNotEmpty);
      for (final c in gp.choices) {
        final cmd = parseStoryCommand(c.action);
        expect(cmd, isNotNull, reason: '读档后选项丢了剧情编码：${c.action}');
        expect(cmd!.stepId, 'ps_ch1_tell');
      }

      // 点一个选项能继续推进
      final before = gp.storyProgress.stepId;
      await gp.processChoice(GameChoice(text: 'x', action: gp.choices.first.action));
      expect(gp.storyProgress.stepId, isNot(before));
    });

    test('结局状态也进存档：读档后 isFinished 保持，不重新触发剧情', () async {
      final gp = await makeStoryGame();
      // 手动推进到结局
      gp.storyProgress = gp.storyProgress.copyWith(endingId: 'ps_ending_steady');
      gp.applySaveData(buildSaveJson(gp));
      expect(gp.storyProgress.isFinished, isTrue);
      expect(gp.storyProgress.endingId, 'ps_ending_steady');

      // 结局后点选项：不推进剧情，只呈现结局
      await gp.processChoice(
        const GameChoice(text: '在城堡里四处走走', action: '在城堡里四处走走'),
      );
      expect(gp.storyProgress.endingId, 'ps_ending_steady');
      expect(gp.currentNarrative, contains('结局'));
    });

    test('脏数据安全降级：story_progress 是个字符串也不崩', () async {
      final gp = await makeGame(offlineQuickMode: true);
      final dirty = buildSaveJson(gp);
      (dirty['extra_data'] as Map<String, dynamic>)['story_progress'] = '坏数据';
      gp.applySaveData(dirty);
      // fromJson 对非 Map 输入会抛类型错误 → applySaveData 需要能兜住
      // （若抛错此测试即失败）
      expect(gp.player, isNotNull);
    });
  });

  group('C · 模式入口', () {
    test('setStoryMode 持久化并可读回', () async {
      SharedPreferences.setMockInitialValues({});
      final app = AppProvider();
      await app.loadSettings();
      expect(app.storyMode, isFalse);

      await app.setStoryMode(true);
      expect(app.storyMode, isTrue);

      // 模拟重启：新 AppProvider 从同一批 mock prefs 读回
      final app2 = AppProvider();
      await app2.loadSettings();
      expect(app2.storyMode, isTrue);
    });

    test('storyMode 开了但没开离线 → 开局照样能进剧情（开局联动兜底）', () async {
      // 玩家只开了 story_mode（比如从别的入口），初始化时 enterStoryMode
      // 不依赖 offlineQuickMode——依赖关系在 intro_screen 里做联动。
      final gp = await makeGame(offlineQuickMode: false);
      gp.enterStoryMode();
      expect(gp.storyProgress.active, isTrue);
      expect(gp.choices, isNotEmpty);
    });

    test('开局进剧情模式：首屏是第一章，不是沙盒开场白', () async {
      final gp = await makeStoryGame();
      expect(gp.currentNarrative, contains('女贞路的信'));
      expect(
        gp.currentNarrative.contains('第 1 章'),
        isTrue,
        reason: '剧情首屏必须带章节抬头',
      );
      expect(gp.apiCalls, 0, reason: '开局进剧情也不许调用 AI');
    });

    test('开局场景决定起始章（9 月开局不许时间倒流回收信）', () async {
      // station 开局 = 9 月 1 日上午在站台 → 直接从第三章开始
      final gp = await makeGame(offlineQuickMode: true);
      gp.openingScene = 'station';
      gp.enterStoryMode();
      expect(gp.storyProgress.stepId, 'ps_ch3_platform');
      expect(gp.currentNarrative, contains('九又四分之三站台'));
      // 跳章开局时选项仍完整可用
      expect(gp.choices, isNotEmpty);
      for (final c in gp.choices) {
        expect(isStoryAction(c.action), isTrue);
      }

      // hall 开局 = 9 月 1 日傍晚分院礼堂 → 直接从分院夜开始
      final gp2 = await makeGame(offlineQuickMode: true);
      gp2.openingScene = 'hall';
      gp2.enterStoryMode();
      expect(gp2.storyProgress.stepId, 'ps_ch4_sorting');
    });
  });
}
