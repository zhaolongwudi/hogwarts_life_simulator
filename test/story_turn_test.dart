/// 剧情回合运行时测试：一个完整的剧情回合能不能正确推进。
///
/// 【这一层测什么】数据层的纯函数已由 `story_data_test.dart` 钉死；
/// 这里测的是**接线**：
///   · 剧情模式下点选项 → 叙事换了、选项换了、进度前进了；
///   · 时间按章节节拍推进（不是按行动关键词猜的）；
///   · 关系/物品/flag 真的落到玩家与记忆上；
///   · 自由输入不会卡死（降级为自由行动）；
///   · 全程 0 AI 调用（离线红线）。
///
/// 【为什么用 `makeGame` 而不是手搓 provider】它是全项目唯一的共享夹具
/// （`test/helpers/test_fixtures.dart`），走真实初始化路径。自己搭一份
/// 会随着初始化逻辑变化而腐烂，且测不出"真实开局能不能进剧情模式"。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/story_progress.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_fixtures.dart';

/// 构造一个已进入剧情模式的 GameProvider。
///
/// 用 `offlineQuickMode: true` 是因为**剧情模式挂在离线分支上**：
/// 没有它，`processChoice` 会因为"没有 AI 服务且未开离线"直接报错返回。
/// `openingScene = 'letter'` 固定从第一章开始（批次 4 起，剧情开局
/// 会按开局场景跳章，夹具不固定的话默认 station 会落到第三章）。
Future<GameProvider> makeStoryGame() async {
  final gp = await makeGame(offlineQuickMode: true);
  gp.openingScene = 'letter';
  gp.enterStoryMode();
  return gp;
}

/// 取当前第一个选项的 action（即玩家的"点按钮"行为）。
String firstAction(GameProvider gp) => gp.choices.first.action;

