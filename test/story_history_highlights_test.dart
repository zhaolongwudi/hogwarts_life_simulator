/// `pickStoryHistoryHighlights` —— 玩家历史摘要的结构性测试。
///
/// 【为什么需要】自由插话层原本是**无记忆**的：AI 只知道当前步的
/// `setup` + `ambient` + 玩家刚说的那句话。玩家写"我把上次那封信拿出来给他看"，
/// AI 不知道"那封信"是什么，只能含糊其辞。
///
/// 这个函数把玩家已有的长期养成资产（跨部继承的 `flags` / `knowledge` /
/// `chosen`）摘成自然语言喂进 prompt。它是**唯一**从"游戏状态"通往
/// "AI 输入"的通道，出错的方式全都很难看：
///
///   · 把 flag id 漏进去（`poa_evidence_handed`）→ 直接剧透，且对模型是噪声；
///   · 没有长度上限 → 683 个跨部 flag 全塞进去约 15000 字符，
///     把当前场景淹掉，AI 转头去写往事而不是写玩家刚做的动作；
///   · 排序不稳定 → Dart 的 `List.sort` 不稳定，
///     同一局面两次调用可能给出不同次序，AI 看到的因果时序随机漂移；
///   · 脏存档（stepId / choiceId 查不到）→ 一旦抛异常，
///     玩家的自由输入会连"本地氛围池兜底"都拿不到。
///
/// 【不测什么】不测 AI 实际生成效果（那要靠真调用，不可复现）。
/// 这里只钉住"注入了什么、注入了多少、以什么顺序"。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
import 'package:hogwarts_life_simulator/mixins/mixin_story_freeform.dart';
import 'package:hogwarts_life_simulator/models/story_progress.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

/// 一份指向固定步的进度的构造器。
StoryProgress progressAt({
  String bookId = 'ps',
  String chapterId = 'ps_ch1',
  String stepId = 'ps_ch1_letter',
  List<String> flags = const [],
  List<String> knowledge = const [],
  Map<String, String> chosen = const {},
}) => StoryProgress(
  active: true,
  bookId: bookId,
  chapterId: chapterId,
  stepId: stepId,
  flags: flags,
  knowledge: knowledge,
  chosen: chosen,
  freeformEnabled: true,
);

