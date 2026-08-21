import 'dart:math';
import 'package:flutter/widgets.dart';
import 'app_provider.dart';
import '../models/player.dart';
import '../models/npc.dart';
import '../models/world_state.dart';
import '../models/game_systems.dart';
import '../data/course_data.dart';
import '../data/wand_data.dart';
import '../data/cg_data.dart';
import '../data/npc_data.dart';
import '../data/world_rules.dart';
import '../services/deepseek_service.dart';
import '../services/save_service.dart';
import '../services/npc_chat_service.dart';

class GameProvider extends ChangeNotifier {
  final AppProvider appProvider;
  DeepSeekService? _deepSeek;
  final SaveService _saveService = SaveService();
  final Random _random = Random();
  late final NpcChatService chatService;

  // ====== 预编译正则（避免循环内重复编译） ======
  static final _reChoiceOption = RegExp(r'^[A-E][\.\)]\s*');
  static final _reMultiNewline = RegExp(r'\n{3,}');
  static final _reAffectionSection = RegExp(r'【好感度变化】[\s\S]*?(?=【|$)');
  static final _reReputationSection = RegExp(r'【声望变化】[\s\S]*?(?=【|$)');
  static final _reChoiceMultiLine = RegExp(r'^[A-E][\.\)]\s', multiLine: true);
  static final _reSectionMarkers = RegExp(r'【[^】]+】');

  Player? _player;
  WorldState _worldState = WorldState();
  final Map<String, NPC> _npcRegistry = {};

  String _currentNarrative = '';
  List<GameChoice> _choices = [];
  bool _isLoading = false;
  bool _isInitializing = false;
  String? _error;
  int _turnCount = 0;
  String? _systemPrompt;
  final List<String> _notifications = [];

  int _totalPromptTokens = 0;
  int _totalCompletionTokens = 0;
  int _totalTokens = 0;
  int _apiCalls = 0;

  int get totalPromptTokens => _totalPromptTokens;
  int get totalCompletionTokens => _totalCompletionTokens;
  int get totalTokens => _totalTokens;
  int get apiCalls => _apiCalls;

  Player? get player => _player;
  WorldState get worldState => _worldState;
  String get currentNarrative => _currentNarrative;
  List<GameChoice> get choices => _choices;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get error => _error;
  int get turnCount => _turnCount;
  Map<String, NPC> get npcRegistry => _npcRegistry;
  List<String> get notifications => List.unmodifiable(_notifications);