/// 取第一章（ps_ch1）的第 [index] 步（0 起）。
///
/// 【为什么不再写死 step id】第一章会随内容扩写增减节拍（目前 9 步）。
/// 测试关心的是"推进顺序、步长、选项指向当前步"这些**结构性质**，
/// 而不是某个具体 id。写死 id 会在每次扩写时误报，掩盖真正的回归。
StoryStepDef _ch1Step(int index) => findStoryBook('ps')!
    .chapters
    .firstWhere((c) => c.id == 'ps_ch1')
    .steps[index];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllStoryBooks);

  group('A · 进入剧情模式', () {
    test('首屏就是第一章第一步，且选项是剧情选项（不是兜底选项）', () async {
      final gp = await makeStoryGame();
      expect(gp.storyProgress.active, isTrue);
      expect(gp.storyProgress.bookId, 'ps');
      expect(gp.storyProgress.chapterId, 'ps_ch1');
      expect(gp.storyProgress.stepId, 'ps_ch1_letter');

      final book = findStoryBook('ps')!;
      expect(gp.currentNarrative, contains(book.title));
      expect(gp.currentNarrative, contains('女贞路的信'));

      final step = findStoryStep('ps', 'ps_ch1', 'ps_ch1_letter')!;
      expect(gp.choices.length, step.choices.length);
      // 关键：action 必须是剧情编码，而不是自由文本
      for (final c in gp.choices) {
        expect(
          isStoryAction(c.action),
          isTrue,
          reason: '选项「${c.text}」的 action 不是剧情编码：${c.action}',
        );
      }
    });

    test('首屏叙事里带章节抬头（玩家要知道自己在第几章）', () async {
      final gp = await makeStoryGame();
      expect(gp.currentNarrative, contains('第 1 章'));
    });

    test('开局进入剧情模式时不调用 AI（离线红线）', () async {
      final gp = await makeStoryGame();
      expect(gp.apiCalls, 0);
    });
  });

  group('B · 一个完整回合的推进', () {
    test('点第一个选项 → 进度前进、叙事换成下一步', () async {
      final gp = await makeStoryGame();
      final beforeStep = gp.storyProgress.stepId;
      final beforeTurn = gp.turnCount;

      await gp.processChoice(GameChoice(text: 'x', action: firstAction(gp)));

      expect(gp.turnCount, beforeTurn + 1, reason: '回合数必须推进');
      expect(
        gp.storyProgress.stepId,
        isNot(beforeStep),
        reason: '剧情游标必须前进',
      );
      expect(gp.storyProgress.stepId, _ch1Step(1).id);
      expect(gp.storyProgress.doneSteps, contains('ps_ch1_letter'));
      expect(
        gp.storyProgress.chosen['ps_ch1_letter'],
        isNotNull,
        reason: '分支选择必须被记录',
      );
    });

    test('叙事里出现"你做了什么"（consequence），而不是只有情境', () async {
      final gp = await makeStoryGame();
      final step = findStoryStep('ps', 'ps_ch1', 'ps_ch1_letter')!;
      final choice = step.choices.first;

      await gp.processChoice(
        GameChoice(text: choice.text, action: firstAction(gp)),
      );

      // consequence 里的关键片段应能在叙事里找到（取前 12 字做探测，
      // 避免标点差异导致断言脆弱）
      final probe = choice.consequence.substring(0, 12);
      expect(
        gp.currentNarrative,
        contains(probe),
        reason: '选完之后读不到自己的行动，玩家会以为没生效',
      );
    });

    test('下一步的选项重新生成，且指向新的步', () async {
      final gp = await makeStoryGame();
      await gp.processChoice(GameChoice(text: 'x', action: firstAction(gp)));

      expect(gp.choices, isNotEmpty);
      final nextStep = _ch1Step(1);
      expect(gp.choices.length, nextStep.choices.length);
      for (final c in gp.choices) {
        final cmd = parseStoryCommand(c.action);
        expect(cmd, isNotNull);
        expect(
          cmd!.stepId,
          nextStep.id,
          reason: '选项必须指向当前步，否则点了会走错分支',
        );
      }
    });

    test('连点到底能一路走完第一章并进入第二章或结局', () async {
      final gp = await makeStoryGame();
      // 第一章共 6 步（收信/告知/预习/家访/回信/前夜）
      final ch1Steps = findStoryBook('ps')!
          .chapters
          .firstWhere((c) => c.id == 'ps_ch1')
          .steps
          .length;
      for (var i = 0; i < ch1Steps; i++) {
        if (gp.choices.isEmpty) break;
        final action = gp.choices.first.action;
        await gp.processChoice(GameChoice(text: 'x', action: action));
      }
      // 走完第一章后应换章
      expect(
        gp.storyProgress.isFinished || gp.storyProgress.chapterId != 'ps_ch1',
        isTrue,
        reason: '第一章走完必须换章或收束到结局，不能原地踏步',
      );
    });
  });

  group('C · 时间按章节节拍推进（不是关键词推断）', () {
    test('推进天数等于本步声明的 timeCostDays', () async {
      final gp = await makeStoryGame();
      final beforeDay = gp.worldState.time.absoluteDayIndex;

      await gp.processChoice(GameChoice(text: 'x', action: firstAction(gp)));

      // 进入的是第一章的第 2 步（随扩写变化，故按顺序取）
      final nextStep = _ch1Step(1);
      final delta = gp.worldState.time.absoluteDayIndex - beforeDay;
      expect(
        delta,
        nextStep.timeCostDays,
        reason: '时间必须按 nextStep.timeCostDays 推进，'
            '而不是被行动关键词猜出来',
      );
    });

    test('同一步重复进入时时间不会被推两遍（关键词推断已让位）', () async {
      final gp = await makeStoryGame();
      final step1 = _ch1Step(1);
      final before = gp.worldState.time.absoluteDayIndex;
      // 第一步默认选第一个分支 → 落到第一章的第 2 步
      await gp.processChoice(GameChoice(text: 'x', action: firstAction(gp)));
      final afterFirst = gp.worldState.time.absoluteDayIndex;
      expect(afterFirst - before, step1.timeCostDays);
      // 再走一步，增量应等于**下一步**的步长（而不是叠加）
      final step2 = _ch1Step(2);
      await gp.processChoice(GameChoice(text: 'x', action: firstAction(gp)));
      final afterSecond = gp.worldState.time.absoluteDayIndex;
      expect(afterSecond - afterFirst, step2.timeCostDays);
    });

    test('worldState 的旧字段与时钟同步（month 字符串等）', () async {
      final gp = await makeStoryGame();
      await gp.processChoice(GameChoice(text: 'x', action: firstAction(gp)));
      final t = gp.worldState.time;
      expect(
        gp.worldState.month,
        GameTime.months[t.month - 1],
        reason: 'month 字符串必须跟着 time 走（fastForwardDays 内部同步）',
      );
      expect(gp.worldState.dayOfMonth, t.day);
    });

    test('回合收尾未丢：NPC/影响力/近期回合都在结算', () async {
      final gp = await makeStoryGame();
      await gp.processChoice(GameChoice(text: 'x', action: firstAction(gp)));
      expect(
        gp.recentTurns,
        isNotEmpty,
        reason: '近期回合必须落库（_finalizeTurn 共用）',
      );
    });
  });

  group('D · 效果落到玩家与记忆', () {
    test('选「先回房间拆信」→ 获得信物 + 情报 flag', () async {
      final gp = await makeStoryGame();
      final step = findStoryStep('ps', 'ps_ch1', 'ps_ch1_letter')!;
      final choice = step.choices.firstWhere((c) => c.id == 'read_in_room');

      await gp.processChoice(
        GameChoice(text: choice.text, action: encodeStoryAction(step.id, choice.id)),
      );

      expect(gp.storyProgress.flags, contains('ps_read_letter_first'));
      expect(gp.storyProgress.knowledge, contains('knows_hogwarts_acceptance'));
      expect(
        gp.player!.inventory.any((i) => i.name == '霍格沃茨的来信'),
        isTrue,
        reason: '道具应进背包（剧情白名单物品按中文名落库）',
      );
    });

    test('两回合累计的数值效果进 effects（供结局判定）', () async {
      final gp = await makeStoryGame();
      // 第一步选"直接问养父母"：spirit -3
      final s1 = findStoryStep('ps', 'ps_ch1', 'ps_ch1_letter')!;
      await gp.processChoice(
        GameChoice(
          text: 'x',
          action: encodeStoryAction(s1.id, 'ask_family'),
        ),
      );
      expect(gp.storyProgress.effects['spirit'], -3);
      final afterFirst = gp.storyProgress.effects['spirit']!;

      // 第二步：走"当前所在的那一步"的第一个分支。
      // 【为什么不写死 ps_ch1_tell】第一章的第二步会随扩写变化（现在是
      // ps_ch1_window）。测试要验的是"效果累加"这一性质，所以应当顺着
      // 游标走，而不是钉死某一步的 id。
      final s2 = _ch1Step(1);
      final c2 = s2.choices.first;
      final spirit2 = c2.effect.spirit;
      final rep2 = c2.effect.reputation;
      await gp.processChoice(
        GameChoice(
          text: 'x',
          action: encodeStoryAction(s2.id, c2.id),
        ),
      );
      expect(
        gp.storyProgress.effects['spirit'],
        afterFirst + spirit2,
        reason: '效果必须**累加**，否则结局判定会随剧情推进漂移',
      );
      // 【口径】effects 只记录"非零增量"，零值不进表。所以要按 rep2 是否为 0
      // 分别断言，而不是直接写死一个数字。
      if (rep2 == 0) {
        expect(
          gp.storyProgress.effects['reputation'],
          anyOf(isNull, 0),
          reason: '本步没有声望效果时，不应凭空多出一条声望记录',
        );
      } else {
        expect(gp.storyProgress.effects['reputation'], rep2);
      }
    });

    test('获得情报时写进长期记忆的 T0 层（离线少有的沉淀机会）', () async {
      final gp = await makeStoryGame();
      final s1 = findStoryStep('ps', 'ps_ch1', 'ps_ch1_letter')!;
      await gp.processChoice(
        GameChoice(
          text: 'x',
          action: encodeStoryAction(s1.id, 'read_in_room'),
        ),
      );
      final facts = gp.memory.keyFacts.map((f) => f.id).toList();
      expect(
        facts,
        contains('story_knows_hogwarts_acceptance'),
        reason: '剧情情报必须沉淀到长期记忆，否则离线长局记忆全空转',
      );
    });
  });

  group('E · 健壮性（自由行动与失效分支）', () {
    // 【行为变更说明】自由输入以前是"空效果推进到下一步"，于是玩家在剧情步
    // 之间说一句话就会**白白花掉一个剧情步**——600+ 步的长局里这是实打实的
    // 损失。现在改为"原地插话"：游标不动、效果不落、原选项重发。
    // 下面三条断言从"必须推进"翻转为"必须不推进"。

    test('自由输入不卡死：原地插话，游标不动且原选项重发', () async {
      final gp = await makeStoryGame();
      final beforeStep = gp.storyProgress.stepId;
      final beforeChoices = gp.choices.map((c) => c.action).toList();

      await gp.processChoice(
        GameChoice(text: '四处看看', action: '四处看看'),
      );

      expect(
        gp.storyProgress.stepId,
        beforeStep,
        reason: '插话不该消耗剧情步——否则长局会被闲聊啃掉一大块',
      );
      expect(gp.currentNarrative, contains('四处看看'));
      expect(gp.choices, isNotEmpty, reason: '插话后必须仍能继续推进剧情');
      expect(
        gp.choices.map((c) => c.action).toList(),
        beforeChoices,
        reason: '插话要重发当前步的原选项，玩家不能因此失去出口',
      );
      expect(gp.error, isNull);
    });

    test('伪造的分支 id 不崩，降级为原地插话', () async {
      final gp = await makeStoryGame();
      await gp.processChoice(
        GameChoice(
          text: 'x',
          action: encodeStoryAction('ps_ch1_letter', '不存在的分支'),
        ),
      );
      // 分支无效 → 视为插话：不推进、不报错、仍给出当前步的选项。
      expect(gp.storyProgress.stepId, 'ps_ch1_letter');
      expect(gp.error, isNull);
      expect(gp.choices, isNotEmpty);
    });

    test('stepId 对不上的旧 action 降级为原地插话（读档后 action 失效）', () async {
      final gp = await makeStoryGame();
      await gp.processChoice(
        GameChoice(
          text: 'x',
          // 故意用上一章的 stepId
          action: encodeStoryAction('ps_ch0_不存在', 'a'),
        ),
      );
      expect(gp.storyProgress.stepId, 'ps_ch1_letter');
      expect(gp.error, isNull);
      expect(gp.choices, isNotEmpty);
    });

    test('剧情游标指向不存在的步时重置到首步，而不是卡死', () async {
      final gp = await makeStoryGame();
      gp.storyProgress = gp.storyProgress.copyWith(
        chapterId: 'ps_ch1',
        stepId: 'ps_ch1_已经删掉了',
      );
      await gp.processChoice(GameChoice(text: 'x', action: '随便走走'));
      expect(
        gp.storyProgress.stepId,
        isNot('ps_ch1_已经删掉了'),
        reason: '游标失效必须自愈',
      );
    });
  });

  group('F · 离线红线', () {
    test('整章跑完 apiCalls 仍为 0（全程 0 AI 调用）', () async {
      final gp = await makeStoryGame();
      for (var i = 0; i < 3 && gp.choices.isNotEmpty; i++) {
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }
      expect(gp.apiCalls, 0, reason: '剧情模式绝不能消耗 AI 额度');
      expect(gp.error, isNull);
    });
  });

  group('G · 沙盒路径不受影响', () {
    test('offlineQuickMode 但未进入剧情模式时，走的仍是沙盒兜底叙事', () async {
      // 不调 enterStoryModeForTest —— 这是"老存档/沙盒玩家"的路径
      SharedPreferences.setMockInitialValues({});
      final gp = await makeGame(offlineQuickMode: true);
      expect(gp.storyProgress.active, isFalse);

      await gp.processChoice(const GameChoice(text: '四处看看', action: '四处看看'));
      expect(gp.storyProgress.active, isFalse, reason: '沙盒模式不该被带进剧情');
      expect(gp.choices, isNotEmpty);
    });

    test('沙盒模式的选项不是剧情编码（两条路径互不污染）', () async {
      SharedPreferences.setMockInitialValues({});
      final gp = await makeGame(offlineQuickMode: true);
      await gp.processChoice(const GameChoice(text: '四处看看', action: '四处看看'));
      for (final c in gp.choices) {
        expect(
          isStoryAction(c.action),
          isFalse,
          reason: '沙盒选项不该带剧情编码：${c.action}',
        );
      }
    });
  });

  // ================================================================
  // H · 剧情 → 项目各功能系统的接线（v2）
  // ================================================================
  //
  // 【为什么单独一组】这一整条链路此前是**断的**，而且没有任何测试覆盖它——
  // 上游 `_finalizeTurn` 把 `@@story:<stepId>:<choiceId>@@` 这个机器编码
  // 直接喂给 `updatePlayerImpactScore(action)`，那里判的是
  // `action.contains('哈利')` / `contains('密室')`，对编码串**永远为假**。
  // 于是玩家在剧情里跟原著角色互动了几十次，影响力分数里一次都没算过。
  //
  // 【为什么原来的测试没抓到】F 组的"回合收尾未丢"只断言了 `recentTurns`，
  // 没有断言影响力真的动过——测试写成了"函数被调用了"，而不是"结果对"。
  // 这组测的是**结果**。
  group('H · 剧情与项目各功能系统的接线', () {
    test('剧情行动的中文语义进了影响力判定（不再吃机器编码）', () async {
      final gp = await makeStoryGame();
      final before = gp.worldState.playerImpactScore;

      // 第一章第一步选"直接问养父母"——选项文案与 consequence 都是中文行动句。
      final step = findStoryStep('ps', 'ps_ch1', 'ps_ch1_letter')!;
      final choice = step.choices.first;
      await gp.processChoice(
        GameChoice(
          text: choice.text,
          action: encodeStoryAction(step.id, choice.id),
        ),
      );

      expect(
        gp.worldState.playerImpactScore,
        greaterThan(before),
        reason: '只要玩家做了选择，影响力就必须增长（每回合基础 +0.003）',
      );
    });

    test('剧情里与原著角色的互动会被影响力系统看见', () async {
      // 直接调收尾函数，喂一条含原著角色名的**语义**字符串，
      // 与喂机器编码的旧行为对照——这是本组要钉死的差异。
      //
      // 【为什么必须写全名】影响力系统的判定是 `action.contains(npc.name)`，
      // 而注册表里的名字是**全名**（`哈利·波特`、`赫敏·格兰杰`），不是昵称。
      // 写"哈利"命中不了——这也解释了为什么剧情文本里若只写昵称，
      // 加成同样拿不到。内容层要吃到这条增益，台词里就得出现接近全名的写法。
      final gp = await makeStoryGame();

      final baseline = gp.worldState.playerImpactScore;
      gp.updatePlayerImpactScore('@@story:ps_ch1_letter:read_in_room@@');
      final encoded = gp.worldState.playerImpactScore - baseline;

      final beforeSemantic = gp.worldState.playerImpactScore;
      gp.updatePlayerImpactScore('你和赫敏·格兰杰一起在图书馆复习了变形术，顺路去看了哈利·波特');
      final semantic = gp.worldState.playerImpactScore - beforeSemantic;

      expect(
        encoded,
        closeTo(0.003, 1e-9),
        reason: '机器编码命不中任何关键词，只拿每回合基础分',
      );
      expect(
        semantic,
        greaterThan(encoded),
        reason: '语义串提到原著角色应比机器编码加更多分——'
            '这正是修复前一直拿不到的增益',
      );
    });

    test('StoryEffect 的新字段确实写进了长期记忆与委托', () async {
      final gp = await makeStoryGame();
      final step = findStoryStep('ps', 'ps_ch1', 'ps_ch1_letter')!;

      // 构造一个"什么接线都拉满"的效果，直接走结算路径。
      const probe = StoryEffect(
        openLoops: ['probe_loop|一封没写清楚的信到底想说什么'],
        addWorldEvents: ['探测事件|这是一条用于验证接线的世界大事'],
        worldEventImportance: 9,
      );
      gp.applyStoryEffectForTest(probe);

      expect(
        gp.memory.openLoops.any((r) => r.id == 'probe_loop' && r.status == 'open'),
        isTrue,
        reason: 'openLoops 必须落进 T1 未完结事项',
      );
      expect(
        gp.memory.worldEvents.any((r) => r.id == 'story_探测事件'),
        isTrue,
        reason: 'addWorldEvents 必须落进 T3 世界大事层',
      );
      expect(
        gp.memory.keyFacts.isNotEmpty || gp.memory.worldEvents.isNotEmpty,
        isTrue,
        reason: '长期记忆不能为空——离线长局的沉淀入口',
      );
      // 保证探针没污染剧情游标。
      expect(gp.storyProgress.stepId, step.id);
    });

    test('closeLoops 能把开过的悬念了结掉', () async {
      final gp = await makeStoryGame();
      gp.applyStoryEffectForTest(
        const StoryEffect(openLoops: ['probe_close|先开一个待会儿要关的悬念']),
      );
      expect(
        gp.memory.openLoops.firstWhere((r) => r.id == 'probe_close').status,
        'open',
      );

      gp.applyStoryEffectForTest(const StoryEffect(closeLoops: ['probe_close']));
      expect(
        gp.memory.openLoops.firstWhere((r) => r.id == 'probe_close').status,
        'done',
        reason: 'closeLoops 必须把悬念标成已了结',
      );
    });

    test('关闭不存在的悬念不报错（内容层改 id 不该崩）', () async {
      final gp = await makeStoryGame();
      expect(
        () => gp.applyStoryEffectForTest(
          const StoryEffect(closeLoops: ['根本不存在_loop']),
        ),
        returnsNormally,
      );
    });

    test('精力/饱食进剧情效果链（体力系统不再是法外之地）', () async {
      final gp = await makeStoryGame();
      gp.player!.energy = 50;
      gp.player!.satiety = 50;

      gp.applyStoryEffectForTest(const StoryEffect(energy: -20, satiety: 10));

      expect(gp.player!.energy, 30);
      expect(gp.player!.satiety, 60);
    });

    test('解锁 CG 走统一入口且幂等（重复解锁不重复计数）', () async {
      final gp = await makeStoryGame();
      final before = gp.player!.cgRecords.length;

      gp.applyStoryEffectForTest(const StoryEffect(unlockCgs: ['CG-002']));
      final once = gp.player!.cgRecords.length;

      gp.applyStoryEffectForTest(const StoryEffect(unlockCgs: ['CG-002']));
      expect(
        gp.player!.cgRecords.length,
        once,
        reason: 'unlockCG 内部按 cgRecords 去重，重复解锁必须幂等',
      );
      expect(once, greaterThanOrEqualTo(before));
      expect(gp.player!.cgRecords.containsKey('CG-002'), isTrue);
    });

    test('「引用条例」只在玩家真的比对过教育令之后才出现', () async {
      // 【这条测的是"条件选项真的接进了游戏"，不是"过滤函数对不对"】
      // 过滤函数本身在 story_data_test 里已单测；这里验证的是：
      // 运行时生成选项列表时，确实把 storyProgress.knowledge 传了下去。
      final gp = await makeStoryGame();
      final step = findStoryStep('ootp', 'ootp_ch4', 'ootp_ch4_raid')!;

      // ① 没有情报时：看不到这条出路
      final before = availableStoryChoices(
        step,
        gp.storyProgress.flags.toSet(),
        knowledge: gp.storyProgress.knowledge.toSet(),
        reputation: gp.player!.wizardingReputation,
      ).map((c) => c.id);
      expect(
        before,
        isNot(contains('cite_the_rules')),
        reason: '没做过功课的人不该看到这条选项',
      );

      // ② 补上那条情报后再看：出现了
      gp.applyStoryEffectForTest(
        const StoryEffect(addKnowledge: ['ootp_edict_contradictions']),
      );
      final after = availableStoryChoices(
        step,
        gp.storyProgress.flags.toSet(),
        knowledge: gp.storyProgress.knowledge.toSet(),
        reputation: gp.player!.wizardingReputation,
      ).map((c) => c.id);
      expect(
        after,
        contains('cite_the_rules'),
        reason: '比对过教育令条款之后，这条出路应当解锁',
      );
    });

    test('替大家说话需要校内声望够高（声望门槛真的生效）', () async {
      final gp = await makeStoryGame();
      final step =
          findStoryStep('ootp', 'ootp_ch7', 'ootp_ch7_accounting')!;
      final flags = gp.storyProgress.flags.toSet();
      final knowledge = gp.storyProgress.knowledge.toSet();

      // 声望压到低位 → 这条选项不可见
      gp.player!.playerReputation.academic = 0;
      gp.player!.playerReputation.social = 0;
      gp.player!.playerReputation.combat = 0;
      gp.player!.playerReputation.moral = 0;
      gp.player!.playerReputation.leadership = 0;
      final low = availableStoryChoices(
        step,
        flags,
        knowledge: knowledge,
        reputation: gp.player!.wizardingReputation,
      ).map((c) => c.id);
      expect(low, isNot(contains('speak_for_group')));

      // 声望拉高 → 可见
      gp.player!.playerReputation.academic = 80;
      gp.player!.playerReputation.social = 80;
      gp.player!.playerReputation.combat = 80;
      gp.player!.playerReputation.moral = 80;
      gp.player!.playerReputation.leadership = 80;
      final high = availableStoryChoices(
        step,
        flags,
        knowledge: knowledge,
        reputation: gp.player!.wizardingReputation,
      ).map((c) => c.id);
      expect(high, contains('speak_for_group'));
    });
  });
}
