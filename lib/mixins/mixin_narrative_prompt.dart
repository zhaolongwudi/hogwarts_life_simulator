import 'dart:math';


import '../data/locations.dart';
import '../models/game_systems.dart';
import '../models/npc.dart';
import '../providers/game_provider_base.dart';
import '../utils/stagnation_detector.dart';
import '../data/attribute_data.dart';
import '../data/course_data.dart';
import '../data/director_beat_data.dart';
import '../data/era_data.dart';
import '../data/faculty_data.dart';
import '../data/game_config_rules.dart';
import '../data/monthly_event_data.dart';
import '../data/narrative_time_rules.dart';
import '../data/npc_schedule_rules.dart';
import '../data/parallel_data.dart';
import '../data/rivalry_data.dart';
import '../data/scar_data.dart';
import '../data/time_cost_rules.dart';
import '../data/wand_data.dart';
import '../data/worldline_data.dart';
import '../models/long_term_memory.dart';
import '../prompts/narrative_prompts.dart';
import 'mixin_narrative_canon.dart';
import 'mixin_narrative_continuity.dart';
import 'mixin_summary_memory.dart';


/// 提示词组装器（第九轮 r9-2 拆分自 mixin_narrative.dart）。
///
/// 【拆分说明】AI 提示词主线 `buildPrompt`（T0-T4 记忆注入/硬设定/连续性
/// 桥接/写作要求，440 行）+ 关键上下文族（`buildCriticalContext` /
/// `buildSceneContext` / `buildQuietPeriodHint` / `isCalmNarrativeContext` /
/// `npcsInCurrentLocation`）+ 意图关键词正则族与锚点图标正则，
/// 约 960 行，从 mixin_narrative 迁入本文件。`GameNarrativeMixin` 声明
/// `on GameNarrativePromptMixin`（跨 mixin 走 on 链，遵守 ADR-001），
/// `GameProvider` 的 with 列表中 prompt 在 narrative 之前。
/// 行为零变化：所有成员仍是 GameProvider 上的实例成员，测试契约不变。
mixin GameNarrativePromptMixin on GameProviderBase, GameNarrativeContinuityMixin,
    GameNarrativeCanonMixin, GameSummaryMemoryMixin {

  /// 上一次注入的政治立场值，用于检测变化（没变化时跳过重复注入）
  /// 选项文本去前缀噪声（canon 过滤链复用，预编译；static 不跨 mixin，本地副本）
  static final RegExp reLeadingNonTextNarrative =
      RegExp(r'^[^\u4e00-\u9fa5A-Za-z]*');

  String lastPoliticalStance = '';

String formatImpact(double score) {
    if (score >= 1.0) return '极高影响力（深度改变历史走向）';
    if (score >= 0.5) return '高影响力（知名人物/学院领袖候选）';
    if (score >= 0.2) return '中等影响力（小有名气）';
    if (score >= 0.05) return '低影响力（普通学生）';
    return '无影响力（边缘人物）';
  }


    /// 锚点去重时剥掉事件前缀图标。原先在两个 for 循环里各写一份，
  /// 每个事件都重新编译一次。
  static final RegExp anchorIconPrefix = RegExp(
    r'^([\u{1F4CA}\u{1F464}\u{1F4AC}\u{1F4C5}\u{1F3C6}\u{1F31F}\u{1F4F0}])',
    unicode: true,
  );


    /// 去重用的空白折叠正则，预先编译，避免在候选过滤循环里反复构造。

    static const StagnationDetector stagnationPrompt = StagnationDetector.instance;

  @override
  int stagnationThresholdFor(String location) =>
      stagnationPrompt.thresholdFor(location);
  @override
  bool narrativeHasUnresolvedHook(String narrative) =>
      stagnationPrompt.hasUnresolvedHook(narrative);


    List<NPC> npcsInCurrentLocation() {
    final location = worldState.currentLocation;
    if (location == null || location.isEmpty) return [];
    return npcRegistry.values.where((npc) {
      // 统一走 isSameLocation（两边先归一再比）：
      // 以前这里裸写 `npc.currentLocation.contains(loc)`，两边都不归一，
      // 玩家写「教室」而教授在「霍格沃茨·变形术教室」时匹配不上，
      // 麦格 / 斯内普 / 弗利维等六位守教室的教授会从【在场】集体消失。
      return npc.introduced && isSameLocation(npc.currentLocation, location);
    }).toList();
  }


    String buildSceneContext() {
    final parts = <String>[];

    // 防御：worldState 有默认值（非空）但为防止未来改类型，统一局部变量引用；
    // player 为可空类型，必须判空
    final ws = worldState;
    final p = player;

    // worldState 始终非空，此处无需 null 判断（避免 analyzer unnecessary_null_comparison）
    final npcsHere = npcsInCurrentLocation();
    if (npcsHere.isNotEmpty) {
      // 档位标签而非裸好感数值（框架2 §6 信息限制 + 审查 F1）：
      // 裸数字「斯内普55」对模型是噪音/误导（它会把数字当指令写出与真实
      // 关系不符的剧情），档位标签「斯内普（对你态度冷淡）」才是关系基调。
      final npcNames = npcsHere
          .where((n) => n.introduced)
          .map((n) {
            if (!n.isAlive) return '${n.name}（已故）';
            final stage = n.affectionStage;
            return stage.isEmpty ? n.name : '${n.name}（$stage）';
          })
          .join('、');
      if (npcNames.isNotEmpty) {
        parts.add('【在场】$npcNames');
      }
    }

    // 宿敌单独成段。行为指令比较长，塞进【在场】里会把那一行撑爆；
    // 而且只有真有宿敌站在面前时才值得花这份 token，
    // 没有仇人的时候这几行一个字都不会出现。
    final today = ws.time.absoluteDayIndex;
    for (final r in npcsHere) {
      if (!r.introduced || !r.hasGrudge) continue;
      final tier = r.rivalryTier(today);
      if (tier == RivalryTier.none) continue;
      parts.add(
        '【宿敌·${rivalryBadgeFor(tier)} ${r.name}】'
        '${rivalryDirectiveFor(tier, r.name, r.rivalryReason())}',
      );
    }
    for (final r in npcsHere) {
      if (!r.introduced || !r.formerRival) continue;
      parts.add('【旧怨已了·${r.name}】${formerRivalLine(r.name)}');
    }

    // 【意外】他不该在这儿。
    // 作息例外让某些人出现在反常的地方，可如果 AI 只看见
    // "斯内普：55"这一行，写出来的就只是"斯内普在教室里"。
    // 有意思的不是他在哪儿，是他在这儿干什么——那句 reason 才是
    // 这段戏的引子（他在熬一种不能在地窖里熬的东西，
    // 被撞见时先做的动作是用身体挡住坩埚）。
    //
    // 跟【宿敌】同理：只有真有人撞上了才花这份 token，
    // 大多数回合这一段一个字都不会出现。
    for (final n in npcsHere) {
      if (!n.introduced) continue;
      final ex = scheduleExceptionFor(
        n.id,
        ws.time.hour,
        weekday: ws.time.weekday,
      );
      if (ex == null) continue;
      parts.add(
        '【意外·${n.name}】他此刻不该在这儿：${ex.reason}'
        '（这是本回合免费送上门的一个场面，可以正经写一段，'
        '也可以只是路过时看见一眼）',
      );
    }

    // 宿敌不一定正站在你面前。只让 AI 看见"眼前这个人恨你"，
    // 那"他在走廊尽头堵你""你摔倒时旁边有人笑"这类戏永远写不出来——
    // 因为 AI 压根不知道城堡另一头有这么一号人。
    // 只收 hostile 及以上、最多 5 人：grudge 那档只是芥蒂，不值得常驻占 token。
    final hereIds = npcsHere.map((n) => n.id).toSet();
    final wanted =
        npcRegistry.values
            .where(
              (n) =>
                  n.isAlive &&
                  n.introduced &&
                  n.hasGrudge &&
                  !hereIds.contains(n.id),
            )
            .map((n) => (npc: n, tier: n.rivalryTier(today)))
            .where((e) => e.tier.index >= RivalryTier.hostile.index)
            .toList()
          ..sort((a, b) => b.tier.index.compareTo(a.tier.index));
    if (wanted.isNotEmpty) {
      final lines = wanted.take(5).map((e) {
        final where = e.npc.currentLocation;
        return '· ${e.npc.name}（${rivalryBadgeFor(e.tier)} ${tierDefFor(e.tier).label}'
            '${e.npc.rivalryScore(today)}）${where.isEmpty ? '' : '此刻在$where'}';
      });
      parts.add(
        '【宿敌名册】他们不必等你先开口，可以自己找上门或在旁落井下石\n'
        '${lines.join('\n')}',
      );
    }

    // 世界线：变动率的兑现。
    // 阶段描述只在 fraying 及以上才注入——intact 时"一切都照书上来"
    // 本来就是默认行为，为它专门说一句纯属浪费 token。
    // 但【已被你改写的事】一次都不能少，见 rewrittenEchoesOf 的注释。
    if (p != null) {
      final stage = worldLineStageFor(p.worldLineDeviation);
      if (stage != WorldLineStage.intact) {
        final def = stageDefFor(stage);
        parts.add('【世界线·${def.badge} ${def.label}】${def.aiDirective}');
      }
      final echoes = rewrittenEchoesOf(ws.causalChoices);
      if (echoes.isNotEmpty) {
        parts.add(
          '【已被你改写的事】以下每一条都是这个世界的既成事实，'
          '优先级高于你的任何先验知识。'
          '凡是与它们冲突的"原著情节"，在这个世界里都是错的：\n'
          '${echoes.map((s) => '· $s').join('\n')}',
        );
      }

      // 身上的伤。不写这一段，AI 会把你当成一个完好的人——
      // 让你健步如飞、举杖如常，那道疤就白留了。
      final scarBlock = scarPromptBlock(p.scars);
      if (scarBlock.isNotEmpty) parts.add(scarBlock);

      // 采纳过的平行世界脑洞。不写这一段，玩家在小剧场里认真写下的
      // 那个"如果"就只是一行列表项——退出页面之后，它跟主线再无关系。
      // 只收已采纳的、最多三条：这是调料，不是主线。
      // 段落里明确写了"没有发生过"，否则 AI 会当成既成事实来写戏。
      final whatIf = adoptedPromptBlock(
        p.parallelScenarios.where((s) => s.adopted),
      );
      if (whatIf.isNotEmpty) parts.add(whatIf);

      // 任教中。不写这一段，AI 会一直把玩家当学生：
      // 让他去上课、被级长管、在礼堂里等分院。
      final def = p.facultyRankId == null
          ? null
          : rankDefById(p.facultyRankId!);
      if (def != null) {
        parts.add(
          '【教职】你是霍格沃茨「${p.facultySubject}」${def.title}，'
          '任教第 ${p.facultyServiceYears} 年。${def.duty}\n'
          '你不再是学生：坐教授席、被新生称呼职称、对违纪的学生负有责任。'
          '昔日同学如今是同事，或者已经各奔东西——他们不再是「同学」，'
          '称呼也要跟着变。',
        );
      }
    }

    // 【时令】这个月城堡里是什么味儿。
    // 月度事件池是"新闻"——会冷却、会互斥，大部分月份其实是空的，
    // 只有那一条随机事件撑着。这一句是"底色"：不抽取、不冷却，
    // 每个月都有一句，每回合都在。
    // 没有底色的月份，AI 写出来的就只是一段没有季节的场景——
    // 五月和十一月在他的笔下没有任何区别。
    final atmosphere = atmosphereForMonth(ws.time.month);
    if (atmosphere.isNotEmpty) parts.add('【时令】$atmosphere');

    final hour = ws.time.hour;
    final timeDesc = hour >= 22 || hour < 6
        ? '深夜'
        : hour >= 18
        ? '夜晚'
        : hour >= 14
        ? '下午'
        : hour >= 10
        ? '上午'
        : '清晨';
    parts.add('【时段】$timeDesc·${ws.time.formattedTime}');

    if (p != null && p.energy < 30) {
      parts.add('【提示】玩家精力较低，建议休息');
    }

    return parts.join('\n');
  }


    String buildQuietPeriodHint() {
    // 如果最近一次转折回合数缺失（开局），跳过
    if (turnsSinceLastTurnBeat < 0) return '';

    // 连续 5 回合以上无转折 → 更强提示
    if (turnsSinceLastTurnBeat >= 5) {
      return '\n📌 【安静期提示】已经连续 $turnsSinceLastTurnBeat 回合没有转折，'
          '本回合必须发生一件实质性的事件——可以是新情报、新冲突、新人物登场，'
          '或者一个旧悬念的重新浮现。不能让剧情继续在原地打转。\n\n';
    }

    // 连续 3 回合无转折 → 提示注入小波澜
    if (turnsSinceLastTurnBeat >= 3) {
      return '\n📌 【安静期提示】最近 $turnsSinceLastTurnBeat 回合没有发生重大转折，'
          '本回合请引入一点小小的波澜——可以是一封意外的信、一个奇怪的声音、'
          '一个突然出现的同学、一句意味深长的话，或者一件打破常规的小事。'
          '不必是惊天动地的大事，但必须让剧情有"往前走"的感觉。\n\n';
    }

    return '';
  }


    bool isCalmNarrativeContext() {
    final t = worldState.time;
    if (worldState.term == 'summer') return true;
    if (t.month == 5 || t.month == 6) return true;
    if (t.hour >= 23 || t.hour < 6) return true;
    return false;
  }


    String buildCriticalContext(String action) {
    final p = player;
    if (p == null) return '';
    final a = action.toLowerCase();
    final parts = <String>[];

    // 战斗/冲突 → 注入关键属性、魔咒、HP
    if (a.contains(reCombatKeywords)) {
      final combatAttrs = p.attributes.entries
          .where((e) => e.value != 0)
          .take(3)
          .map((e) => '${attrLabel(e.key)}:${e.value}')
          .join(' ');
      if (combatAttrs.isNotEmpty) parts.add('【战斗】$combatAttrs');
      if (p.learnedSpells.isNotEmpty) {
        final spells = p.learnedSpells.entries
            .take(3)
            .map((e) => e.key)
            .join('、');
        parts.add('魔咒:$spells');
      }
      parts.add('HP:${p.health} MP:${p.magic}');
    }

    // 学业/考试 → 注入相关属性
    if (a.contains(reStudyKeywords)) {
      // 原来这里筛的是 const {'智慧','魔力','勤奋'}——属性表里根本没有这三个
      // 名字，过滤结果恒为空，【学业】上下文从来没注入过。改成按课程会提升的
      // 属性筛（kStudyAttributeKeys，与 course_data 对齐）。
      final study = p.attributes.entries
          .where((e) => kStudyAttributeKeys.contains(e.key))
          .where((e) => e.value != 0)
          .map((e) => '${attrLabel(e.key)}:${e.value}')
          .join(' ');
      if (study.isNotEmpty) parts.add('【学业】$study');
    }

    // 社交/对话：若行动中提到具体NPC名则精准注入其好感，否则按关键词注入
    final mentioned = npcRegistry.values
        .where((n) => action.contains(n.name))
        .toList();
    if (mentioned.isNotEmpty) {
      final affs = mentioned
          .take(2)
          .map((n) => '${n.name}:好感${n.affection}(${n.affectionStage})')
          .join('；');
      parts.add('【关系】$affs');
    } else if (a.contains(reRomanceKeywords)) {
      final affs = formatAffections(maxEntries: 2);
      if (affs.isNotEmpty && !affs.contains('暂无深入关系')) parts.add('【关系】$affs');
    }

    // 购物/交易 → 注入金币和前3背包物品
    if (a.contains(reEconomyKeywords)) {
      parts.add('【经济】加隆:${p.galleons} 银行:${p.bankGalleons}');
      if (p.inventory.isNotEmpty) {
        final inv = p.inventory.take(3).map((e) => e.name).join('、');
        parts.add('背包:$inv');
      }
    }

    return parts.isNotEmpty ? '【状态】\n${parts.join('\n')}' : '';
  }


    static final RegExp reAcquaintanceKeywords = RegExp(
      r'(结识|认识了|正式见面|成为朋友|初见了)',
      caseSensitive: false);

  static final RegExp reCombatKeywords =
      RegExp(r'(战斗|决斗|攻击|防御|施展咒语|施法|黑魔法|施咒|念咒|反击)');

  static final RegExp reStudyKeywords =
      RegExp(r'(上课|考试|测验|作业|复习|学习|论文|写论文|做功课)');

  static final RegExp reRomanceKeywords =
      RegExp(r'(约会|表白|心动|拥抱|接吻|单独见面|私聊)');

  static final RegExp reEconomyKeywords =
      RegExp(r'(购买|出售|购物|交易|取钱|存钱|存取古灵阁)');


  String buildPrompt(String safeAction) {
      final p = player!;

      final contextBuffer = StringBuffer();

      // 优先使用 Player 字段；若为 null，resolveMagicAptitude 会从 T0 核心事实回填
      // （并写回 Player，避免后续每回合都解析）
      final effectiveAptitude = resolveMagicAptitude(p);
      final aptitudeForPrompt = effectiveAptitude.isEmpty
          ? '普通'
          : effectiveAptitude;

      final profileLine =
          '【档案】${p.name}·${p.house ?? '未分院'}·${p.grade}年·天赋$aptitudeForPrompt·精神${p.spirit}·精力${p.energy}';
      final impactLine = '影响力：${formatImpact(worldState.playerImpactScore)}';
      contextBuffer.writeln('$profileLine｜$impactLine');
      contextBuffer.writeln('');

      // ========== 硬设定：在任校长 / 杖芯 / 当前可达区域 ==========
      // 这三样以前都写在数据表里却没人读：
      //  - eraHeadmaster 零引用 → 开学宴的致辞者在 1892 年还是邓布利多
      //    （那年他本人是 11 岁的新生）；
      //  - wandCoreTraits 零引用 → 选什么杖芯对数值和叙事都没影响；
      //  - MapRegionDef.unlockCondition 只当文案打印 →
      //    写着「高年级开放」的禁林，一年级新生照样一个人走进去。
      final settingLine = <String>[
        '校长：${headmasterLineForEra(eraDefByEra(appProvider.era).eraKey)}',
        if (wandCoreTraitLine(wandById(p.wandId ?? '')?.core).isNotEmpty)
          wandCoreTraitLine(wandById(p.wandId ?? '')?.core),
      ].join('｜');
      contextBuffer.writeln('【本局硬设定】$settingLine');

      // 政治立场原先只在开局的 system prompt 里注入过一次。
      // LLM 记不住二十回合前的设定，中期立场会漂：开局定的「纯血至上」，
      // 二十回合后开始跟麻瓜出身的同学称兄道弟，玩家会觉得这人设是假的。
      // 每回合重述一次，成本一行。只在变化时注入，避免重复。
      final stance = p.politicalTendency?.trim() ?? '';
      if (stance.isNotEmpty && stance != lastPoliticalStance) {
        lastPoliticalStance = stance;
        contextBuffer.writeln(
          '【政治立场】$stance（主角对纯血论、麻瓜出身、混血的态度；'
          'NPC 的台词与玩家可选的做法都需贴合此立场，'
          '不要因为剧情一时温情就软化或反转）',
        );
      }

      final isWeekend = isWeekendWeekday(worldState.time.weekday);
      final lockedNow = lockedRegionsFor(grade: p.grade, isWeekend: isWeekend);
      if (lockedNow.isNotEmpty) {
        contextBuffer.writeln(
          '【当前无法进入的区域】${lockedNow.map((r) => '${r.name}（${r.unlockCondition ?? '未开放'}）').join('、')}'
          ' —— 玩家现在到不了这些地方，不要安排他独自前往；'
          '确有需要时必须有教授带队或给出明确的违规代价。',
        );
      }
      contextBuffer.writeln('');

      // ========== T0 / T1 / T2 / T3 结构化长期记忆注入（永不压缩的纯事实层） ==========
      // 永远放在【世界上下文】最前面，防止后面截断看不到
      // T0: 核心事实 (importance ≥ 5，重要性高到低)
      //   分层注入（修复"永不遗忘层在注入侧被截断"）：
      //     · importance ≥ kPersistentFactImportance（9）→ 全量注入，
      //       上限 kT0InjectionPersistentQuota（= 存储容量 kMaxPersistentKeyFacts）
      //     · 其余 → 按分数选，上限 kT0InjectionRegularQuota
      //   旧实现写死 `i < 40`，而存储层允许永不遗忘层留 60 条，
      //   导致第 41 条起的 9 分事实（结婚/死亡/誓言）存着但永远读不到。
      final t0 = memory.keyFacts.where((f) => f.importance >= 5).toList()
        ..sort((a, b) {
          final c = b.importance.compareTo(a.importance);
          // 同分按写入时间新的靠前：Dart 的 sort 不稳定，大量 9 分并列时
          // 若不加次级键，前 N 条每回合可能换一批，AI 记住的旧事随机漂移。
          if (c != 0) return c;
          return b.absoluteDay.compareTo(a.absoluteDay);
        });
      // 第16轮G：过滤与 Player 权威事实冲突的历史污染条目。
      // P0-1 修复后新摘要不会写错，但更早版本的错误摘要已写进 keyFacts
      // （如"宠物猫头鹰绯月"——绯月是九尾灵狐；"闪电形伤疤"——主角非哈利）。
      // 这里在注入侧拦截，不改存档数据，AI 不再读到冲突事实。
      t0.removeWhere((f) => factConflictsWithAuthority(f.fact));
      if (t0.isNotEmpty) {
        // 配额由纯函数算，便于单测（test/t0_injection_quota_test.dart）。
        final quota = computeT0InjectionQuota(
          t0.map((f) => f.importance).toList(),
        );
        contextBuffer.writeln('【T0 核心事实（永不遗忘；纯事实，不得更改或遗忘）】');
        for (var i = 0; i < quota.total; i++) {
          final f = t0[i];
          contextBuffer.writeln('• [${f.importance}] ${f.fact}');
        }
        contextBuffer.writeln('');
      }
      // T1: 未完结事项 (open 状态优先，importance 排序，最多 40 条)
      final t1 = memory.openLoops.where((l) => l.status == 'open').toList()
        ..sort((a, b) => b.importance.compareTo(a.importance));
      if (t1.isNotEmpty) {
        contextBuffer.writeln('【T1 未完结事项（承诺/债务/约定/未完成任务，说话要算数）】');
        for (int i = 0; i < t1.length && i < 40; i++) {
          final l = t1[i];
          contextBuffer.writeln('• [${l.importance}] ${l.description}');
        }
        contextBuffer.writeln('');
      }
      // ========== 短期断言：上回合生效的物理/姿态/状态事实（防止 AI 失忆打脸） ==========
      final assertionsBlock = buildAssertionsPromptBlock();
      if (assertionsBlock.isNotEmpty) {
        contextBuffer.write(assertionsBlock);
      }
      // ========== T1 超期未推进的"别忘了这些重要伏笔"提醒 ==========
      final loopsHint = buildOpenLoopsStagnationHint();
      if (loopsHint.isNotEmpty) {
        contextBuffer.write(loopsHint);
      }
      // T2: NPC 关键关系（场景感知裁剪，同场景全量+高好感摘要）
      final currentLoc = worldState.currentLocation ?? '';
      final allIntroduced = npcRegistry.values.where((npc) => npc.introduced == true).toList()
        ..sort((a, b) => b.affection.abs().compareTo(a.affection.abs()));

      // 同场景NPC（全量注入）
      final sameLocationNpcs = allIntroduced.where((n) => n.currentLocation == currentLoc).take(5).toList();
      // 高好感场景外NPC（摘要注入）
      final otherHighAffection = allIntroduced
        .where((n) => n.currentLocation != currentLoc && !sameLocationNpcs.contains(n))
        .take(3)
        .toList();

      final t2Lines = <String>[];
      for (final npc in sameLocationNpcs) {
        final anchor = memory.relationshipAnchors[npc.id];
        if (anchor == null) continue;
        final buf = StringBuffer();
        buf.write('${npc.name}(好感${npc.affection >= 0 ? '+' : ''}${npc.affection}，${anchor.currentStage})');
        if (anchor.firstMeeting.isNotEmpty) buf.write('｜初见:${anchor.firstMeeting}');
        if (anchor.keyMoments.isNotEmpty) {
          buf.write('｜关键:${anchor.keyMoments.skip(max(0, anchor.keyMoments.length - 3)).join("；")}');
        }
        if (anchor.secretsShared.isNotEmpty) buf.write('｜交换秘密:${anchor.secretsShared.take(3).join("；")}');
        if (anchor.promisesExchanged.isNotEmpty) buf.write('｜承诺:${anchor.promisesExchanged.take(3).join("；")}');
        t2Lines.add('• ${buf.toString()}');
      }
      for (final npc in otherHighAffection) {
        final anchor = memory.relationshipAnchors[npc.id];
        if (anchor == null) continue;
        t2Lines.add('• ${npc.name}(好感${npc.affection >= 0 ? '+' : ''}${npc.affection}，${anchor.currentStage})');
      }
      if (t2Lines.isNotEmpty) {
        contextBuffer.writeln('【T2 NPC 关键关系（纯事实结构锚，永不压缩）】');
        contextBuffer.writeln(t2Lines.join('\n'));
        contextBuffer.writeln('');
      }
      // T3: 世界事件银行（重要性 * 新鲜度，近期优先 + 高分补位，总 40 条）
      // 审查 F7：老事件（>60 天）分数低但仍占名额，事件多时把近期事件挤掉，
      // AI 参考的是"几个月前的旧闻"。改为：近 60 天事件取前 30 条，
      // 60 天外的高分事件最多补 10 条——近期优先，重要旧事不丢。
      final ts = worldState.time.absoluteDayIndex;
      final t3Order = <WorldEventRecord, int>{
        for (var i = 0; i < memory.worldEvents.length; i++)
          memory.worldEvents[i]: i,
      };
      int t3Cmp(WorldEventRecord a, WorldEventRecord b) {
        final c = b.score(ts).compareTo(a.score(ts));
        if (c != 0) return c;
        // 与淘汰侧同一套次级键：自动提取的事件 importance 恒为 6，500 条
        // 里大量同分，不补键的话 Dart 的不稳定排序会让每回合注入的前 40 条
        // 换一批，玩家感觉 AI 记的世界线在随机漂移。
        final d = b.absoluteDay.compareTo(a.absoluteDay);
        if (d != 0) return d;
        return (t3Order[b] ?? 0).compareTo(t3Order[a] ?? 0);
      }

      final recentEvents = List<WorldEventRecord>.from(
        memory.worldEvents,
      ).where((e) => ts - e.absoluteDay <= 60).toList()..sort(t3Cmp);
      final oldEvents = List<WorldEventRecord>.from(
        memory.worldEvents,
      ).where((e) => ts - e.absoluteDay > 60).toList()..sort(t3Cmp);
      final t3 = <WorldEventRecord>[
        // S3 减法：原先 近期 30 + 旧 10 = 40 条，每回合注入约 800~1500 token，
        // 而其中绝大多数对「本回合该怎么写」零信息量（自动提取的事件 importance
        // 恒为 6，同分堆叠）。降到 近期 12 + 旧 3 = 15 条：保留「最近发生了什么」
        // 的骨架，把预算让给 T0 事实与在场人物。
        ...recentEvents.take(12),
        ...oldEvents.take(3),
      ];
      if (t3.isNotEmpty) {
        contextBuffer.writeln('【T3 世界事件银行（近期优先，按重要性+新鲜度排序）】');
        for (final e in t3) {
          final cons = e.consequences.isNotEmpty
              ? ' → 后续:${e.consequences.join(";")}'
              : '';
          contextBuffer.writeln(
            '• [${e.importance}]${e.timestamp} ${e.category}｜${e.title}:${e.description}$cons',
          );
        }
        contextBuffer.writeln('');
      }

      // ========== T4 自然语言摘要（有损压缩历史背景，权重最低，严格控量） ==========
      // 重要：T4 是 LLM 压缩的「模糊历史记忆」，可能包含过期/错误细节（如"开局巨怪事件"）
      //      → 模型能力升级后放宽到 600 字注入，但仍保持"不能用于生成当前选项"的强约束
      //      → 跳过阈值从 12 条放宽到 30 条，给模型更多参考
      if (narrativeSummary.isNotEmpty) {
        final structuredCount = t0.length + t1.length;
        // 以前这里是「结构化事实少于 30 条才注入，否则整段不注入」。
        // 而 t0 数的是**未截断**的 importance≥4 事实：开局 10 条，
        // 每 20 回合一次摘要、每次最多 10 条，三次摘要后就稳稳超过 30，
        // 于是从中期开始 narrativeSummary 永久不再进入 prompt——
        // 摘要任务照样每 20 回合跑一次，结果却从来没人读。
        // 整段剧情脉络（谁跟谁好上了、结了什么怨、许过什么诺）只剩碎片。
        //
        // 改成按量给：事实越多，摘要给得越短，但永远不归零。
        final budget = structuredCount < 30
            ? 600
            : structuredCount < 60
            ? 400
            : 250;
        final trimmedSummary = narrativeSummary.length > budget
            ? '${narrativeSummary.substring(0, budget)}…'
            : narrativeSummary;
        // 强约束：只当"关系和转折"参考，严格禁止基于此生成当前回合选项/场景
        contextBuffer.write(
          '【历史背景（仅供参考，严禁基于此生成当前回合的选项与场景）】\n$trimmedSummary\n\n',
        );
      }

      // 保留旧的 world_state.recent* 注入，作为软备份（与 T3 并存不冲突）
      // 2026-08-23：6→12 条；过滤"好感本周已达上限"这类系统通知刷屏
      final ws = worldState;
      final worldAnchors = <String>[];
      final alreadyAnchors = <String>{}; // 去重
      // 世界重大事件锚点「伪造事件」真校验：
      // - 🏆成就类：必须真正解锁才允许注入（check against player.achievements）
      // - 👤结识类：必须对应 NPC 确实 introduced=true 才允许注入
      // - 否则直接丢弃（AI 之前乱塞"你认识哈利""你获得了什么什么成就"都是伪造事件）
      final introducedSet = npcRegistry.values
          .where((n) => n.introduced)
          .map((n) => n.name)
          .toSet();

      bool looksFake(String text) {
        final clean = text.replaceAll(reLeadingNonTextNarrative, '');
        // 成就类伪造：含"成就/🏆"，但 achievement 关键词不在已解锁集合
        if (clean.contains('成就') || text.contains('🏆')) {
          final unlocked = player?.achievements ?? const <String>[];
          // 尝试找成就id/名称；若在已解锁集合找不到，算伪造
          if (unlocked.isEmpty) return true; // 宣称解锁但全局没解过任何成就=假
          // 按名称匹配：把 clean 与已解锁成就描述做交集
          final names = achievementCatalog.map((a) => a.id).toSet()
            ..addAll(achievementCatalog.map((a) => a.name));
          final hitAch = names.any((n) => n.isNotEmpty && clean.contains(n));
          // 双重校验：还必须有具体成就 ID 出现在已解锁列表中（避免文案命中但未解锁）
          final hitUnlocked = unlocked.any(
            (id) =>
                clean.contains(id) ||
                clean.contains(
                  achievementCatalog
                      .firstWhere(
                        (a) => a.id == id,
                        orElse: () => achievementCatalog.first,
                      )
                      .name,
                ),
          );
          if (!(hitAch && hitUnlocked)) return true;
        }
        // 结识类伪造：含"结识/认识/见面/认识了/👤"但对应NPC没introduced
        if (reAcquaintanceKeywords.hasMatch(clean) ||
            text.contains('👤')) {
          final hitNpc = introducedSet.any(
            (n) => n.isNotEmpty && clean.contains(n),
          );
          if (!hitNpc) return true;
        }
        return false;
      }

      // 近期事件锚点注入（如果 T3 已经注入足够近期事件，则跳过重复注入）
      if (t3.isNotEmpty && t3.any((e) => ts - e.absoluteDay <= 3)) {
        // T3 已包含近期事件，跳过重复注入
      } else {
        // 日志分析第16轮D：CG/成就类锚点对 AI 当前回合零信息量却刷屏
        // （16 条里 14 条是「解锁CG」），挤掉真正的剧情事件 → 降权：
        // 成就/CG 全局最多保留 2 条（且只取最新的），剧情事件优先占满。
        bool isMetaEvent(String e) =>
            e.contains('🏆') || e.contains('📸') || e.contains('解锁成就') ||
            e.contains('解锁CG');
        var metaKept = 0;
        if (ws.recentEvents.isNotEmpty) {
          for (final ev in ws.recentEvents.reversed) {
            final e = ev.text;
            if (e.contains('好感本周已达上限') || e.contains('周好感度已达上限')) continue;
            if (looksFake(e)) continue;
            if (isMetaEvent(e)) {
              if (metaKept >= 2) continue;
              metaKept++;
            }
            final k = e.replaceAll(anchorIconPrefix, '').trim();
            if (!alreadyAnchors.add(k)) continue;
            worldAnchors.add(e);
            // S3 减法：锚点总量 12+16=28 上限 → 合计 6 条。锚点是「硬锚」，
            // 6 条足以钉住世界线主干；再多只是把 T3 已经说过的事换个说法重述。
            if (worldAnchors.length >= 6) break;
          }
        }
        if (ws.recentNarrativeEvents.isNotEmpty) {
          for (final ev in ws.recentNarrativeEvents.reversed) {
            final e = ev.text;
            if (e.contains('好感本周已达上限') || e.contains('周好感度已达上限')) continue;
            if (looksFake(e)) continue;
            if (isMetaEvent(e)) {
              if (metaKept >= 2) continue;
              metaKept++;
            }
            final k = e.replaceAll(anchorIconPrefix, '').trim();
            if (!alreadyAnchors.add(k)) continue;
            worldAnchors.add('剧情锚：$e');
            if (worldAnchors.length >= 6) break;
          }
        }
        if (worldAnchors.isNotEmpty) {
          contextBuffer.writeln('【世界近期重大事件（硬锚，不能丢）】');
          contextBuffer.writeln(worldAnchors.join('\n'));
          contextBuffer.writeln('');
        }
      }

      // 只注入最近 2 回合（而非3），避免历史叙事过多导致 AI 被旧场景文本"锚定"而原地打转
      final filteredTurns = <String>[];
      for (int i = recentTurns.length - 1; i >= 0; i--) {
        final entry = recentTurns[i];
        filteredTurns.insert(0, entry);
        if (filteredTurns.length >= 2) break;
      }
      final recentBuffer = filteredTurns.isNotEmpty
          ? filteredTurns.join('\n\n')
          : currentNarrative;
      // 截断到 800 字（而非1600），只保留末尾用于理解当前处境
      // 过多的前情文本会让AI认为场景还应该在前一个地点继续
      final recent = truncateNarrativeContext(recentBuffer, 800);
      // 关键改进：明确标注为"已生成的前情"，禁止 AI 重复或改写
      contextBuffer.write('【前情回顾（已生成内容，严禁重复或改写其中任何段落，仅用于理解当前处境）】\n$recent');

      final context = contextBuffer.toString();
      final statusTag = buildStatusTag(p);
      final extra = buildCriticalContext(safeAction);
      final sceneInfo = buildSceneContext();

      // 事件锚点注入：手写剧情骨架，保证关键节点在正确时间发生
      final anchorLine = pendingAnchorDirective != null
          ? '【剧情节点】本回合请自然融入以下既定剧情骨架（不必生硬转折，可结合玩家行动展开）：\n$pendingAnchorDirective\n\n'
          : '';

      // 场景停滞强制推进：玩家在同一地点停留过久时，注入强制场景转换指令
      // 这是「最后一道防线」——prompt 规则 + 上下文压缩都失效时的硬性兜底
      // （已加入三级豁免：地点白名单、叙事钩子未解决、分级阈值，避免打断重要剧情）
      final curLoc = worldState.currentLocation ?? '当前地点';
      final threshold = stagnationThresholdFor(curLoc);
      final hasHook = narrativeHasUnresolvedHook(currentNarrative);
      // 判定统一走 StagnationDetector.evaluate，措辞按叙事 AI 的口径组织。
      // 此前这里只认「强制」一档，「开局」与「剧情进行中」两档在叙事端永远发不出去。
      final level = stagnationPrompt.evaluate(
        currentLocation: curLoc,
        turnsAtSameLocation: turnsAtSameLocation,
        hasUnresolvedHook: hasHook,
        turnCount: turnCount,
      );
      final stagnationLine = switch (level) {
        StagnationLevel.forced =>
          '【⚠️强制推进指令】玩家已在「$curLoc」停留 $turnsAtSameLocation 回合（该场景允许阈值=$threshold），剧情已停滞！'
              '本回合必须发生场景转换——例如：有人敲门通知该出发、时间到了必须动身前往下一站、'
              '收到猫头鹰信件催促、窗外发生引人注意的事件、被召唤去某处等。'
              '${stagnationPrompt.exemptHint(curLoc)}'
              '严禁继续在「$curLoc」原地打转、反复施法、反复探索同一现象。'
              '本回合结尾必须让玩家处于「正在前往/即将到达下一场景」的状态。\n\n',
        StagnationLevel.earlyGame =>
          '📌 【开局阶段】现在是「收到信 → 准备出发」这一段，本回合叙事请把玩家推向离家：'
              '收拾行李、与家人道别、动身前往对角巷采购入学用品（车站/九又四分之三站台要等 9 月 1 日开学当天才去）。'
              '不要让剧情继续停在$curLoc 原地打转。\n\n',
        StagnationLevel.inProgress =>
          '💡 【剧情进行中】上一回合收尾留有未解决的冲突或悬念，本回合优先把它收掉；'
              '收尾之后请带出场景转换的趋势（例如"做完这件事便动身前往下一处"），'
              '不要整回合停在「$curLoc」不动。\n\n',
        StagnationLevel.none => '',
      };

      // 导演指令：prompt 里塞的全是"状态 + 规则 + 上下文"，
      // 唯独没说这一回合要干嘛，于是 AI 每回合平均用力，一整局读下来是平的。
      // 第九次审查：三回合固定相位改为概率抽取（久未转折权重递增）+ 场景感知
      // （考试周/暑假/深夜转折概率减半），转折仍不会缺席太久，但玩家摸不到规律。
      final beat = directorBeatFor(
        turn: turnCount,
        hasUnresolvedHook: hasHook,
        turnsSinceLastTurn: turnsSinceLastTurnBeat,
        calmContext: isCalmNarrativeContext(),
        random: random,
      );
      turnsSinceLastTurnBeat = beat == DirectorBeat.turn
          ? 0
          : turnsSinceLastTurnBeat + 1;
      final directorLine = directorLineFor(beat);

      // 命运时刻：这一回合要把抉择摆到玩家面前，但不能替他做决定。
      // AI 一旦自己写"你冲了上去"或者"你转过身"，玩家点什么都没意义了。
      final pendingCausal = pendingCausalAnchorId == null
          ? null
          : causalAnchorFor(pendingCausalAnchorId!);
      final causalLine =
          pendingCausal != null &&
              !worldState.causalChoices.containsKey(pendingCausal.anchorId)
          ? '【命运时刻·${pendingCausal.title}】\n'
                '${pendingCausal.setup}\n'
                '本回合的叙事必须停在这个抉择的当口：把上面这个情境写出来，'
                '一直写到"要不要动手"的那一瞬间为止。'
                '严禁替玩家做出选择——不要写他冲上去了，也不要写他转身走了；'
                '不要给出倾向，不要预写后果，把决定权原样留在那一秒。\n\n'
          : '';  // 保持原样，但确认没有额外开销（只在有实际锚点时生成字符串）

      // 安静期提示：检测最近几回合是否连续平淡，若连续3回合以上无转折，
      // 注入"本回合需要一点波澜"的指令，防止叙事陷入日常循环。
      // 审查 F6：停滞 forced 档已下发"必须换场景"的强指令，此时再注入
      // "来点小波澜"会形成两条长指令叠加，Agnes 注意力被分散——互斥跳过。
      final quietPeriodHint = level == StagnationLevel.forced
          ? ''
          : buildQuietPeriodHint();

      return '''【世界上下文】
  $context

  ${statusTag.isNotEmpty ? '【状态】$statusTag\n' : ''}
  【当前场景】${worldState.timestamp}｜${worldState.currentLocation ?? '未知'}
  ${timeBudgetPromptLine(resolveActionCost(safeAction))}
  $sceneInfo
  ${buildContinuityBridgePromptLine()}
  $stagnationLine$anchorLine$causalLine$directorLine$quietPeriodHint
  ${extra.isNotEmpty ? '$extra\n' : ''}【玩家行动】
  $safeAction

${buildForwardConstraintBlock()}
${buildNarrativeRules(turn: turnCount)}
  ''';
    }

}
