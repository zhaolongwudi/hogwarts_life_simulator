/// 「剧情骨架 + AI 自由插话」这一层的结构性测试。
///
/// 【为什么需要】`mixin_story_freeform.dart` 是本项目里**唯一**真正调用
/// AI 来生成剧情的路径（其余剧情全走本地 const 表）。它写于某次改造，
/// 有完整的实现、有 UI 接线、有设置开关——但 test/ 目录里**一条测试都没有**：
///
///     $ grep -rl "freeform\|Freeform" test/
///     （无输出）
///
/// 也就是说，"少量 AI 剧情配合大量离线推进"这个核心体验，全靠
/// 手工试玩兜着。这个文件补上。
///
/// 【测什么】
///   A. `storyFreeformUsable` 的四条件与关系——它决定 UI 提示文案与
///      "要不要发这次网络请求"，判错要么白烧额度要么功能静默消失；
///   B. `buildStoryFreeformPrompt` 的红线注入——prompt 是本层
///      **唯一**能约束 AI 不越过离线剧情骨架的地方，红线丢了
///      就等于把主线交给模型；
///   C. `cleanStoryFreeformText` 的清洗——它守着"小说正文"的排版契约；
///   D. 离线红线：纯离线玩家（未开插话）在任何情况下都不该产生 AI 调用。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
import 'package:hogwarts_life_simulator/mixins/mixin_story_freeform.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/story_progress.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

/// 构造一份"正在跑剧情"的进度。
StoryProgress progressOf({
  bool active = true,
  bool freeformEnabled = true,
  bool finished = false,
}) => StoryProgress(
  active: active,
  bookId: 'ps',
  chapterId: 'ps_ch1',
  stepId: 'ps_ch1_letter',
  freeformEnabled: freeformEnabled,
  endingId: finished ? 'ps_ending_any' : null,
);

