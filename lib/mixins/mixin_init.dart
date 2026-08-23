import 'dart:async';
import 'package:flutter/widgets.dart';
import '../services/rate_limiter.dart';
import '../data/pet_data.dart';
import '../providers/app_provider.dart';
import '../models/npc.dart';
import '../models/game_systems.dart';
import '../data/world_rules.dart';
import '../models/player.dart';
import '../data/trait_data.dart';
import '../data/npc_data.dart';
import '../data/wand_data.dart';
import '../models/world_state.dart';
import '../models/long_term_memory.dart';
import '../utils/crash_logger.dart';
import '../providers/game_provider_base.dart';
import '../prompts/narrative_prompts.dart';

mixin GameInitMixin on GameProviderBase {
  String buildSystemPrompt() {
    final p = player;
    final effectiveEra = worldState.era.isNotEmpty ? worldState.era : appProvider.era.name;
    final eraName = _eraLabelShort(_parseEra(effectiveEra));

    final profile = p != null
        ? '【档案】${p.name}·${bloodStatusLabel(p.bloodType)}·${p.house ?? '未分院'}·${p.grade}年·天赋${p.magicAptitude ?? '普通'}·精神${p.spirit}·精力${p.energy}'
        : '';

    // 角色创建时的玩家属性（必须注入，否则 AI 完全不知道玩家选了什么）
    final characterLines = <String>[];
    if (p != null) {
      if (p.birthIdentity != null && p.birthIdentity!.isNotEmpty) {
        characterLines.add('【出生身份】${p.birthIdentity}（必须体现在叙事中：经济条件、家族状态、对血统观念的态度都由此决定）');
      }
      if (p.personalityTraits.isNotEmpty) {
        characterLines.add('【性格】${p.personalityTraits.join('、')}（AI 描写主角心理和言行时必须贴合此性格，严禁写成冷酷控制欲型）');
      }
      if (p.appearance != null && p.appearance!.isNotEmpty) {
        characterLines.add('【外貌】${p.appearance}（叙事中当其他 NPC 第一次看到主角或主角照镜子/被观察时，必须描写外貌）');
      }
      if (p.childhoodExperiences.isNotEmpty) {
        characterLines.add('【童年奇迹】${p.childhoodExperiences.join('；')}（这些是主角的神秘伏笔，可在特殊场景或梦境中暗示，但不宜过多直白提及）');
      }
      if (p.beliefs != null && p.beliefs!.isNotEmpty) {
        characterLines.add('【信念】${p.beliefs}（主角的道德底线和行为准则，严重违背的选项不允许出现在 ABCD 中）');
      }
      if (p.politicalTendency != null && p.politicalTendency!.isNotEmpty) {
        characterLines.add('【政治立场】${p.politicalTendency}（主角对纯血论、麻瓜、混血的态度，NPC 互动和选项需贴合）');
      }
      if (p.initialTalent != null && p.initialTalent!.isNotEmpty) {
        characterLines.add('【初始天赋专精】${p.initialTalent}（相关魔法成功率和理解更高，叙事中可体现主角的擅长领域）');
      }
      if (p.magicAptitude != null && p.magicAptitude!.isNotEmpty) {
        characterLines.add('【魔法资质】${p.magicAptitude}（主角学习新魔法的速度、掌握深度、施法威力和稳定性都依此浮动，严禁在叙事中把"资质平平/普通"写成"天才"，也严禁把"天才级"写成"资质普通"）');
      }
      if (p.familyBackground != null && p.familyBackground!.isNotEmpty) {
        characterLines.add('【家族背景】${p.familyBackground}（经济条件、在家中的地位、父母亲人对主角的态度、家族在魔法界的名声和人脉——必须体现在 NPC 互动和场景描述里）');
      }
      if (p.housePreference != null && p.housePreference!.isNotEmpty && p.house == null) {
        characterLines.add('【学院倾向】${p.housePreference}（分院前分院帽会优先倾听此意愿；分院后如实际学院不同，主角内心的落差感要体现在心理描写里）');
      }
      if (p.simulationStyle != null && p.simulationStyle!.isNotEmpty) {
        characterLines.add('【模拟风格】${p.simulationStyle}（叙事整体走向、冲突密度、感情线推进速度、政治剧情比重都需贴合此风格）');
      }
      if (p.petId != null && p.petId!.isNotEmpty) {
        final pd = petById(p.petId!);
        final petName = (p.petName != null && p.petName!.isNotEmpty) ? p.petName : (pd?.name ?? '宠物');
        if (pd != null) {
          final abilityDesc = pd.abilities.isNotEmpty ? '；能力：${pd.abilities.join('、')}' : '';
          final transformDesc = pd.canTransform ? '；可化人形' : '';
          characterLines.add('【宠物】$petName（${pd.species}${pd.species == pd.name ? '' : '·' + pd.name}）。${pd.description.trim()}$abilityDesc$transformDesc。当宠物出现在场景中时，必须符合这些设定，不能凭空添加/删除能力或改性格。');
        } else {
          characterLines.add('【宠物】$petName（契约伙伴，宠物出现在场景中时必须体现它的存在）');
        }
      }
      if (p.wandId != null && p.wandId!.isNotEmpty) {
        final wd = wandById(p.wandId!);
        if (wd != null) {
          final woodClean = wd.wood.endsWith('木') ? wd.wood : '${wd.wood}木';
          characterLines.add('【魔杖】$woodClean·${wd.core}·${wd.length}（主角施法时请描写这根魔杖的触感和反应，绝对不要写成柳木或其他木材；来源必须为奥利凡德魔杖店选中，绝对不要描写为捡来的木棍/祖传物品/自制）');
        }
      }
    }

    // 身份模式：穿越者拥有对原作剧情的隐约记忆，原住民则一无所知
    final identityLine = appProvider.identityMode == IdentityMode.transmigration
        ? '【身份模式】穿越者：你对原作的命运走向留有隐约记忆，可作为行动依据，但他人不会轻信"预言"；引用未来信息需克制并举证自洽。'
        : '【身份模式】原住民：你对命运走向一无所知，只凭自己的判断与本能行事。';

    // 人生目标：若已设定，注入为剧情牵引方向（非强制任务）
    final goalLine = (p != null && p.currentGoal != null && p.currentGoal!.isNotEmpty)
        ? '【人生目标】${p.currentGoal}（仅作剧情牵引方向，玩家仍可自由行动，切勿变成每回合的任务推送）'
        : '';

    final worldRules = kUseFusedCompact ? kWorldRulesFusedCompact : kWorldRulesFused;

    final buffer = StringBuffer()
      ..write(worldRules)
      ..write('\n\n')
      ..write(profile);
    if (characterLines.isNotEmpty) {
      buffer
        ..write('\n')
        ..write(characterLines.join('\n'));
    }
    buffer
      ..write('\n【时代】')
      ..write(eraName)
      ..write('\n')
      ..write(identityLine);
    if (goalLine.isNotEmpty) {
      buffer
        ..write('\n')
        ..write(goalLine);
    }
    final traitLine = _traitNarrativeHints();
    if (traitLine.isNotEmpty) {
      buffer
        ..write('\n')
        ..write(traitLine);
    }
    return buffer.toString();
  }

  String eraLabel(Era era) {
    return switch (era) {
      Era.dumbledore => '邓布利多时代（1892-1899）：少年阿不思·邓布利多在霍格沃茨求学，认识盖勒特·格林德沃。',
      Era.marauders => '亲世代（1971-1978）：掠夺者四人组与莉莉·伊万斯同窗的时代。',
      Era.first_war => '第一次巫师战争（1970s后期）：社会氛围紧张，伏地魔崛起的阴影笼罩魔法界。',
      Era.harry_same => '子世代（1991-1998）：哈利·波特在霍格沃茨的求学时期。',
      Era.post_war => '现代（2020+）：战后重建的魔法世界，阿不思·波特与斯科皮·马尔福的时代。',
      Era.random => '随机时代：由叙事开始时随机决定。',
    };
  }

  /// 短版时代描述（节省 token。系统提示词和开场叙事中使用）

  String _eraLabelShort(Era era) {
    return switch (era) {
      Era.dumbledore => '邓布利多时代 1892（少年邓布利多求学）',
      Era.marauders => '亲世代 1971（掠夺者同窗）',
      Era.first_war => '一战末期 1976（伏地魔崛起）',
      Era.harry_same => '子世代 1991（哈利入学）',
      Era.post_war => '战后 2020（阿不思·波特时代）',
      Era.random => '随机时代',
    };
  }

  Era _parseEra(String eraStr) {
    return Era.values.firstWhere(
      (e) => e.name == eraStr.toLowerCase(),
      orElse: () => Era.marauders,
    );
  }

  // ==================== 重置全部游戏状态 ====================
  /// 用于「开始新游戏」时彻底清空旧存档上下文，避免新游戏的第一回合仍被旧摘要、
  /// 旧剧情缓冲、旧回合计数器影响，导致 AI"接着之前的剧情写"。

  void resetAllState() {
    player = null;
    worldState = WorldState();
    npcRegistry.clear();
    memory = LongTermMemory();
    currentNarrative = '';
    narrativeSummary = '';
    pendingSummary = '';
    recentTurns.clear();
    choices.clear();
    commandResult = null;
    isLoading = false;
    isInitializing = false;
    error = null;
    turnCount = 0;
    lastPlayerAction = '';
    systemPrompt = null;
    loadingStage = '';
    notifications.clear();
    gameWeek = 1;
    lastSchoolYearStart = 0;
    pendingAnchorDirective = null;
    totalTokens = 0;
    lastRoundTokens = 0;
    apiCalls = 0;
    openingScene = 'station';
    lastScannedNarrativeHash = null;
    // 清除响应缓存（重要：防止旧剧情数据泄漏到新游戏）
    ResponseCache.instance.clear();
    // 清除速率限制器状态
    AgnesRateLimiter.instance.reset();
    SenseNovaQuotaManager.instance.reset();
    // 销毁旧路由器（清除响应缓存、已注册的服务实例）
    router = null;
    // 清除 NPC 聊天缓存（对话历史、路由器）
    chatService.clearCache();
    chatService.refreshClient();
    notifyListeners();
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
    String openingScene = 'station',
  }) async {
    // 先彻底清空所有旧状态（防止新开局把旧摘要/近期剧情注入到 Prompt）
    resetAllState();
    // 重新创建路由器（resetAllState 已将 router 置空）
    updateClient();
    // 清空旧自动存档文件（防止新游戏误加载到旧存档）
    try {
      await saveService.clearAutoSave();
    } catch (e) {
      debugPrint('清理旧存档失败(不影响游戏): $e');
    }
    isLoading = true;
    notifyListeners();

    try {
      final birthYear = _calculateBirthYear();
      final startYear = _startYearForEra(appProvider.era);
      // letter 起点（收到录取通知书）按原著为 7 月 31 日前后；其它 3 个起点才是 9 月 1 日特快出发日
      // 防止 letter 开局刚收到信，下一回合场景直接跳到 9 月 1 日已在站台导致整个暑假剧情丢失。
      int startMonth, startDay, startHour, startMinute;
      switch (openingScene) {
        case 'letter':
          startMonth = 7; startDay = 31; startHour = 18; startMinute = 45;
          break;
        case 'diagon':
          startMonth = 8; startDay = 20; startHour = 10; startMinute = 30;
          break;
        case 'station':
          startMonth = 9; startDay = 1; startHour = 10; startMinute = 45; // 10:45才接近发车11点
          break;
        case 'eve':
        case 'hall':
          startMonth = 9; startDay = 1; startHour = 18; startMinute = 0;
          break;
        default:
          startMonth = 9; startDay = 1; startHour = 9; startMinute = 0;
      }

      // ====== 角色资料交叉校验（防止逻辑自相矛盾，AI写崩） ======
      // 校验1：出生身份与家族背景不可冲突
      // 例："纯血豪门" vs "麻瓜家庭" → 统一以 birthIdentity 为主，familyBackground 改为合理描述
      var fb = familyBackground ?? '';
      final familyLower = fb.toLowerCase();
      final idLower = (birthIdentity ?? '').toLowerCase();
      if (birthIdentity != null &&
          birthIdentity.isNotEmpty &&
          fb.isNotEmpty) {
        const pureBloodKeywords = ['纯血', '豪门', '神圣二十八族', 'pureblood'];
        const muggleKeywords = ['麻瓜', '普通', '无魔法', 'muggle'];
        final hasPure = pureBloodKeywords.any((k) => idLower.contains(k));
        final hasMuggleFamily = muggleKeywords.any((k) => familyLower.contains(k));
        if (hasPure && hasMuggleFamily) {
          // 允许"神圣二十八族没落支系+麻瓜养父母"这种设定，但不能写成"普通麻瓜家庭出身"
          final sanitized = fb.replaceAll(RegExp(r'[麻普通无魔法]', caseSensitive: false), '').trim();
          if (sanitized.isEmpty) {
            fb = '麻瓜养父母家庭';
          } else {
            fb = fb
                .replaceAll('普通麻瓜家庭', '麻瓜养父母家庭')
                .replaceAll('麻瓜家庭', '麻瓜养父母家庭');
          }
          familyBackground = '神圣二十八族没落支系，由$fb抚养长大，亲生父母早已不在人世，血脉仍保留纯血族谱印记';
        }
      }

      player = Player(
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
        grade: 1,
      );

      // 开局特质抽取（3个，软保底稀有度）
      final rolledTraits = _rollStartingTraits();
      player!.traits.addAll(rolledTraits.map((t) => t.id));
      _applyTraitBonuses(rolledTraits);

      worldState = WorldState(
        era: appProvider.era.name,
        academicYear: _academicYearForEra(appProvider.era),
        time: GameTime(
          year: startYear,
          month: startMonth,
          day: startDay,
          hour: startHour,
          minute: startMinute,
        ),
      );
      // letter 起点时同步 currentLocation 为玩家出生地（避免 prompt 里显示「未知」导致 AI 乱跳地点）
      if (openingScene == 'letter') {
        worldState.currentLocation = '${player!.birthLocation}·家中';
      } else if (openingScene == 'station') {
        worldState.currentLocation = '伦敦国王十字车站';
      } else if (openingScene == 'hall') {
        worldState.currentLocation = '霍格沃茨大礼堂';
      } else if (openingScene == 'eve') {
        worldState.currentLocation = '霍格沃茨新生宿舍';
      }
      lastSchoolYearStart = startYear;
      updateAcademicYearLabel();

      // 必须在 player 和 worldState 都赋值后再构建系统提示词
      systemPrompt = buildSystemPrompt();

      _initializeNPCsByEra();
      _assignInitialRelationships();

      // ====== 注入开局 T0 核心事实（永不遗忘层 LongTermMemory.keyFacts） ======
      // 这些是「身份级」事实，即使 AI 摘要压缩也不会丢；importance 9 永远保留。
      // 写入顺序要在 _generateOpeningScene 之前，确保第一回合 prompt 已经含有这些纯事实。
      final ts0 = worldState.time.format();
      void addT0(String id, String fact, {String? category, Set<String> npcIds = const {}}) {
        memory = memory.addKeyFact(KeyFactRecord(
          id: id,
          fact: fact,
          importance: 9,
          timestamp: ts0,
          category: category,
          npcIds: npcIds,
        ));
      }
      final p0 = player!;
      // 1. 基础身份：姓名 + 时代出生年份（避免AI记混）
      addT0(
        'identity:name_birth',
        '主角姓名为${p0.name}，出生于${p0.birthYear}年，血统为${bloodStatusLabel(p0.bloodType)}，出生地：${p0.birthLocation}。',
        category: 'identity',
      );
      // 2. 魔杖：木材/杖芯/长度（如果AI在开局就写错，后续极难纠正，必须提前锁死）
      if (p0.wandId != null && p0.wandId!.isNotEmpty) {
        final wd = wandById(p0.wandId!);
        if (wd != null) {
          final woodClean = wd.wood.endsWith('木') ? wd.wood : '${wd.wood}木';
          addT0(
            'identity:wand',
            '主角的魔杖为$woodClean·${wd.core}·${wd.length}，购自对角巷奥利凡德魔杖店，由魔杖主动选中。',
            category: 'asset',
          );
        }
      }
      // 3. 宠物：普通宠物写5分，绯月九尾狐写9分+明确能力和忠诚（东方神话属性对整个叙事走向影响大）
      if (p0.petId != null && p0.petId!.isNotEmpty) {
        final pd = petById(p0.petId!);
        final petName = (p0.petName != null && p0.petName!.isNotEmpty) ? p0.petName! : (pd?.name ?? '宠物');
        if (p0.petId == 'kyuubi' || (pd?.canTransform ?? false)) {
          final abilities = pd?.abilities.isNotEmpty ?? false ? '，能力：${pd!.abilities.join('、')}' : '';
          addT0(
            'pet:kyuubi',
            '主角的契约宠物是九尾灵狐"$petName"（绯月），来自东方青丘神话，可化人形$abilities，对主角完全忠诚、绝对听命。',
            category: 'pet',
          );
        } else if (pd != null) {
          final ab3 = pd.abilities.take(2).join('、');
          addT0(
            'pet:${p0.petId}',
            '主角饲养的宠物是${pd.species}"$petName"${ab3.isNotEmpty ? '，擅长' + ab3 : ''}，是重要的陪伴和伙伴。',
            category: 'pet',
          );
          // 普通宠物 importance 7 即可，不占最高档槽位
          // 目前 addT0 都写 9；这里手动覆盖为 7
          memory = memory.addKeyFact(KeyFactRecord(
            id: 'pet:${p0.petId}',
            fact: '主角饲养的宠物是${pd.species}"$petName"${ab3.isNotEmpty ? '，擅长' + ab3 : ''}，是重要的陪伴和伙伴。',
            importance: 7,
            timestamp: ts0,
            category: 'pet',
          ));
        } else {
          memory = memory.addKeyFact(KeyFactRecord(
            id: 'pet:${p0.petId}',
            fact: '主角的契约伙伴：$petName。',
            importance: 7,
            timestamp: ts0,
            category: 'pet',
          ));
        }
      }
      // 4. 初始天赋专精：AI容易忽略并写成"天赋平平"，提前写死
      if (p0.initialTalent != null && p0.initialTalent!.isNotEmpty) {
        addT0(
          'ability:initial_talent',
          '主角在入学前就在「${p0.initialTalent}」方向展现出明显的天赋和长期积累，学习相关魔法时理解更快、效果更强。',
          category: 'ability',
        );
      }
      // 5. 魔法资质：防止AI统一写成"普通"
      if (p0.magicAptitude != null && p0.magicAptitude!.isNotEmpty) {
        addT0(
          'ability:aptitude',
          '主角的整体魔法资质为${p0.magicAptitude}，这决定了学习速度、施法威力和魔力总量的天花板。',
          category: 'ability',
        );
      }

      this.openingScene = openingScene;
      await _generateOpeningScene();

      // 本地分院衔接：当玩家选择「hall（大礼堂）」或「eve（分院前夜）」作为剧情起点时，
      // 先在初始化后立刻跑一次本地逻辑分院（不消耗 token），把 house 提前写好；
      // 叙事合并进开场叙事并解锁 'sorted' 成就，后续 AI prompt 中的学院就正确了。
      // 如果玩家已经通过 AI 叙事解析得到 house（如 station 起点写了很多回合后分院），这里会被跳过。
      if (player != null && player!.house == null && (openingScene == 'hall' || openingScene == 'eve')) {
        try {
          final house = computeHouseLocal();
          final sortingNarrative = generateSortingNarrative(house);
          player!.house = house;
          bumpImpactScore(0.05, debugReason: '分院仪式');
          unlockAchievement('sorted');
          // 合并：本地分院叙事拼接在开场叙事后面
          if (sortingNarrative.trim().isNotEmpty) {
            currentNarrative = (currentNarrative.trim() +
                '\n\n—— 分院仪式 ——\n\n' +
                sortingNarrative.trim()).trim();
          }
          debugPrint('⚡ 开局本地分院：${player!.house} (起点=$openingScene)');
        } catch (e) {
          debugPrint('开局本地分院失败(不影响游戏): $e');
        }
      }

      appProvider.setGameStarted(true);
      unlockAchievement('first_letter');
      if (player!.letters.isEmpty) {
        player!.letters.add(Letter(
          id: 'L_admission',
          sender: '霍格沃茨魔法学校',
          date: '${player!.birthYear}年7月',
          content: '亲爱的${player!.name}小姐/先生：\n\n我们愉快地通知您，您已获准在霍格沃茨魔法学校就读。随信附上所需书籍与装备一览表。\n学期定于九月一日开始，我们将于七月三十一日前静候您的猫头鹰带来回音。\n\n您忠诚的\n副校长（女）\n米勒娃·麦格 谨上',
        ));
      }
      isLoading = false;
      notifyListeners();
      autoSave();
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
      unawaited(CrashLogger.instance.record(
        e,
        StackTrace.current,
        screen: 'openingInit',
        extra: 'name=$name, era=${appProvider.era.name}',
      ));
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
    npcRegistry.clear();
    final eraKey = _eraKey(appProvider.era);
    final seeds = eraNpcSeeds[eraKey] ?? [];

    for (final seed in seeds) {
      npcRegistry[seed.id] = NPC(
        id: seed.id,
        name: seed.name,
        aliases: List.of(seed.aliases),
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
          academic: roll(15, 45),
          social: roll(15, 45),
          combat: roll(10, 40),
          moral: roll(20, 50),
          leadership: roll(10, 40),
          dark: seed.era == 'dumbledore' || seed.id == 'grindelwald'
              ? roll(30, 60)
              : roll(0, 20),
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
    if (seed.grade == 0) return roll(0, 10);
    return roll(0, 15);
  }

  int roll(int min, int max) => min + random.nextInt(max - min + 1);

  /// 建立玩家初始关系
  /// 说明：开局不自动把「同年级同学」标记为已认识——必须在剧情中正式见面/产生互动才会 introduced=true。
  /// 仅对血缘亲属、开场设定的宠物绯月等明确认识的角色默认 introduced。

  void _assignInitialRelationships() {
    final p = player;
    if (p == null) return;
    for (final npc in npcRegistry.values) {
      if (npc.grade > 0 && npc.grade == (p.grade ?? 1)) {
        p.relationships[npc.id] = Relationship(
          targetId: npc.id,
          targetName: npc.name,
          relationType: '同学',
          level: 0, // 仅登记关系档案，好感待剧情中建立
        );
      }
    }
  }

  /// 显式标记某 NPC 已登场/被玩家认识（并记录认识事件）

  void markNpcIntroduced(NPC npc) {
    if (npc.introduced) return;
    npc.introduced = true;
    final event = '初次见面';
    if (!npc.recentEvents.contains(event)) {
      npc.recentEvents.insert(0, event);
      if (npc.recentEvents.length > 10) npc.recentEvents.removeLast();
    }
    worldState.addNarrativeEvent('👤 你结识了 ${npc.name}', turn: turnCount);
  }

  static const List<String> _signoffKeywords = [
    '敬启', '谨启', '谨致', '此致', '敬礼', '敬意', '顺颂', '顺颂时祺',
    '顺颂安祺', '祝好', '祝安好', '谨上', '敬上', '顿首', '拜上',
    '签名', '落款', '联系人', '联系电话', '地址：', '邮编：',
    '校长：', '副校长：', '院长：', '教授：', '老师：',
    '魔法部部长：', '傲罗办公室主任：', '司长：', '厅长：',
    'Headmaster ', 'Deputy Head', 'Professor ', 'Mr.', 'Mrs.', 'Miss', 'Ms.',
    'Sincerely', 'Yours truly', 'Best regards', 'Kind regards', 'Warm regards',
    'From,', 'With love,', 'Cheers,', 'Regards,',
  ];

  List<(int, int)> _signatureRanges(String text) {
    final ranges = <(int, int)>[];
    if (text.isEmpty) return ranges;

    final lines = text.split('\n');
    if (lines.isEmpty) return ranges;

    int currentOffset = 0;
    final lineOffsets = <int>[];
    for (final line in lines) {
      lineOffsets.add(currentOffset);
      currentOffset += line.length + 1;
    }

    int signatureStartLine = -1;
    int consecutiveHits = 0;
    const maxSignatureLines = 15;

    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        if (signatureStartLine != -1) {
          consecutiveHits++;
          if (consecutiveHits > 2) break;
        }
        continue;
      }

      bool isSignatureLine = false;

      for (final keyword in _signoffKeywords) {
        if (line.contains(keyword)) {
          isSignatureLine = true;
          break;
        }
      }

      if (!isSignatureLine) {
        final titlePattern = RegExp(r'^[\u4e00-\u9fa5A-Za-z]{2,15}[：:]\s*\S');
        if (titlePattern.hasMatch(line)) {
          isSignatureLine = true;
        }
      }

      if (isSignatureLine) {
        signatureStartLine = i;
        consecutiveHits = 0;
      } else if (signatureStartLine != -1) {
        consecutiveHits++;
        if (consecutiveHits > 2) break;
      }

      if (signatureStartLine != -1 && (signatureStartLine - i) >= maxSignatureLines) {
        break;
      }
    }

    if (signatureStartLine != -1) {
      final startOffset = lineOffsets[signatureStartLine];
      final endOffset = text.length;
      ranges.add((startOffset, endOffset));
    }

    return ranges;
  }

  bool _inSignatureRange(int idx, List<(int, int)> ranges) {
    for (final range in ranges) {
      if (idx >= range.$1 && idx <= range.$2) {
        return true;
      }
    }
    return false;
  }

  bool _sliceOverlapsSignature(int start, int end, List<(int, int)> ranges) {
    for (final range in ranges) {
      final overlapStart = start > range.$1 ? start : range.$1;
      final overlapEnd = end < range.$2 ? end : range.$2;
      final overlapLen = overlapEnd > overlapStart ? overlapEnd - overlapStart : 0;
      final sliceLen = end - start;
      if (sliceLen > 0 && overlapLen * 2 >= sliceLen) {
        return true;
      }
    }
    return false;
  }

  /// 扫描剧情文本，匹配到已知 NPC 名字时自动标记 introduced

  void markIntroducedFromNarrative(String text) {
    if (text.isEmpty || npcRegistry.isEmpty) return;

    final signatureRanges = _signatureRanges(text);

    const interactionVerbs = [
      '见面', '握手', '介绍', '对视', '打招呼', '对话', '交谈', '自我介绍',
      '走进', '进来', '敲门', '推开', '开门', '向你走', '看到你', '来到',
      '回应你', '你唤', '你叫', '你问', '问你', '对你说', '告诉你',
      '递给你', '你接过', '你握', '拥抱', '拍肩', '微笑着', '点头',
      '行礼', '鞠躬', '一起坐', '坐下', '上楼', '下楼', '同行', '并肩'
    ];

    int markedThisRound = 0;
    const maxPerRound = 5;
    final npcs = npcRegistry.values.toList()
      ..sort((a, b) => b.name.length.compareTo(a.name.length));
    for (final npc in npcs) {
      if (npc.introduced) continue;
      if (markedThisRound >= maxPerRound) break;

      final hitMidpoints = <int>{};
      bool contextHasInteraction = false;

      for (final alias in npc.allNames) {
        if (alias.runes.length < 2) continue;
        if (!_standaloneNameMentioned(text, alias)) continue;

        int searchFrom = 0;
        while (true) {
          final idx = text.indexOf(alias, searchFrom);
          if (idx == -1) break;

          if (_inSignatureRange(idx, signatureRanges)) {
            searchFrom = idx + alias.length;
            continue;
          }

          final midpoint = idx + (alias.length ~/ 2);
          bool isDuplicate = false;
          for (final existing in hitMidpoints) {
            if ((existing - midpoint).abs() < alias.length) {
              isDuplicate = true;
              break;
            }
          }
          if (!isDuplicate) {
            hitMidpoints.add(midpoint);
          }

          final start = idx - 80 < 0 ? 0 : idx - 80;
          final end = idx + alias.length + 80 > text.length
              ? text.length
              : idx + alias.length + 80;

          if (!_sliceOverlapsSignature(start, end, signatureRanges)) {
            final slice = text.substring(start, end);
            if (interactionVerbs.any((v) => slice.contains(v))) {
              contextHasInteraction = true;
            }
          }

          searchFrom = idx + alias.length;
        }
        if (contextHasInteraction) break;
      }

      final totalMentionCount = hitMidpoints.length;
      final shouldMark = contextHasInteraction || totalMentionCount >= 3;
      if (shouldMark && totalMentionCount > 0) {
        markNpcIntroduced(npc);
        markedThisRound++;
      }
    }
  }

  /// 判断 name 是否在 text 中以「可识别方式」出现。
  /// 关键修复：中文（CJK）文本不用空格分词，因此「金妮」嵌在「捕捉到了金妮骤然...」
  /// 中间就是正常的独立出现——如果还要求前后字符不是汉字就会永远匹配失败，
  /// 造成所有 NPC 剧情里出现了但大世界永远显示「未登场 0 人」。
  ///
  /// 规则：
  ///   - 主要由 CJK 字符构成的名称（中文姓名）：只要文本 contains 就算。
  ///     另外对「姓氏两字简称」（如"韦斯莱"）加一层宽松保护：若前后紧接更多
  ///     CJK 字符构成更长真实姓名的一部分也允许匹配（剧情里常简称姓氏）。
  ///   - 主要由拉丁/数字构成的名称（英文代号）：仍执行严格边界检查，
  ///     防止 "哈利" 匹配进 "哈利波特童装店" 这种英文子串误命中场景。
  static bool _standaloneNameMentioned(String text, String name) {
    if (name.isEmpty || text.isEmpty) return false;

    // 统计 name 中 CJK 字符比例
    int cjkCount = 0;
    for (final code in name.codeUnits) {
      if ((code >= 0x4E00 && code <= 0x9FFF) ||
          (code >= 0x3400 && code <= 0x4DBF)) {
        cjkCount++;
      }
    }
    final mostlyCjk = cjkCount * 2 >= name.length; // ≥50% 字符是 CJK 视为中文名称

    if (mostlyCjk) {
      // 中文名称：只要包含即可出现即算。
      // 故事文本里出现「了金妮骤」「·韦斯莱僵」这种就是角色名字正常出现，
      // 中文不用空格分词，不存在"嵌在更长词组里就不算"的问题。
      return text.contains(name);
    }

    // ====== 拉丁/数字为主的名称：走严格边界检查 ======

    bool isBoundary(int charCode) {
      if (charCode == 0) return true;
      if ((charCode >= 0x4E00 && charCode <= 0x9FFF) ||
          (charCode >= 0x3400 && charCode <= 0x4DBF)) return true; // CJK 对英文名字天然视作分隔
      if ((charCode >= 0x41 && charCode <= 0x5A) ||
          (charCode >= 0x61 && charCode <= 0x7A) ||
          (charCode >= 0xFF21 && charCode <= 0xFF3A) ||
          (charCode >= 0xFF41 && charCode <= 0xFF5A) ||
          (charCode >= 0x30 && charCode <= 0x39) ||
          (charCode >= 0xFF10 && charCode <= 0xFF19)) return false;
      if (charCode == 0x00B7 || charCode == 0x2022 ||
          charCode == 0x2D || charCode == 0x5F) return false;
      return true;
    }

    int idx = 0;
    while (true) {
      idx = text.indexOf(name, idx);
      if (idx == -1) return false;
      final before = idx == 0 ? 0 : text.codeUnitAt(idx - 1);
      final after = idx + name.length >= text.length
          ? 0
          : text.codeUnitAt(idx + name.length);
      if (isBoundary(before) && isBoundary(after)) return true;
      idx += name.length;
    }
  }

  String _calculateBirthYear() {
    // 入学时11岁：出生年份 = 时代入学年份 - 11
    return (_startYearForEra(appProvider.era) - 11).toString();
  }

  /// 时代对应的入学年份（游戏开始年份）

  int _startYearForEra(Era era) {
    return switch (era) {
      Era.dumbledore => 1892,
      Era.marauders => 1971,
      Era.first_war => 1976,
      Era.harry_same => 1991,
      Era.post_war => 2020,
      Era.random => 1991,
    };
  }

  // ==================== 开局特质抽取（软保底） ====================

  /// 抽取 3 个开局特质，稀有度软保底

  List<TraitDef> _rollStartingTraits() {
    final byRarity = traitsByRarity();
    final commons = byRarity['common'] ?? [];
    final rares = byRarity['rare'] ?? [];
    final legendaries = byRarity['legendary'] ?? [];

    final picked = <TraitDef>[];
    final usedIds = <String>{};
    int pity = 0; // 连续未出稀有/传说的次数

    while (picked.length < 3) {
      // 软保底：连续未出高稀有度时提升概率
      final pityBoost = (pity ~/ TraitRarityWeights.pityThreshold) * TraitRarityWeights.pityBonus;
      final legendaryP = TraitRarityWeights.legendaryBase + pityBoost * 0.5;
      final rareP = TraitRarityWeights.rareBase + pityBoost;

      final roll = random.nextDouble();
      String rarity;
      if (roll < legendaryP && legendaries.isNotEmpty) {
        rarity = 'legendary';
      } else if (roll < legendaryP + rareP && rares.isNotEmpty) {
        rarity = 'rare';
      } else {
        rarity = 'common';
      }

      final pool = switch (rarity) {
        'legendary' => legendaries,
        'rare' => rares,
        _ => commons,
      };
      final available = pool.where((t) => !usedIds.contains(t.id)).toList();
      if (available.isEmpty) {
        // 该稀有度已抽完，回退到普通
        final fallback = commons.where((t) => !usedIds.contains(t.id)).toList();
        if (fallback.isEmpty) break;
        final t = fallback[random.nextInt(fallback.length)];
        picked.add(t);
        usedIds.add(t.id);
        continue;
      }

      final trait = available[random.nextInt(available.length)];
      picked.add(trait);
      usedIds.add(trait.id);
      if (rarity == 'common') {
        pity++;
      } else {
        pity = 0;
      }
    }
    return picked;
  }

  /// 应用特质属性加成

  void _applyTraitBonuses(List<TraitDef> traits) {
    final p = player;
    if (p == null) return;
    for (final t in traits) {
      t.attributeBonus.forEach((key, bonus) {
        // energy/health 等是顶层字段，attributes 是技能属性
        switch (key) {
          case 'energy':
            p.energy = (p.energy + bonus).clamp(0, 100);
            break;
          case 'health':
            p.health = (p.health + bonus).clamp(0, 100);
            break;
          case 'moral':
            p.playerReputation.add('moral', bonus);
            break;
          case 'spirit':
            p.spirit = (p.spirit + bonus).clamp(0, 100);
            break;
          case 'social':
            // social 既是属性也是声望，这里加到属性
            p.attributes['social'] = ((p.attributes['social'] ?? 50) + bonus).clamp(0, 100);
            break;
          default:
            p.attributes[key] = ((p.attributes[key] ?? 50) + bonus).clamp(0, 100);
        }
      });
      // 节俭特质：初始加隆略多
      if (t.id == 'thrifty') {
        p.galleons += 100;
      }
    }
    if (traits.isNotEmpty) {
      notifications.add('✨ 你获得了特质：${traits.map((t) => t.name).join('、')}');
    }
  }

  /// 特质叙事提示（注入系统提示词）

  String _traitNarrativeHints() {
    final p = player;
    if (p == null || p.traits.isEmpty) return '';
    final hints = p.traits
        .map((id) => traitById(id))
        .where((t) => t != null && t.narrativeHint.isNotEmpty)
        .map((t) => t!.narrativeHint)
        .toList();
    if (hints.isEmpty) return '';
    return '【出身特质】${hints.join('；')}';
  }


  // ==================== 生成开场场景 ====================

  Future<void> _generateOpeningScene() async {
    if (player == null) return;

    final p = player!;
    final wandData = p.wandId != null ? wandById(p.wandId!) : null;
    final wandInfo = wandData != null
        ? '${wandData.name}（${wandData.wood}·${wandData.core}·${wandData.length}）'
        : '尚未选择的魔杖';

    final petInfo = _buildPetDescriptionShort(p);
    final startPoint = _buildStartPointNarrative();

    // 只收集已设定字段，减少 token 噪声
    final profile = <String>[];
    profile.add('姓名：${p.name}｜11岁｜${bloodStatusLabel(p.bloodType)}｜${p.birthLocation}');
    if (p.personalityTraits.isNotEmpty) profile.add('性格：${p.personalityTraits.join('、')}');
    if (p.birthIdentity != null && p.birthIdentity!.isNotEmpty) profile.add('出身：${p.birthIdentity}');
    if (p.appearance != null && p.appearance!.isNotEmpty) profile.add('外貌：${p.appearance}');
    if (p.familyBackground != null && p.familyBackground!.isNotEmpty) profile.add('家族：${p.familyBackground}');
    if (p.childhoodExperiences.isNotEmpty) profile.add('童年：${p.childhoodExperiences.join('；')}');
    if (p.beliefs != null && p.beliefs!.isNotEmpty) profile.add('信念：${p.beliefs}');
    if (p.magicAptitude != null && p.magicAptitude!.isNotEmpty) profile.add('资质：${p.magicAptitude}');
    if (p.initialTalent != null && p.initialTalent!.isNotEmpty) profile.add('天赋：${p.initialTalent}');
    if (p.housePreference != null && p.housePreference!.isNotEmpty) profile.add('学院倾向：${p.housePreference}');
    if (p.traits.isNotEmpty) {
      final traitNames = p.traits
          .map((id) => traitById(id)?.name)
          .where((n) => n != null)
          .join('、');
      if (traitNames.isNotEmpty) profile.add('出身特质：$traitNames');
    }
    profile.add('时代：${_eraLabelShort(appProvider.era)}');
    profile.add('魔杖：$wandInfo');
    profile.add('宠物：$petInfo');

    final wandSourceLine = '玩家的魔杖是奥利凡德先生在对角巷亲手选中的（魔杖选择巫师），绝不是捡来的木棍、祖传物品、或自己制作。';
    final wandDetail = wandData != null
        ? '${wandData.wood}木·${wandData.core}·${wandData.length}'
        : '指定魔杖';
    final prompt = buildOpeningNarrativePrompt(
      profileLine: profile.join('｜'),
      startPoint: startPoint,
      wandDetail: wandDetail,
      wandSourceLine: wandSourceLine,
    );

    if (router == null || !router!.hasNarrativeService) {
      currentNarrative =
          '${p.name}，你在${p.birthLocation}长大，等待来自霍格沃茨的信已经等了很久。\n\n📅 ${worldState.timestamp}\n\n魔法世界的大门即将为你打开。';
      choices = [
        GameChoice(text: '等待猫头鹰送来的信', action: '等待猫头鹰送来的信'),
        GameChoice(text: '收拾行李，准备出发', action: '收拾行李，准备出发'),
        GameChoice(text: '再检查一遍霍格沃茨的入学清单', action: '再检查一遍霍格沃茨的入学清单'),
      ];
      appendRecentTurn(currentNarrative);
      return;
    }

    try {
      final response = await callDeepSeek(prompt);
      parseResponse(response.content);
      accumulateForSummary(currentNarrative);
      appendRecentTurn(currentNarrative);
      notifyListeners();
      autoSave();
    } catch (e) {
      error = e.toString();
      currentNarrative =
          '${p.name}，故事即将开始。请稍候，魔法正在酝酿。';
      choices = [GameChoice(text: '继续', action: '继续')];
      appendRecentTurn(currentNarrative);
      notifyListeners();
      autoSave();
      unawaited(CrashLogger.instance.record(
        e,
        StackTrace.current,
        screen: 'generateOpeningScene',
        extra: 'player=${p.name}, era=${appProvider.era.name}',
      ));
    }
  }

  // ==================== 开场辅助：宠物描述（短版，省token） ====================

  String _buildPetDescriptionShort(Player p) {
    final petId = p.petId;
    final petName = p.petName ?? '';
    if (petId == null) return '未饲养';
    // 优先使用 PetDef 数据层（避免 UI/Provider 两处硬编码不一致）
    final def = petById(petId);
    if (def != null) {
      final ab = def.abilities.take(3).join('·');
      final tf = def.canTransform ? '·可化人形' : '';
      final nm = petName.isNotEmpty ? petName : def.name;
      return '$nm（${def.species}$tf，能力：$ab）';
    }
    // 数据层找不到时的兜底
    switch (petId) {
      case 'owl': return '$petName（猫头鹰·聪明忠诚）';
      case 'cat': return '$petName（猫·神秘敏感）';
      case 'toad': return '$petName（蟾蜍·传统伴侣）';
      case 'rat': return '$petName（老鼠·机灵小巧）';
      case 'kyuubi': return '绯月（九尾灵狐·东方青丘祥瑞，可化人形·幻术/灵视·完全效忠）';
      default: return '$petName（特殊伙伴）';
    }
  }

  // ==================== 开场辅助：剧情起点 ====================

  String _buildStartPointNarrative() {
    switch (openingScene) {
      case 'letter':
        return '故事从你收到霍格沃茨录取通知书的那一刻开始——那只迟来的猫头鹰终于叩响了你的窗。';
      case 'station':
        return '故事从你站在九又四分之三站台前开始——蒸汽火车冒着白烟等待着你。';
      case 'hall':
        return '故事从你第一次踏入霍格沃茨大礼堂开始——金色的烛光在长桌上方摇曳。';
      case 'eve':
        return '故事从分院仪式前夜开始——你躺在床上翻来覆去，想着明天会被分到哪个学院。';
      default:
        return '故事从你站在九又四分之三站台前开始——蒸汽火车冒着白烟等待着你。';
    }
  }

  // ==================== 处理选择 / 指令 ====================

  String computeHouseLocal() {
    final traits = player!.personalityTraits.join(' ');
    final dims = player!.houseDimensions;

    // 学院倾向优先
    final pref = player!.housePreference;
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

    // 基于学院四维（houseDimensions）
    final courage = (dims['courage'] ?? 50).toInt();
    final ambition = (dims['ambition'] ?? 50).toInt();
    final wisdom = (dims['wisdom'] ?? 50).toInt();
    final loyalty = (dims['loyalty'] ?? 50).toInt();
    scores['Gryffindor'] = (scores['Gryffindor'] ?? 0) + courage;
    scores['Slytherin'] = (scores['Slytherin'] ?? 0) + ambition;
    scores['Ravenclaw'] = (scores['Ravenclaw'] ?? 0) + wisdom;
    scores['Hufflepuff'] = (scores['Hufflepuff'] ?? 0) + loyalty;

    // 政治倾向加分
    final pol = player!.politicalTendency ?? '';
    if (pol.contains('纯血')) scores['Slytherin'] = (scores['Slytherin'] ?? 0) + 1;
    if (pol.contains('平等') || pol.contains('凤凰社')) scores['Gryffindor'] = (scores['Gryffindor'] ?? 0) + 1;

    // 血统背景
    final blood = player!.bloodType;
    if (blood == 'pureblood') scores['Slytherin'] = (scores['Slytherin'] ?? 0) + 1;
    if (blood == 'muggleborn') scores['Gryffindor'] = (scores['Gryffindor'] ?? 0) + 1;

    // 如果都是0，默认可变随机
    final maxScore = scores.values.reduce((a, b) => a > b ? a : b);
    if (maxScore == 0) {
      final houses = ['Gryffindor', 'Slytherin', 'Ravenclaw', 'Hufflepuff'];
      return houses[random.nextInt(4)];
    }

    // 最高分校，但加入少量随机扰动（防止同质化）
    final candidates = scores.entries.where((e) => e.value == maxScore).toList();
    candidates.shuffle(random);
    return candidates.first.key;
  }

  String generateSortingNarrative(String house) {
    final houseName = switch (house) {
      'Gryffindor' => '格兰芬多',
      'Slytherin' => '斯莱特林',
      'Ravenclaw' => '拉文克劳',
      'Hufflepuff' => '赫奇帕奇',
      _ => '格兰芬多',
    };

    final thoughts = [
      '嗯……有意思。这个孩子有${player!.personalityTraits.join('、')}的特质。',
      '让我想想……勇敢？智慧？忠诚？野心？',
      '这很有趣，真的很有趣。',
      '决定了——',
    ];
    thoughts.shuffle(random);

    return '分院帽在你的头顶停留了片刻，轻声低语：「${thoughts.join(' ')}」\n\n'
        '最终它大声宣布：**$houseName**！';
  }

  // ==================== 魔杖选择（本地逻辑，不消耗 token） ====================
  Future<Map<String, dynamic>> selectWand(List<Map<String, dynamic>> options) async {
    if (player == null) {
      return {'selected': options.first, 'narrative': ''};
    }

    isLoading = true;
    notifyListeners();

    try {
      final selected = _computeWandLocal(options);
      player!.wandId = selected['id'] as String?;
      unlockAchievement('first_wand');
      bumpImpactScore(0.03, debugReason: '首次魔杖选择');
      final narrative = _generateWandNarrative(selected);

      isLoading = false;
      notifyListeners();
      return {'selected': selected, 'narrative': narrative};
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return {'selected': options.first, 'narrative': ''};
    }
  }

  Map<String, dynamic> _computeWandLocal(List<Map<String, dynamic>> options) {
    if (options.isEmpty) return {};

    final personality = player!.personalityTraits.join(' ');
    final dims = player!.houseDimensions;

    // 根据玩家特质为每根魔杖打分
    final scored = <String, double>{};
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

      // 学院四维加成
      final courage = dims['courage'] ?? 50;
      final ambition = dims['ambition'] ?? 50;
      final wisdom = dims['wisdom'] ?? 50;
      final loyalty = dims['loyalty'] ?? 50;

      if (wood == '冬青木' || wood == '橡木') score += courage * 0.05;
      if (wood == '紫杉木' || wood == '榆木') score += ambition * 0.05;
      if (wood == '葡萄藤木' || wood == '枫木') score += wisdom * 0.05;
      if (wood == '樱桃木' || wood == '雪松木' || wood == '柳木') score += loyalty * 0.05;

      final wid = wand['id'] ?? wand['name'] ?? '';
      scored[wid] = score;
    }

    // 选最高分，同分随机
    final maxScore = scored.values.isEmpty ? 0.0 : scored.values.reduce((a, b) => a > b ? a : b);
    final candidates = scored.keys.where((w) => scored[w] == maxScore).toList();
    candidates.shuffle(random);
    final bestId = candidates.first;
    for (final wand in options) {
      if ((wand['id'] ?? wand['name']) == bestId) return wand;
    }
    return options.first;
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
}
