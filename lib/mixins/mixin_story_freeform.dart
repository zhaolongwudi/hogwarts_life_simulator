/// 剧情自由插话（"剧情骨架 + AI 自由发挥"的 AI 侧）。
///
/// 【它解决什么问题】剧情模式（`mixin_narrative.dart` 的 `_runStoryTurn`）
/// 是完全本地的：原著主线由 `lib/data/story_data*.dart` 的 const 表驱动，
/// 全程 0 AI 调用，好处是免费、稳定、不跑题；代价是玩家**只有"点选项"
/// 一种交互**——不能多问一句、不能描述自己想做的动作。
///
/// 本 mixin 补上这一层：玩家在剧情步之间打的自由文本，若开关打开且 AI 可用，
/// 就让 AI **在原著框架内**续写一段细节。它是**增强而非依赖**：
///   · 开关默认关闭 → 老行为逐字节不变；
///   · 无 Key / 超时 / 异常 → 返回 null，剧情回合走本地氛围池兜底；
///   · 两种情况都**不移动剧情游标**，玩家一步都不会少。
///
/// 【为什么是"预先取回 + 就地读取"两段式】
/// `_runStoryTurn` 整条链路是**同步**的——它必须保证"点一次按钮 = 一个完整
/// 回合"的原子性（含 `autoSave` 的时序）。为一次可选的 AI 续写把整条链路
/// 改成异步，会波及 `_finalizeTurn` / `_settleAfterNarrative` / `autoSave`
/// 三处的时序契约，风险远大于收益。
/// 折中：UI 侧在玩家提交自由文本时**先 await** [prefetchStoryFreeformNarration]，
/// 把文本取回来放进 [_pendingFreeform]；随后同步的剧情回合只做
/// [takePendingFreeformText] 读取。
///
/// 【归属判断】缓存里连同 `stepId` + 玩家原文一起存，读取时两者都要匹配才
/// 命中。这是为了防止"玩家在上一步插话、AI 慢返回、玩家已经点选项进入
/// 下一步"时，那段陈旧文本被错贴到新一步上。
library;

import 'dart:async';

import '../models/story_progress.dart';
import '../providers/game_provider_base.dart';
import '../services/ai_router.dart';
import '../utils/debug_log.dart';

/// 一次已取回、待消费的 AI 续写。
class _PendingFreeform {
  final String stepId;
  final String playerInput;
  final String text;

  const _PendingFreeform({
    required this.stepId,
    required this.playerInput,
    required this.text,
  });
}

