import 'package:flutter/foundation.dart';
import 'app_provider.dart';
import '../models/player.dart';
import '../models/npc.dart';
import '../models/world_state.dart';
import '../services/deepseek_service.dart';
import '../services/save_service.dart';

class GameProvider extends ChangeNotifier {
  final AppProvider appProvider;
  DeepSeekService? _deepSeek;
  final SaveService _saveService = SaveService();

  Player? _player;
  WorldState _worldState = WorldState();
  final Map<String, NPC> _npcRegistry = {};

  String _currentNarrative = '';
  List<GameChoice> _choices = [];
  bool _isLoading = false;
  String? _error;
  int _turnCount = 0;
  String? _systemPrompt;
  String? _lastSlotId;

  Player? get player => _player;
  WorldState get worldState => _worldState;
  String get currentNarrative => _currentNarrative;
  List<GameChoice> get choices => _choices;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get turnCount => _turnCount;
  Map<String, NPC> get npcRegistry => _npcRegistry;

  GameProvider(this.appProvider) {
    _updateClient();
    appProvider.addListener(_onApiKeyChange);
  }

  void _onApiKeyChange() => _updateClient();

  void _updateClient() {
    if (appProvider.apiKey != null) {
      _deepSeek = DeepSeekService(apiKey: appProvider.apiKey!);
    }
  }

  Future<void> updateApiKey(String key) async {
    _deepSeek = DeepSeekService(apiKey: key);
    notifyListeners();
  }

