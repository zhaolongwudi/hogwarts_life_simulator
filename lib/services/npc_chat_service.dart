import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../models/world_state.dart';
import '../data/npc_chat_wordbank.dart';
import '../data/offline_extras_data.dart';
import '../providers/app_provider.dart';
import '../utils/prompt_sanitizer.dart';
import 'ai_router.dart';
import '../utils/debug_log.dart';

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  /// 是否为离线兜底回复（AI 调用失败时生成）。仅内存标记，不落盘。
  final bool offline;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.offline = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: json['role'] is String ? json['role'] as String : '',
    content: json['content'] is String ? json['content'] as String : '',
    timestamp: _safeTimestamp(json['timestamp']),
  );

  /// 存档时间戳类型防御（P#6）：时间戳缺失/损坏时回退当前时间，
  /// 不抛异常导致整段会话拒载。
  static DateTime _safeTimestamp(dynamic v) {
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    if (v is DateTime) return v;
    return DateTime.now();
  }
}

class NpcChatService {
  final AppProvider appProvider;
  AiRouter? _router;
  final Map<String, List<ChatMessage>> _conversationCache = {};

  /// 近 1 分钟内的 AI 调用时间戳（Q11 连发保护）。
  ///
  /// 近 1 分钟连发保护（本地闸门，与具体提供商无关）。默认 npcChat → SenseNova，
  /// 玩家连续快速发消息时，计数接近上限后直接降级本地模板——对玩家是
  /// 「回答变快但略显模板化」，远好于「一句话卡半分钟」。
  static const int kMaxRpmWindow = 18;
  static const Duration kRpmWindow = Duration(minutes: 1);
  final List<DateTime> _recentAiCalls = [];

  /// 串行化所有会话文件写操作，避免并发写同一文件导致丢更新
  Future<void> _writeChain = Future.value();