  GameProvider(this.appProvider) {
    chatService = NpcChatService(appProvider: appProvider);
    _updateClient();
    appProvider.addListener(_onApiKeyChange);
    if (appProvider.isGameStarted) {
      _isInitializing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryAutoLoad();
      });
    }
  }

  Future<void> _tryAutoLoad() async {
    if (!appProvider.isGameStarted) return;
    final data = await _saveService.loadAutoSave();
    if (data == null) {
      _isInitializing = false;
      appProvider.setGameStarted(false);
      notifyListeners();
      return;
    }
    try {
      _player = Player.fromJson(data['player'] as Map<String, dynamic>);
      _worldState = WorldState.fromJson(data['world_state'] as Map<String, dynamic>);
      _systemPrompt = _buildSystemPrompt();
      _npcRegistry.clear();
      (data['npc_registry'] as Map<String, dynamic>).forEach((k, v) {
        _npcRegistry[k] = NPC.fromJson(v as Map<String, dynamic>);
      });
      _currentNarrative = data['narrative'] as String? ?? '';
      _choices = (data['choices'] as List<dynamic>?)
          ?.map((c) => GameChoice(text: c['text'] as String, action: c['action'] as String))
          .toList() ?? [];
      _turnCount = data['turn_count'] as int? ?? 0;
      _isInitializing = false;
      debugPrint('✅ 自动存档加载成功: ${_player?.name} 第$_turnCount回合');
      notifyListeners();
    } catch (e) {
      _isInitializing = false;
      debugPrint('❌ 自动存档加载失败: $e');
      appProvider.setGameStarted(false);
      _error = '存档加载失败: $e';
      notifyListeners();
    }
  }

  Future<void> _autoSave() async {
    if (_player == null) return;
    try {
      await _saveService.autoSave(
        player: _player!.toJson(),
        worldState: _worldState.toJson(),
        npcRegistry: _npcRegistry.map((k, v) => MapEntry(k, v.toJson())),
        narrative: _currentNarrative,
        choices: _choices.map((c) => {'text': c.text, 'action': c.action}).toList(),
        turnCount: _turnCount,
      );
    } catch (e) {
      debugPrint('❌ 自动存档失败: $e');
    }
  }

  void _onApiKeyChange() {
    _updateClient();
    chatService.refreshClient();
  }

  void _updateClient() {
    if (appProvider.apiKey != null && appProvider.apiKey!.isNotEmpty) {
      _deepSeek = DeepSeekService(config: appProvider.aiConfig);
    }
  }

  void updateNpcAffection(String npcId, int change) {
    final npc = _npcRegistry[npcId];
    if (npc == null) return;
    npc.affection = (npc.affection + change).clamp(-100, 100);
    notifyListeners();
    _autoSave();
  }

  Future<void> updateApiKey(String key) async {
    if (key.isNotEmpty) {
      _deepSeek = DeepSeekService(config: appProvider.aiConfig.copyWith(apiKey: key));
    }
    notifyListeners();
  }

  // ==================== 系统提示词（精简版世界观 + 核心法则 + AI禁令 + 叙事风格） ====================
  String _buildSystemPrompt() {
    final eraName = _eraLabel(appProvider.era);
    final worldRules = kUseCompactWorldRules ? kWorldRulesCompact : kWorldRulesPrompt;
    return '''你是【哈利·波特·魔法纪元·世界模拟系统】，负责维护原著优先级别、魔法、血统、家族、魔法部、霍格沃茨、神奇生物、黑巫师、预言、历史、时间、因果。而玩家负责自己的人生。

$worldRules

【当前时代】$eraName

【七大核心法则】
1. 玩家是普通学生，不是天选之人：不因玩家身份自动获得特殊待遇。
2. 自由选择与后果：玩家可以做出任何选择，但每个选择都必须带来合理且持久的后果。
3. 信息受限原则：NPC与玩家只能知晓其合理接触范围内可以获得的信息；秘密必须通过探索、对话、推理逐步揭示。
4. 时间流逝一致性：每回合消耗合理时间，不同活动时间成本不同；时间推进必须清晰标注（📅 [年份]年[月]月[日]日，[星期X]，[时段] [时:分]）。
5. NPC独立人格：每个NPC都有独立人生、目标、喜怒哀乐，不围着玩家转。
6. 生命与历史敬畏：重大事件（死亡、背叛、战争）不可轻率发生，一旦发生不可轻易逆转。
7. 魔法世界首先是生活：课堂、友谊、三餐、散步都是重要内容，不只是战斗副本。

【AI 十二条禁令】
1. 严禁替玩家做决定或假设玩家行动。
2. 严禁替玩家说话，玩家对话必须通过选择或自由输入进行。
3. 严禁无铺垫地推进重大剧情（死亡/战争/表白等）。
4. 严禁强制玩家加入原著事件；玩家可以选择远离。
5. 严禁直接透露NPC内心或未来信息，除非通过合理途径得知。
6. 严禁编造玩家未拥有的物品、技能、记忆或关系。
7. 严禁让玩家或NPC瞬间满级、无敌或拥有无限资源。
8. 严禁性描写或过度露骨内容；恋爱描写止于亲吻与拥抱。
9. 严禁让原著角色OOC（脱离性格）。
10. 严禁跳过玩家的选择直接"安排好结局"。
11. 严禁在未触发条件时解锁CG或达成恋爱关系。
12. 严禁回复超出叙事范围的元信息。

【叙事风格】
- 如J.K.罗琳：富有画面感、幽默、细腻，兼具温暖与悬疑。
- 每段叙事至少包含3个感官细节（视觉、听觉、嗅觉、触觉、味觉）。
- 使用「【叙事】」「【可选行动】」「【自由行动】」的结构化输出。
- 叙事长度：推进事件200-400字；关键事件（战斗/表白/重大发现）400-600字。
- 时间推进后，叙事开头附上时间戳。

【时间系统】
- 每回合行动消耗合理时间（对话10分钟，一餐30分钟，一节课90分钟，自习120分钟，魁地奇训练120分钟，霍格莫德一日游300分钟，禁林探索180分钟，一夜睡眠480分钟）。
- 时段：晨间/上午/午间/下午/黄昏/晚间/深夜。

【好感度系统】
- 范围-100~+100。阶段：死敌(-100~-81)/宿怨(-80~-51)/反感(-50~-21)/冷漠(-20~-10)/中立(-9~+9)/好感(+10~+29)/友好(+30~+49)/信任(+50~+69)/亲密(+70~+84)/深爱(+85~+94)/灵魂伴侣(+95~+100)。
- 变化规则：日常对话+1~2，冲突-3~-1；送礼/事件梯度递增（一般礼物+1~3，喜欢+5~8，挚爱+10~15；中等事件+4~8；重大事件+10~20；极端事件+20~30；背叛-30~-15）。
- 在叙事中自然体现好感变化，并在每轮更新【好感度变化】小节。

【指令系统】
玩家输入 /状态 /时间 /地图 /通知 /帮助 /关系 /恋爱 /声望 /课程 /收藏 /日记 /档案 /成就 /宠物 /信 /血缘 /联动 /世界演化 /cheat 等指令时由本地系统处理，不需要生成叙事。

【防过度热闹协议】
禁止每个月都有黑魔头/魂器/死亡圣器/魔法战争。魔法世界也必须拥有大量普通生活。

【防主角光环协议】
玩家没有默认传奇血统、死亡圣器、预言、强大魔杖。除非通过真实行动获得。''';
  }

  String _eraLabel(Era era) {
    return switch (era) {
      Era.dumbledore => '邓布利多时代（1892-1899）：少年阿不思·邓布利多在霍格沃茨求学，认识盖勒特·格林德沃。',
      Era.marauders => '亲世代（1971-1978）：掠夺者四人组与莉莉·伊万斯同窗的时代。',
      Era.first_war => '第一次巫师战争（1970s后期）：社会氛围紧张，伏地魔崛起的阴影笼罩魔法界。',
      Era.harry_same => '子世代（1991-1998）：哈利·波特在霍格沃茨的求学时期。',
      Era.post_war => '现代（2020+）：战后重建的魔法世界，阿不思·波特与斯科皮·马尔福的时代。',
      Era.random => '随机时代：由叙事开始时随机决定。',
    };
  }

  // ==================== 初始化游戏 ====================
  Future<void> initializeGame({
    required String name,
    required String bloodStatus,
    required String birthLocation,
    required List<String> personalityTraits,
    String? gender,
    String? appearance,
    String? familyBackground,
    List<String>? childhoodExperiences,
    String? beliefs,
    String? wandId,
    String? petName,
    String? petId,
    String? sexOrientation,
    String? birthday,
    Map<String, int>? attributes,
    Map<String, int>? houseDimensions,
    String? initialTalent,
    String? magicAptitude,
    String? housePreference,
    String? politicalTendency,
    String? simulationStyle,
    String? birthIdentity,
  }) async {
    _isLoading = true;
    _error = null;
    _notifications.clear();
    notifyListeners();

    try {
      _systemPrompt = _buildSystemPrompt();
      final birthYear = _calculateBirthYear();
      final startHour = 9;
      final startMinute = 0;

      _player = Player(
        name: name,
        birthYear: birthYear,
        bloodType: bloodStatus,
        birthLocation: birthLocation,
        personalityTraits: personalityTraits,
        gender: gender ?? '',
        appearance: appearance,
        familyBackground: familyBackground,
        childhoodExperiences: childhoodExperiences ?? const [],
        beliefs: beliefs,
        wandId: wandId,
        petId: petId,
        petName: petName,
        sexOrientation: sexOrientation,
        birthDay: birthday,
        attributes: attributes,
        houseDimensions: houseDimensions,
        initialTalent: initialTalent,
        magicAptitude: magicAptitude,
        housePreference: housePreference,
        politicalTendency: politicalTendency,
        simulationStyle: simulationStyle,
        birthIdentity: birthIdentity,
      );

      _worldState = WorldState(
        era: appProvider.era.name,
        academicYear: _academicYearForEra(appProvider.era),
        time: GameTime(
          year: int.parse(birthYear),
          month: 9,
          day: 1,
          hour: startHour,
          minute: startMinute,
        ),
      );

      _initializeNPCsByEra();
      _assignInitialRelationships();
      await _generateOpeningScene();

      appProvider.setGameStarted(true);
      _isLoading = false;
      notifyListeners();
      _autoSave();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  String _academicYearForEra(Era era) {
    return switch (era) {
      Era.dumbledore => '1892-1893',
      Era.marauders => '1971-1972',
      Era.first_war => '1976-1977',
      Era.harry_same => '1991-1992',
      Era.post_war => '2020-2021',
      Era.random => '1991-1992',
    };
  }

  /// 按时代初始化 NPC（数据层 npc_data.dart）
  void _initializeNPCsByEra() {
    _npcRegistry.clear();
    final eraKey = _eraKey(appProvider.era);
    final seeds = eraNpcSeeds[eraKey] ?? [];

    for (final seed in seeds) {
      _npcRegistry[seed.id] = NPC(
        id: seed.id,
        name: seed.name,
        house: seed.house,
        grade: seed.grade,
        bloodStatus: seed.bloodStatus,
        isCanon: true,
        personality: List.of(seed.personality),
        appearance: seed.appearance,
        sexOrientation: seed.sexOrientation,
        giftPrefs: Map.of(seed.giftPrefs),
        personalGoal: seed.personalGoal,
        affection: _initialAffectionFor(seed),
        reputation: Reputation(
          academic: _roll(15, 45),
          social: _roll(15, 45),
          combat: _roll(10, 40),
          moral: _roll(20, 50),
          leadership: _roll(10, 40),
          dark: seed.era == 'dumbledore' || seed.id == 'grindelwald'
              ? _roll(30, 60)
              : _roll(0, 20),
        ),
      );
    }
  }

  String _eraKey(Era era) {
    return switch (era) {
      Era.dumbledore => 'dumbledore',
      Era.marauders => 'marauders',
      Era.first_war => 'marauders',
      Era.harry_same => 'harry_same',
      Era.post_war => 'post_war',
      Era.random => 'random',
    };
  }

  int _initialAffectionFor(NpcSeed seed) {
    if (seed.grade == 0) return _roll(0, 10);
    return _roll(0, 15);
  }

  int _roll(int min, int max) => min + _random.nextInt(max - min + 1);

  /// 建立玩家初始关系（同年级同学认识）
  void _assignInitialRelationships() {
    final p = _player;
    if (p == null) return;
    for (final npc in _npcRegistry.values) {
      if (npc.grade > 0 && npc.grade == (p.grade ?? 1)) {
        p.relationships[npc.id] = Relationship(
          targetId: npc.id,
          targetName: npc.name,
          relationType: '同学',
          level: 10,
        );
      }
    }
  }

  String _calculateBirthYear() {
    return switch (appProvider.era) {
      Era.dumbledore => '1881',
      Era.marauders => '1960',
      Era.first_war => '1965',
      Era.harry_same => '1980',
      Era.post_war => '2009',
      Era.random => '1980',
    };
  }

  

  // ==================== 生成开场场景 ====================
  Future<void> _generateOpeningScene() async {
    if (_player == null) return;

    final p = _player!;
    final wandData = p.wandId != null ? wandById(p.wandId!) : null;
    final wandInfo = wandData != null
        ? '${wandData.name}（${wandData.wood}·${wandData.core}·${wandData.length}，适合${wandData.suitType}）'
        : '玩家自选的魔杖';

    final petInfo = _buildPetDescription(p);
    final startPoint = _buildStartPointNarrative();

    final prompt = '''你是【哈利·波特·魔法纪元·世界模拟系统】的叙事者，风格如J.K.罗琳。

【玩家档案 - 必须全部融入叙事】
- 姓名：${p.name}
- 年龄：11岁
- 血统：${_bloodStatusLabel(p.bloodType)}
- 出生身份：${p.birthIdentity ?? '未设定'}
- 出生地：${p.birthLocation}
- 性格：${p.personalityTraits.join(', ')}
- 时代：${_eraLabel(appProvider.era)}
- 外貌：${p.appearance ?? '自行合理描述'}
- 家族背景：${p.familyBackground ?? '未设定'}
- 童年经历：${p.childhoodExperiences.isEmpty ? '无特殊经历' : p.childhoodExperiences.join('；')}
- 信仰：${p.beliefs ?? '未设定'}
- 魔法资质：${p.magicAptitude ?? '普通'}
- 初始天赋：${p.initialTalent ?? '未设定'}
- 学院倾向：${p.housePreference ?? '系统判定'}
- 政治倾向：${p.politicalTendency ?? '未设定'}
- 模拟风格：${p.simulationStyle ?? '混合模式'}
- 魔杖：$wandInfo
- 宠物：$petInfo

【剧情起点】$startPoint

【生成规则 - 必须全部遵守】
1. **必须**在叙事中自然融入：玩家的血统、家族背景、童年经历、魔杖、宠物
2. 宠物 $petInfo 必须在开场叙事中出现，描述玩家与它的关系
3. 魔杖 $wandInfo 必须被提及，比如作为生日礼物、家族传承或斜角巷的收获
4. 必须体现玩家的【性格特质】和【信仰】
5. 麻瓜出身：展示普通家庭日常生活，魔法觉醒的意外事件
6. 魔法/纯血家庭：巫师家庭日常，可能有家族传统或期望
7. 哑炮/默然者/狼人等特殊血统：展示其特殊处境
8. 只展示角色合理知道的信息
9. 不要让玩家自动成为主角
10. 根据模拟风格调整叙事基调
11. 保持魔法氛围，融入至少3个感官细节

【输出格式 - 严格遵守】
【叙事】
（300-500字沉浸叙事，融入上述所有玩家设定，包含≥3个感官细节）

【可选行动】
A. （选项1）
B. （选项2）
C. （选项3）
D. （可选）
【自由行动】''';

    if (_deepSeek == null) {
      _currentNarrative =
          '${p.name}，你在${p.birthLocation}长大，等待来自霍格沃茨的信已经等了很久。\n\n📅 ${_worldState.timestamp}\n\n魔法世界的大门即将为你打开。';
      _choices = [
        GameChoice(text: '等待猫头鹰送来的信', action: '等待猫头鹰送来的信'),
        GameChoice(text: '收拾行李，准备出发', action: '收拾行李，准备出发'),
        GameChoice(text: '再检查一遍霍格沃茨的入学清单', action: '再检查一遍霍格沃茨的入学清单'),
      ];
      return;
    }

    try {
      final response = await _callDeepSeek(prompt);
      _parseResponse(response);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _currentNarrative =
          '${p.name}，故事即将开始。请稍候，魔法正在酝酿。';
      _choices = [GameChoice(text: '继续', action: '继续')];
      notifyListeners();
    }
  }

  // ==================== 开场辅助：宠物描述 ====================
  String _buildPetDescription(Player p) {
    final petId = p.petId;
    final petName = p.petName ?? '';

    if (petId == null) return '未饲养宠物';

    final petData = {
      'owl': '$petName（送信、探索的好伙伴，聪明独立）',
      'cat': '$petName（神秘独立的小巫师，偶尔能预知危险）',
      'toad': '$petName（传统而忠诚的伙伴）',
      'rat': '$petName（小巧机灵，好奇心旺盛）',
      'kyuubi': _kyuubiPetDescription(),
    };

    return petData[petId] ?? '$petName（玩家的特殊伙伴）';
  }

  String _kyuubiPetDescription() {
    return '''九尾灵狐「绯月」（取自东方古国传说。传说中九尾狐乃青丘山上的祥瑞，化为人形时倾国倾城。
    她与玩家缔结契约后完全听命，擅长幻术、感知力极强，能化成人形陪伴左右。
    性格：温柔、忠诚、聪慧，对主人言听计从。能力：幻术/魅惑/预知/灵视''';
  }

  // ==================== 开场辅助：剧情起点 ====================
  String _buildStartPointNarrative() {
    // 可根据玩家选择或默认生成
    final starts = [
      '故事从你收到霍格沃茨录取通知书的那一刻开始——那只迟来的猫头鹰终于叩响了你的窗。',
      '故事从你站在九又四分之三站台前开始——蒸汽火车冒着白烟等待着你。',
      '故事从你第一次踏入霍格沃茨大礼堂开始——金色的烛光在长桌上方摇曳。',
      '故事从分院仪式前夜开始——你躺在床上翻来覆去，想着明天会被分到哪个学院。',
    ];
    return starts[_random.nextInt(starts.length)];
  }

  // ==================== 处理选择 / 指令 ====================
  Future<void> processChoice(GameChoice choice) async {
    if (_player == null) return;

    // 本地指令解析
    final action = choice.action.trim();
    if (action.startsWith('/')) {
      final handled = _handleLocalCommand(action);
      if (handled) {
        notifyListeners();
        _autoSave();
        return;
      }
    }

    if (_deepSeek == null) return;

    _isLoading = true;
    _turnCount++;
    notifyListeners();

    try {
      // 精简后的 prompt：只发关键状态，减少 token
      final attributesStr = _player!.attributes.entries
          .where((e) => e.value != 0)
          .map((e) => '${_attrLabel(e.key)}:${e.value}')
          .join(', ');

      String spellsStr = _player!.learnedSpells.isEmpty
          ? '无'
          : _player!.learnedSpells.entries
              .take(8)
              .map((e) => '${e.key}(Lv${e.value.level})')
              .join(', ');
      if (_player!.learnedSpells.length > 8) {
        spellsStr += ' 等${_player!.learnedSpells.length}个';
      }

      String invStr = _player!.inventory.isEmpty
          ? '空'
          : _player!.inventory.take(10).map((e) => e.name).join(', ');
      if (_player!.inventory.length > 10) invStr += ' 等${_player!.inventory.length}件';

      final npcStr = _formatAffections(maxEntries: 6);
      final recentEventsStr = _worldState.recentEvents.isEmpty
          ? '无'
          : _worldState.recentEvents.take(3).join('；');

      final prompt = '''继续游戏叙事。

【情境】
$_currentNarrative

【玩家】${_player!.name}｜${_bloodStatusLabel(_player!.bloodType)}｜${_player!.house ?? '未分院'}｜${_player!.grade}年级
性格：${_player!.personalityTraits.isEmpty ? '未设定' : _player!.personalityTraits.join('、')}
${_player!.magicAptitude ?? '普通'}天赋｜倾向：${_player!.politicalTendency ?? '未设定'}
状态 HP:${_player!.health}/MP:${_player!.magic}/SP:${_player!.spirit}/精力:${_player!.energy}
属性：$attributesStr
魔咒：$spellsStr
物品：$invStr

【当前】${_worldState.timestamp}｜学年${_worldState.academicYear}｜${_worldState.currentLocation ?? '未知'}｜${_worldState.weather ?? '晴朗'}
学院积分：${_worldState.housePoints.entries.map((e) => '${_houseLabel(e.key)}${e.value}').join('·')}

【关系】$npcStr
【事件】$recentEventsStr

【玩家行动】
$action

【要求】
1. 叙事 200-400字，必须包含≥3个感官细节
2. 开头附时间戳
3. 体现玩家【性格特质】和【血统】
4. NPC有独立人格，不围着玩家转
5. 每回合更新【好感度变化】小节（对话+1~2，冲突-3~-1，事件梯度）
6. 不强行把玩家塞进原著事件

【输出格式 - 必须严格】
【叙事】
（200-400字，含≥3感官细节）

【好感度变化】
NPC名: ±X（原因）

【可选行动】
A. （具体行动）
B. （具体行动）
C. （具体行动）
D. （可选）

【自由行动】（玩家可输入任何合理行为）''';

      final response = await _callDeepSeek(prompt);
      _parseResponse(response);
      _advanceTimeForAction(action);
      _updateNPCsFromAction(action);
      _isLoading = false;
      notifyListeners();
      _autoSave();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 本地指令解析（设定文档第X部分指令系统）
  bool _handleLocalCommand(String command) {
    final p = _player;
    if (p == null) return false;
    final parts = command.split(RegExp(r'\s+'));
    final cmd = parts[0];

    switch (cmd) {
      case '/状态':
        _currentNarrative = _formatStatus();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/时间':
        _currentNarrative = _formatTime();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/地图':
        _currentNarrative = _formatMap();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/通知':
        _currentNarrative = _formatNotifications();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/帮助':
        _currentNarrative = _formatHelp();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/关系':
        _currentNarrative = _formatRelationships();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/恋爱':
        _currentNarrative = _formatLove();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/声望':
        _currentNarrative = _formatReputation();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/课程':
        _currentNarrative = _formatCourses();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/收藏':
        _currentNarrative = _formatCollection();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/日记':
        _currentNarrative = _formatDiary();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/档案':
        _currentNarrative = _formatArchive();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/成就':
        _currentNarrative = _formatAchievements();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/宠物':
        _currentNarrative = _formatPet();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/信':
        _currentNarrative = _formatLetters();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/血缘':
        _currentNarrative = _formatBloodRelatives();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/联动':
        _currentNarrative = '【联动系统】\n当前时代：${_eraLabel(appProvider.era)}\n'
            '联动系统允许你在特定节点与其他时代剧情产生关联（例如在子世代时遇到亲世代留下的物品或信件）。\n'
            '当前已触发的联动痕迹：\n${_worldState.timelineBranches.isEmpty ? '暂无。' : _worldState.timelineBranches.map((b) => '· $b').join('\n')}';
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/世界演化':
        _currentNarrative = _formatWorldEvolution();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/新NPC':
        _generateNewNPC();
        return true;

      case '/cheat':
        _handleCheat(parts);
        return true;
    }
    return false;
  }

  // ==================== 作弊指令（设定 8.1-8.5） ====================
  void _handleCheat(List<String> parts) {
    final p = _player;
    if (p == null) return;
    if (parts.length < 2) {
      _currentNarrative = _formatCheatHelp();
      _choices = [GameChoice(text: '返回', action: '继续')];
      return;
    }
    final sub = parts[1];

    switch (sub) {
      case '好感':
      case 'affection':
        if (parts.length >= 4) {
          final npc = _npcRegistry.values
              .firstWhere((n) => n.name.contains(parts[2]),
                  orElse: () => _npcRegistry[parts[2]] ?? _npcRegistry.values.first);
          final delta = int.tryParse(parts[3]);
          if (delta != null) {
            npc.affection = (npc.affection + delta).clamp(-100, 100);
            _currentNarrative = '已调整「${npc.name}」的好感度：${npc.affection}（${npc.affectionStage}）';
          }
        }
        break;

      case '资源':
      case 'resources':
        if (parts.length >= 4) {
          final amount = int.tryParse(parts[2]) ?? 0;
          switch (parts[3]) {
            case '魔力':
            case 'mp':
              p.magic = (p.magic + amount).clamp(0, 100);
              break;
            case '精神力':
            case 'sp':
              p.spirit = (p.spirit + amount).clamp(0, 100);
              break;
            case '饱食':
            case 'sat':
              p.satiety = (p.satiety + amount).clamp(0, 100);
              break;
            case '精力':
            case 'energy':
              p.energy = (p.energy + amount).clamp(0, 100);
              break;
            case '生命':
            case 'hp':
              p.health = (p.health + amount).clamp(0, 100);
              break;
          }
          _currentNarrative = '资源已调整。';
        }
        break;

      case '声望':
      case 'reputation':
        if (parts.length >= 4) {
          final amount = int.tryParse(parts[2]) ?? 0;
          p.playerReputation.add(parts[3], amount);
          _currentNarrative =
              '${p.playerReputation.labelOf(parts[3])} ${p.playerReputation.get(parts[3])}';
        }
        break;

      case '时间':
      case 'time':
        if (parts.length >= 3) {
          final days = int.tryParse(parts[2]);
          if (days != null) _fastForwardTime(days);
          _currentNarrative = '时间已推进 $days 天。\n${_worldState.timestamp}';
        }
        break;

      case '骨科':
        if (parts.length >= 3 && parts[2] == '无视') {
          p.boneMode = true;
          _currentNarrative =
              '【骨科模式已开启】三代内血亲的禁忌限制已解除，但这意味着你的选择将付出更沉重的代价。';
        } else {
          _currentNarrative = '使用方式：/cheat 骨科 无视（开启骨科模式）';
        }
        break;

      case '解锁CG':
      case 'cg':
        if (parts.length >= 3) {
          final cg = cgById(parts[2]);
          if (cg != null) {
            _unlockCG(cg);
            _currentNarrative = '已解锁 CG：${cg.name}';
          } else {
            _currentNarrative = '未找到该 CG，可用：${allCgs().map((c) => c.id).take(10).join(', ')}...';
          }
        }
        break;

      default:
        _currentNarrative = _formatCheatHelp();
    }
    _choices = [GameChoice(text: '返回', action: '继续')];
  }

  String _formatCheatHelp() {
    return '''【作弊指令】
/cheat 好感 <NPC名> <数值>  — 调整好感度
/cheat 资源 <数值> <魔力|精神力|饱食|精力|生命>
/cheat 声望 <数值> <academic|social|combat|moral|leadership|dark>
/cheat 时间 <天数>
/cheat 骨科 无视 — 开启骨科模式
/cheat 解锁CG <CG编号> — 解锁指定CG''';
  }

  // ==================== 生成新NPC ====================
  void _generateNewNPC() {
    final p = _player;
    if (p == null) return;

    final count = _npcRegistry.values.where((n) => n.isGenerated).length;
    if (count >= 4) {
      _currentNarrative = '新NPC数量已达到上限（每学年最多新增4位）。';
      _choices = [GameChoice(text: '返回', action: '继续')];
      return;
    }

    const surnames = ['布莱克', '隆巴顿', '洛夫古德', '迪戈里', '波特', '马尔福', '沙比尼', '韦斯莱', '克鲁姆', '安德森'];
    const givenMale = ['西奥多', '塞巴斯蒂安', '艾德里安', '卡斯珀', '伊万', '诺亚', '奥利弗', '利奥'];
    const givenFemale = ['塞西莉亚', '艾拉', '薇奥拉', '罗莎琳', '埃洛伊斯', '伊莎贝拉', '莉莉安', '海伦娜'];
    final isMale = _random.nextBool();
    final name = '${isMale ? givenMale[_random.nextInt(givenMale.length)] : givenFemale[_random.nextInt(givenFemale.length)]}·${surnames[_random.nextInt(surnames.length)]}';
    final houses = ['Gryffindor', 'Slytherin', 'Ravenclaw', 'Hufflepuff'];
    final house = houses[_random.nextInt(houses.length)];
    final id = 'generated_${DateTime.now().millisecondsSinceEpoch}';
    final grade = p.grade ?? 1;

    final npc = NPC(
      id: id,
      name: name,
      house: house,
      grade: grade,
      bloodStatus: 'unknown',
      personality: ['友善', '独立'],
      appearance: '一位来自${house == 'Gryffindor' ? '格兰芬多' : house == 'Slytherin' ? '斯莱特林' : house == 'Ravenclaw' ? '拉文克劳' : '赫奇帕奇'}的${isMale ? '男' : '女'}生，面容${isMale ? '俊朗' : '清秀'}，眼神里带着好奇。',
      sexOrientation: isMale ? '女' : '男',
      affection: _roll(5, 15),
      isGenerated: true,
      generatedProfile: '新生，与你同年级，来自$house。',
    );

    _npcRegistry[id] = npc;
    p.relationships[id] = Relationship(
      targetId: id,
      targetName: name,
      relationType: '同学',
      level: 10,
    );
    _notifications.add('📬 新同学加入了你的圈子：$name');
    _currentNarrative =
        '一位新的同学出现在霍格沃茨的走廊里——$name，来自$house学院。也许你们会有一段值得书写的故事。\n\n'
        '（你可以继续探索，或与这位新同学互动）';
    _choices = [
      GameChoice(text: '上前与新同学打招呼', action: '上前与新同学打招呼'),
      GameChoice(text: '保持距离，观察一下', action: '保持距离，观察一下'),
    ];
  }

  int _calculateAge() {
    final p = _player;
    if (p == null) return 11;
    try {
      final birthYear = int.parse(p.birthYear);
      return _worldState.time.year - birthYear;
    } catch (_) {
      return 11;
    }
  }

  int _playerGold() {
    // 金加隆暂以背包中是否拥有金币物品判定
    final hasGold = _player?.inventory.any((e) => e.name.contains('加隆') || e.name.contains('金币')) ?? false;
    return hasGold ? 1 : 0;
  }

  // ==================== 指令格式化 ====================
  String _formatStatus() {
    final p = _player!;
    final w = _worldState;
    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  《哈利·波特·魔法纪元·人生状态》')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln()
      ..writeln('【时间】${w.timestamp}')
      ..writeln('【年龄】${_calculateAge()}岁')
      ..writeln('【血统】${_bloodStatusLabel(p.bloodType)}')
      ..writeln('【身份】${p.birthIdentity ?? '未设定'}')
      ..writeln('【所在地】${w.currentLocation ?? '未知'}')
      ..writeln('【学院】${p.house ?? '未分院'} · ${p.grade ?? 1}年级')
      ..writeln('【职业】${p.initialTalent ?? '学生'}')
      ..writeln('【财富】💰 ${_playerGold()}金加隆')
      ..writeln('【家庭】${p.familyBackground ?? '未设定'}')
      ..writeln('【社会地位】学院声望${p.houseReputation} · 魔法界声望${p.wizardingReputation} · 阵营声望${p.factionReputation}')
      ..writeln()
      ..writeln('【生存状态】')
      ..writeln('❤️ 生命：${p.health}/100')
      ..writeln('🔮 魔力：${p.magic}/100')
      ..writeln('🧠 精神力：${p.spirit}/100')
      ..writeln('🍗 饱食度：${p.satiety}/100')
      ..writeln('⚡ 精力：${p.energy}/100')
      ..writeln()
      ..writeln('【魔法能力】')
      ..writeln('魔法资质：${p.magicAptitude ?? '普通'}')
      ..writeln('主修天赋：${p.initialTalent ?? '未设定'}')
      ..writeln('已学魔咒：${p.learnedSpells.isEmpty ? '尚未学会任何魔咒' : '${p.learnedSpells.length}个咒语'}')
      ..writeln()
      ..writeln('【学院四维】')
      ..writeln('勇气：${p.houseDimensions['courage']}  智慧：${p.houseDimensions['wisdom']}')
      ..writeln('忠诚：${p.houseDimensions['loyalty']}  野心：${p.houseDimensions['ambition']}')
      ..writeln()
      ..writeln('【政治倾向】${p.politicalTendency ?? '未设定'}')
      ..writeln('【模拟风格】${p.simulationStyle ?? '混合模式'}')
      ..writeln('【恋爱状态】${p.loveState.status}${p.loveState.partnerName != null ? '（${p.loveState.partnerName}）' : ''}')
      ..writeln('【世界线变动率】${(p.worldLineDeviation * 100).toStringAsFixed(1)}%')
      ..writeln()
      ..writeln('【当前目标】${p.currentGoal ?? '尚未设定目标'}');
    return buf.toString();
  }

  String _formatTime() {
    final w = _worldState;
    return '【当前时间】\n${w.timestamp}\n'
        '学年：${w.academicYear}\n'
        '学期：${_termLabel(w.term)}\n'
        '流速模式：${_flowModeLabel(w.timeFlowMode)}\n'
        '${w.specialMarkers.isEmpty ? '' : '特殊标记：${w.specialMarkers.join(' ')}'}';
  }

  String _formatMap() {
    return '''【霍格沃茨地图】
当前地点：${_worldState.currentLocation ?? '九又四分之三站台 / 霍格沃茨特快'}

已知区域：
🏰 城堡主楼（大礼堂、各学院公共休息室、图书馆、教室）
🧙 各学院公共休息室
🌳 禁林（高年级或特定课程开放）
🧪 地下教室（魔药学、斯莱特林公共休息室）
🏟️ 魁地奇球场
🏘️ 霍格莫德村（周末开放）
🧹 天文塔
📚 图书馆（含禁书区）

各NPC当前位置：
${_npcRegistry.values.where((n) => n.isAlive).take(6).map((n) => '· ${n.name}：${n.currentLocation}').join('\n')}''';
  }

  String _formatNotifications() {
    if (_notifications.isEmpty) {
      return '【通知】\n暂无新通知。';
    }
    return '【通知】\n${_notifications.reversed.take(10).map((n) => '· $n').join('\n')}';
  }

  String _formatHelp() {
    return '''【指令系统】
/状态 — 查看角色完整状态
/时间 — 查看当前时间与特殊标记
/地图 — 查看霍格沃茨地图与NPC位置
/通知 — 查看未读通知
/帮助 — 查看指令说明
/关系 — 查看所有NPC好感度与关系
/恋爱 — 查看恋爱状态
/声望 — 查看声望档案
/课程 — 查看课程表与进度
/收藏 — 查看收藏品
/日记 — 查看CG图鉴与日记
/档案 — 查看角色完整档案
/成就 — 查看成就
/宠物 — 查看宠物状态
/信 — 查看收到的信件
/新NPC — 生成一位新NPC（每学年限4次）
/血缘 — 查看血缘亲属
/联动 — 查看时代联动痕迹
/cheat — 作弊指令（详见 /cheat）''';
  }

  String _formatRelationships() {
    if (_npcRegistry.isEmpty) return '暂无认识的人。';
    final buf = StringBuffer('【关系列表】\n');
    final list = _npcRegistry.values.where((n) => n.isAlive).toList()
      ..sort((a, b) => b.affection.compareTo(a.affection));
    for (final n in list.take(15)) {
      buf.writeln('· ${n.name}：好感 ${n.affection}（${n.affectionStage}）');
    }
    return buf.toString();
  }

  String _formatLove() {
    final love = _player!.loveState;
    if (love.status == '单身') {
      return '【恋爱状态】单身\n'
          '${_formatHighAffectionHints()}';
    }
    return '【恋爱状态】${love.status}\n'
        '对象：${love.partnerName}\n'
        '${love.history.isEmpty ? '' : '恋爱历程：\n${love.history.map((h) => '· ${h['date']}：${h['event']}').join('\n')}'}';
  }

  String _formatHighAffectionHints() {
    final hints = _npcRegistry.values
        .where((n) => n.affection >= 70 && n.isAlive && !n.confessed)
        .map((n) => '· ${n.name}（好感 ${n.affection}）${n.isConsideringConfession ? '—— 似乎正在酝酿着什么……' : ''}')
        .toList();
    if (hints.isEmpty) return '还没有人对你表现出特别的好感。';
    return '对你有较高好感的NPC：\n${hints.join('\n')}';
  }

  String _formatReputation() {
    final rep = _player!.playerReputation;
    final p = _player!;
    return '''【声望档案】
学术声望：${rep.academic}（${reputationGrade(rep.academic)}）
社交声望：${rep.social}（${reputationGrade(rep.social)}）
战斗声望：${rep.combat}（${reputationGrade(rep.combat)}）
道德声望：${rep.moral}（${reputationGrade(rep.moral)}）
领导声望：${rep.leadership}（${reputationGrade(rep.leadership)}）
黑魔法声望：${rep.dark}（${reputationGrade(rep.dark)}）

学院声望：${p.houseReputation}
魔法界声望：${p.wizardingReputation}
阵营声望：${p.factionReputation}''';
  }

  String _formatCourses() {
    final buf = StringBuffer('【课程系统】\n必修课：\n');
    for (final c in requiredCourses) {
      buf.writeln('· ${c.name}（${c.professor}）');
    }
    buf.writeln('\n选修课（三年级起，至少选2门）：');
    for (final c in electiveCourses) {
      buf.writeln('· ${c.name}（${c.professor}）');
    }
    return buf.toString();
  }

  String _formatCollection() {
    if (_player!.collection.isEmpty) {
      return '【收藏】\n暂无收藏品。在冒险中收集独特物品，如巧克力蛙画片、日记本等。';
    }
    return '【收藏】\n${_player!.collection.map((c) => '· $c').join('\n')}';
  }

  String _formatDiary() {
    if (_player!.cgRecords.isEmpty) {
      return '【日记 / CG图鉴】\n暂无解锁CG。在关键剧情节点将解锁专属CG。';
    }
    return '【日记 / CG图鉴】（已解锁 ${_player!.cgRecords.length}/36）\n'
        '${_player!.cgRecords.values.map((c) => '· ${c.cgId} ${c.name}（${c.unlockedDate}）').join('\n')}';
  }

  String _formatArchive() {
    final p = _player!;
    return '''【角色完整档案】
姓名：${p.name}｜性别：${p.gender.isEmpty ? '未设定' : p.gender}
生日：${p.birthDay ?? '未设定'}｜出生年份：${p.birthYear}
血统：${_bloodStatusLabel(p.bloodType)}｜出生地：${p.birthLocation}
学院：${p.house ?? '未分院'}｜年级：${p.grade ?? 1}
性取向：${p.sexOrientation ?? '未设定'}
魔杖：${p.wandId != null ? wandById(p.wandId!)?.name ?? p.wandId : '未选择'}
宠物：${p.petName ?? '无'}
外貌：${p.appearance ?? '未设定'}
家族背景：${p.familyBackground ?? '未设定'}
童年经历：${p.childhoodExperiences.isEmpty ? '未设定' : p.childhoodExperiences.join('；')}
信仰与价值观：${p.beliefs ?? '未设定'}
初始天赋：${p.initialTalent ?? '未设定'}
性格特质：${p.personalityTraits.isEmpty ? '未设定' : p.personalityTraits.join('、')}
当前目标：${p.currentGoal ?? '无'}''';
  }

  String _formatAchievements() {
    final unlocked = _player!.achievements;
    final catalog = achievementCatalog;
    final buf = StringBuffer('【成就】（${unlocked.length}/${catalog.length}）\n');
    for (final a in catalog) {
      final has = unlocked.contains(a.id);
      buf.writeln('${has ? '✅' : '🔒'} ${a.name}${has ? ' — ${a.description}' : ''}');
    }
    return buf.toString();
  }

  String _formatPet() {
    final p = _player!;
    if (p.petId == null && p.petName == null) {
      return '【宠物】\n你还没有宠物。可以去对角巷挑选一只猫头鹰、猫或蟾蜍。';
    }
    return '【宠物】\n名字：${p.petName ?? '未命名'}\n羁绊：${p.petBond}/100\n宠物可以帮你送信、在冒险中提供帮助。';
  }

  String _formatLetters() {
    if (_player!.letters.isEmpty) {
      return '【信件】\n暂无信件。';
    }
    return '【信件】\n${_player!.letters.map((l) => '· ${l.sender}（${l.date}）：${l.content.length > 30 ? '${l.content.substring(0, 30)}…' : l.content}').join('\n')}';
  }

  String _formatBloodRelatives() {
    if (_player!.bloodRelatives.isEmpty) {
      return '【血缘】\n未设定血缘亲属关系。三代内血亲不可攻略（除非开启骨科模式）。';
    }
    return '【血缘】\n${_player!.bloodRelatives.join('、')}\n${_player!.boneMode ? '（骨科模式已开启，禁忌限制解除）' : '（三代内血亲不可攻略）'}';
  }

  /// 月度世界演化报告（第47章）
  String _formatWorldEvolution() {
    final w = _worldState;
    final eraName = _eraLabel(appProvider.era);
    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  《月度世界演化报告》')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln()
      ..writeln('【当前时代】$eraName')
      ..writeln('【时间】${w.timestamp}')
      ..writeln('【学年】${w.academicYear}')
      ..writeln()
      ..writeln('【九大文明支柱状态】');
    for (int i = 0; i < kCivilizationPillars.length; i++) {
      buf.writeln('  ${i + 1}. ${kCivilizationPillars[i]}');
    }
    buf
      ..writeln()
      ..writeln('【世界五层结构】');
    for (final layer in kWorldLayers) {
      buf.writeln('  $layer');
    }
    buf
      ..writeln()
      ..writeln('【区域危险度】');
    for (final zone in kDangerZones) {
      buf.writeln('  $zone');
    }
    buf
      ..writeln()
      ..writeln('【货币体系】$kCurrencyRate')
      ..writeln()
      ..writeln('【当前地点】${w.currentLocation ?? '未知'}')
      ..writeln('【天气】${w.weather ?? '晴朗'}')
      ..writeln()
      ..writeln('【近期世界事件】')
      ..writeln(w.recentEvents.isEmpty ? '暂无记录' : w.recentEvents.map((e) => '· $e').join('\n'))
      ..writeln()
      ..writeln('【世界线变动率】${(_player?.worldLineDeviation ?? 0) * 100}%')
      ..writeln()
      ..writeln('【终极原则】');
    for (final principle in kUltimatePrinciples) {
      buf.writeln('  $principle');
    }
    return buf.toString();
  }

  String _formatAffections({int maxEntries = 8}) {
    final list = _player == null
        ? const <NPC>[]
        : _npcRegistry.values
            .where((n) => n.affection.abs() >= 30 || _player!.relationships.containsKey(n.id))
            .toList()
          ..sort((a, b) => b.affection.compareTo(a.affection));
    if (list.isEmpty) return '暂无深入关系';
    final entries = list.take(maxEntries).map((n) => '${n.name}(${n.affection})').join('、');
    if (list.length > maxEntries) return '$entries 等${list.length}人';
    return entries;
  }

  // ==================== NPC 主动表白机制 ====================
  void checkNPCConfessions() {
    final p = _player;
    if (p == null || p.loveState.status != '单身') return;
    if (p.loveState.awaitingConfession) return;

    // 候选：好感≥85、未表白过、性取向匹配（未指定取向的NPC可向任意性别表白）
    final candidates = _npcRegistry.values.where((n) {
      if (!n.isAlive || n.affection < 85 || n.confessed) return false;
      if (n.sexOrientation != null && n.sexOrientation != p.sexOrientation) {
        return false;
      }
      return true;
    }).toList();

    if (candidates.isEmpty) return;

    // 概率触发：每轮20%概率有NPC酝酿表白
    if (_random.nextDouble() > 0.2) {
      // 仍可标记"正在考虑"
      final npc = candidates[_random.nextInt(candidates.length)];
      npc.isConsideringConfession = true;
      return;
    }

    final npc = candidates[_random.nextInt(candidates.length)];
    npc.isConsideringConfession = true;
    npc.isAlive = true;

    final originalNarrative = _currentNarrative;
    _currentNarrative =
        (originalNarrative.isEmpty ? '' : '$originalNarrative\n\n') +
            '${npc.name}走到你面前，深深吸了一口气，像是下了很大的决心。\n\n'
            '"${p.name}，我有话想对你说……" 他/她低着头，声音有些颤抖。'
            '月光洒在走廊上，一切仿佛都静止了。\n\n'
            '【${npc.name}的表白】\n'
            '"我喜欢你。从很久以前就开始了。如果你愿意，我想和你在一起。"\n\n'
            '你的心跳漏了一拍。';
    _choices = [
      GameChoice(text: '接受这份心意', action: '接受${npc.name}的表白'),
      GameChoice(text: '婉拒，但保持朋友关系', action: '婉拒${npc.name}，希望保持朋友关系'),
    ];
    p.loveState.awaitingConfession = true;
    p.loveState.consideringNpcName = npc.name;
  }

  /// 处理表白回应
  void resolveConfession(bool accepted, String npcName) {
    final p = _player;
    if (p == null) return;
    final npc = _npcRegistry.values
        .firstWhere((n) => n.name == npcName, orElse: () => _npcRegistry.values.first);
    npc.confessed = true;
    npc.isConsideringConfession = false;
    p.loveState.awaitingConfession = false;
    p.loveState.consideringNpcName = null;

    if (accepted) {
      p.loveState.status = '恋爱';
      p.loveState.partnerId = npc.id;
      p.loveState.partnerName = npc.name;
      p.loveState.history.add({
        'date': _worldState.timestamp,
        'event': '接受了${npc.name}的表白',
      });
      _unlockCG(cgById('CG-010'));
      _unlockCG(cgById('CG-CF-001'));
      _notifications.add('💕 你与${npc.name}开始了恋爱！');
      _currentNarrative =
          '你点了点头，${npc.name}的眼睛瞬间亮了起来，像被月光点亮。\n\n'
          '他/她握住你的手，声音里带着掩饰不住的喜悦："真的吗？太好了……"\n\n'
          '你们在月色下相视而笑，霍格沃茨的钟声在远处敲响，仿佛在为这段感情祝福。';
    } else {
      npc.affection -= 5;
      _unlockCG(cgById('CG-CF-002'));
      _currentNarrative =
          '你温和地摇了摇头。${npc.name}的眼神黯淡了一下，但很快挤出一个微笑。\n\n'
          '"我明白了……那我们，还是朋友吧？"\n\n'
          '他/她松开手，向你露出一个勉强却真心的笑容。月光依旧明亮，只是空气里多了一丝惆怅。';
    }
    _choices = [GameChoice(text: '继续', action: '继续')];
  }
  // ==================== 时间格式化 ====================
  String _formatDate() {
    final t = _worldState.time;
    final year = t.year;
    final month = _worldState.month;
    final day = _worldState.dayOfMonth;
    final weekday = _worldState.dayOfWeek;
    final hour = t.hour.toString().padLeft(2, '0');
    final minute = t.minute.toString().padLeft(2, '0');
    return '📅 $year年$month$day日，$weekday，[$hour:$minute]';
  }


  // ==================== CG 解锁 ====================
  void _unlockCG(CgDef? cg) {
    final p = _player;
    if (cg == null || p == null) return;
    if (p.cgRecords.containsKey(cg.id)) return;
    p.cgRecords[cg.id] = CgRecord(
      cgId: cg.id,
      name: cg.name,
      unlockedDate: _formatDate(),
      chapter: cg.chapter,
    );
    _notifications.add('📸 解锁CG：${cg.name}');
  }

  // ==================== 时间推进 ====================
  void _advanceTimeForAction(String action) {
    int minutes = 15;
    if (action.contains('吃饭') || action.contains('用餐') || action.contains('早餐') || action.contains('午餐') || action.contains('晚餐')) {
      minutes = 30;
    } else if (action.contains('上课') || action.contains('听课') || action.contains('教室')) {
      minutes = 90;
    } else if (action.contains('图书馆') || action.contains('自习') || action.contains('学习') || action.contains('看书')) {
      minutes = 120;
    } else if (action.contains('魁地奇') || action.contains('训练')) {
      minutes = 120;
    } else if (action.contains('霍格莫德')) {
      minutes = 300;
    } else if (action.contains('禁林')) {
      minutes = 180;
    } else if (action.contains('睡觉') || action.contains('休息') || action.contains('就寝')) {
      minutes = 480;
    } else if (action.contains('对话') || action.contains('聊天') || action.contains('交谈') || action.contains('打招呼')) {
      minutes = 10;
    } else if (action.contains('探索') || action.contains('闲逛') || action.contains('散步')) {
      minutes = 60;
    }
    _worldState.time.advanceMinutes(minutes);

    // 深夜触发满月标记
    if (_worldState.time.isFullMoon && !_worldState.specialMarkers.contains('🌙满月')) {
      _worldState.specialMarkers.add('🌙满月');
    } else if (!_worldState.time.isFullMoon) {
      _worldState.specialMarkers.remove('🌙满月');
    }

    // 同步旧字段
    _worldState.dayOfMonth = _worldState.time.day;
    _worldState.dayOfWeek = GameTime.weekdays[_worldState.time.weekday];
    _worldState.month = GameTime.months[_worldState.time.month - 1];
  }

  void _fastForwardTime(int days) {
    for (int i = 0; i < days; i++) {
      _worldState.time.advanceMinutes(24 * 60);
    }
    _worldState.dayOfMonth = _worldState.time.day;
    _worldState.dayOfWeek = GameTime.weekdays[_worldState.time.weekday];
    _worldState.month = GameTime.months[_worldState.time.month - 1];
  }

  // ==================== NPC 状态更新 ====================
  void _updateNPCsFromAction(String action) {
    // 消耗资源
    final p = _player!;
    p.energy = max(0, p.energy - 5);
    p.satiety = max(0, p.satiety - 3);
    p.spirit = max(0, p.spirit - 2);

    if (action.contains('吃饭') || action.contains('用餐')) {
      p.satiety = min(100, p.satiety + 25);
    }
    if (action.contains('睡觉') || action.contains('休息')) {
      p.energy = min(100, p.energy + 40);
      p.spirit = min(100, p.spirit + 20);
    }

    // 每日随机触发好感微调
    for (final npc in _npcRegistry.values) {
      if (npc.affection > 0 && _random.nextDouble() < 0.05) {
        npc.affection = (npc.affection + 1).clamp(-100, 100);
      }
    }

    // 检测表白时机（恋爱剧情推进时）
    if (p.loveState.status == '恋爱' && _random.nextDouble() < 0.1) {
      _spawnRomanticEvent();
    }
  }

  void _spawnRomanticEvent() {
    final p = _player;
    final partner = p?.loveState.partnerId;
    if (partner == null) return;
    final npc = _npcRegistry[partner];
    if (npc == null) return;

    _notifications.add('💕 与${npc.name}之间发生了一段浪漫插曲。');
  }

  // ==================== 快速推进 ====================
  Future<void> fastForward(int days) async {
    _isLoading = true;
    notifyListeners();
    _fastForwardTime(days);
    _isLoading = false;
    notifyListeners();
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
      'affection': npc.affection,
      'affectionStage': npc.affectionStage,
      'appearance': npc.appearance,
      'relationship': rel != null
          ? {'type': rel.relationType, 'level': rel.level}
          : null,
      'personality': npc.personality,
      'knowsAbout': npc.knowsAbout.take(3).toList(),
      'reputation': npc.reputation,
    };
  }

  bool _isNPCVisible(NPC npc) {
    if (_player == null) return false;
    if (_player!.relationships.containsKey(npc.id)) return true;
    if (npc.house == _player!.house) return true;
    if (npc.isCanon && _worldState.playerImpactScore > 0.5) return true;
    return false;
  }

  bool isNearby(String npcId) {
    final npc = _npcRegistry[npcId];
    if (npc == null || _player == null) return false;
    return npc.currentLocation == (_worldState.currentLocation ?? '');
  }

  int getAffection(String npcId) {
    final rel = _player?.relationships[npcId];
    if (rel != null) return rel.level;
    final npc = _npcRegistry[npcId];
    return npc?.affection ?? 0;
  }

  void travelTo(String location) {
    _worldState.currentLocation = location;
    notifyListeners();
  }

  // ==================== 好感度操作（供UI调用） ====================
  void adjustAffection(String npcId, int delta) {
    final npc = _npcRegistry[npcId];
    if (npc == null) return;
    npc.affection = (npc.affection + delta).clamp(-100, 100);
    _checkLocks(npc);
    _syncRelationshipLevel(npc);
    notifyListeners();
  }

  void _checkLocks(NPC npc) {
    if (npc.affection >= 50 && !npc.hasLock('信任锁')) {
      npc.affectionLocks.add('信任锁');
    }
    if (npc.affection >= 70 && !npc.hasLock('情感锁')) {
      npc.affectionLocks.add('情感锁');
    }
  }

  void _syncRelationshipLevel(NPC npc) {
    final p = _player;
    if (p == null) return;
    final rel = p.relationships[npc.id];
    if (rel != null) {
      rel.level = npc.affection.clamp(0, 100);
    }
  }

  // ==================== DeepSeek 调用 ====================
  Future<String> _callDeepSeek(String prompt) async {
    if (_deepSeek == null) throw Exception('API Key 未设置');
    final result = await _deepSeek!.chatComplete(
      prompt: prompt,
      systemPrompt: _systemPrompt ?? '',
      temperature: 0.8,
      maxTokens: 6000,
    );
    _totalPromptTokens += result.usage.promptTokens;
    _totalCompletionTokens += result.usage.completionTokens;
    _totalTokens += result.usage.totalTokens;
    _apiCalls++;
    notifyListeners();
    return result.content;
  }

  // ==================== 解析响应 ====================
  void _parseResponse(String text) {
    final lines = text.split('\n');
    _currentNarrative = '';
    _choices = [];
    bool inNarrative = false;

    // Pass 1: Try structured parsing with explicit markers
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == '【叙事】') {
        inNarrative = true;
        continue;
      } else if (trimmed.startsWith('【可选行动】') ||
          trimmed.startsWith('【自由行动】') ||
          trimmed.startsWith('【好感度变化】') ||
          trimmed.startsWith('【声望变化】')) {
        inNarrative = false;
        continue;
      }
      if (inNarrative) {
        if (trimmed.isNotEmpty) {
          _currentNarrative += '$trimmed\n';
        }
      } else if (_reChoiceOption.hasMatch(trimmed)) {
        final action =
            trimmed.replaceFirst(_reChoiceOption, '').trim();
        if (action.isNotEmpty) {
          _choices.add(GameChoice(text: action, action: action));
        }
      }
    }

    // Pass 2: If narrative is empty or too short (< 20 chars), try
    // to extract from raw text before choices
    if (_currentNarrative.isEmpty || _currentNarrative.length < 20) {
      _extractNarrativeFromRawText(text);
    }

    _currentNarrative = _currentNarrative
        .replaceAll(_reMultiNewline, '\n\n')
        .trim();

    // Pass 3: If still empty, generate a fallback narrative
    if (_currentNarrative.isEmpty) {
      _currentNarrative = _generateFallbackNarrative();
    }

    // Parse affection changes
    _parseAffectionChanges(text);

    // Parse reputation changes
    _parseReputationChanges(text);

    if (_choices.isEmpty) {
      _choices.addAll(_generateFallbackChoices());
    }

    // Check NPC confessions every turn
    checkNPCConfessions();
  }

  void _extractNarrativeFromRawText(String text) {
    var cleaned = text;

    cleaned = cleaned.replaceAllMapped(_reAffectionSection, (m) => '');
    cleaned = cleaned.replaceAllMapped(_reReputationSection, (m) => '');

    final choiceMatch = _reChoiceMultiLine.firstMatch(cleaned);
    if (choiceMatch != null) {
      cleaned = cleaned.substring(0, choiceMatch.start);
    } else {
      cleaned = cleaned.split('\n\n').first;
    }

    cleaned = cleaned
        .replaceAll(_reSectionMarkers, '')
        .replaceAll(RegExp(r'\n{2,}'), '\n\n')
        .trim();

    if (cleaned.isNotEmpty && cleaned.length > 10) {
      _currentNarrative = cleaned;
    }
  }

  String _generateFallbackNarrative() {
    final p = _player;
    if (p == null) return '你站在霍格沃茨的走廊上，等待着下一段旅程。';

    final location = _worldState.currentLocation ?? '霍格沃茨';
    final time = _worldState.timestamp;
    final weather = _worldState.weather ?? '晴朗';

    final fallbacks = [
      '📅 $time\n\n你在$location，感受着魔法世界的脉搏。周围的一切都在等待你的下一步行动。',
      '📅 $time\n\n$location的空气中弥漫着魔法的气息。$weather的天气让人想继续探索这个奇妙的世界。',
      '📅 $time\n\n作为一名${p.grade}年级的学生，你在$location经历着霍格沃茨的又一天。每件事都可能改变故事的走向。',
      '📅 $time\n\n${p.name}，你身处$location。接下来会发生什么，完全取决于你的选择。',
    ];

    final idx = _turnCount % fallbacks.length;
    return fallbacks[idx];
  }

  List<GameChoice> _generateFallbackChoices() {
    final location = _worldState.currentLocation ?? '霍格沃茨';

    final locationChoices = {
      '霍格沃茨': [
        ('去教室上课', '前往教室学习'),
        ('在走廊散步', '在走廊里走动'),
        ('去大礼堂', '前往大礼堂'),
        ('找朋友聊天', '与朋友交谈'),
      ],
      '霍格莫德村': [
        ('去三把扫帚酒吧', '前往三把扫帚'),
        ('逛蜂蜜公爵糖果店', '去糖果店'),
        ('拜访邮局', '去邮局寄信'),
        ('返回霍格沃茨', '回到学校'),
      ],
      '对角巷': [
        ('去魔杖店', '前往奥利凡德'),
        ('逛魔法部', '去魔法部'),
        ('去古灵阁', '去古灵阁银行'),
        ('返回霍格沃茨', '回到学校'),
      ],
      '禁林': [
        ('小心深入探索', '深入禁林'),
        ('观察神奇生物', '观察生物'),
        ('原路返回', '返回安全区'),
        ('寻找光源', '寻找光源'),
      ],
    };

    final options = locationChoices[location] ?? [
      ('继续前进', '继续探索'),
      ('仔细观察', '观察周围'),
      ('与人交谈', '和周围的人交流'),
      ('返回原地', '回到之前的位置'),
    ];

    final idx = _turnCount % options.length;
    final rotated = [
      options[idx],
      options[(idx + 1) % options.length],
      options[(idx + 2) % options.length],
    ];

    return rotated
        .map((e) => GameChoice(text: e.$1, action: e.$2))
        .toList();
  }

  void _parseAffectionChanges(String text) {
    if (_npcRegistry.isEmpty) return;
    final inSection = text.split('【好感度变化】');
    if (inSection.length < 2) return;
    final section = inSection[1].split('【').first;
    for (final line in section.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final match = RegExp(r'^(.*?)[:：]\s*([+-]?\d+)').firstMatch(trimmed);
      if (match == null) continue;
      final npcName = match.group(1)!.trim();
      final delta = int.tryParse(match.group(2)!) ?? 0;
      final npc = _npcRegistry.values
          .firstWhere((n) => n.name == npcName, orElse: () => _npcRegistry.values.first);
      if (npc.name == npcName) {
        npc.affection = (npc.affection + delta).clamp(-100, 100);
        _checkLocks(npc);
        _syncRelationshipLevel(npc);
      }
    }
  }

  void _parseReputationChanges(String text) {
    final inSection = text.split('【声望变化】');
    if (inSection.length < 2) return;
    final section = inSection[1].split('【').first;
    for (final line in section.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final match = RegExp(r'^(.*?)[:：]\s*([+-]?\d+)').firstMatch(trimmed);
      if (match == null) continue;
      final dim = match.group(1)!.trim();
      final delta = int.tryParse(match.group(2)!) ?? 0;
      _player?.playerReputation.add(dim, delta);
    }
  }

  // ==================== 更多建议（本地生成，不消耗 token） ====================
  Future<void> generateMoreSuggestions() async {
    if (_player == null || _isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final suggestions = _generateLocalSuggestions();
      if (suggestions.isEmpty) {
        _error = '暂时想不出更多建议，请继续';
      } else {
        _choices = suggestions;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<GameChoice> _generateLocalSuggestions() {
    final location = _worldState.currentLocation ?? '霍格沃茨';
    final house = _player!.house ?? '';
    final personality = _player!.personalityTraits;
    final narrativeLower = _currentNarrative.toLowerCase();

    final bucket = <String, List<String>>{
      'classroom': [
        '认真听教授讲课并做笔记',
        '举手回答教授的提问',
        '与邻座同学小声讨论课堂内容',
        '对教授的讲解提出疑问',
        '利用上课时间偷偷翻阅其他书籍',
      ],
      'great_hall': [
        '前往大礼堂享用早餐',
        '与舍友讨论今天的课程安排',
        '观察四周的同学和幽灵',
        '向魁地奇球队的同学打听训练情况',
        '阅读《预言家日报》了解近期新闻',
      ],
      'library': [
        '查阅相关资料完成作业',
        '在禁书区寻找有趣的书',
        '与图书馆管理员交流',
        '研究某门学科的进阶内容',
        '整理笔记并复习重点',
      ],
      'corridor': [
        '在走廊上与同学闲聊',
        '前往下一节课的教室',
        '观察走廊上的画像与装饰物',
        '和路过的幽灵打声招呼',
        '去盥洗室整理一下',
      ],
      'outside': [
        '在草坪上晒太阳放松',
        '观看魁地奇球队训练',
        '探索城堡周围的小径',
        '和朋友一起散步聊天',
        '观察禁林边缘的动植物',
      ],
      'common_room': [
        '在公共休息室与舍友聊天',
        '练习今天所学的魔咒',
        '整理物品与学习资料',
        '玩一局巫师棋放松',
        '写一封家书',
      ],
      'forbidden_forest': [
        '小心翼翼地探索森林边缘',
        '寻找稀有草药',
        '观察神奇生物的踪迹',
        '沿原路返回，避免深入',
        '留下标记以便返回',
      ],
      'diagon_alley': [
        '前往魔杖店/书店/药店采购',
        '在三把扫帚喝一杯黄油啤酒',
        '逛逛恶作剧商店淘点新奇货',
        '打听最新的魔法界传闻',
        '留意周围可疑的人物',
      ],
      'hospital': [
        '去医疗翼探望受伤的同学',
        '向庞弗雷夫人请教健康问题',
        '领取常用的治疗药水',
        '在医疗翼休息片刻',
        '了解常见伤病的处理方法',
      ],
      'duel_club': [
        '报名加入决斗俱乐部',
        '观摩高年级学生的切磋',
        '与同学进行安全的练习',
        '向助教请教防御技巧',
        '研究非战斗类的实用魔咒',
      ],
      'default': [
        '继续前进，看看会发生什么',
        '观察周围环境，留意细节',
        '与附近的NPC交流',
        '回到熟悉的地方',
        '尝试一个新的地点',
      ],
    };

    String key = 'default';
    final loc = location.toLowerCase();
    if (loc.contains('教室') || loc.contains('classroom') || loc.contains('教室')) key = 'classroom';
    if (loc.contains('大礼堂') || loc.contains('great hall')) key = 'great_hall';
    if (loc.contains('图书馆') || loc.contains('library')) key = 'library';
    if (loc.contains('走廊') || loc.contains('corridor')) key = 'corridor';
    if (loc.contains('城堡外') || loc.contains('outside') || loc.contains('草坪')) key = 'outside';
    if (loc.contains('公共休息室') || loc.contains('common')) key = 'common_room';
    if (loc.contains('禁林') || loc.contains('forbidden')) key = 'forbidden_forest';
    if (loc.contains('对角巷') || loc.contains('diagon')) key = 'diagon_alley';
    if (loc.contains('医疗翼') || loc.contains('hospital')) key = 'hospital';
    if (loc.contains('决斗') || loc.contains('duel')) key = 'duel_club';

    // 情境追加：根据叙事关键词添加专属建议
    final extra = <String>[];
    if (narrativeLower.contains('魁地奇') || narrativeLower.contains('quidditch')) {
      extra.addAll([
        '前往魁地奇球场观看或加入训练',
        '与球队队员交谈获取赛事信息',
      ]);
    }
    if (narrativeLower.contains('食堂') || narrativeLower.contains('餐') || narrativeLower.contains('food')) {
      extra.addAll(['前往厨房准备一些食物', '请家养小精灵帮忙准备餐点']);
    }
    if (narrativeLower.contains('黑魔法') || narrativeLower.contains('dark')) {
      extra.addAll(['向教授请教防御方法', '了解相关历史背景']);
    }
    if (narrativeLower.contains('课') || narrativeLower.contains('homework')) {
      extra.addAll(['集中精力完成作业', '请同学帮忙讲解难点']);
    }
    if (narrativeLower.contains('朋友') || narrativeLower.contains('friend')) {
      extra.addAll(['邀请朋友一起活动', '与朋友分享最近的见闻']);
    }
    if (house.isNotEmpty) {
      extra.add('参加${house}学院的活动');
      extra.add('为${house}学院的荣誉加分');
    }
    for (final t in personality) {
      if (t.contains('勇敢') || t.contains('勇气')) extra.add('勇敢地面对当前的挑战');
      if (t.contains('聪明') || t.contains('智慧')) extra.add('冷静分析当前局势');
      if (t.contains('忠诚')) extra.add('坚定地支持朋友');
      if (t.contains('野心') || t.contains('ambitious')) extra.add('把握机会证明自己');
    }

    final pool = <String>[...?bucket[key], ...extra];
    // 去重并打乱
    final seen = <String>{};
    final deduped = pool.where((s) {
      final key = s.replaceAll(RegExp(r'\s+'), '');
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
    deduped.shuffle(_random);

    final result = <GameChoice>[];
    for (int i = 0; i < deduped.length && result.length < 4; i++) {
      result.add(GameChoice(text: deduped[i], action: deduped[i]));
    }
    if (result.length < 2) {
      for (final s in bucket['default']!) {
        if (result.length >= 4) break;
        result.add(GameChoice(text: s, action: s));
      }
    }
    return result;
  }

  // ==================== 分院仪式（本地逻辑，不消耗 token） ====================
  Future<Map<String, String>> sortPlayer() async {
    if (_player == null) {
      return {'house': 'Gryffindor', 'narrative': ''};
    }

    _isLoading = true;
    notifyListeners();

    try {
      final house = _computeHouseLocal();
      final narrative = _generateSortingNarrative(house);
      _player!.house = house;

      _isLoading = false;
      notifyListeners();
      return {'house': house, 'narrative': narrative};
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'house': 'Gryffindor', 'narrative': ''};
    }
  }

  String _computeHouseLocal() {
    final traits = _player!.personalityTraits.join(' ');
    final attributes = _player!.attributes;

    // 学院倾向优先
    final pref = _player!.housePreference;
    if (pref != null && pref != '系统判定') {
      if (pref.contains('格兰芬多')) return 'Gryffindor';
      if (pref.contains('斯莱特林')) return 'Slytherin';
      if (pref.contains('拉文克劳')) return 'Ravenclaw';
      if (pref.contains('赫奇帕奇')) return 'Hufflepuff';
    }

    final scores = <String, int>{
      'Gryffindor': 0,
      'Slytherin': 0,
      'Ravenclaw': 0,
      'Hufflepuff': 0,
    };

    // 基于性格特质
    final gryffindorTraits = ['勇敢', '勇气', '无畏', '热情', '骑士', '正义'];
    final slytherinTraits = ['野心', '精明', '狡猾', '意志', '血统', '领导'];
    final ravenclawTraits = ['智慧', '聪明', '好奇', '知识', '创造', '学习'];
    final hufflepuffTraits = ['忠诚', '勤勉', '公平', '坚韧', '正直', '耐心'];

    for (final t in gryffindorTraits) {
      if (traits.contains(t)) scores['Gryffindor'] = (scores['Gryffindor'] ?? 0) + 2;
    }
    for (final t in slytherinTraits) {
      if (traits.contains(t)) scores['Slytherin'] = (scores['Slytherin'] ?? 0) + 2;
    }
    for (final t in ravenclawTraits) {
      if (traits.contains(t)) scores['Ravenclaw'] = (scores['Ravenclaw'] ?? 0) + 2;
    }
    for (final t in hufflepuffTraits) {
      if (traits.contains(t)) scores['Hufflepuff'] = (scores['Hufflepuff'] ?? 0) + 2;
    }

    // 基于属性
    final courage = attributes['勇气'] ?? attributes['courage'] ?? 0;
    final ambition = attributes['野心'] ?? attributes['ambition'] ?? 0;
    final wisdom = attributes['智慧'] ?? attributes['wisdom'] ?? 0;
    final loyalty = attributes['忠诚'] ?? attributes['loyalty'] ?? 0;
    scores['Gryffindor'] = (scores['Gryffindor'] ?? 0) + courage;
    scores['Slytherin'] = (scores['Slytherin'] ?? 0) + ambition;
    scores['Ravenclaw'] = (scores['Ravenclaw'] ?? 0) + wisdom;
    scores['Hufflepuff'] = (scores['Hufflepuff'] ?? 0) + loyalty;

    // 政治倾向加分
    final pol = _player!.politicalTendency ?? '';
    if (pol.contains('纯血')) scores['Slytherin'] = (scores['Slytherin'] ?? 0) + 1;
    if (pol.contains('平等') || pol.contains('凤凰社')) scores['Gryffindor'] = (scores['Gryffindor'] ?? 0) + 1;

    // 血统背景
    final blood = _player!.bloodType;
    if (blood == '纯血') scores['Slytherin'] = (scores['Slytherin'] ?? 0) + 1;
    if (blood == '麻瓜出身') scores['Gryffindor'] = (scores['Gryffindor'] ?? 0) + 1;

    // 如果都是0，默认可变随机
    final maxScore = scores.values.reduce((a, b) => a > b ? a : b);
    if (maxScore == 0) {
      final houses = ['Gryffindor', 'Slytherin', 'Ravenclaw', 'Hufflepuff'];
      return houses[_random.nextInt(4)];
    }

    // 最高分校，但加入少量随机扰动（防止同质化）
    final candidates = scores.entries.where((e) => e.value == maxScore).toList();
    candidates.shuffle(_random);
    return candidates.first.key;
  }

  String _generateSortingNarrative(String house) {
    final houseName = switch (house) {
      'Gryffindor' => '格兰芬多',
      'Slytherin' => '斯莱特林',
      'Ravenclaw' => '拉文克劳',
      'Hufflepuff' => '赫奇帕奇',
      _ => '格兰芬多',
    };

    final thoughts = [
      '嗯……有意思。这个孩子有${_player!.personalityTraits.join('、')}的特质。',
      '让我想想……勇敢？智慧？忠诚？野心？',
      '这很有趣，真的很有趣。',
      '决定了——',
    ];
    thoughts.shuffle(_random);

    return '分院帽在你的头顶停留了片刻，轻声低语：「${thoughts.join(' ')}」\n\n'
        '最终它大声宣布：**$houseName**！';
  }

  // ==================== 魔杖选择（本地逻辑，不消耗 token） ====================
  Future<Map<String, dynamic>> selectWand(List<Map<String, dynamic>> options) async {
    if (_player == null) {
      return {'selected': options.first, 'narrative': ''};
    }

    _isLoading = true;
    notifyListeners();

    try {
      final selected = _computeWandLocal(options);
      _player!.wandId = selected['id'] as String?;
      final narrative = _generateWandNarrative(selected);

      _isLoading = false;
      notifyListeners();
      return {'selected': selected, 'narrative': narrative};
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'selected': options.first, 'narrative': ''};
    }
  }

  Map<String, dynamic> _computeWandLocal(List<Map<String, dynamic>> options) {
    if (options.isEmpty) return {};

    final personality = _player!.personalityTraits.join(' ');
    final attributes = _player!.attributes;

    // 根据玩家特质为每根魔杖打分
    final scored = <Map<String, dynamic>, double>{};
    for (final wand in options) {
      double score = 0.0;
      final suit = (wand['suitType'] ?? '') as String;
      final desc = (wand['description'] ?? '') as String;
      final wood = (wand['wood'] ?? '') as String;
      final core = (wand['core'] ?? '') as String;

      final combined = '$suit $desc $wood $core';

      // 性格匹配
      final traitKeywords = <String, int>{
        '勇敢': 2, '勇气': 2, '无畏': 2,
        '野心': 2, '精明': 2, '领导': 2,
        '智慧': 2, '聪明': 2, '好奇': 2,
        '忠诚': 2, '正直': 2, '勤勉': 2,
        '温柔': 1, '善良': 1, '慷慨': 1,
        '狡猾': 1, '意志': 1, '坚强': 1,
        '创造': 1, '学习': 1, '知识': 1,
        '坚韧': 1, '耐心': 1, '公平': 1,
      };
      for (final entry in traitKeywords.entries) {
        if (personality.contains(entry.key) && combined.contains(entry.key)) {
          score += entry.value;
        }
      }

      // 杖芯属性
      if (core == '独角兽毛') score += 1;
      if (core == '龙心脏腱索') score += 1;
      if (core == '凤凰羽毛') score += 1;

      // 属性加成
      final courage = attributes['勇气'] ?? attributes['courage'] ?? 0;
      final ambition = attributes['野心'] ?? attributes['ambition'] ?? 0;
      final wisdom = attributes['智慧'] ?? attributes['wisdom'] ?? 0;
      final loyalty = attributes['忠诚'] ?? attributes['loyalty'] ?? 0;

      if (wood == '冬青木' || wood == '橡木') score += courage * 0.05;
      if (wood == '紫杉木' || wood == '榆木') score += ambition * 0.05;
      if (wood == '葡萄藤木' || wood == '枫木') score += wisdom * 0.05;
      if (wood == '樱桃木' || wood == '雪松木' || wood == '柳木') score += loyalty * 0.05;

      scored[wand] = score;
    }

    // 选最高分，同分随机
    final maxScore = scored.values.isEmpty ? 0.0 : scored.values.reduce((a, b) => a > b ? a : b);
    final candidates = scored.keys.where((w) => scored[w] == maxScore).toList();
    candidates.shuffle(_random);
    return candidates.first;
  }

  String _generateWandNarrative(Map<String, dynamic> wand) {
    final name = wand['name'] ?? '未知魔杖';
    final wood = wand['wood'] ?? '';
    final core = wand['core'] ?? '';
    final len = wand['length'] ?? '';
    final suit = wand['suitType'] ?? '';

    final lines = [
      '奥利凡德先生用他那双近乎透明的眼睛凝视着你，片刻后低语：「有意思……很是有意思。」',
      '他在一排排积满灰尘的魔杖盒前缓缓踱步，抽出一根又一根——',
      '最终，当一根触碰到你指尖的瞬间，它迸发出一簇暖金色的火花，空气中响起一声清脆的共鸣。',
      '「$name，$wood，$core，$len。」他轻声介绍，「这根魔杖适合$suit的人。」',
      '你握着它，感到一股熟悉的力量在掌心流淌。',
    ];
    return lines.join('\n\n');
  }

  // ==================== 存档系统 ====================
  Future<void> quickSave() async {
    if (_player == null) return;
    await _saveService.saveGame(
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
    _systemPrompt = _buildSystemPrompt();
    _npcRegistry.clear();
    (data['npc_registry'] as Map<String, dynamic>).forEach((k, v) {
      _npcRegistry[k] = NPC.fromJson(v as Map<String, dynamic>);
    });
    _currentNarrative = data['narrative'] as String? ?? '';
    _choices = (data['choices'] as List<dynamic>?)
        ?.map((c) => GameChoice(text: c['text'] as String, action: c['action'] as String))
        .toList() ?? [];
    _turnCount = data['turn_count'] as int? ?? 0;
    appProvider.setGameStarted(true);
    notifyListeners();
    _autoSave();
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

  Future<Map<String, dynamic>?> get quotaInfo async {
    if (_deepSeek == null) return null;
    return await _deepSeek!.getQuotaInfo();
  }

  void resetTokenUsage() {
    _totalPromptTokens = 0;
    _totalCompletionTokens = 0;
    _totalTokens = 0;
    _apiCalls = 0;
    notifyListeners();
  }

  // ==================== 辅助方法 ====================
  String _bloodStatusLabel(String status) {
    return {
      'muggleborn': '麻瓜出身',
      'halfblood': '混血巫师',
      'pureblood': '纯血',
      'pureblood_side': '纯血旁支',
      'pureblood_sacred': '神圣二十八族',
      'special': '特殊家庭',
      'squib': '哑炮',
      'obscurial': '默然者',
      'veela': '混血媚娃',
      'werewolf': '狼人',
      'half_giant': '半巨人',
      'muggle_family': '麻瓜家庭',
      'custom': '自定义',
    }[status] ?? status;
  }

  String _attrLabel(String key) {
    return {
      'spell_understanding': '魔咒理解',
      'transfiguration': '变形术',
      'potions': '魔药',
      'herbology': '草药学',
      'dda': '黑魔法防御',
      'flying': '飞行',
      'theory': '理论知识',
      'memory': '记忆力',
      'observation': '观察力',
      'magic_control': '魔法控制',
      'reaction_time': '反应速度',
      'emotional_stability': '情绪稳定',
      'creativity': '创造力',
      'social': '社交',
      'courage': '勇气',
      'caution': '谨慎',
      'willpower': '意志',
      'logic': '逻辑',
      'intuition': '直觉',
    }[key] ?? key;
  }

  String _houseLabel(String house) {
    return {
      'Gryffindor': '格兰芬多',
      'Slytherin': '斯莱特林',
      'Ravenclaw': '拉文克劳',
      'Hufflepuff': '赫奇帕奇',
    }[house] ?? house;
  }

  String _termLabel(String term) {
    return {
      'first': '第一学期',
      'second': '第二学期',
      'third': '第三学期',
      'summer': '暑假',
    }[term] ?? term;
  }

  String _flowModeLabel(String mode) {
    return {
      'normal': '正常',
      'story': '剧情加速',
      'fast': '快速',
    }[mode] ?? mode;
  }

  @override
  void dispose() {
    _autoSave();
    appProvider.removeListener(_onApiKeyChange);
    super.dispose();
  }
}

class GameChoice {
  final String text;
  final String action;
  GameChoice({required this.text, required this.action});
}
