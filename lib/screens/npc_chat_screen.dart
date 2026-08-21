import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/npc.dart';
import '../providers/game_provider.dart';
import '../services/npc_chat_service.dart';

class NpcChatScreen extends StatefulWidget {
  final NPC npc;

  const NpcChatScreen({super.key, required this.npc});

  @override
  State<NpcChatScreen> createState() => _NpcChatScreenState();
}

class _NpcChatScreenState extends State<NpcChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  late final NpcChatService _chatService;

  @override
  void initState() {
    super.initState();
    _chatService = context.read<GameProvider>().chatService;
    _loadHistory().then((_) {
      _sendInitialGreeting();
    });
  }

  Future<void> _loadHistory() async {
    final history = await _chatService.loadConversation(widget.npc.id);
    if (mounted && history.isNotEmpty) {
      setState(() {
        _messages.addAll(history);
      });
      _scrollToBottom();
    }
  }

  void _sendInitialGreeting() {
    if (_messages.isEmpty) {
      final greeting = _generateGreeting(widget.npc);
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: greeting));
      });
    }
  }

  String _generateGreeting(NPC npc) {
    if (npc.affection >= 30) {
      return '${npc.name}："你来了！我正想找你呢..."';
    } else if (npc.affection >= 0) {
      return '${npc.name}："哦，是你啊。有什么事吗？"';
    } else {
      return '${npc.name}："你来做什么？我很忙。"';
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    final gp = context.read<GameProvider>();
    final player = gp.player;
    if (player == null) return;

    setState(() {
      _isLoading = true;
      _messages.add(ChatMessage(role: 'user', content: text));
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final historyForApi = _messages.length > 1 ? _messages.sublist(0, _messages.length - 1) : <ChatMessage>[];
      final response = await _chatService.chatWithNPC(
        npc: widget.npc,
        player: player,
        worldState: gp.worldState,
        userMessage: text,
        history: historyForApi,
      );

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(role: 'assistant', content: response));
          _isLoading = false;
        });
        _scrollToBottom();
        await _chatService.saveConversation(widget.npc.id, _messages);
        _updateAffection(text, response);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(role: 'assistant', content: '（${widget.npc.name}似乎没听清...）'));
          _isLoading = false;
        });
      }
    }
  }

  void _updateAffection(String userMsg, String npcReply) {
    final gp = context.read<GameProvider>();
    final npc = gp.npcRegistry[widget.npc.id];
    if (npc == null) return;

    int change = 0;
    final msg = userMsg.toLowerCase();

    if (msg.contains('你好') || msg.contains('嗨') || msg.contains('在吗')) {
      change = 1;
    } else if (msg.contains('讨厌') || msg.contains('烦') || msg.contains('滚')) {
      change = -3;
    } else if (msg.contains('喜欢') || msg.contains('漂亮') || msg.contains('好看')) {
      change = 3;
    } else if (msg.contains('谢谢') || msg.contains('感谢') || msg.contains('麻烦')) {
      change = 2;
    } else if (msg.contains('?') || msg.contains('？')) {
      change = 1;
    } else {
      change = 1;
    }

    if (npcReply.contains('笑') || npcReply.contains('哈哈') || npcReply.contains('好')) {
      change += 1;
    }
    if (npcReply.contains('滚') || npcReply.contains('烦') || npcReply.contains('别')) {
      change -= 2;
    }

    gp.updateNpcAffection(widget.npc.id, change);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final npc = widget.npc;
    final houseColor = _getHouseColor(npc.house);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: houseColor.withValues(alpha: 0.15),
                border: Border.all(color: houseColor, width: 1.5),
              ),
              child: Center(
                child: Text(
                  npc.name.isNotEmpty ? npc.name[0] : '?',
                  style: TextStyle(color: houseColor, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(npc.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(
                    _getAffectionLabel(npc.affection),
                    style: TextStyle(fontSize: 12, color: _getAffectionColor(npc.affection)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空对话',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('清空对话'),
                  content: Text('确定要清空与${npc.name}的所有对话记录吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        _chatService.clearConversation(npc.id);
                        setState(() => _messages.clear());
                        Navigator.pop(ctx);
                      },
                      child: const Text('确定', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text('和${npc.name}开始对话吧', style: TextStyle(color: Colors.grey.withValues(alpha: 0.7))),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _buildMessageBubble(_messages[index], npc),
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, NPC npc) {
    final isUser = message.role == 'user';
    final houseColor = _getHouseColor(npc.house);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: houseColor.withValues(alpha: 0.15),
                border: Border.all(color: houseColor.withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Text(
                  npc.name.isNotEmpty ? npc.name[0] : '?',
                  style: TextStyle(fontSize: 14, color: houseColor, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.85)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: isUser ? null : Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser ? const Color(0xFF0d1117) : const Color(0xFFE6EDF3),
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              ),
              child: const Center(
                child: Icon(Icons.person, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: '说点什么...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, color: Color(0xFF0d1117)),
                onPressed: _isLoading ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getHouseColor(String house) {
    switch (house) {
      case 'Gryffindor':
        return const Color(0xFF740001);
      case 'Slytherin':
        return const Color(0xFF1A472A);
      case 'Ravenclaw':
        return const Color(0xFF0E1A40);
      case 'Hufflepuff':
        return const Color(0xFFECB939);
      default:
        return const Color(0xFFD3A625);
    }
  }

  String _getAffectionLabel(int affection) {
    if (affection >= 95) return '灵魂伴侣 💞';
    if (affection >= 85) return '深爱 ❤️';
    if (affection >= 70) return '亲密 💕';
    if (affection >= 50) return '信任 😊';
    if (affection >= 30) return '友好 🙂';
    if (affection >= 10) return '好感 😃';
    if (affection >= -9) return '中立 😐';
    if (affection >= -20) return '冷漠 😶';
    if (affection >= -50) return '反感 😒';
    if (affection >= -80) return '宿怨 😠';
    return '死敌 💀';
  }

  Color _getAffectionColor(int affection) {
    if (affection >= 70) return Colors.pink;
    if (affection >= 30) return Colors.green;
    if (affection >= -9) return Colors.grey;
    if (affection >= -50) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