  // ==================== 初始化游戏 ====================
  Future<void> initializeGame({
    required String name,
    required String bloodStatus,
    required String birthLocation,
    required List<String> personalityTraits,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _player = Player(
        name: name,
        birthYear: _calculateBirthYear(),
        bloodStatus: bloodStatus,
        birthLocation: birthLocation,
        personalityTraits: personalityTraits,
      );

      _worldState = WorldState(era: appProvider.era.name);
      _initializeCanonNPCs();
      await _generateOpeningScene();

      appProvider.setGameStarted(true);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _initializeCanonNPCs() {
    final grade = _getPlayerGrade();
    final canonNPCs = [
      ('harry', '哈利·波特', 'Gryffindor', grade, true),
      ('hermione', '赫敏·格兰杰', 'Gryffindor', grade, true),
      ('ron', '罗恩·韦斯莱', 'Gryffindor', grade, true),
      ('draco', '德拉科·马尔福', 'Slytherin', grade, true),
      ('neville', '纳威·隆巴顿', 'Hufflepuff', grade, true),
      ('luna', '卢娜·洛夫古德', 'Ravenclaw', grade + 1, true),
      ('cedric', '塞德里克·迪戈里', 'Hufflepuff', grade + 2, true),
      ('fred', '弗雷德·韦斯莱', 'Gryffindor', grade + 2, true),
      ('george', '乔治·韦斯莱', 'Gryffindor', grade + 2, true),
      ('ginny', '金妮·韦斯莱', 'Gryffindor', grade - 1, true),
      ('dumbledore', '阿不思·邓布利多', '', 0, true),
      ('snape', '西弗勒斯·斯内普', 'Slytherin', 0, true),
      ('mcgonagall', '米勒娃·麦格', 'Gryffindor', 0, true),
      ('hagrid', '鲁伯·海格', '', 0, true),
      ('voldemort', '伏地魔', '', 0, true),
    ];

    for (final entry in canonNPCs) {
      _npcRegistry[entry.$1] = NPC(
        id: entry.$1,
        name: entry.$2,
        house: entry.$3,
        grade: entry.$4,
        isCanon: entry.$5,
        personality: _generatePersonality(entry.$2),
      );
    }
  }

  List<String> _generatePersonality(String name) {
    final personalities = {
      '哈利·波特': ['勇敢', '忠诚', '冲动', '富有同情心'],
      '赫敏·格兰杰': ['聪明', '勤奋', '正义', '有时固执'],
      '罗恩·韦斯莱': ['幽默', '忠诚', '嫉妒', '勇敢'],
      '德拉科·马尔福': ['野心', '骄傲', '忠诚', '偏见'],
      '纳威·隆巴顿': ['善良', '勇敢', '笨拙', '成长'],
      '卢娜·洛夫古德': ['独特', '善良', '超脱', '直觉'],
      '塞德里克·迪戈里': ['正直', '优秀', '稳重', '公平'],
      '弗雷德·韦斯莱': ['调皮', '创意', '幽默', '冒险'],
      '乔治·韦斯莱': ['调皮', '商业头脑', '幽默', '忠诚'],
      '金妮·韦斯莱': ['独立', '勇敢', '热情', '强势'],
      '阿不思·邓布利多': ['智慧', '神秘', '仁慈', '深谋远虑'],
      '西弗勒斯·斯内普': ['复杂', '严厉', '深情', '傲慢'],
      '米勒娃·麦格': ['公正', '严格', '关怀', '强大'],
      '鲁伯·海格': ['善良', '热情', '天真', '忠诚'],
    };
    return personalities[name] ?? ['普通', '友好'];
  }

  String _calculateBirthYear() {
    final map = {
      'marauders': '1960-1968',
      'first_war': '1970-1978',
      'harry_same': '1979-1981',
      'post_war': '1990-2000',
    };
    return map[appProvider.era.name] ?? '1980';
  }

  int _getPlayerGrade() {
    return switch (appProvider.era) {
      Era.marauders => 4,
      _ => 1,
    };
  }

  // ==================== 生成开场场景 ====================
  Future<void> _generateOpeningScene() async {
    if (_player == null || _deepSeek == null) return;

    _systemPrompt = '''你是《哈利·波特》世界的人生模拟器主持者。核心规则：
1. 玩家不是天命主角，只是普通人
2. 不能因玩家身份自动获得特殊待遇
3. 原作事件存在但不强制玩家参与
4. 玩家可以改变历史但要承担后果
5. 只展示角色合理知道的信息
6. 魔法世界首先是生活，不是战斗副本
7. 每个NPC都有独立人生
8. 保持哈利波特世界观的魔法氛围''';

    final prompt = '''
你是《哈利·波特》世界的叙事者，风格如J.K.罗琳。

【玩家信息】
- 姓名：${_player!.name}
- 年龄：11岁
- 血统：${_player!.bloodStatus}
- 出生地：${_player!.birthLocation}
- 性格：${_player!.personalityTraits.join(', ')}
- 时代：${appProvider.era.name}
- 学年：${_worldState.academicYear}

【生成规则】
1. 麻瓜出身：展示普通家庭日常生活，魔法觉醒的意外事件，收到霍格沃茨通知书时的震惊
2. 魔法家庭：巫师家庭日常生活，对魔法世界的熟悉感
3. 纯血家庭：可能有的家族传统或压力，家族期望
4. 只展示角色合理知道的信息
5. 不要让玩家自动成为主角
6. 保持魔法氛围，但不夸大

【输出格式】
【叙事】
（300-500字沉浸叙事）

【可选行动】
A. （选项1）
B. （选项2）
C. （选项3）
D. （选项4）
【自由行动】（输入任何合理行为）''';

    final response = await _callDeepSeek(prompt);
    _parseResponse(response);
    notifyListeners();
  }

  // ==================== 处理选择 ====================
  Future<void> processChoice(GameChoice choice) async {
    if (_deepSeek == null || _player == null) return;

    _isLoading = true;
    _turnCount++;
    notifyListeners();

    try {
      final prompt = '''
继续游戏叙事。

【当前情境】
$_currentNarrative

【玩家选择】
${choice.action}

【世界状态】
- 学年：${_worldState.academicYear}
- 学期：${_worldState.term}
- 日期：${_worldState.month} ${_worldState.dayOfMonth}日
- 玩家学院：${_player!.house ?? '未分院'}
- 玩家年级：${_player!.grade ?? 1}

【玩家属性】
${_player!.attributes.entries.take(5).map((e) => '- ${e.key}: ${e.value}').join('\n')}

【重要NPC关系】
${_player!.relationships.isEmpty
    ? '暂无深入关系'
    : _player!.relationships.entries
        .map((e) => '- ${e.value.targetName} (${e.value.relationType}): ${e.value.level}/100')
        .join('\n')}

【原著事件提醒】
${_worldState.recentEvents.isEmpty ? '暂无记录' : _worldState.recentEvents.map((e) => '- $e').join('\n')}

【附近NPC】
${_getNearbyNPCs()}

请生成选择的后果和新的选项。保持：
1. 只有玩家合理能经历的事情发生
2. NPC有自己的人生
3. 不强行把玩家塞进原著事件
4. 如果玩家远离事件，就正常过校园生活

格式：
【叙事】
（200-400字）

【可选行动】
A. ...
B. ...
C. ...
【自由行动】...''';

      final response = await _callDeepSeek(prompt);
      _parseResponse(response);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  String _getNearbyNPCs() {
    final sameHouse = _npcRegistry.values
        .where((n) =>
            n.house == _player!.house && n.grade == _player!.grade && n.isAlive)
        .toList();
    if (sameHouse.isEmpty) return '暂无同年级同学院的同学';
    return sameHouse
        .take(5)
        .map((n) => '- ${n.name} (${n.currentLocation})')
        .join('\n');
  }

  // ==================== DeepSeek 调用 ====================
  Future<String> _callDeepSeek(String prompt) async {
    if (_deepSeek == null) throw Exception('API Key 未设置');
    return await _deepSeek!.chat(
      prompt: prompt,
      systemPrompt: _systemPrompt ?? '',
      temperature: 0.8,
      maxTokens: 2000,
    );
  }

  // ==================== 解析响应 ====================
  void _parseResponse(String text) {
    final lines = text.split('\n');
    _currentNarrative = '';
    _choices = [];
    bool inNarrative = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == '【叙事】') {
        inNarrative = true;
        continue;
      } else if (trimmed.startsWith('【可选行动】') ||
          trimmed.startsWith('【自由行动】')) {
        inNarrative = false;
        continue;
      }
      if (inNarrative) {
        if (trimmed.isNotEmpty) {
          _currentNarrative += '$trimmed\n';
        }
      } else if (RegExp(r'^[A-E][\.\)]\s*').hasMatch(trimmed)) {
        final action =
            trimmed.replaceFirst(RegExp(r'^[A-E][\.\)]\s*'), '').trim();
        if (action.isNotEmpty) {
          _choices.add(GameChoice(text: action, action: action));
        }
      }
    }

    _currentNarrative = _currentNarrative
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (_choices.isEmpty) {
      _choices.add(GameChoice(text: '继续', action: '继续'));
    }
  }

  // ==================== 分院仪式 ====================
  Future<Map<String, String>> sortPlayer() async {
    if (_player == null || _deepSeek == null) {
      return {'house': 'Gryffindor', 'narrative': ''};
    }

    _isLoading = true;
    notifyListeners();

    try {
      final prompt = '''
你是霍格沃茨的分院帽。

请为以下学生分院：
- 姓名：${_player!.name}
- 血统：${_player!.bloodStatus}
- 出生地：${_player!.birthLocation}
- 性格：${_player!.personalityTraits.join(', ')}
- 最看重的品质：${_getTopValues()}

请给出：
1. 分院帽的内心独白（思考该学生的特质）
2. 最终的学院决定

注意：分院要考虑学生的选择、价值观、潜在能力，不只是刻板印象。''';

      final response = await _callDeepSeek(prompt);
      final house = _extractHouse(response);
      _player!.house = house;

      _isLoading = false;
      notifyListeners();
      return {'house': house, 'narrative': response};
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'house': 'Gryffindor', 'narrative': ''};
    }
  }

  String _getTopValues() {
    final sorted = _player!.attributes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => e.key).join(', ');
  }