mixin GameStoryFreeformMixin on GameProviderBase {
  /// 已取回但还没被剧情回合消费的 AI 续写。
  ///
  /// 只留最近一条：玩家插话是串行的（一次点击一个回合），不需要队列。
  _PendingFreeform? _pendingFreeform;

  /// 是否正在为一个插话向 AI 取文本（UI 侧据此显示"续写中"）。
  bool storyFreeformLoading = false;

  /// 自由插话的文本长度上限（与输入框一致，防超长 prompt 烧额度）。
  static const int _maxInputChars = 200;

  /// AI 续写的字数上限。插话只是"加一段"，不该生成整章。
  static const int _maxOutputTokens = 600;

  /// 向 AI 取一段"在当前剧情步里续写玩家行动"的文本。
  ///
  /// 【什么时候不取】
  ///   · 开关关闭（`storyProgress.freeformEnabled == false`）→ 直接返回，
  ///     **不发任何网络请求**。这是"纯本地路径 0 AI 调用"的保证点；
  ///   · 没有可用的叙事服务（没配 Key）→ 同上；
  ///   · 已经到结局（`isFinished`）→ 结局后让玩家自由活动即可，不必续写。
  ///
  /// 【失败怎么办】全部异常吞掉并置空缓存。插话是可选增强，
  /// 让它把整局游戏搞崩是不可接受的。
  @override
  Future<void> prefetchStoryFreeformNarration({
    required String stepId,
    required String setup,
    required List<String> ambient,
    required String playerInput,
  }) async {
    _pendingFreeform = null;

    if (!storyProgress.freeformEnabled) return;
    if (storyProgress.isFinished) return;

    final input = playerInput.trim();
    if (input.isEmpty) return;

    final r = router;
    if (r == null || !r.hasNarrativeService) return;

    storyFreeformLoading = true;
    notifyListeners();
    try {
      final result = await r.chatComplete(
        scene: AiScene.narrative,
        prompt: buildStoryFreeformPrompt(
          bookTitle: _bookTitle(),
          chapterTitle: _chapterTitle(),
          stepSetup: setup,
          ambient: ambient,
          playerInput: input.length > _maxInputChars
              ? input.substring(0, _maxInputChars)
              : input,
        ),
        systemPrompt: kStoryFreeformSystemPrompt,
        temperature: 0.9,
        maxTokens: _maxOutputTokens,
      );
      final text = cleanStoryFreeformText(result.content);
      if (text.isNotEmpty) {
        _pendingFreeform = _PendingFreeform(
          stepId: stepId,
          playerInput: input,
          text: text,
        );
      }
    } catch (_) {
      // 静默失败：剧情回合会自动走本地氛围池兜底，玩家不会看到报错弹窗。
      _pendingFreeform = null;
    } finally {
      storyFreeformLoading = false;
      notifyListeners();
    }
  }

  @override
  String? takePendingFreeformText(String stepId, String playerInput) {
    final p = _pendingFreeform;
    if (p == null) return null;
    // 步与原文都必须匹配：AI 慢返回时玩家可能已经走到下一步了，
    // 那段文本属于上一步，贴到新一步上就是张冠李戴。
    if (p.stepId != stepId || p.playerInput != playerInput.trim()) {
      return null;
    }
    _pendingFreeform = null;
    return p.text;
  }

  @override
  void clearStoryFreeformCache() {
    _pendingFreeform = null;
    storyFreeformLoading = false;
  }

  String _bookTitle() {
    final b = findStoryBook(storyProgress.bookId);
    return b?.title ?? '';
  }

  String _chapterTitle() {
    final c = findStoryChapter(storyProgress.bookId, storyProgress.chapterId);
    return c?.title ?? '';
  }

  /// 该玩家当前是否处于"剧情 + AI 自由插话"可用状态。
  ///
  /// 【为什么判据抽成顶层纯函数】UI 要据此决定输入框下方的提示文案
  /// （"自由插话已开启，AI 会在原著框架内续写" vs "当前为纯本地剧情模式"）。
  /// 逻辑只能有一份，避免 UI 与引擎对"开没开"的理解漂移。
  bool get storyFreeformUsableNow =>
      storyFreeformUsable(
        progress: storyProgress,
        hasAiService: router?.hasNarrativeService ?? false,
      );

  /// 当前剧情步（UI 取 `setup`/`ambient` 去预取 AI 续写用）。
  /// 非剧情模式或游标失效时返回 null。
  StoryStepDef? get currentStoryStep {
    if (!storyProgress.active) return null;
    return findStoryStep(
      storyProgress.bookId,
      storyProgress.chapterId,
      storyProgress.stepId,
    );
  }

  /// 切换当前局的「剧情 + AI 自由发挥」开关。
  ///
  /// 【为什么清缓存】关掉开关后，上一句插话预取回来的文本如果还留着，
  /// 会在下一次插话时被消费——玩家看到"我明明关了 AI 还在续写"。
  void setStoryFreeformEnabled(bool value) {
    storyProgress = storyProgress.copyWith(freeformEnabled: value);
    clearStoryFreeformCache();
    debugLog('📖 剧情自由插话：${value ? '开启' : '关闭'}');
    notifyListeners();
    // 开关本身是长期偏好，落盘不算作弊——玩家不想每次开局重设。
    unawaited(autoSave());
  }
}

// ================================================================
// 纯函数（可单测）
// ================================================================

