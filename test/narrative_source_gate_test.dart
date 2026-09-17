// v4 批次35 叙事来源抽象 + 自动降级开关（P1）测试。
//
// 覆盖:
//  - 离线/无 AI 恒走本地;
//  - 连续失败达阈值自动降级本地;
//  - 宽限回合用尽 / 一次成功即自动恢复;
//  - reset 复位。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/narrative/narrative_source_gate.dart';

import 'helpers/test_fixtures.dart';

void main() {
  group('P1 · 叙事来源自动降级开关', () {
    NarrativeSourceGate gate({int maxFails = 2, int grace = 3}) =>
        NarrativeSourceGate(maxFailuresBeforeDegrade: maxFails, localGraceTurns: grace);

    test('离线/无AI 恒为本地,不因失败计数而变', () {
      final g = gate();
      expect(g.effective(offlineQuickMode: true, aiAvailable: true),
          NarrativeSource.local);
      expect(g.effective(offlineQuickMode: true, aiAvailable: false),
          NarrativeSource.local);
      expect(g.effective(offlineQuickMode: false, aiAvailable: false),
          NarrativeSource.local);
    });

    test('正常 AI 可用且未降级时为 AI', () {
      final g = gate();
      expect(g.effective(offlineQuickMode: false, aiAvailable: true),
          NarrativeSource.ai);
      expect(g.isAutoDegraded, isFalse);
    });

    test('连续失败未达阈值仍走 AI', () {
      final g = gate();
      g.recordFailure();
      expect(g.isAutoDegraded, isFalse);
      expect(g.effective(offlineQuickMode: false, aiAvailable: true),
          NarrativeSource.ai);
    });

    test('连续失败达阈值自动降级本地', () {
      final g = gate();
      g.recordFailure();
      g.recordFailure();
      expect(g.isAutoDegraded, isTrue);
      expect(g.effective(offlineQuickMode: false, aiAvailable: true),
          NarrativeSource.local);
    });

    test('降级后本地宽限回合用尽即自动恢复 AI', () {
      final g = gate(maxFails: 1, grace: 2);
      g.recordFailure();
      expect(g.isAutoDegraded, isTrue);
      // 两个本地回合后恢复
      g.onLocalTurn();
      expect(g.isAutoDegraded, isTrue, reason: '第一个本地回合仍在宽限内');
      g.onLocalTurn();
      expect(g.isAutoDegraded, isFalse, reason: '宽限用尽应自动恢复');
      expect(g.effective(offlineQuickMode: false, aiAvailable: true),
          NarrativeSource.ai);
    });

    test('降级期间一次 AI 成功立即恢复', () {
      final g = gate(maxFails: 1, grace: 5);
      g.recordFailure();
      expect(g.isAutoDegraded, isTrue);
      g.recordSuccess();
      expect(g.isAutoDegraded, isFalse);
      expect(g.effective(offlineQuickMode: false, aiAvailable: true),
          NarrativeSource.ai);
    });

    test('reset 复位后回到初始态', () {
      final g = gate();
      g.recordFailure();
      g.recordFailure();
      expect(g.isAutoDegraded, isTrue);
      g.resetForTest();
      expect(g.isAutoDegraded, isFalse);
      expect(g.effective(offlineQuickMode: false, aiAvailable: true),
          NarrativeSource.ai);
    });
  });

  group('P1 · 接入 GameProvider 的来源标签', () {
    test('离线快速模式下有效来源为本地,标签为「本地模式」', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final gp = await makeGame(offlineQuickMode: true);
      expect(gp.effectiveNarrativeSource, NarrativeSource.local);
      expect(gp.narrativeSourceLabel, '本地模式');
      // 离线模式不影响降级门自身状态
      expect(gp.narrativeSourceGate.isAutoDegraded, isFalse);
    });
  });

  group('P2 · 可选 AI 润色门控', () {
    test('未开启润色开关时返回 null,绝不触发 AI', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final gp = await makeGame(offlineQuickMode: true);
      expect(gp.appProvider.narrativePolishEnabled, isFalse);
      expect(await gp.polishLocalNarrativeForTest('一段本地叙事'), isNull);
    });

    test('开启润色但无 AI 服务(未配 Key)时安全回退 null', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final gp = await makeGame(offlineQuickMode: true);
      await gp.appProvider.setNarrativePolishEnabled(true);
      expect(gp.appProvider.narrativePolishEnabled, isTrue);
      // makeGame 未注入任何 AI router / key，hasNarrativeService=false
      expect(await gp.polishLocalNarrativeForTest('一段本地叙事'), isNull);
    });
  });
}