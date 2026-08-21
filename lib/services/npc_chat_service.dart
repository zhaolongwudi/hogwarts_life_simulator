import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../models/world_state.dart';
import '../providers/app_provider.dart';
import 'deepseek_service.dart';
import 'ai_router.dart';

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
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

  NpcChatService({required this.appProvider}) {
    _initClient();
  }

  void _initClient() {
    final config = AiRouterConfig(
      narrativeProvider: appProvider.providerForScene(AiScene.narrative),
      summaryProvider: appProvider.providerForScene(AiScene.summary),
      npcChatProvider: appProvider.providerForScene(AiScene.npcChat),
    );
    final router = AiRouter(config);
    for (final p in AiProvider.values) {
      if (appProvider.hasKey(p)) {
        router.register(appProvider.configForProvider(p));
      }
    }
    _router = router;
  }

  void refreshClient() => _initClient();

  Future<String> chatWithNPC({
    required NPC npc,
    required Player player,
    required WorldState worldState,
    required String userMessage,
    List<ChatMessage>? history,
  }) async {
    _initClient();
    if (_router == null) {
      return _generateLocalResponse(npc, userMessage);
    }

    final systemPrompt = _buildNpcSystemPrompt(npc, player, worldState);
    final promptBuffer = StringBuffer();
    promptBuffer.writeln(systemPrompt);

    if (history != null && history.isNotEmpty) {
      final recent = history.length > 20 ? history.sublist(history.length - 20) : history;
      for (final msg in recent) {
        promptBuffer.writeln('${msg.role.toUpperCase()}: ${msg.content}');
      }
    }

    promptBuffer.writeln('USER: $userMessage');
    promptBuffer.write('ASSISTANT: ');

    try {
      final response = await _router!.chatComplete(
        scene: AiScene.npcChat,
        prompt: promptBuffer.toString(),
        temperature: 0.9,
        maxTokens: 500,
      );

      final responseText = response.content.replaceFirst(RegExp(r'^[\*\[]'), '').trim();
      return responseText;
    } catch (e) {
      return _generateLocalResponse(npc, userMessage);
    }
  }

  String _buildNpcSystemPrompt(NPC npc, Player player, WorldState worldState) {
    final personalityStr = npc.personality.join('、');
    final houseName = {
      'Gryffindor': '格兰芬多',
      'Slytherin': '斯莱特林',
      'Ravenclaw': '拉文克劳',
      'Hufflepuff': '赫奇帕奇',
    }[npc.house] ?? '';

    final eraName = {
      'dumbledore': '邓布利多时代',
      'marauders': '亲世代',
      'harry_same': '子世代',
      'post_war': '现代',
    }[worldState.era] ?? '霍格沃茨';

    final timeStr = '${worldState.time.month}月${worldState.time.day}日 ${worldState.time.hour}:${worldState.time.minute.toString().padLeft(2, '0')}';

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
      'Gryffindor': [
        '嘿！${npc.name}？我在呢！',
        '哇，你说的真有意思！',
        '我觉得我们应该去冒险！',
      ],
      'Slytherin': [
        '（挑眉）你想做什么？',
        '……有事吗？',
        '别浪费我的时间。',
      ],
      'Ravenclaw': [
        '嗯，这是个有趣的话题。',
        '让我想想……你说的有道理。',
        '知识就是力量，不是吗？',
      ],
      'Hufflepuff': [
        '你好呀！今天过得怎么样？',
        '我觉得大家都很好相处。',
        '要一起去厨房做点东西吃吗？',
      ],
    };

    final staffResponses = [
      '来我办公室一趟。',
      '我对你的表现很关注。',
      '记得按时完成作业。',
    ];

    final list = responses[npc.house] ?? staffResponses;
    final idx = (message.hashCode & 0x7fffffff) % list.length;
    return list[idx];
  }

  // ====== 对话历史持久化 ======

  Future<String> _getSavePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/npc_conversations.json';
  }

  Future<void> saveConversation(String npcId, List<ChatMessage> messages) async {
    _conversationCache[npcId] = messages;
    try {
      final path = await _getSavePath();
      final file = File(path);
      final Map<String, dynamic> data = {};
      if (await file.exists()) {
        final content = await file.readAsString();
        data.addAll(jsonDecode(content) as Map<String, dynamic>);
      }
      data[npcId] = messages.map((m) => m.toJson()).toList();
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
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
          final messages = (data[npcId] as List).map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
          _conversationCache[npcId] = messages;
          return messages;
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> clearConversation(String npcId) async {
    _conversationCache.remove(npcId);
    try {
      final path = await _getSavePath();
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        data.remove(npcId);
        await file.writeAsString(jsonEncode(data));
      }
    } catch (_) {}
  }
}