StoryStepDef? stepOf(String bookId, String chapterId, String stepId) =>
    findStoryStep(bookId, chapterId, stepId);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllStoryBooks);

  // ==============================================================
  // A · 空与退化输入
  // ==============================================================
  group('A · 空与退化输入：绝不抛异常，绝不凭空造内容', () {
    test('全新的进度 → 空列表', () {
      // 【为什么钉这条】开局第一步就是这个状态：手头 0 个 flag、
      // 0 条情报、0 次选择。此处的正确行为是"什么都不知道"，
      // 让 prompt 保持原样——而不是硬凑几句占位文本。
      final r = pickStoryHistoryHighlights(
        step: stepOf('ps', 'ps_ch1', 'ps_ch1_letter'),
        progress: progressAt(),
      );
      expect(r, isEmpty);
    });

    test('step 为 null 且无任何积累 → 空列表，不抛异常', () {
      final r = pickStoryHistoryHighlights(
        step: null,
        progress: progressAt(),
      );
      expect(r, isEmpty);
    });

    test('maxChars 为 0 → 空列表（预算耗尽即停）', () {
      final r = pickStoryHistoryHighlights(
        step: null,
        progress: progressAt(chosen: _oneRealChoice()),
        maxChars: 0,
      );
      expect(r, isEmpty);
    });

    test('chosen 里的 stepId 在表里查不到（脏存档）→ 跳过，不抛异常', () {
      final r = pickStoryHistoryHighlights(
        step: null,
        progress: progressAt(chosen: {'ps_ch1_不存在的一步': 'a1'}),
      );
      expect(r, isEmpty, reason: '查不到的步必须静默跳过');
    });

    test('chosen 里的 choiceId 在该步里不存在（脏存档）→ 跳过，不抛异常', () {
      final r = pickStoryHistoryHighlights(
        step: null,
        progress: progressAt(chosen: {'ps_ch1_letter': '不存在的选项'}),
      );
      expect(r, isEmpty, reason: '查不到的选项必须静默跳过');
    });
  });

  // ==============================================================
  // B · 分层与优先级
  // ==============================================================
  group('B · 分层：chosen 的 consequence 是主力素材', () {
    test('chosen 反查得到的是 consequence 原文', () {
      // 【为什么是 consequence 而不是选项 text】`text` 是"你要做什么"
      // （把攒了一个月的问题全问出来）；`consequence` 是"你做了什么、
      // 世界怎么回应"（你抄满了整整两页纸……）。后者才是叙事资产，
      // 也是让 AI 接得上前文的依据。
      final r = pickStoryHistoryHighlights(
        step: null,
        progress: progressAt(chosen: {'ps_ch1_letter': _firstChoiceId('ps_ch1_letter')}),
      );
      expect(r, isNotEmpty);
      expect(r.first, contains('你'), reason: 'consequence 是第二人称叙事');
      expect(
        r.first,
        isNot(contains('@@')),
        reason: '不能混进内部编码',
      );
    });

    test('chosen 的素材排在 flags 素材之前', () {
      // 分层顺序即质量顺序：Pass B（consequence）> Pass D（flag 兜底）。
      // 预算不够时先饿死低质量素材，而不是均匀截断。
      final r = pickStoryHistoryHighlights(
        step: null,
        progress: progressAt(
          chosen: {'ps_ch1_letter': _firstChoiceId('ps_ch1_letter')},
          flags: const ['这面墙记得你上次来过的样子'],
        ),
      );
      expect(r.length, greaterThanOrEqualTo(2));
      expect(r.first, isNot(contains('这面墙')), reason: 'consequence 优先');
      expect(r.last, contains('这面墙'), reason: 'flag 兜底排在最后');
    });

    test('knowledge 能进历史', () {
      final r = pickStoryHistoryHighlights(
        step: null,
        progress: progressAt(knowledge: const ['霍格沃茨特快在九又四分之三站台']),
      );
      expect(r, contains('霍格沃茨特快在九又四分之三站台'));
    });

    test('纯英文 id 形态的 knowledge 一律丢弃', () {
      // 【为什么这条最要紧】实测 `addKnowledge` 的 403 个词条**含中文的有 0 个**
      // （全是 `cos_archive_details` / `hbp_expelliarmus` 这类蛇形 id）。
      // 把它们喂给模型不只是噪声——id 的名字本身就在剧透：
      // `knows_hogwarts_acceptance` 直接告诉模型"玩家已被录取"。
      final r = pickStoryHistoryHighlights(
        step: null,
        progress: progressAt(knowledge: const [
          'knows_hogwarts_acceptance',
          'cos_archive_details',
          'hbp_expelliarmus',
        ]),
      );
      expect(r, isEmpty, reason: '英文 id 不得进入 prompt');
    });

    test('真正的中文情报能进历史', () {
      final r = pickStoryHistoryHighlights(
        step: null,
        progress: progressAt(knowledge: const ['你在站台上第一次听见了那个名字']),
      );
      expect(r, contains('你在站台上第一次听见了那个名字'));
    });

    test('纯 ASCII 的 flag id 一律丢弃', () {
      // 【为什么钉这条】flag id 形如 `ps_built_snowman`，本身就是剧透
      // （"建过雪人"这件事在哪个时间点被玩家知道，是有节奏的），
      // 而且对模型只是噪声，还白占预算。宁可少给，不可错给。
      final r = pickStoryHistoryHighlights(
        step: null,
        progress: progressAt(flags: const [
          'ps_built_snowman',
          'ootp_left_gifts',
          'hbp_seen_the_locket',
        ]),
      );
      expect(r, isEmpty);
    });

    test('结果里不含任何内部 id 字样（用真实进度）', () {
      // 【为什么用真实进度】手造的 id 列表只能证明"这条规则写了"，
      // 证明不了"真实数据里不会漏"。这里直接取表里的真实步，
      // 填上真实的 flag / 情报 / 选择，再断言输出里没有任何 `xx_yy` 形态。
      final book = findStoryBook('ps')!;
      final ch = book.chapters.first;
      final step = ch.steps.first;
      final cid = step.choices.first.id;

      final r = pickStoryHistoryHighlights(
        step: step,
        progress: progressAt(
          chapterId: ch.id,
          stepId: step.id,
          flags: book.chapters
              .expand((c) => c.steps)
              .map((s) => s.id)
              .take(5)
              .toList(),
          knowledge: const [
            'knows_hogwarts_acceptance',
            'knows_school_basics',
            '你在站台上第一次听见了那个名字',
          ],
          chosen: {step.id: cid},
        ),
      );

      final joined = r.join('\n');
      final idLike = RegExp(r'\b[a-z]{2,6}_[a-z0-9_]+\b');
      expect(
        idLike.hasMatch(joined),
        isFalse,
        reason: '输出里不得出现 `ps_xxx` 这类内部 id：\n$joined',
      );
      // 顺带确认"该留的留着"，避免把过滤写成"全丢"
      expect(joined, contains('你在站台上第一次听见了那个名字'));
    });

    test('Pass A：只有带门槛的选项才算"你的积累"', () {
      // 门槛选项的含义是"你现在能做这件事，是因为之前做过某件事"——
      // 这才是历史证据。无门槛选项是人人可见的通用出路，与历史无关。
      final gated = StoryChoiceDef(
        id: 'g',
        text: '拿出你藏了很久的那样东西',
        consequence: '你把它递了过去。',
        nextStepId: '',
        effect: const StoryEffect(),
        requireFlag: 'some_prior_flag',
      );
      final plain = StoryChoiceDef(
        id: 'p',
        text: '站在原地不动',
        consequence: '你什么也没做。',
        nextStepId: '',
        effect: const StoryEffect(),
      );
      final step = StoryStepDef(
        id: 'x',
        chapterId: 'x_ch1',
        setup: '一个假设出来的场景，长度足够通过校验。',
        choices: [plain, gated],
      );

      final r = pickStoryHistoryHighlights(step: step, progress: progressAt());
      expect(r, contains('拿出你藏了很久的那样东西'));
      expect(r, isNot(contains('站在原地不动')));
    });
  });

  // ==============================================================
  // C · 预算与截断
  // ==============================================================
  group('C · 预算与截断：prompt 不能被历史撑爆', () {
    test('长条目被截断且以省略号收尾', () {
      final long = '啊' * 300;
      final step = StoryStepDef(
        id: 'x',
        chapterId: 'x_ch1',
        setup: '一个假设出来的场景，长度足够通过校验。',
        choices: [
          StoryChoiceDef(
            id: 'g',
            text: long,
            consequence: '无关',
            nextStepId: '',
            effect: const StoryEffect(),
            requireFlag: 'f',
          ),
        ],
      );
      final r = pickStoryHistoryHighlights(step: step, progress: progressAt());
      expect(r, hasLength(1));
      expect(r.first.length, lessThanOrEqualTo(kStoryHistoryItemMaxChars + 1));
      expect(r.first.endsWith('…'), isTrue);
    });

    test('总字符数不超过预算', () {
      // 683 个跨部 flag 全塞进去约 15000 字符，会把 setup/ambient 淹掉。
      final step = StoryStepDef(
        id: 'x',
        chapterId: 'x_ch1',
        setup: '一个假设出来的场景，长度足够通过校验。',
        choices: [
          for (var i = 0; i < 50; i++)
            StoryChoiceDef(
              id: 'g$i',
              text: '第 $i 条很久以前的经历，' * 5,
              consequence: '无关',
              nextStepId: '',
              effect: const StoryEffect(),
              requireFlag: 'f',
            ),
        ],
      );
      final r = pickStoryHistoryHighlights(
        step: step,
        progress: progressAt(),
        maxChars: 600,
      );
      expect(r.join().length, lessThanOrEqualTo(600));
      expect(r, isNotEmpty, reason: '至少要能装下第一条');
    });

    test('同一输入跑两次结果完全相同（防 List.sort 不稳定）', () {
      // 【为什么必须钉这条】Dart 的 `List.sort` 是不稳定排序
      // （项目已在 `long_term_memory.dart` 里记过这个坑）。
      // 截断发生在"排序之后、按序 append 到预算耗尽为止"，
      // 所以一旦次序漂移，被截掉的是哪几条也会跟着漂——
      // 同一个存档两次插话，AI 看到的历史可能不一样。
      final chosen = <String, String>{};
      final book = findStoryBook('ps')!;
      for (final ch in book.chapters.take(3)) {
        for (final s in ch.steps.take(3)) {
          if (s.choices.isNotEmpty) {
            chosen[s.id] = s.choices.first.id;
          }
        }
      }
      final p = progressAt(
        flags: const ['一句中文的兜底', '另一句中文的兜底'],
        knowledge: const ['一条情报'],
        chosen: chosen,
      );

      final a = pickStoryHistoryHighlights(step: null, progress: p);
      final b = pickStoryHistoryHighlights(step: null, progress: p);
      expect(b, equals(a), reason: '两次调用必须逐字相同');
    });

    test('重复文本只出现一次', () {
      final step = StoryStepDef(
        id: 'x',
        chapterId: 'x_ch1',
        setup: '一个假设出来的场景，长度足够通过校验。',
        choices: [
          for (var i = 0; i < 3; i++)
            StoryChoiceDef(
              id: 'g$i',
              text: '同一句重复的经历',
              consequence: '无关',
              nextStepId: '',
              effect: const StoryEffect(),
              requireFlag: 'f$i',
            ),
        ],
      );
      final r = pickStoryHistoryHighlights(step: step, progress: progressAt());
      expect(r.where((e) => e == '同一句重复的经历').length, 1);
    });

    test('空白的 knowledge / flags 项被丢弃，不占预算', () {
      final r = pickStoryHistoryHighlights(
        step: null,
        progress: progressAt(
          knowledge: const ['', '   ', '真正的一条情报'],
          flags: const ['', '  '],
        ),
      );
      expect(r, equals(['真正的一条情报']));
    });

    test('全库知识/flag id 扫一遍：一个都不该漏进来', () {
      // 【为什么做全库扫描而不是抽样】上面几条都是"我挑几个 id 试试"，
      // 只能证明规则写了。这里把 const 表里**真实存在的全部** flag 与
      // knowledge id 一次性灌进去，断言输出为空——覆盖的是数据，
      // 不是我以为的数据。将来谁往表里加了含中文的 id，
      // 这条会亮，而不是静默混进 prompt。
      final ids = <String>{};
      for (final b in kStoryBooks.values) {
        for (final c in b.chapters) {
          for (final s in c.steps) {
            for (final ch in s.choices) {
              if (ch.requireFlag != null) ids.add(ch.requireFlag!);
              ids.addAll(ch.requireAllFlags);
              ids.addAll(ch.requireAnyFlags);
              ids.addAll(ch.requireKnowledge);
              if (ch.hideIfFlag != null) ids.add(ch.hideIfFlag!);
              ids.addAll(ch.effect.setFlags);
              ids.addAll(ch.effect.addKnowledge);
            }
          }
        }
      }
      expect(ids.length, greaterThan(500), reason: '前置条件：真的捞到了全量 id');

      final r = pickStoryHistoryHighlights(
        step: null,
        progress: progressAt(
          flags: ids.toList(),
          knowledge: ids.toList(),
        ),
      );
      expect(
        r,
        isEmpty,
        reason: '全库 ${ids.length} 个内部 id 里不该有任何一个进 prompt，'
            '实际漏进来的是：$r',
      );
    });
  });

  // ==============================================================
  // D · prompt 集成
  // ==============================================================
  group('D · prompt 集成：默认参数下输出逐字节不变', () {
    String build({List<String> history = const []}) => buildStoryFreeformPrompt(
      bookTitle: '魔法石',
      chapterTitle: '第一章',
      stepSetup: '你坐在窗边，手里捏着那封信。',
      ambient: const ['雨点敲着屋顶'],
      playerInput: '我把信翻过来看了看火漆。',
      historyHighlights: history,
    );

    test('有历史时 prompt 含历史段落', () {
      final p = build(history: const ['你抄满了整整两页纸。']);
      expect(p, contains('【玩家此前已经历过的事'));
      expect(p, contains('- 你抄满了整整两页纸。'));
    });

    test('有历史时仍保留原有的场景/氛围/玩家输入三段', () {
      final p = build(history: const ['你抄满了整整两页纸。']);
      expect(p, contains('【此刻的场景】'));
      expect(p, contains('【环境氛围'));
      expect(p, contains('【玩家刚才做的事 / 说的话】'));
      expect(p, contains('我把信翻过来看了看火漆。'));
    });

    test('历史段落排在场景之后、氛围之前', () {
      // 顺序有实际意义：场景是"现在在哪"，历史是"怎么走到这里的"，
      // 氛围是"当下有什么"。把历史插在氛围之后，模型容易把它当成
      // 环境描写的一部分。
      final p = build(history: const ['一段往事。']);
      expect(
        p.indexOf('【此刻的场景】'),
        lessThan(p.indexOf('【玩家此前已经历过的事')),
      );
      expect(
        p.indexOf('【玩家此前已经历过的事'),
        lessThan(p.indexOf('【环境氛围')),
      );
    });

    test('history 为空（默认参数）→ 不出现历史段落', () {
      final p = build();
      expect(p, isNot(contains('此前已经历过的事')));
    });

    test('history 全是空白项 → 同样不出现历史段落', () {
      // 否则会留下一个空标题 + 零条列表，纯浪费 token 还让模型费解。
      final p = build(history: const ['', '   ']);
      expect(p, isNot(contains('此前已经历过的事')));
    });

    test('系统提示词含第 6 条红线：历史只加质感，不预告后续', () {
      // 【为什么必须有这条】给了模型历史背景，它未被约束时的本能是
      // 把背景"用起来"——写成"你后来才明白，那封信意味着……"。
      // 那就等于用注入的历史绕过本地剧情表，把后续剧透了。
      expect(kStoryFreeformSystemPrompt, contains('6.'));
      expect(kStoryFreeformSystemPrompt, contains('不预告后续'));
      expect(kStoryFreeformSystemPrompt, contains('不要复述'));
    });

    test('原有 5 条红线一条不少', () {
      for (final n in ['1.', '2.', '3.', '4.', '5.']) {
        expect(
          kStoryFreeformSystemPrompt.contains('\n$n'),
          isTrue,
          reason: '第 $n 条红线丢了',
        );
      }
    });
  });

  // ==============================================================
  // E · 离线红线：历史摘要不得改变"0 调用"保证
  // ==============================================================
  group('E · 离线红线', () {
    test('未开插话时预取是 no-op，全程 0 AI 调用', () async {
      // 【为什么这条最要紧】"大量离线推进 + 少量 AI 剧情"是产品的核心承诺。
      // 这次的改动往 prompt 里塞了新内容，一旦接线位置放错（例如把取历史
      // 摘要挪到守卫之前），纯离线玩家就会开始产生额外开销。
      final gp = await makeGame(offlineQuickMode: true);
      gp.openingScene = 'letter';
      gp.enterStoryMode();

      // 走几步，让进度里真的累积出可注入的历史（否则测不出东西）。
      for (var i = 0; i < 4; i++) {
        final cs = gp.choices;
        if (cs.isEmpty) break;
        await gp.processChoice(cs.first);
      }

      expect(gp.storyProgress.chosen, isNotEmpty, reason: '前置条件：已有历史可选');
      expect(gp.apiCalls, 0);

      final before = gp.apiCalls;
      final step = gp.currentStoryStep;
      if (step != null) {
        await gp.prefetchStoryFreeformNarration(
          stepId: step.id,
          setup: step.setup,
          ambient: step.ambient,
          playerInput: '我抬头看了看天花板。',
        );
      }
      expect(gp.apiCalls, before, reason: '未开插话的局不得产生任何 AI 调用');
    });

    test('开了插话但无叙事服务 → 仍是 0 调用', () async {
      final gp = await makeGame(offlineQuickMode: true);
      gp.openingScene = 'letter';
      gp.enterStoryMode();
      gp.setStoryFreeformEnabled(true);

      final step = gp.currentStoryStep!;
      await gp.prefetchStoryFreeformNarration(
        stepId: step.id,
        setup: step.setup,
        ambient: step.ambient,
        playerInput: '我抬头看了看天花板。',
      );
      expect(gp.apiCalls, 0, reason: '没配 Key 就不该发请求');
      expect(gp.error, isNull);
    });
  });
}

/// 取某步第一个选项的 id（真实表里的）。
String _firstChoiceId(String stepId) {
  final s = findStoryStepAnywhere('ps', stepId);
  if (s != null && s.choices.isNotEmpty) return s.choices.first.id;
  // 兜底：可能在别的书里
  for (final b in kStoryBooks.values) {
    for (final c in b.chapters) {
      for (final st in c.steps) {
        if (st.id == stepId && st.choices.isNotEmpty) return st.choices.first.id;
      }
    }
  }
  return 'a1';
}

/// 一条真实可反查出来的 `chosen`。
Map<String, String> _oneRealChoice() => {
  'ps_ch1_letter': _firstChoiceId('ps_ch1_letter'),
};
