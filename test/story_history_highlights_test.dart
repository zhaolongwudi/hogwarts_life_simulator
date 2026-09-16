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

    test('结果里不含任何 flag id 字样（用真实进度）', () {
      // 【为什么用真实进度】手造的 flag 列表只能证明"这条规则写了"，
      // 证明不了"真实数据里不会漏"。这里直接取表里的真实步，
      // 填上真实的 flag 与真实的选择，再断言输出里没有任何 `xx_yy` 形态。
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
          knowledge: const ['你在站台上第一次听见了那个名字'],
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