  String _extractHouse(String text) {
    final houseMap = {
      '格兰芬多': 'Gryffindor',
      '斯莱特林': 'Slytherin',
      '拉文克劳': 'Ravenclaw',
      '赫奇帕奇': 'Hufflepuff',
    };
    for (final entry in houseMap.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return 'Gryffindor';
  }

  // ==================== 魔杖选择 ====================
  Future<Map<String, dynamic>> selectWand(List<Map<String, dynamic>> options) async {
    if (_player == null || _deepSeek == null) {
      return {'selected': options.first, 'narrative': ''};
    }

    _isLoading = true;
    notifyListeners();

    try {
      final prompt = '''
你是奥利凡德魔杖店的主人。

玩家信息：
- 姓名：${_player!.name}
- 性格：${_player!.personalityTraits.join(', ')}

可用魔杖：
${options.map((w) => '- ${w['name']}: ${w['description']}').join('\n')}

请推荐最适合的魔杖并说明原因。''';

      final response = await _callDeepSeek(prompt);
      final idx = int.tryParse(response.replaceAll(RegExp(r'[^\d]'), '')) ?? 1;
      final selected = options[(idx - 1).clamp(0, options.length - 1)];
      _player!.wandId = selected['id'] as String?;

      _isLoading = false;
      notifyListeners();
      return {'selected': selected, 'narrative': response};
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'selected': options.first, 'narrative': ''};
    }
  }