/// 自由插话的系统提示词。
///
/// 【为什么把红线写这么死】AI 未被约束时会本能地"帮忙推进剧情"：
/// 让它续写一句打听消息的话，它可能直接写出"你从教授口中得知密室的位置，
/// 决定今晚就去"——那就等于用 AI 绕过了本地剧情表，主线会跑偏，
/// 而且玩家会遇到"叙事说我已经行动了，界面还在等我选那一步"的撕裂。
/// 所以这里明确：**你只加氛围，不推动任何事**。
const String kStoryFreeformSystemPrompt =
    '你是一款《哈利·波特》世界观人生模拟游戏的叙事助手。'
    '玩家扮演的是霍格沃茨里一名**原创角色**（不是哈利·波特本人，'
    '不是任何原著主角），正沿着原著时间线经历七个学年。\n'
    '\n'
    '【你的唯一任务】玩家在当前剧情场景中做了一个自由小动作或说了一句话，'
    '请写出**这个动作在场景里引起的一小段细节反应**。\n'
    '\n'
    '【必须遵守的红线】\n'
    '1. 不推动主线。不要让人物做出改变局势的重大决定，不要给出新线索、'
    '新任务、新地点，不要"揭晓"任何谜团。原著大事按原著发生，'
    '不因玩家的这个动作而改变。\n'
    '2. 不新增原著事实。不要编造原著里没有的人物、地点、事件或物品。\n'
    '3. 玩家不是哈利·波特。不要写"你的伤疤""你是救世主""你额上的闪电"'
    '这类把玩家当成原著主角的句子。\n'
    '4. 不替玩家做决定。点到为止，把选择权留给玩家，'
    '结尾不要出现"你要不要……？"之外的推进性问题。\n'
    '5. 不抄录原著原文句子，只写氛围与细节。\n'
    '\n'
    '【篇幅】2~4 句，60~140 字。第二人称"你"。'
    '风格克制、具体、有生活质感，避免华丽辞藻与感叹号堆砌。\n'
    '【输出格式】只输出正文段落，不要标题、不要 Markdown、不要列表、'
    '不要任何括号注释或元信息。';

/// 构造自由插话的 prompt。
///
/// 拆成纯函数是为了可以在单测里直接断言"红线是否都注入了"，
/// 而不必真的发一次网络请求。
String buildStoryFreeformPrompt({
  required String bookTitle,
  required String chapterTitle,
  required String stepSetup,
  required List<String> ambient,
  required String playerInput,
}) {
  final buf = StringBuffer();
  buf.writeln('【当前剧情位置】'
      '${bookTitle.isEmpty ? '霍格沃茨' : '《$bookTitle》'}'
      '${chapterTitle.isEmpty ? '' : ' · $chapterTitle'}');
  if (stepSetup.trim().isNotEmpty) {
    buf.writeln();
    buf.writeln('【此刻的场景】');
    buf.writeln(stepSetup.trim());
  }
  if (ambient.isNotEmpty) {
    buf.writeln();
    buf.writeln('【环境氛围（可参考，不必逐句使用）】');
    for (final a in ambient) {
      if (a.trim().isNotEmpty) buf.writeln('- ${a.trim()}');
    }
  }
  buf.writeln();
  buf.writeln('【玩家刚才做的事 / 说的话】');
  buf.writeln(playerInput.trim());
  buf.writeln();
  buf.writeln('请写这个动作在场景里引起的一小段细节反应。'
      '记住：不推动主线、不新增原著事实、玩家不是哈利·波特、不替玩家做决定。'
      '只输出 2~4 句正文。');
  return buf.toString();
}

