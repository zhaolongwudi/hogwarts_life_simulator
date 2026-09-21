/// Batch 10 · Issue #13：CI「全开 smoke」套件。
///
/// 审查报告 §四.13 指出：默认关掉全部新系统保证 1900+ 既有用例稳定，
/// 代价是**默认配置与测试配置完全不同**——线上问题无法用现有测试复现。
///
/// 本文件在 CI 上跑一份「与生产默认一致」的长局冒烟：
///
///   ① P10 奇遇 / P11 羁绊 / P12 宠物 / P13 来信 / P14 社团 全部保持生产默认
///      （AppProvider 默认 `true`，不手动关闭）；
///   ② 连续推进 N 回合（真实离线回合循环，含各层随机触发），断言不崩、
///      世界时钟前进、叙事有内容；
///   ③ 存档→读档往返，字段不丢、进度可续；
///   ④ 主线剧情模式 + 全开系统共存跑一小段（剧情引擎与随机层互不炸）。
///
/// 【与 batch44 的分工】batch44 钉死的是「同一回合多层同时可触发时的互斥
/// 优先级契约」（刻意构造多条件齐备的极端场景）；本文件钉的是「生产默认
/// 配置下整体可玩」的回归基线（真实随机节奏下的长局不炸）。两者互补。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Batch 10 · Issue #13：生产默认全开 smoke', () {
    test('生产默认：P10~P14 全部默认开启（与 AppProvider 一致）', () async {
      // 【为什么不能走 makeGame】共享测试夹具会显式关闭 P10~P14 以保证
      // 既有确定性用例稳定；要验证「生产默认」必须绕过夹具、直接构造
      // AppProvider 看它的初始值。
      SharedPreferences.setMockInitialValues({});
      final app = AppProvider();
      await app.loadSettings();
      // 线上配置：五个新系统默认全开（见 app_provider.dart 注释）。
      // 本断言防止未来有人把默认改成 false 而不自知——那是线上行为变更。
      expect(app.happenstanceEnabled, isTrue,
          reason: 'P10 奇遇生产默认应开启');
      expect(app.companionArcEnabled, isTrue,
          reason: 'P11 羁绊生产默认应开启');
      expect(app.petStoryEnabled, isTrue,
          reason: 'P12 宠物生产默认应开启');
      expect(app.letterEnabled, isTrue,
          reason: 'P13 来信生产默认应开启');
      expect(app.clubEnabled, isTrue,
          reason: 'P14 社团生产默认应开启');
    });

    test('全开配置下连续推进 30 回合不崩、时钟前进、叙事非空', () async {
      final gp = await makeGame(offlineQuickMode: true);
      // P10~P14 保持生产默认（全开）——makeGame 会显式关掉，这里再开回来，
      // 模拟「真实跑局」的开关组合。
      gp.appProvider.happenstanceEnabled = true;
      gp.appProvider.companionArcEnabled = true;
      gp.appProvider.petStoryEnabled = true;
      gp.appProvider.letterEnabled = true;
      gp.appProvider.clubEnabled = true;

      final startDay = gp.worldState.time.absoluteDayIndex;
      var narrativeNonEmpty = 0;
      var guard = 0;

      while (guard < 30) {
        guard++;
        // 离线快速模式：choices 由本地模板生成，可安全用首个选项推进。
        expect(gp.choices, isNotEmpty, reason: '第 $guard 回合应有可用选项');
        final action = gp.choices.first.action;
        await gp.processChoice(GameChoice(text: '继续', action: action));
        expect(gp.player, isNotNull, reason: '推进后玩家对象必须存在');
        expect(gp.worldState, isNotNull, reason: '推进后世界状态必须存在');
        // 叙事应持续产出内容（离线模板至少渲染一句话）
        final text = gp.currentNarrative.trim();
        if (text.isNotEmpty) narrativeNonEmpty++;
      }

      expect(
        gp.worldState.time.absoluteDayIndex,
        greaterThan(startDay),
        reason: '推进 30 回合后世界时钟必须前进',
      );
      expect(narrativeNonEmpty, greaterThan(0),
          reason: '全开配置下离线叙事应持续产出内容');
    });

    test('全开配置下存档→读档往返：关键字段不丢、进度可续', () async {
      final gp = await makeGame(offlineQuickMode: true);
      gp.appProvider.happenstanceEnabled = true;
      gp.appProvider.companionArcEnabled = true;
      gp.appProvider.petStoryEnabled = true;
      gp.appProvider.letterEnabled = true;
      gp.appProvider.clubEnabled = true;

      // 先推进若干回合，制造有内容的存档
      for (var i = 0; i < 10; i++) {
        expect(gp.choices, isNotEmpty);
        await gp.processChoice(
          GameChoice(text: '继续', action: gp.choices.first.action),
        );
      }
      final dayBefore = gp.worldState.time.absoluteDayIndex;
      final turnBefore = gp.turnCount;

      // 存档（走真实 saveGameNamed → SharedPreferences 通道）
      await gp.saveGameNamed('smoke_slot');
      // 读档回同一实例（离线快速模式下从存档重建）
      // 【注意】loadFromSave 失败时设 error 而不抛异常，须显式断言 error 为空。
      await gp.loadFromSave('smoke_slot');
      expect(gp.error, isNull, reason: '全开配置存档应能读回（error 应为空）');

      expect(gp.worldState.time.absoluteDayIndex, greaterThanOrEqualTo(dayBefore),
          reason: '读档后世界时钟不应回退');
      expect(gp.turnCount, greaterThanOrEqualTo(turnBefore),
          reason: '读档后回合数不应回退');
      expect(gp.player, isNotNull);
      expect(gp.worldState, isNotNull);
    });

    test('主线剧情模式 + 全开系统共存跑一小段不炸', () async {
      final gp = await makeGame(offlineQuickMode: true);
      gp.appProvider.happenstanceEnabled = true;
      gp.appProvider.companionArcEnabled = true;
      gp.appProvider.petStoryEnabled = true;
      gp.appProvider.letterEnabled = true;
      gp.appProvider.clubEnabled = true;

      gp.openingScene = 'letter';
      gp.enterStoryMode();
      expect(gp.storyProgress.active, isTrue, reason: '应进入剧情模式');

      // 剧情模式推 5 步：选项来自剧情分支（choices.first 是剧情步的分支）
      for (var i = 0; i < 5; i++) {
        expect(gp.choices, isNotEmpty,
            reason: '剧情模式第 $i 步应有剧情分支可选');
        await gp.processChoice(
          GameChoice(text: '继续', action: gp.choices.first.action),
        );
        expect(gp.player, isNotNull);
        expect(gp.worldState, isNotNull);
      }
      // 剧情模式 + 全开系统共存下世界状态仍有效
      expect(gp.storyProgress.active, isTrue,
          reason: '推 5 步后仍在剧情模式内（尚未完结）');
    });
  });
}