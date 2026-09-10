import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../models/world_state.dart';
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
    role: json['role'] as String,
    content: json['content'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

class NpcChatService {
  final AppProvider appProvider;
  AiRouter? _router;
  final Map<String, List<ChatMessage>> _conversationCache = {};

  /// 串行化所有会话文件写操作，避免并发写同一文件导致丢更新
  Future<void> _writeChain = Future.value();

  Future<T> _serialized<T>(Future<T> Function() task) {
    final result = _writeChain.then((_) => task());
    _writeChain = result.then((_) {}, onError: (_) {});
    return result;
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

  /// NPC 聊天返回 (回复文本, 是否离线兜底)。
  /// AI 调用失败或返回空内容时，离线位为 true，回复为本地模板。
  Future<(String, bool)> chatWithNPC({
    required NPC npc,
    required Player player,
    required WorldState worldState,
    required String userMessage,
    List<ChatMessage>? history,
  }) async {
    if (_router == null) {
      return (_generateLocalResponse(npc, userMessage), true);
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
        return (_generateLocalResponse(npc, safeMessage), true);
      }
      return (responseText, false);
    } catch (e) {
      return (_generateLocalResponse(npc, safeMessage), true);
    }
  }

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
  @visibleForTesting
  String localResponseFor(NPC npc, String message) =>
      _generateLocalResponse(npc, message);

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
  /// 不顺带做复杂性陷阱：这里的核心目标是"同样的故障下，玩家感觉在跟
  /// 有趣的NPC说话"。池子够大、分档合理即可，不追求真实聊天逻辑。
  String _generateLocalResponse(NPC npc, String message) {
    // 好感度分档：< -10 冷淡；> 15 友好；中间普通
    final String tier = npc.affection <= -10
        ? 'cold'
        : (npc.affection >= 15 ? 'warm' : 'neutral');

    // 教职工（无学院归属或未知学院）→ 专属词库
    final bool isStaff = !{'Gryffindor', 'Slytherin', 'Ravenclaw', 'Hufflepuff'}
        .contains(npc.house);
    final Map<String, List<String>> pool =
        isStaff ? _staffPool : (_housePool[npc.house] ?? _staffPool);

    // 从对应档位取词库；若该档为空回退到中性档
    final lines = (pool[tier] != null && pool[tier]!.isNotEmpty)
        ? pool[tier]!
        : (pool['neutral'] ?? const ['嗯，你说。']);

    // 轮转种子 = 消息 hash + 自增计数：同消息多次问会轮换句子，
    // 不同消息错开，不再"同一句必同回"。
    _localReplyCounter++;
    final seed =
        (message.hashCode & 0x7fffffff) + (_localReplyCounter * 31);
    return lines[seed % lines.length];
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
        await file.writeAsString(jsonEncode(data));
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
          await file.writeAsString(jsonEncode(data));
        }
      });
    } catch (e) {
      debugLog('❌ clearConversation($npcId) 失败: $e');
    }
  }
}