  Future<T> _serialized<T>(Future<T> Function() task) {
    final result = _writeChain.then((_) => task());
    _writeChain = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// 原子写（P#7）：先写临时文件再 rename，避免写一半崩溃把整份会话记录截断。
  /// 与 save_service._atomicWrite 同思路，但这是独立文件，不复用其私有实现。
  Future<void> _atomicWriteJson(String path, String content) async {
    final tmpPath = '$path.tmp';
    final tmpFile = File(tmpPath);
    await tmpFile.writeAsString(content);
    await tmpFile.rename(path);
  }

  NpcChatService({required this.appProvider}) {
    _initClient();
  }

  void _initClient() {
    final config = AiRouterConfig(
      narrativeProvider: appProvider.providerForScene(AiScene.narrative),
      summaryProvider: appProvider.providerForScene(AiScene.summary),
      npcChatProvider: appProvider.providerForScene(AiScene.npcChat),
      choiceProvider: appProvider.providerForScene(AiScene.choice),
    );
    final router = AiRouter(config);
    for (final p in AiProvider.values) {
      if (appProvider.hasKey(p)) {
        final configs = appProvider.configsForProvider(p);
        for (final cfg in configs) {
          router.register(cfg);
        }
      }
    }
    _router = router;
  }

  void refreshClient() => _initClient();

  void clearCache() {
    _conversationCache.clear();
  }

  /// P8：NPC 回忆支线解锁。好感达标且未收集的回忆，在聊天回复末尾追加
  /// 一段回忆叙事，并结算好感/加隆奖励。入口统一在 [chatWithNPC] 的
  /// 本地兜底与 AI 回复两条路径之后调用，保证离线/在线行为一致。
  /// 返回「已追加回忆的回复文本」；无新回忆时原样返回。
  ///
  /// 奖励好感直接写回 npc.affection（与聊天屏每轮 updateNpcAffection 的
  /// 落盘路径不冲突——解锁本身就是「聊出来的关系进展」）。
  String withUnlockedMemories(NPC npc, Player player, String reply) {
    final pending = pendingMemoriesFor(
      npc.id,
      npc.affection,
      player.collectedMemories.toSet(),
    );
    if (pending.isEmpty) return reply;
    final buf = StringBuffer(reply);
    for (final m in pending) {
      player.collectedMemories.add(m.id);
      npc.affection = (npc.affection + m.rewardAffection).clamp(-100, 100).toInt();
      if (m.rewardGalleons > 0) player.galleons += m.rewardGalleons;
      buf.writeln();
      buf.writeln();
      buf.writeln('—— ${npc.name}讲起了一段往事 ——');
      buf.writeln('【回忆】${m.title}');
      buf.writeln(m.text);
      final rewards = <String>['好感 +${m.rewardAffection}'];
      if (m.rewardGalleons > 0) rewards.add('${m.rewardGalleons} 加隆');
      buf.writeln('（已收入回忆册 · $m.title：${rewards.join('、')}）');
    }
    return buf.toString();
  }

  /// AI 调用失败或返回空内容时，离线位为 true，回复为本地模板。
  Future<(String, bool)> chatWithNPC({
    required NPC npc,
    required Player player,
    required WorldState worldState,
    required String userMessage,
    List<ChatMessage>? history,
  }) async {
    // P3：本地兜底回复（含可选 AI 润色）。每个本地返回点都走这里，保证
    // 润色门控只此一处，不会某些返回点跳过润色。
    Future<(String, bool)> local() async {
      final text = _generateLocalResponse(npc, userMessage, player: player);
      final polished = await _maybePolishLocalReply(npc, text);
      // P8：本地兜底同样走回忆解锁，离线/在线行为一致
      return (withUnlockedMemories(npc, player, polished), true);
    }

    if (_router == null) {
      return local();
    }

    // 用户输入进入 Prompt 前做注入防御净化
    final safeMessage = PromptSanitizer.sanitize(userMessage);

    final systemPrompt = _buildNpcSystemPrompt(npc, player, worldState);
    final promptBuffer = StringBuffer();

    if (history != null && history.isNotEmpty) {
      // 双维度裁剪：条数上限 20 条 + 总字符上限 3000，防止长会话撑爆上下文
      final recent = history.length > 20
          ? history.sublist(history.length - 20)
          : history;
      final buffer = StringBuffer();
      int totalChars = 0;
      final kept = <ChatMessage>[];
      for (final msg in recent.reversed) {
        if (totalChars + msg.content.length > 3000) break;
        totalChars += msg.content.length;
        kept.insert(0, msg);
      }
      for (final msg in kept) {
        buffer.writeln(
          '${msg.role.toUpperCase()}: ${msg.content}',
        );
      }
      promptBuffer.write(buffer);
    }

    promptBuffer.writeln('USER: $safeMessage');
    promptBuffer.write('ASSISTANT: ');

    try {
      // Q11：连发保护——窗口内已接近本地限流上限时，直接降级本地模板，
      // 不进入会让玩家干等的「等待窗口滑出」。判定离线（false）不计数。
      if (_shouldDegradeLocal()) {
        _recordAiCall();
        return local();
      }
      _recordAiCall();
      final response = await _router!.chatComplete(
        scene: AiScene.npcChat,
        prompt: promptBuffer.toString(),
        systemPrompt: systemPrompt,
        temperature: 0.9,
        maxTokens: 500,
      );

      var responseText = response.content
          .replaceFirst(RegExp(r'^[\*\[]'), '')
          .trim();
      if (responseText.isEmpty) {
        return local();
      }
      // P8：AI 回复同样走回忆解锁，保证在线/离线行为一致
      return (withUnlockedMemories(npc, player, responseText), false);
    } catch (e) {
      return local();
    }
  }

  /// P3：可选 AI 润色本地兜底回复。门控与叙事润色一致：仅当本地模式开启
  /// `narrativePolishEnabled` 且 AI 服务可用时，才用一次轻量调用润色措辞；
  /// 失败/超时/空结果一律保留原文，绝不把润色变成聊天的新断点。
  Future<String> _maybePolishLocalReply(NPC npc, String text) async {
    if (!appProvider.narrativePolishEnabled) return text;
    final router = _router;
    if (router == null || !router.hasNarrativeService) return text;
    if (text.trim().isEmpty) return text;
    try {
      final result = await router.chatComplete(
        scene: AiScene.npcChat,
        temperature: 0.9,
        maxTokens: 300,
        // 润色失败不写 Key 熔断：可选增强不该把健康 Key 记上冷却（审批 3.1）。
        trackCircuit: false,
        prompt: '''
你是一名哈利·波特世界的对话润色师。下面是本地引擎生成的「${npc.name}」的一句回复。
请只润色措辞与语气，让句子更像这个人会说的话；不得改变原意、身份设定或新增信息。用简体中文，直接输出润色后的一句回复，不要加引号、点评或前后缀。

【性格】${npc.personality.join('、')}
【好感】${npc.affection}

【原回复】
$text
''',
      );
      final polished = result.content.trim();
      if (polished.isEmpty || polished.length > text.length * 3) return text;
      return polished;
    } catch (e) {
      debugLog('⚠️ ⚠️ NPC 润色失败，保留本地回复: $e');
      return text;
    }
  }

  /// P3 测试别名：供测试直接调用润色逻辑。
  @visibleForTesting
  Future<String> polishLocalReplyForTest(NPC npc, String text) =>
      _maybePolishLocalReply(npc, text);

  /// Q11 连发保护判定：滑动窗口内已发起 >= [kMaxRpmWindow] 次 AI 调用。
  ///
  /// 抽成独立方法便于单测——不必真的打进 18 个网络请求就能断言行为。
  @visibleForTesting
  bool shouldDegradeLocalForTest() {
    _pruneRpmWindow();
    return _recentAiCalls.length >= kMaxRpmWindow;
  }

  /// Q11 连发保护判定（chatWithNPC 内部使用；对测试暴露无下划线别名）。
  bool _shouldDegradeLocal() => shouldDegradeLocalForTest();

  /// 记录一次 AI 调用时间戳（滑动窗口按需清理过期项）。
  void _recordAiCall() {
    _recentAiCalls.add(DateTime.now());
    _pruneRpmWindow();
  }

  /// Q11 测试钩子：手动注入一次调用计数（不真正发请求）。
  @visibleForTesting
  void recordAiCallForTest() => _recordAiCall();

  void _pruneRpmWindow() {
    final cutoff = DateTime.now().subtract(kRpmWindow);
    _recentAiCalls.removeWhere((t) => t.isBefore(cutoff));
  }

  /// 测试复位：清空 RPM 计数，避免跨用例累计污染连发判定。
  @visibleForTesting
  void resetRpmWindowForTest() => _recentAiCalls.clear();

  String _buildNpcSystemPrompt(NPC npc, Player player, WorldState worldState, {String? relationshipAnchor}) {
    final personalityStr = npc.personality.join('、');
    final houseName =
        {
          'Gryffindor': '格兰芬多',
          'Slytherin': '斯莱特林',
          'Ravenclaw': '拉文克劳',
          'Hufflepuff': '赫奇帕奇',
        }[npc.house] ??
        '';

    final eraName =
        {
          'dumbledore': '邓布利多时代',
          'marauders': '亲世代',
          'harry_same': '子世代',
          'post_war': '现代',
        }[worldState.era] ??
        '霍格沃茨';

    final timeStr =
        '${worldState.time.month}月${worldState.time.day}日 ${worldState.time.hour}:${worldState.time.minute.toString().padLeft(2, '0')}';

    String prompt = '''你现在扮演霍格沃茨的学生/教职工「${npc.name}」。

【角色设定】
- 学院：${houseName}
- 性格：${personalityStr}
- 外貌：${npc.appearance}
- 目标：${npc.personalGoal ?? '在霍格沃茨生活'}
- 对玩家「${player.name}」的好感度：${npc.affection}（范围-100到+100，正值为友好）

【当前世界状态】
- 时代：$eraName
- 时间：$timeStr
- 地点：${npc.currentLocation}

【对话规则】
1. 严格保持「${npc.name}」的性格，不要出戏。
2. 回复要简短自然，像真实对话，不要太正式或太长。
3. 根据好感度调整语气：好感高时友好亲近，好感低时冷淡疏离。
4. 不要暴露NPC不该知道的信息。
5. 回复用第一人称。
6. 如果玩家说的话不符合场景（如深夜说要去禁林），可以表现出惊讶或劝阻。
7. 回复用中文。''';

    if (relationshipAnchor != null && relationshipAnchor.isNotEmpty) {
      prompt += '\n\n【关系记忆】\n$relationshipAnchor';
    }

    return prompt;
  }

  /// 纯本地兜底回复生成（Q14）。
  ///
  /// 与 [chatWithNPC] 的离线分支共用同一实现。抽成独立方法并 `@visibleForTesting`
  /// 暴露，让测试无需真正发起网络请求即可断言好感度分档 / 同消息轮转。
  /// [player] 用于关系历史回声：传入玩家的关系记录，让兜底偶尔引用一段
  /// 与这个 NPC 的共同经历。
  @visibleForTesting
  String localResponseFor(NPC npc, String message, {Player? player}) =>
      _generateLocalResponse(npc, message, player: player);

  /// 本地兜底回复轮转计数（Q14 修复"同消息必同回复"）。
  ///
  /// 修复前：只用 `message.hashCode` 选回复——同一句话永远得到同一条回复，
  /// 玩家在 AI 故障/限流时连续问两次就能识破"是机器人"。现在给每个实例
  /// 一个自增计数，轮转种子随调用增长，同一条消息也会轮换到不同句子。
  int _localReplyCounter = 0;

  /// 按好感度分档挑选本地模板（Q14）。
  ///
  /// 修复前：所有示例只有一套，且人设（宿敌/恋人）与好感度完全不进模板，
  /// 回复千篇一律。现在按好感度分成 冷淡 / 普通 / 友好 三档，每档独立词库，
  /// 搭配每个"人设关键词/学院/教职工"的组合词池，让兜底回复也有人味。
  ///
  /// P0 续：再叠加三个维度让“话题感知”真正生效——
  /// ① 话题：命中关键词就切到该话题的专属句（见 `data/npc_chat_wordbank.dart`）；
  /// ② 性格：按 NPC 性格立场（敢闯/好胜/博学）优先取定制口吻；
  /// ③ 关系历史：偶尔引用玩家与该 NPC 过往的共同经历。
  ///
  /// 不顺带做复杂性陷阱：这里的核心目标是"同样的故障下，玩家感觉在跟
  /// 有趣的NPC说话"。池子够大、分档合理即可，不追求真实聊天逻辑。
  String _generateLocalResponse(NPC npc, String message, {Player? player}) {
    // 好感度分档：< -10 冷淡；> 15 友好；中间普通
    final String tier = npc.affection <= -10
        ? 'cold'
        : (npc.affection >= 15 ? 'warm' : 'neutral');

    // 轮转种子 = 消息 hash + 自增计数：同消息多次问会轮换句子，
    // 不同消息错开，不再"同一句必同回"。
    _localReplyCounter++;
    final seed =
        (message.hashCode & 0x7fffffff) + (_localReplyCounter * 31);

    // 【① 关系历史回声】与这个 NPC 有共同经历且命中轮转时，优先说一段
    // 只有这段存档才知道的事（只有传入 player 才可能触发）。
    final historyEcho = _relationshipEcho(player, npc, seed);
    if (historyEcho != null) return historyEcho;

    // 【②③ 话题 × 性格】命中话题优先按“性格口吻 → 通用话题词库”取句。
    final topic = detectNpcChatTopic(message);
    if (topic != null) {
      final topicLine = _topicLine(topic, tier, npc.personality, seed);
      if (topicLine != null) return topicLine;
    }

    // 【兜底】学院 × 档位（既有），性格口吻不覆盖时也走这里。
    final bool isStaff = !{'Gryffindor', 'Slytherin', 'Ravenclaw', 'Hufflepuff'}
        .contains(npc.house);
    final Map<String, List<String>> pool =
        isStaff ? _staffPool : (_housePool[npc.house] ?? _staffPool);
    final lines = (pool[tier] != null && pool[tier]!.isNotEmpty)
        ? pool[tier]!
        : (pool['neutral'] ?? const ['嗯，你说。']);
    return lines[seed % lines.length];
  }

  /// 关系历史回声：玩家与这个 NPC 有 relationship.history 时，约 1/3 轮次
  /// 引用最近一段共同经历。无历史或未传 player 返回 null。
  String? _relationshipEcho(Player? player, NPC npc, int seed) {
    if (player == null) return null;
    final rel = player.relationships[npc.id];
    final hist = rel?.history;
    if (hist == null || hist.isEmpty) return null;
    if (seed % 3 != 0) return null; // 只在部分轮次插入，避免句句重复同一件事
    final evt = _shear(hist.last, 26);
    return '还有，$evt——那件事，我一直记着。';
  }

  /// 命中话题：优先性格立场定制口吻，其次通用话题词库，最后回退 null。
  String? _topicLine(String topic, String tier, List<String> personality, int seed) {
    final stance = npcChatStanceOf(personality);
    final List<String>? lines = _pick(
      [[stance, topic], [topic]], tier,
    );
    if (lines == null || lines.isEmpty) return null;
    return lines[seed % lines.length];
  }

  /// 依次尝试多个池键，取第一个非空命中。
  ///
  /// [keys] 空形如 [['bold','forest'], ['forest']]，前者查性格口吻池，后者查通用话题池。
  List<String>? _pick(List<List<String>> keys, String tier) {
    for (final key in keys) {
      if (key.length == 2) {
        final stanceLines = kNpcStanceTopicPool[key[0]]?[key[1]];
        final l = _tiered(stanceLines, tier);
        if (l != null) return l;
      } else {
        final l = _tiered(kNpcTopicPool[key[0]], tier);
        if (l != null) return l;
      }
    }
    return null;
  }

  /// 从「话题/性格 → 档位 → 句子」里取档位行；档位缺失回退 neutral。
  List<String>? _tiered(Map<String, List<String>>? byTier, String tier) {
    if (byTier == null) return null;
    var l = byTier[tier];
    if (l == null || l.isEmpty) l = byTier['neutral'];
    if (l == null || l.isEmpty) return null;
    return l;
  }

  /// 截断过长的存档历史文本，避免把回复撑爆。
  static String _shear(String s, [int max = 26]) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  // 各学院 × 好感度档位 的兜底词库（Q14 扩展）：
  // 每档 3 条，四学院 + 教职工共 5 组，篇幅小、人设感强。
  static const Map<String, Map<String, List<String>>> _housePool = {
    'Gryffindor': {
      'cold': ['哼，格兰芬多的风头不是谁都能沾的。', '别挡道，我有自己的事。', '想套近乎？省省吧。'],
      'neutral': ['嘿！你也在啊？', '你今天精神不错，对吧？', '待会有空可以一起复习。'],
      'warm': ['和朋友一起做什么都开心！', '你简直是格兰芬多的骄傲！', '走，咱俩去搞点有意思的！'],
    },
    'Slytherin': {
      'cold': ['（冷冷地扫你一眼）有事说事。', '我不觉得你值得我浪费时间。', '……别打搅我。'],
      'neutral': ['嗯，可以聊。', '你有什么高见？', '合理。然后呢？'],
      'warm': ['（难得露出笑意）你倒是有点意思。', '我对你的评价一直很高。', '能和你站一边，是件好事。'],
    },
    'Ravenclaw': {
      'cold': ['你的逻辑……有待商榷。', '我对这个论点持保留意见。', '先查查资料，再回来聊。'],
      'neutral': ['这倒是个有意思的问题。', '让我想想……你说得有几分道理。', '知识就是力量，不是吗？'],
      'warm': ['和你讨论总能学到新东西！', '你的见解越来越成熟了。', '正好，我也在想这个问题。'],
    },
    'Hufflepuff': {
      'cold': ['……（显得有些为难）', '我可能不太方便多说。', '抱歉，我没听太明白。'],
      'neutral': ['你好呀！今天怎么样？', '大家愿意的话，一起去厨房坐坐？', '我觉得你人挺好的。'],
      'warm': ['有你在我总觉得安心。', '你总是这么温暖！', '今晚要一起做点好吃的吗？'],
    },
  };

  static const Map<String, List<String>> _staffPool = {
    'cold': ['（威严地）注意你的言行。', '这件事还有待观察。', '我希望你已经改了。'],
    'neutral': ['来我办公室一趟，有事谈谈。', '我对你近期的表现有所关注。', '记得按时完成作业。'],
    'warm': ['你是我见过最有潜力的学生之一。', '关于你，我一直很看好。', '课后留下来，我们聊聊你的方向。'],
  };

  // ====== 对话历史持久化 ======

  Future<String> _getSavePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/npc_conversations.json';
  }