/// 清洗 AI 返回的插话文本。
///
/// 【为什么必须清洗】剧情叙事走的是"三层三明治"结构（情境/因果/氛围），
/// 段落由 `_composeStoryNarrative` 用 `\n\n` 拼接。如果 AI 返回里带
/// Markdown 标题、列表符号、或"以下是我的续写："这类元信息，它会原样
/// 混进小说式正文里，破坏排版（`story_text_renderer` 的段落分类会误判）。
/// 这里只做**结构性清洗**，不改写内容。
String cleanStoryFreeformText(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return '';

  // 去掉包裹的 Markdown 代码块围栏。
  if (s.startsWith('```')) {
    final firstNl = s.indexOf('\n');
    if (firstNl != -1) {
      s = s.substring(firstNl + 1);
    }
    final fence = s.lastIndexOf('```');
    if (fence != -1) s = s.substring(0, fence);
    s = s.trim();
  }

  final lines = <String>[];
  for (var raw in s.split('\n')) {
    var line = raw.trim();
    if (line.isEmpty) continue;
    // 【先判标题】必须在剥前缀之前判：`## 你的动作` 剥完只剩「你的动作」，
    // 与一句真实的短句在字面上完全一样，之后再想区分就不可能了。
    //
    // 判定口径：Markdown 标题在这份输出里**永远是标签**，不是正文——
    // 系统提示词明确要求「只输出正文段落，不要标题」。所以：
    //   · `## 你的动作`           → 标签，丢弃；
    //   · `## 你的动作\n- 正文`   → 标签，丢弃；
    //   · `## 你的动作。`          → 带句读，当正文留着（模型偶尔这么写）。
    final isHeading = _reHeading.hasMatch(line);
    if (isHeading) {
      line = line.replaceFirst(_reHeading, '').trim();
      if (line.isEmpty) continue;
      if (!_reSentenceEnd.hasMatch(line)) continue;
    }
    // 剥掉无序列表前缀（AI 很爱用它分点，但正文是散文）。
    line = line.replaceFirst(_reBullet, '').trim();
    // 剥掉有序列表前缀。
    line = line.replaceFirst(_reOrdered, '').trim();
    if (line.isEmpty) continue;
    // 剥掉常见的"元信息开场白"。
    line = _stripMetaOpener(line);
    if (line.isEmpty) continue;
    lines.add(line);
  }
  return lines.join('');
}

/// 判断一行是否以句读收尾（说明它是正文而不是标题标签）。
final RegExp _reSentenceEnd = RegExp(r'[。！？…”』」)]$');

/// 去掉行首的"元信息开场白"。
///
/// 【为什么是"前缀剥离"而不是"整行丢弃"】这些词是模型在正文前加的客套，
/// 但模型**经常把客套和正文写在同一行**：
///
///     好的，你把它翻了过来。
///     → 以前整行丢弃 → 玩家提交了一句插话，屏幕上什么都没有。
///
/// 所以改成只切掉客套前缀、保留后面的正文。切完为空（整行只有客套、
/// 例如单独一行的「续写：」）才由调用方丢弃。
///
/// 【为什么必须用 first-match 而不是循环剥离】「好的，好的，」这种叠词
/// 是模型罕见但确实会出的输出；反复剥会一路吃掉正文。剥一次就够。
String _stripMetaOpener(String line) {
  for (final p in _metaOpeners) {
    if (line.startsWith(p)) {
      final rest = line.substring(p.length).trim();
      // 只剥问候式客套；「续写：」这类标签后面若直接是正文也要留住，
      // 所以两者一视同仁——反正中间的分隔符（，/：）已经连同前缀一起切掉了。
      return rest;
    }
  }
  return line;
}

/// 会被剥掉的"元信息开场白"前缀。
const List<String> _metaOpeners = [
  '以下是我的续写',
  '以下是续写',
  '续写：',
  '续写:',
  '好的，',
  '好的,',
  '好的。',
];

// 【为什么提到文件级】本文件有源码形状守卫
// （`test/regex_hotpath_test.dart`）：循环体内现编译 RegExp 会被判失败。
// `cleanStoryFreeformText` 逐行跑，三条正则若写在 `for` 里就是"每行编译一次"。
final RegExp _reHeading = RegExp(r'^#{1,6}\s*');
final RegExp _reBullet = RegExp(r'^[-*+]\s+');
final RegExp _reOrdered = RegExp(r'^\d+[.)]\s+');

/// 该玩家当前是否处于"剧情 + AI 自由插话"可用状态。
///
/// 【为什么单独抽一个判据】UI 要据此决定输入框下方的提示文案
/// （"自由插话已开启，AI 会在原著框架内续写" vs "当前为纯本地剧情模式"）。
/// 逻辑只能有一份，避免 UI 与引擎对"开没开"的理解漂移。
bool storyFreeformUsable({
  required StoryProgress progress,
  required bool hasAiService,
}) =>
    progress.active &&
    progress.freeformEnabled &&
    hasAiService &&
    !progress.isFinished;

/// 单次插话允许的最大字符数（UI 输入框与 prompt 双重限长）。
const int kStoryFreeformMaxInputChars = 200;