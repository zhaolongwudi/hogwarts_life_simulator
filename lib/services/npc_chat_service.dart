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
    promptBuffer.writeln(systemPrompt);

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
        // 历史消息回放前重净化：当次消息的 sanitize 覆盖不了历史里的注入内容
        buffer.writeln(
          '${msg.role.toUpperCase()}: ${PromptSanitizer.sanitize(msg.content)}',
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

  String _buildNpcSystemPrompt(NPC npc, Player player, WorldState worldState) {
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

    return '''你现在扮演霍格沃茨的学生/教职工「${npc.name}」。

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
  }

  String _generateLocalResponse(NPC npc, String message) {
    final responses = <String, List<String>>{
      'Gryffindor': ['嘿！${npc.name}？我在呢！', '哇，你说的真有意思！', '我觉得我们应该去冒险！'],
      'Slytherin': ['（挑眉）你想做什么？', '……有事吗？', '别浪费我的时间。'],
      'Ravenclaw': ['嗯，这是个有趣的话题。', '让我想想……你说的有道理。', '知识就是力量，不是吗？'],
      'Hufflepuff': ['你好呀！今天过得怎么样？', '我觉得大家都很好相处。', '要一起去厨房做点东西吃吗？'],
    };

    final staffResponses = ['来我办公室一趟。', '我对你的表现很关注。', '记得按时完成作业。'];

    final list = responses[npc.house] ?? staffResponses;
    final idx = (message.hashCode & 0x7fffffff) % list.length;
    return list[idx];
  }

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
      debugPrint('❌ saveConversation($npcId) 写盘失败: $e');
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
      debugPrint('❌ loadConversation($npcId) 读取失败: $e');
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
      debugPrint('❌ clearConversation($npcId) 失败: $e');
    }
  }
}
