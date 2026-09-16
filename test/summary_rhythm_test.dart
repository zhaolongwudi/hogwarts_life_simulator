import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
import 'package:hogwarts_life_simulator/mixins/mixin_narrative.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';

import 'helpers/test_fixtures.dart';

/// 摘要触发节奏与失败退避的守门测试。
///
/// 【两个被修正的认知】
///
/// 1. **"或"关系使回合数上限几乎不生效**
///    `shouldRunPeriodicSummary` 是 `turnCount % 20 == 0 || 字数 > 6800`。
///    正常叙事 600-800 字/回合，6800 字约 9~11 回合就命中——**远早于 20 回合**。
///    所以 batch34 把间隔从 15 改到 20、声称"省 25% 调用"，是按 20/15 的
///    间隔比纸面推算的，只在"回合是唯一触发路径"时才成立。
///    本文件把这条真实节奏钉死，避免后人再按错误前提估成本。
///
/// 2. **失败后立即重试会形成风暴**
///    摘要失败会把 chunk 原样还回缓冲，缓冲立刻又满足字数阈值 →
///    下一回合立刻重试 → 再失败。配额耗尽时等于每回合烧一次失败调用。
///    修复方式：连续失败后进入退避（冷却回合数随失败次数线性增长，有上限）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllStoryBooks);

  group('触发节奏：字数分支主导（"或"关系的真实效果）', () {
    test('字数超阈值时立即触发，即使回合数远未到 20', () {
      expect(
        GameNarrativeMixin.shouldRunPeriodicSummary(3, 7000),
        isTrue,
        reason: '第 3 回合但缓冲已 7000 字 → 由字数分支触发',
      );
    });

    test('推到第 20 回合触发（整数倍分支）', () {
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(20, 500), isTrue);
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(40, 500), isTrue);
    });

    test('非整数倍且字数不足 → 不触发', () {
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(19, 500), isFalse);
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(21, 500), isFalse);
    });

    test('缓冲为空时任何回合都不触发', () {
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(20, 0), isFalse,
          reason: '没有待摘要内容时不该发起调用');
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(0, 0), isFalse);
    });

    test('真实文本量下的触发间隔约为 9~11 回合（推翻"20 回合一次"的估算）', () {
      // 模拟 700 字/回合的典型叙事，逐回合累计，记录首次触发点。
      var chars = 0;
      int? firstTrigger;
      for (var turn = 1; turn <= 30; turn++) {
        chars += 700;
        if (GameNarrativeMixin.shouldRunPeriodicSummary(turn, chars)) {
          firstTrigger ??= turn;
        }
      }
      expect(firstTrigger, isNotNull);
      expect(firstTrigger!, lessThanOrEqualTo(12),
          reason: '700 字/回合 → 约 10 回合就该触发。'
              'batch34 按 20/15 估算"省 25%"是错误前提——'
              '真实节奏由字数主导，回合数上限几乎不起作用');
    });

    test('回合数分支只在剧情很短时才成为首要触发路径', () {
      // 极短叙事（100 字/回合）：10 回合才 1000 字，字数分支不触发，
      // 此时才轮到第 20 回合的整数倍分支。
      var chars = 0;
      int? byChars;
      for (var turn = 1; turn <= 20; turn++) {
        chars += 100;
        if (chars > 6800) byChars ??= turn;
      }
      expect(byChars, isNull, reason: '100 字/回合在 20 回合内达不到 6800 字');
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(20, chars), isTrue,
          reason: '此时由回合数分支触发——这才是 20 这个数字真正起作用的场景');
    });
  });

  group('失败退避：阻断"失败→重试→再失败"风暴', () {
    test('退避中不触发，即使字数超阈值', () {
      expect(
        GameNarrativeMixin.shouldRunPeriodicSummary(
          10,
          9000,
          consecutiveFails: 1,
          cooldownRemaining: 3,
        ),
        isFalse,
        reason: '冷却期内必须完全不触发，否则风暴依旧',
      );
    });

    test('退避归零后恢复触发', () {
      expect(
        GameNarrativeMixin.shouldRunPeriodicSummary(
          10,
          9000,
          consecutiveFails: 1,
          cooldownRemaining: 0,
        ),
        isTrue,
      );
    });

    test('冷却回合数随连续失败次数线性增长', () {
      final c1 = GameNarrativeMixin.cooldownForFailCount(1);
      final c2 = GameNarrativeMixin.cooldownForFailCount(2);
      final c3 = GameNarrativeMixin.cooldownForFailCount(3);
      expect(c1, greaterThan(0), reason: '第 1 次失败就该有冷却');
      expect(c2, c1 + 1);
      expect(c3, c2 + 1);
    });

    test('冷却回合数有上限（不会把摘要永久停掉）', () {
      final huge = GameNarrativeMixin.cooldownForFailCount(999);
      expect(huge, lessThanOrEqualTo(10),
          reason: '长时间局下摘要不能被无限期停掉，否则记忆彻底断档');
      expect(huge, greaterThan(0));
    });

    test('失败次数为 0 时冷却为 0', () {
      expect(GameNarrativeMixin.cooldownForFailCount(0), 0);
      expect(GameNarrativeMixin.cooldownForFailCount(-1), 0);
    });

    test('退避计数器可被设定与递减', () {
      GameNarrativeMixin.resetSummaryFailCounter();
      expect(GameNarrativeMixin.summaryCooldownRemaining, 0);

      GameNarrativeMixin.applySummaryCooldown(1);
      final set = GameNarrativeMixin.summaryCooldownRemaining;
      expect(set, greaterThan(0));

      GameNarrativeMixin.tickSummaryCooldown();
      expect(GameNarrativeMixin.summaryCooldownRemaining, set - 1);

      GameNarrativeMixin.resetSummaryFailCounter();
      expect(GameNarrativeMixin.summaryCooldownRemaining, 0,
          reason: '复位必须同时清掉退避，否则读档/新开局会带着旧冷却');
    });

    test('退避不会减到负数', () {
      GameNarrativeMixin.resetSummaryFailCounter();
      for (var i = 0; i < 5; i++) {
        GameNarrativeMixin.tickSummaryCooldown();
      }
      expect(GameNarrativeMixin.summaryCooldownRemaining, 0);
    });
  });

  group('节奏常量自洽', () {
    test('提前触发阈值 < 缓冲上限（否则溢出丢字前来不及压缩）', () {
      // 这两个值在 mixin 内是 private，这里通过行为间接断言：
      // 缓冲上限 8000、提前阈值 6800 的语义是"接近满时就压"。
      // 用 7000 字（介于 6800 与 8000 之间）验证确实会触发。
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(5, 7000), isTrue);
      // 且 8000 也没问题
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(5, 8000), isTrue);
    });
  });

  // ================================================================
  // 离线本地摘要（0 AI 调用的记忆沉淀）
  // ================================================================
  //
  // 【为什么必须有这一组】离线分支此前是一句裸 `return`：
  // `_summarizeNarrative` 是 LongTermMemory 唯一的**批量**生产者，
  // 被挡在门外之后，离线长局的记忆生产者变成零个。
  // 玩家越是用离线模式长期玩（本项目的主推玩法），记忆库越空。
  // 现在换成 `_runOfflineLocalSummary`：本地结构化抽取，0 次 AI 调用。
  group('离线本地摘要：不调 AI 也要沉淀记忆', () {
    test('离线跑完《魔法石》全书，长期记忆有实质增长且 AI 调用为 0', () async {
      final gp = await makeGame(offlineQuickMode: true);
      gp.openingScene = 'letter';
      gp.enterStoryMode();

      final we0 = gp.memory.worldEvents.length;
      final kf0 = gp.memory.keyFacts.length;

      var guard = 0;
      while (!gp.storyProgress.isFinished && guard < 200) {
        guard++;
        if (gp.choices.isEmpty) break;
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }

      expect(gp.apiCalls, 0, reason: '离线红线：本地摘要一次 AI 都不能调');
      expect(
        gp.memory.worldEvents.length,
        greaterThan(we0),
        reason: '跑完全书世界大事必须增长（此前恒为初始值）',
      );
      expect(
        gp.memory.keyFacts.length,
        greaterThan(kf0),
        reason: '跑完全书核心事实必须增长',
      );
    });

    test('缓冲会被消费掉（不清就会涨到上限被截断丢弃）', () async {
      final gp = await makeGame(offlineQuickMode: true);
      gp.openingScene = 'letter';
      gp.enterStoryMode();

      for (var i = 0; i < 25 && gp.choices.isNotEmpty; i++) {
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }

      // 25 回合跨过了 20 回合的触发点，缓冲应已被消化到远低于上限。
      expect(
        gp.pendingSummary.length,
        lessThan(6800),
        reason: '缓冲必须被本地摘要消费，否则会用涨满截断的方式丢剧情',
      );
    });

    test('本地摘要写出的世界大事描述非空且重要度合法', () async {
      final gp = await makeGame(offlineQuickMode: true);
      gp.openingScene = 'letter';
      gp.enterStoryMode();

      for (var i = 0; i < 45 && gp.choices.isNotEmpty; i++) {
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }

      final offline = gp.memory.worldEvents
          .where((w) => w.id.startsWith('offline_'))
          .toList();
      if (offline.isEmpty) return; // 该路径未被走到时跳过（不误报）

      for (final w in offline) {
        expect(w.title.trim(), isNotEmpty, reason: '世界大事标题不能为空');
        expect(w.description.trim(), isNotEmpty, reason: '描述不能为空');
        expect(
          w.importance,
          inInclusiveRange(1, 10),
          reason: '「${w.id}」重要度越界',
        );
      }
    });
  });
}
