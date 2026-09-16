// v4 批次31 玩家沟通层:Q2 / Q6 / Q8 / Q14 行为测试。
//
// 覆盖四件事:
//  - Q2:SenseNovaQuotaManager 暴露「已用/剩余」只读视角,
//        窗口内计数准确、超窗口不计入;设置页配额卡片可渲染。
//  - Q6:narrativeExpectedWaitSeconds 用超时预算公式推算最坏等待,
//        无 AI Key / 离线时返回 0;UI 徽标在未配 AI 时不显示。
//  - Q8:摘要连续失败达到阈值才通知玩家,成功一次清零;
//        失败未达阈值不打扰。
//  - Q14:NPC 本地兜底回复按好感度分档,同消息多次问会轮换句子。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hogwarts_life_simulator/mixins/mixin_narrative.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';
import 'package:hogwarts_life_simulator/services/npc_chat_service.dart';
import 'package:hogwarts_life_simulator/services/prefs_store.dart';
import 'package:hogwarts_life_simulator/services/rate_limiter.dart';
import 'package:hogwarts_life_simulator/screens/settings/settings_quota_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Q2 配额窗口只用只读视角', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      PrefsStore.instance.resetForTest();
      SenseNovaQuotaManager.instance.reset();
      await PrefsStore.instance.init();
    });

    test('无调用时已用 0、剩余=上限', () async {
      const model = 'sensenova-6.8-flash-lite';
      expect(await SenseNovaQuotaManager.instance.usedInWindow(model), 0);
      expect(await SenseNovaQuotaManager.instance.remainingInWindow(model),
          SenseNovaQuotaManager.quotaForModel(model));
    });

    test('占用配额后已用与剩余之和等于上限', () async {
      const model = 'sensenova-6.8-flash-lite';
      final limit = SenseNovaQuotaManager.quotaForModel(model);
      for (var i = 0; i < 3; i++) {
        await SenseNovaQuotaManager.instance
            .waitForQuota(model, timeout: const Duration(seconds: 5));
      }
      final used = await SenseNovaQuotaManager.instance.usedInWindow(model);
      expect(used, 3);
      expect(await SenseNovaQuotaManager.instance.remainingInWindow(model),
          limit - 3);
    });

    testWidgets('设置页配额卡片展示「5 小时配额窗口」', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SettingsQuotaWindowForTest()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('5 小时配额窗口'), findsOneWidget);
    });
  });

  group('Q6 叙事最坏等待预期', () {
    late AppProvider app;
    late GameProvider gp;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      PrefsStore.instance.resetForTest();
      await PrefsStore.instance.init();
      app = AppProvider();
      gp = GameProvider(app);
    });

    test('无 AI Key 时返回 0(不展示等待)', () {
      expect(gp.narrativeExpectedWaitSeconds, 0);
      expect(gp.narrativeExpectedWaitHint, '');
    });

    test('有 SenseNova 与 Agnes Key 时返回正值且 hint 非空', () {
      app.setAllKeysForProvider(AiProvider.sensenova, ['sk-a']);
      app.setAllKeysForProvider(AiProvider.agnes, ['sk-b']);
      final gp2 = GameProvider(app);
      expect(gp2.narrativeExpectedWaitSeconds, greaterThan(0),
          reason: '配了叙事路由两个提供商的 Key,应有可估算的最坏等待');
      expect(gp2.narrativeExpectedWaitHint, isNotEmpty);
      expect(gp2.narrativeExpectedWaitHint, startsWith('预计最坏'));
    });
  });

  group('Q8 摘要连续失败阈值', () {
    setUp(() => GameNarrativeMixin.resetSummaryFailCounter());
    tearDown(() => GameNarrativeMixin.resetSummaryFailCounter());

    test('连续失败未达阈值不触发通知', () {
      expect(GameNarrativeMixin.advanceSummaryFailCounter(), isFalse);
      expect(GameNarrativeMixin.advanceSummaryFailCounter(), isFalse);
    });

    test('恰好第 N 次失败跨过阈值触发通知', () {
      expect(GameNarrativeMixin.summaryConsecutiveFails, 0);
      expect(GameNarrativeMixin.advanceSummaryFailCounter(), isFalse);
      expect(GameNarrativeMixin.advanceSummaryFailCounter(), isFalse);
      // 第三次(达到阈值)才通知
      expect(GameNarrativeMixin.advanceSummaryFailCounter(), isTrue);
    });

    test('成功一次清零后重新计数', () {
      GameNarrativeMixin.advanceSummaryFailCounter();
      GameNarrativeMixin.advanceSummaryFailCounter();
      GameNarrativeMixin.resetSummaryFailCounter();
      // 清零后再失败从 1 开始,不再直接跨阈值
      expect(GameNarrativeMixin.advanceSummaryFailCounter(), isFalse);
    });
  });

  group('Q14 NPC 本地兜底回复', () {
    late NpcChatService service;
    setUp(() {
      service = NpcChatService(appProvider: AppProvider());
    });

    NPC npcOf(String house, int affection) => NPC(
          id: 'n1',
          name: '测试',
          house: house,
          affection: affection,
        );

    test('好感度分档:冷淡与友好不会取自同一句', () {
      final coldReplies = <String>{
        for (var i = 0; i < 9; i++)
          service.localResponseFor(npcOf('Gryffindor', -50), 'hi-$i'),
      };
      final warmReplies = <String>{
        for (var i = 0; i < 9; i++)
          service.localResponseFor(npcOf('Gryffindor', 50), 'hi-$i'),
      };
      expect(coldReplies.intersection(warmReplies), isEmpty);
    });

    test('同消息多次问会轮换句子,不再"同句必同回"', () {
      final r1 = service.localResponseFor(npcOf('Hufflepuff', 0), '在吗');
      final r2 = service.localResponseFor(npcOf('Hufflepuff', 0), '在吗');
      expect(r1, isNot(equals(r2)),
          reason: 'Q14:同一条消息第二次应轮换到不同句子');
    });

    test('教职工(无学院)走专属词库,不再落到未知空回', () {
      final r = service.localResponseFor(npcOf('', 0), '先生');
      expect(r.trim(), isNotEmpty);
    });
  });
}

/// 测试辅助:把 Q2 的 SettingsQuotaWindow 包装成可泵入的 Widget。
class SettingsQuotaWindowForTest extends StatelessWidget {
  const SettingsQuotaWindowForTest({super.key});
  @override
  Widget build(BuildContext context) {
    return const SettingsQuotaWindow();
  }
}