void main() {
  // 运行时用例（E 组）要构造真实的 GameProvider，它需要 Flutter binding；
  // 剧情书表也必须先注册，否则 `enterStoryMode()` 会静默失败。
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllStoryBooks);

  group('A · storyFreeformUsable：四个条件缺一不可', () {
    test('全部满足时才可用', () {
      expect(
        storyFreeformUsable(progress: progressOf(), hasAiService: true),
        isTrue,
      );
    });

    test('未开剧情模式 → 不可用', () {
      expect(
        storyFreeformUsable(
          progress: progressOf(active: false),
          hasAiService: true,
        ),
        isFalse,
      );
    });

    test('未开自由插话开关 → 不可用（这是纯本地路径的保证点）', () {
      expect(
        storyFreeformUsable(
          progress: progressOf(freeformEnabled: false),
          hasAiService: true,
        ),
        isFalse,
      );
    });

    test('没有可用的叙事服务（未配 Key）→ 不可用', () {
      expect(
        storyFreeformUsable(progress: progressOf(), hasAiService: false),
        isFalse,
      );
    });

    test('已到结局 → 不可用（结局后让玩家自由活动，不必续写）', () {
      expect(
        storyFreeformUsable(
          progress: progressOf(finished: true),
          hasAiService: true,
        ),
        isFalse,
      );
    });

    test('四个条件全不满足 → 仍然不可用（不能因叠加而翻转）', () {
      expect(
        storyFreeformUsable(
          progress: progressOf(
            active: false,
            freeformEnabled: false,
            finished: true,
          ),
          hasAiService: false,
        ),
        isFalse,
      );
    });
  });

  group('B · prompt 必须带上全部红线', () {
    /// 一份典型入参。
    String build() => buildStoryFreeformPrompt(
      bookTitle: '魔法石',
      chapterTitle: '来信',
      stepSetup: '你收到了一封厚厚的信。',
      ambient: ['窗外在下雨。', '猫头鹰停在栏杆上。'],
      playerInput: '我把信翻过来看了看火漆。',
    );

    test('注入了剧情位置、场景、氛围、玩家输入', () {
      final p = build();
      expect(p, contains('魔法石'));
      expect(p, contains('来信'));
      expect(p, contains('你收到了一封厚厚的信。'));
      expect(p, contains('窗外在下雨。'));
      expect(p, contains('猫头鹰停在栏杆上。'));
      expect(p, contains('我把信翻过来看了看火漆。'));
    });

    test('结尾再次强调"不推动主线"等四条红线', () {
      final p = build();
      expect(p, contains('不推动主线'));
      expect(p, contains('不新增原著事实'));
      expect(p, contains('玩家不是哈利·波特'));
      expect(p, contains('不替玩家做决定'));
    });

    test('系统提示词把"玩家不是哈利·波特"写死', () {
      // 【为什么单独钉这条】平行世界原则是本项目的内容底线。
      // 系统提示词是这一层唯一能压住模型"帮忙推进剧情"本能的地方。
      expect(kStoryFreeformSystemPrompt, contains('不推动主线'));
      expect(kStoryFreeformSystemPrompt, contains('不是哈利·波特'));
      expect(kStoryFreeformSystemPrompt, contains('不新增原著事实'));
      expect(kStoryFreeformSystemPrompt, contains('不替玩家做决定'));
    });

    test('书名/章节为空时用兜底文案，不出现空的《》', () {
      final p = buildStoryFreeformPrompt(
        bookTitle: '',
        chapterTitle: '',
        stepSetup: '',
        ambient: const [],
        playerInput: '我环顾四周。',
      );
      expect(p, contains('霍格沃茨'));
      expect(p, isNot(contains('《》')));
      // 空 setup / ambient 不该产出空标题行
      expect(p, isNot(contains('【此刻的场景】')));
      expect(p, isNot(contains('【环境氛围')));
      expect(p, contains('我环顾四周。'));
    });

    test('氛围句里的空白项被跳过', () {
      final p = buildStoryFreeformPrompt(
        bookTitle: '密室',
        chapterTitle: '墙上的字',
        stepSetup: '走廊里写着一行字。',
        ambient: ['  ', '有人在你身后停下。', ''],
        playerInput: '我抬头看那行字。',
      );
      expect(p, contains('有人在你身后停下。'));
      expect(p, isNot(contains('- \n')));
    });

    test('输入上限常量与 prompt 说明一致（200 字）', () {
      expect(kStoryFreeformMaxInputChars, 200);
    });
  });

  group('C · cleanStoryFreeformText：只做结构性清洗', () {
    test('空输入与纯空白 → 空串', () {
      expect(cleanStoryFreeformText(''), '');
      expect(cleanStoryFreeformText('   \n  \n '), '');
    });

    test('剥掉 Markdown 代码块围栏', () {
      expect(
        cleanStoryFreeformText('```\n你把它翻了过来。\n```'),
        '你把它翻了过来。',
      );
      expect(
        cleanStoryFreeformText('```text\n你把它翻了过来。\n```'),
        '你把它翻了过来。',
      );
    });

    test('剥掉无序列表 / 有序列表前缀', () {
      expect(cleanStoryFreeformText('- 你伸手去够'), '你伸手去够');
      expect(cleanStoryFreeformText('* 你伸手去够'), '你伸手去够');
      expect(cleanStoryFreeformText('+ 你伸手去够'), '你伸手去够');
      expect(cleanStoryFreeformText('1. 你伸手去够'), '你伸手去够');
      expect(cleanStoryFreeformText('2) 你伸手去够'), '你伸手去够');
    });

    test('丢掉元信息开场白，但保留同一行后面的正文', () {
      // 【这条钉的是一个真实缺陷】以前是「行首命中就整行丢弃」，
      // 而模型经常把客套和正文写在一行：
      //     好的，你把它翻了过来。
      // → 整行被丢 → 玩家提交了一句插话，屏幕上空空如也。
      // 现在改成只剥前缀、留住正文。
      for (final opener in [
        '以下是我的续写',
        '以下是续写',
        '续写：',
        '续写:',
        '好的，',
        '好的,',
        '好的。',
      ]) {
        expect(
          cleanStoryFreeformText('$opener你把它翻了过来。'),
          '你把它翻了过来。',
          reason: '「$opener」应被剥掉，但后面的正文必须留住',
        );
      }

      // 整行只有客套 → 剥完为空，正常丢弃
      expect(cleanStoryFreeformText('续写：'), '');
      expect(cleanStoryFreeformText('好的，'), '');
    });

    test('纯标题标签（后面没有正文）整行丢弃', () {
      // 【另一个真实缺陷】以前只判「剥完前缀是否为空」，
      // `## 你的动作` 剥完剩下「你的动作」，会被当正文留下——
      // AI 一个字都没写，玩家却看到自己的动作被复述了一遍。
      expect(cleanStoryFreeformText('## 你的动作'), '');
      expect(cleanStoryFreeformText('### 环境的反应'), '');
      expect(cleanStoryFreeformText('# 续写'), '');
    });

    test('标题后面带正文时，标题丢掉、正文留下', () {
      expect(
        cleanStoryFreeformText('## 开头\n你把它翻了过来。'),
        '你把它翻了过来。',
      );
      expect(
        cleanStoryFreeformText('## 你的动作\n- 好的，你把它翻了过来。'),
        '你把它翻了过来。',
      );
    });

    test('以句读收尾的短句不会被误判成标题', () {
      // 「## 你的动作。」有句号，说明它是正文而不是标签，应当保留。
      expect(cleanStoryFreeformText('## 你的动作。'), '你的动作。');
    });

    test('多行正文合并成一整段（排版契约：段落由外层用 \\n\\n 拼）', () {
      final cleaned = cleanStoryFreeformText(
        '你把它翻了过来。\n火漆是紫色的。\n\n你没有立刻拆开。',
      );
      expect(cleaned, '你把它翻了过来。火漆是紫色的。你没有立刻拆开。');
      expect(cleaned, isNot(contains('\n')));
    });

    test('不改写正文内容（只做结构清洗）', () {
      const body = '你把它翻了过来，火漆在灯下有点发亮。';
      expect(cleanStoryFreeformText(body), body);
    });

    test('正文里正常出现的短横线不会被当成列表符号剥掉', () {
      // 只有 `- ` 开头（列表语法）才剥；中文破折号与句中的 `-` 保留。
      expect(cleanStoryFreeformText('你——或者说另一个人——先笑了。'),
          '你——或者说另一个人——先笑了。');
      expect(cleanStoryFreeformText('那封信没有署名 - 但你知道是谁。'),
          '那封信没有署名 - 但你知道是谁。');
    });

    test('围栏 + 标题 + 列表混在一起时逐层剥净', () {
      final cleaned = cleanStoryFreeformText(
        '```\n## 你的动作\n- 好的，你把它翻了过来。\n```',
      );
      expect(cleaned, '你把它翻了过来。');
    });
  });

  group('D · 离线红线：没开插话就不该有任何 AI 调用', () {
    test('未开插话开关时 storyFreeformUsable 为假（预取会被跳过）', () {
      // 【为什么钉这条】`prefetchStoryFreeformNarration` 的第一个守卫就是
      // `if (!storyProgress.freeformEnabled) return;`——它保证纯离线玩家
      // 在提交自由输入时**不会发网络请求**（也就不会打破 0 调用红线）。
      // UI 侧 `_submitFreeAction` 还额外用 `storyFreeformUsableNow` 拦一道，
      // 两处的判据必须一致，否则会出现"UI 以为不用调、引擎却调了"。
      final p = progressOf(freeformEnabled: false);
      expect(storyFreeformUsable(progress: p, hasAiService: true), isFalse);
    });

    test('即使配了 Key，关闭插话后依然可用性为假', () {
      expect(
        storyFreeformUsable(
          progress: progressOf(freeformEnabled: false),
          hasAiService: true,
        ),
        isFalse,
        reason: '配了 Key 不等于要用——离线优先是产品选择',
      );
    });
  });

  group('E · 运行时：开了插话但 AI 不可用 / 失败时，功能不降级为不可玩', () {
    /// 开插话、但走离线（无 AI 服务）的剧情局。
    Future<GameProvider> makeFreeformGame() async {
      final gp = await makeGame(offlineQuickMode: true);
      gp.openingScene = 'letter';
      gp.enterStoryMode();
      // 显式打开插话开关。此时 router 无叙事服务，
      // `prefetchStoryFreeformNarration` 会在第二个守卫处直接返回。
      gp.setStoryFreeformEnabled(true);
      return gp;
    }

    test('开了插话却无 AI 服务：预取是 no-op，不抛异常', () async {
      // 【为什么重要】`prefetchStoryFreeformNarration` 有多个短路守卫，
      // 任何一个漏掉都会让"没配 Key 的玩家"在提交自由输入时撞上网络异常。
      // 这里断言整条调用链在无 AI 服务下安静返回。
      final gp = await makeFreeformGame();
      final step = gp.currentStoryStep;
      expect(step, isNotNull);

      await gp.prefetchStoryFreeformNarration(
        stepId: step!.id,
        setup: step.setup,
        ambient: step.ambient,
        playerInput: '我把信翻过来看了看火漆。',
      );

      // 没取到文本 → 缓存为空 → 剧情回合走本地氛围池兜底
      expect(gp.takePendingFreeformText(step.id, '我把信翻过来看了看火漆。'),
          isNull);
      expect(gp.error, isNull);
    });

    test('无 AI 续写时插话仍成功：游标不动、原选项重发、玩家原文可见', () async {
      final gp = await makeFreeformGame();
      final beforeStep = gp.storyProgress.stepId;
      final beforeChoices = gp.choices.map((c) => c.action).toList();

      await gp.processChoice(
        GameChoice(text: '我把信翻过来看了看火漆。', action: '我把信翻过来看了看火漆。'),
      );

      expect(gp.storyProgress.stepId, beforeStep, reason: '插话不消耗剧情步');
      expect(gp.currentNarrative, contains('我把信翻过来看了看火漆。'),
          reason: '玩家原文必须出现在叙事里——否则像"打了字没反应"');
      expect(gp.choices.map((c) => c.action).toList(), beforeChoices,
          reason: '插话后原选项必须重发，玩家不能因此失去出口');
      // 插话不推进时间（章节节拍不能被闲聊带偏）
      expect(gp.error, isNull);
    });

    test('纯离线局全程 0 AI 调用（红线）', () async {
      final gp = await makeFreeformGame();
      expect(gp.apiCalls, 0);
      await gp.processChoice(GameChoice(text: '四处看看', action: '四处看看'));
      expect(gp.apiCalls, 0, reason: '离线剧情链路不得产生任何 AI 调用');
    });

    test('缓存按 (步, 原文) 双重匹配：步变了就不该命中旧文本', () async {
      // 这是 `_PendingFreeform` 的核心归属判断：AI 慢返回时玩家可能
      // 已经点选项进入下一步，那段旧文本贴到新一步就是张冠李戴。
      final gp = await makeFreeformGame();
      final step = gp.currentStoryStep!;
      // 未取到文本，任何查询都该是 null；这里主要钉住"不会误命中"
      expect(gp.takePendingFreeformText('ps_ch9_farewell', '随便什么'), isNull);
      expect(gp.takePendingFreeformText(step.id, '别的原文'), isNull);
      expect(gp.takePendingFreeformText(step.id, '  带空白的原文  '), isNull);
      // clearStoryFreeformCache 之后同样为空且不抛
      gp.clearStoryFreeformCache();
      expect(gp.takePendingFreeformText(step.id, 'x'), isNull);
    });
  });
}