  Future<void> saveConversation(
    String npcId,
    List<ChatMessage> messages,
  ) async {
    // 历史上限：单 NPC 会话裁剪到最近 50 条（约 3000 字），
    // 防止「读-改-写整个文件」随消息量无限膨胀（审查发现的历史只增不减）
    final trimmed = messages.length > 50
        ? messages.sublist(messages.length - 50)
        : messages;
    _conversationCache[npcId] = trimmed;
    try {
      await _serialized(() async {
        final path = await _getSavePath();
        final file = File(path);
        final Map<String, dynamic> data = {};
        if (await file.exists()) {
          final content = await file.readAsString();
          data.addAll(jsonDecode(content) as Map<String, dynamic>);
        }
        data[npcId] = trimmed.map((m) => m.toJson()).toList();
        await _atomicWriteJson(path, jsonEncode(data));
      });
    } catch (e) {
      // 聊天记录写盘失败必须留痕（此前静默吞掉，坏了无法排查）
      debugLog('❌ saveConversation($npcId) 写盘失败: $e');
    }
  }

  Future<List<ChatMessage>> loadConversation(String npcId) async {
    if (_conversationCache.containsKey(npcId)) {
      return _conversationCache[npcId]!;
    }
    try {
      final path = await _getSavePath();
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        if (data.containsKey(npcId)) {
          final messages = (data[npcId] as List)
              .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList();
          _conversationCache[npcId] = messages;
          return messages;
        }
      }
    } catch (e) {
      debugLog('❌ loadConversation($npcId) 读取失败: $e');
    }
    return [];
  }

  Future<void> clearConversation(String npcId) async {
    _conversationCache.remove(npcId);
    try {
      await _serialized(() async {
        final path = await _getSavePath();
        final file = File(path);
        if (await file.exists()) {
          final content = await file.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          data.remove(npcId);
          await _atomicWriteJson(path, jsonEncode(data));
        }
      });
    } catch (e) {
      debugLog('❌ clearConversation($npcId) 失败: $e');
    }
  }
}