  // ==================== 查看人物 ====================
  Map<String, dynamic>? getViewableCharacter(String npcId) {
    final npc = _npcRegistry[npcId];
    if (npc == null || !_isNPCVisible(npc)) return null;

    final rel = _player?.relationships[npcId];
    return {
      'id': npc.id,
      'name': npc.name,
      'house': npc.house,
      'grade': npc.grade,
      'location': npc.currentLocation,
      'mood': npc.mood,
      'alive': npc.isAlive,
      'relationship': rel != null
          ? {'type': rel.relationType, 'level': rel.level}
          : null,
      'personality': npc.personality,
      'knowsAbout': npc.knowsAbout.take(3).toList(),
    };
  }

  bool _isNPCVisible(NPC npc) {
    if (_player == null) return false;
    if (_player!.relationships.containsKey(npc.id)) return true;
    if (npc.house == _player!.house) return true;
    if (npc.isCanon && _worldState.playerImpactScore > 0.5) return true;
    return false;
  }

  // ==================== 快速推进 ====================
  Future<void> fastForward(int days) async {
    _isLoading = true;
    notifyListeners();
    _worldState.dayOfMonth += days;
    while (_worldState.dayOfMonth > 30) {
      _worldState.dayOfMonth -= 30;
      _advanceMonth();
    }
    _isLoading = false;
    notifyListeners();
  }

  void _advanceMonth() {
    const months = ['September', 'October', 'November', 'December',
        'January', 'February', 'March', 'April', 'May', 'June'];
    final idx = months.indexOf(_worldState.month);
    if (idx >= 0 && idx < months.length - 1) {
      _worldState.month = months[idx + 1];
    }
  }

  // ==================== 存档系统 ====================
  Future<void> quickSave() async {
    if (_player == null) return;
    _lastSlotId = await _saveService.saveGame(
      player: _player!.toJson(),
      worldState: _worldState.toJson(),
      npcRegistry: _npcRegistry.map((k, v) => MapEntry(k, v.toJson())),
      narrative: _currentNarrative,
      choices: _choices.map((c) => {'text': c.text, 'action': c.action}).toList(),
      turnCount: _turnCount,
      slotName: '快速存档',
    );
  }

  Future<void> loadFromSave(String slotId) async {
    final data = await _saveService.loadGame(slotId);
    if (data == null) return;

    _player = Player.fromJson(data['player'] as Map<String, dynamic>);
    _worldState = WorldState.fromJson(data['world_state'] as Map<String, dynamic>);
    _npcRegistry.clear();
    (data['npc_registry'] as Map<String, dynamic>).forEach((k, v) {
      _npcRegistry[k] = NPC.fromJson(v as Map<String, dynamic>);
    });
    _currentNarrative = data['narrative'] as String;
    _choices = (data['choices'] as List<dynamic>)
        .map((c) => GameChoice(text: c['text'] as String, action: c['action'] as String))
        .toList();
    _turnCount = data['turn_count'] as int? ?? 0;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> listSaves() async {
    return _saveService.listSaves();
  }

  Future<bool> deleteSave(String slotId) async {
    return _saveService.deleteSave(slotId);
  }

  // ==================== API 检查 ====================
  Future<bool> checkConnection() async {
    if (_deepSeek == null) return false;
    return await _deepSeek!.checkConnection();
  }

  Future<double?> get balance async {
    if (_deepSeek == null) return null;
    return await _deepSeek!.getBalance();
  }

  @override
  void dispose() {
    appProvider.removeListener(_onApiKeyChange);
    super.dispose();
  }
}

class GameChoice {
  final String text;
  final String action;
  GameChoice({required this.text, required this.action});
}
