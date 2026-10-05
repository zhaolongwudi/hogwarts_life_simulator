/// 探索与收集子系统（r6-10 拆分自 mixin_play.dart）。
///
/// 覆盖：禁林探险、魔法生物图鉴、支线委托板、学院杯。全部本地离线结算
/// （零 AI 调用），通过 on 链复用 [GamePlayToolsMixin] 与
/// [GamePlayMixin] 的物品/属性/每日上限工具。
library;

import '../data/item_data.dart';
import '../data/house_data.dart';
import '../data/house_cup_data.dart';
import '../data/club_data.dart';
import '../data/bestiary_data.dart';
import '../data/quest_data.dart';
import '../data/balance_constants.dart';
import '../data/offline_extras_data.dart';
import '../models/long_term_memory.dart';
import '../data/memory_importance_config.dart';
import 'mixin_play.dart';
import 'mixin_play_tools.dart';

mixin GamePlayExplorationMixin on GamePlayMixin, GamePlayToolsMixin {
  // ==================== 6. 禁林探险 ====================

  @override
  void exploreForbiddenForest() {
    final p = player;
    if (p == null) return;
    if (p.energy < 15) {
      finishLocal('你的精力所剩无几（${p.energy}/100）。禁林不是能空手而归的地方，先休息吧。');
      return;
    }
    if (p.satiety < 15) {
      finishLocal('你饿得前胸贴后背（饱食度 ${p.satiety}/100），进禁林之前先吃点东西吧。');
      return;
    }
    // 每日次数上限：禁林是材料/生物图鉴的主要来源，不设限的话
    // 一个下午就能把图鉴刷满、材料堆成山，后期采集玩法直接失去意义。
    if (!canDoDaily('forest')) {
      finishLocal(
        '海格远远朝你摆手：「今天进去 ${dailyLimitOf('forest')} 趟啦，林子也得喘口气。」\n\n'
        '天色确实不早了，明天再来吧。',
      );
      return;
    }

    recordDailyActivity('forest');
    advanceTimeForAction('禁林探险');
    p.energy = (p.energy - 15).clamp(0, 100);
    p.satiety = (p.satiety - 5).clamp(0, 100);

    final grade = p.grade ?? 1;
    final rollValue = random.nextInt(100);
    final buf = StringBuffer('【禁林探险】\n');

    // P8：特殊遭遇——按年级门控解锁的剧情事件（人马/独角兽/巨蛛巢等）。
    // 15% 概率命中；只挑当前年级可解锁的事件，同一次探险至多触发一条。
    final specials = kForestSpecialEncounters
        .where((e) => grade >= e.minGrade)
        .toList();
    if (specials.isNotEmpty && rollValue < 15) {
      final ev = specials[random.nextInt(specials.length)];
      buf.writeln(ev.text);
      // 剧情遭遇附带的战利品：人马尾鬃 / 月长石花 / 凤凰羽毛 入背包
      switch (ev.id) {
        case 'forest_centaur':
          gainItem('月长石粉');
          buf.writeln('\n【收获】月长石粉 已收入背包');
        case 'forest_golden_flower':
          gainItem('曼德拉草叶');
          buf.writeln('\n【收获】曼德拉草叶 已收入背包');
        case 'forest_phoenix_feather':
          gainItem('凤羽');
          buf.writeln('\n【收获】凤羽 已收入背包');
        case 'forest_treasure':
          final coins = 8 + random.nextInt(15);
          p.galleons += coins;
          gainItem('夜骐尾羽');
          buf.writeln('\n【收获】$coins 加隆 · 夜骐尾羽 已收入背包');
      }
      if (grade >= 3) {
        p.playerReputation.add('explore', 2);
        buf.writeln('探索声望 +2（你在这片林子里越来越游刃有余了）');
      }
      buf.writeln('\n禁林入口的风从你身后吹来，你决定先返回城堡。');
      finishLocal(buf.toString());
      return;
    }

    // 可遭遇生物：按年级限制危险度上限（防崩坏）
    final maxDanger = grade >= 5
        ? 5
        : grade >= 3
        ? 4
        : grade >= 2
        ? 3
        : 2;
    final pool = kCreatureCatalog.where((c) => c.danger <= maxDanger).toList();

    if (rollValue < 30 && pool.isNotEmpty) {
      // 遭遇生物
      // 委托目标加成：活跃委托（gather 看掉落、defeat 看生物名）对应的生物
      // 获得额外权重，避免高价值委托因低危生物权重碾压而永远推不动。
      final wantedLoot = <String>{};
      final wantedCreatures = <String>{};
      for (final q in p.quests) {
        if (q.status != 'active') continue;
        if (q.type == 'gather') wantedLoot.add(q.target);
        if (q.type == 'defeat') wantedCreatures.add(q.target);
      }
      final weighted = <CreatureDef>[];
      for (final c in pool) {
        var w = (6 - c.danger).clamp(1, 4);
        final isWanted =
            c.loot.any(wantedLoot.contains) || wantedCreatures.contains(c.name);
        if (isWanted) w += 3; // 委托目标显著加权
        for (var i = 0; i < w; i++) {
          weighted.add(c);
        }
      }
      final creature = weighted[random.nextInt(weighted.length)];
      _recordCreature(creature);
      buf.writeln('密林深处传来窸窣声。你屏住呼吸，看到了——${creature.name}。');
      buf.writeln(creature.desc);
      buf.writeln(
        '\n【图鉴更新】${creature.name}（${dangerLabel(creature.danger)}）已收录',
      );

      if (creature.danger >= 3) {
        // 对抗判定
        final escapeP =
            (0.35 +
                    (attr('reaction_time') - 50) / 500 +
                    (attr('observation') - 50) / 500 +
                    (p.petBond >= 40 ? 0.1 : 0) +
                    equipmentCastBonus() / 1000)
                .clamp(0.15, 0.85);
        if (random.nextDouble() < escapeP) {
          buf.writeln(
            '\n${creature.name} 向你逼近，你抓住它停顿的一瞬，闪身躲进树根后，'
            '贴着地面退了回去。心跳如擂鼓，但你没受伤。',
          );
        } else {
          final creaturePower = creature.danger * 18 + 10;
          final myPower = playerPower();
          final win =
              (myPower + random.nextInt(21)) >=
              (creaturePower + random.nextInt(16));
          if (win) {
            p.health = (p.health - 5 * creature.danger).clamp(1, 100);
            p.playerReputation.add('combat', 4 + creature.danger * 2);
            addHouseCupPoints(5, '禁林战胜危险生物');
            buf.writeln(
              '\n你抽出魔杖迎战。经过几个来回，${creature.name} 终于哀鸣着退入黑暗。'
              '战斗声望 +${4 + creature.danger * 2} · 学院杯 +5',
            );
            if (creature.loot.isNotEmpty) {
              final drop = creature.loot[random.nextInt(creature.loot.length)];
              gainItem(drop);
              buf.writeln('你在战利品中找到了「$drop」，收进背包。');
            }
            progressQuest('defeat', creature.name, 1);
          } else {
            p.health = (p.health - 15 - 5 * creature.danger).clamp(0, 100);
            pendingDeathCause = '禁林中${creature.name}的致命袭击';
            buf.writeln(
              '\n你没能拦住${creature.name}的冲击，被重重撞飞。'
              '好在它没有追杀，你拖着受伤的身体逃回了城堡。'
              '（生命 ${p.health}/100，可去校医院用白鲜香精治疗）',
            );
          }
        }
      } else {
        if (creature.loot.isNotEmpty) {
          final drop = creature.loot[random.nextInt(creature.loot.length)];
          gainItem(drop);
          buf.writeln('它并不怕你，还在附近留下了「$drop」——你小心翼翼地收了起来。');
        }
        buf.writeln('\n你悄悄退开，没有惊扰它。');
      }
    } else if (rollValue < 55) {
      // 采集材料：稀有档单独摇一次，让「再翻一次」值得期待
      final material = rollLootMaterial(random.nextInt(1000));
      final rare = kRareLootMaterials.contains(material);
      gainItem(material);
      if (rare) {
        buf.writeln(
          '你拨开一丛暗色的苔藓，底下的东西让你屏住了呼吸——「$material」。'
          '这种东西可不是随便就能碰上的，你小心翼翼地收好。',
        );
      } else {
        buf.writeln('你在树根与岩石之间仔细翻找，收获了一份「$material」，塞进背包。');
      }
    } else if (rollValue < 70) {
      // 金币
      final coins = 5 + random.nextInt(16);
      p.galleons += coins;
      buf.writeln(
        '你在一条干涸的溪流边捡到一个小皮袋，里面装着 $coins 加隆。'
        '大概是哪个倒霉鬼掉的。',
      );
    } else if (rollValue < 85) {
      buf.writeln(
        '这一趟有惊无险——除了几只不咬人的护树罗锅远远望着你，禁林安静得不像话。'
        '你几乎空手而归，但至少熟悉了这片林子。',
      );
      // 空手而归的这一档给一次收藏品机会：独角兽尾毛是禁林里唯一拿得到的
      // 纪念品，不给个明确来源的话它就永远是「看得见拿不到」。
      if (random.nextInt(100) < 12) addCollectibleSighting(buf);
    } else {
      p.health = (p.health - 8 - random.nextInt(8)).clamp(1, 100);
      if (!p.injuries.contains('禁林擦伤')) p.injuries.add('禁林擦伤');
      buf.writeln(
        '你在湿滑的苔藓上滑了一跤，撞上裸露的树根，额头擦破了皮。'
        '（生命 ${p.health}/100，注意包扎）',
      );
    }

    buf.writeln('\n禁林入口的风从你身后吹来，你决定先返回城堡。');
    finishLocal(buf.toString());
  }

  void _recordCreature(CreatureDef c) {
    final p = player!;
    if (!p.bestiary.contains(c.id)) {
      p.bestiary.add(c.id);
    }
    if (p.bestiary.length >= 3) unlockAchievement('bestiary_3');
  }

  // ==================== 7. 魔法生物图鉴 ====================

  @override
  String formatBestiary() {
    final p = player;
    final buf = StringBuffer(
      '【魔法生物图鉴】（${p?.bestiary.length ?? 0}/${kCreatureCatalog.length}）\n',
    );
    if (p == null || p.bestiary.isEmpty) {
      buf.writeln(
        '\n尚未发现任何生物。去 /禁林 探险，或观察身边的花园与城堡，'
        '与神奇生物相遇吧。',
      );
      return buf.toString();
    }
    for (final c in kCreatureCatalog) {
      final found = p.bestiary.contains(c.id);
      if (!found) continue;
      buf.writeln('\n『${c.name}』 ${dangerLabel(c.danger)}');
      buf.writeln('栖息地：${c.habitat}');
      buf.writeln(c.desc);
      if (c.loot.isNotEmpty) {
        buf.writeln('可获材料：${c.loot.join('、')}');
      }
    }
    buf.writeln('\n已发现 ${p.bestiary.length} 种。继续探索可解锁全部图鉴。');
    return buf.toString();
  }

  // ==================== 8. 支线委托板 ====================

  /// 列出板上 3 个当前可接取的模板。
  /// 结果会缓存进 [questBoardIds]，保证「看到的编号」与「接到的委托」一致；
  /// 只有 [forceRefresh] 为 true（玩家显式 /委托 刷新）或缓存条目已失效时才重排。
  List<QuestTemplate> _board({bool forceRefresh = false}) {
    final p = player;
    final taken = <String>{};
    for (final q in p?.quests ?? const <QuestRecord>[]) {
      taken.add(q.templateId);
    }
    final grade = p?.grade ?? 1;

    // 跨周自动补货，让委托板随时间变化而不是一进游戏就定死
    if (questBoardWeek != gameWeek) {
      questBoardWeek = gameWeek;
      forceRefresh = true;
    }

    if (!forceRefresh && questBoardIds.isNotEmpty) {
      final cached = questBoardIds
          .map(questTemplateById)
          .whereType<QuestTemplate>()
          .where((t) => !taken.contains(t.id) && t.minGrade <= grade)
          .take(3)
          .toList();
      if (cached.isNotEmpty) return cached;
    }

    final available =
        kQuestTemplates
            .where((t) => !taken.contains(t.id) && (t.minGrade <= grade))
            .toList()
          ..shuffle(random);
    final picked = available.take(3).toList();
    questBoardIds = picked.map((t) => t.id).toList();
    return picked;
  }

  @override
  void refreshQuestBoard() {
    final board = _board(forceRefresh: true);
    final buf = StringBuffer('【委托板 · 已刷新】\n');
    if (board.isEmpty) {
      buf.writeln('板子上暂时没有适合你的委托。之后再来看看，或者去禁林碰碰运气。');
    } else {
      buf.writeln('（可接受的委托）');
      for (var i = 0; i < board.length; i++) {
        final q = board[i];
        buf.writeln('\n${i + 1}. ${q.title}（${_questTypeLabel(q.type)}）');
        buf.writeln('   ${q.desc}');
        buf.writeln(
          '   目标：${q.target} ×${q.targetCount} ｜ 奖励：${q.rewardGalleons}加隆 + ${q.rewardHousePoints}分',
        );
      }
      buf.writeln('\n输入 /委托 接受 [编号] 接下委托。');
    }
    finishLocal(buf.toString());
  }

  /// 委托类型 → 中文名。表在 lib/data/quest_data.dart（委托板 UI 共用）。
  String _questTypeLabel(String type) => questTypeLabel(type);

  @override
  String formatQuests() {
    final p = player;
    final buf = StringBuffer('【支线委托】\n');
    if (p == null || p.quests.isEmpty) {
      buf.writeln('你还没有接下任何委托。');
    } else {
      for (var i = 0; i < p.quests.length; i++) {
        final q = p.quests[i];
        final done = q.isDone;
        final claimed = q.status == 'claimed';
        buf.writeln(
          '\n${i + 1}. [${claimed
              ? '已领取'
              : done
              ? '可交付'
              : '进行中'}] ${q.title}',
        );
        buf.writeln('   ${q.desc}');
        buf.writeln('   进度：${q.progress}/${q.targetCount}（${q.target}）');
        if (claimed) {
          buf.writeln('   ✅ 奖励已领取');
        } else if (done) {
          buf.writeln('   ⭐ 目标达成，/委托 交付 ${i + 1} 领取奖励！');
        }
      }
    }
    buf.writeln('\n/委托 查看 ｜ /委托 刷新 ｜ /委托 接受 [编号] ｜ /委托 交付 [编号]');
    buf.writeln('收集与讨伐类委托会在禁林探险中自动推进，培养类随宠物互动增长。');
    return buf.toString();
  }

  @override
  void acceptQuest(int index) {
    final board = _board();
    if (index < 0 || index >= board.length) {
      finishLocal('编号无效。板子上目前有 ${board.length} 条可接受委托（/委托 刷新 查看）。');
      return;
    }
    acceptQuestTemplate(board[index].id);
  }

  /// 按模板 ID 接取委托（委托板独立页面使用，避免与随机刷板索引不一致）
  @override
  void acceptQuestTemplate(String id) {
    final p = player;
    if (p == null) return;
    final t = questTemplateById(id);
    if (t == null) {
      finishLocal('这个委托似乎已经从板子上撤下了。');
      return;
    }
    if ((p.grade ?? 1) < t.minGrade) {
      finishLocal(
        '「${t.title}」的难度超出了你现在的年级（要求 ${t.minGrade} 年级以上）。先成长一阵子再来吧。',
      );
      return;
    }
    final taken = <String>{};
    for (final q in p.quests) {
      taken.add(q.templateId);
    }
    if (taken.contains(t.id)) {
      finishLocal('你已经接过「${t.title}」这个委托了。');
      return;
    }
    p.quests.add(QuestRecord.fromTemplate(t, week: gameWeek));
    // ====== 长线记忆写入：T1 未完结事项（委托接取） ======
    // 委托是"承诺/约定"类未完结事项，必须写入 T1 防止 AI 数百回合后遗忘。
    final ts = worldState.time.format();
    memory = memory.addOrUpdateOpenLoop(
      OpenLoopRecord(
        id: 'quest_${t.id}',
        description:
            '接取委托「${t.title}」：需收集${t.target}×${t.targetCount}，奖励${t.rewardGalleons}加隆+${t.rewardHousePoints}分',
        status: 'open',
        importance: kImportanceQuestOpen,
        openedAt: ts,
        loopType: 'quest',
        openedTurn: turnCount,
      ),
    );
    finishLocal(
      '【已接取委托】\n${t.title}\n\n${t.desc}\n\n'
      '目标：${t.target} ×${t.targetCount} ｜ 奖励：${t.rewardGalleons}加隆 + ${t.rewardHousePoints}分\n\n'
      '完成后输入 /委托 交付 领取奖励。',
    );
  }

  @override
  void deliverQuest(int index) {
    final p = player;
    if (p == null) return;
    final qs = p.quests;
    if (index < 0 || index >= qs.length) {
      finishLocal('编号无效。输入 /委托 查看当前委托清单。');
      return;
    }
    final q = qs[index];
    if (q.status == 'claimed') {
      finishLocal('「${q.title}」的奖励你已经领过了。');
      return;
    }
    if (!q.isDone) {
      finishLocal(
        '「${q.title}」还未完成：${q.progress}/${q.targetCount}（${q.target}）。继续加油。',
      );
      return;
    }
    q.status = 'claimed';
    p.galleons += q.rewardGalleons;
    addHouseCupPoints(q.rewardHousePoints, '完成委托');
    p.playerReputation.add('academic', 2);
    p.playerReputation.add('moral', 3);
    // ====== 长线记忆写入：关闭 T1 委托事项 + T3 世界事件 ======
    memory = memory.addOrUpdateOpenLoop(
      OpenLoopRecord(
        id: 'quest_${q.templateId}',
        description:
            '完成委托「${q.title}」：收集${q.target}×${q.targetCount}，获得${q.rewardGalleons}加隆+${q.rewardHousePoints}分',
        status: 'done',
        importance: kImportanceQuestDone,
        openedAt: worldState.time.format(),
        closedAt: worldState.time.format(),
        loopType: 'quest',
        openedTurn: turnCount,
      ),
    );
    memory = memory.addWorldEvent(
      WorldEventRecord(
        id: 'quest_done_${q.templateId}_$turnCount',
        timestamp: worldState.time.format(),
        title: '完成委托',
        description:
            '主角完成委托「${q.title}」，获得${q.rewardGalleons}加隆与${q.rewardHousePoints}学院分',
        importance: kImportanceQuestDoneEvent,
        category: 'personal',
      ),
    );
    final buf = StringBuffer('【委托交付 · ${q.title}】\n');
    buf.writeln(
      '你带着${q.target}（${q.progress}/${q.targetCount}）交回委托板，负责的老巫师仔细清点后露出赞许的笑容。',
    );
    buf.writeln(
      '\n奖励：${q.rewardGalleons} 加隆 · 学院杯 +${q.rewardHousePoints} 分 · 学术声望 +2 · 道德声望 +3',
    );
    unlockAchievement('first_quest');
    finishLocal(buf.toString());
  }

  // ==================== 9. 学院杯 ====================

  /// 学院杯加分的唯一入口。
  ///
  /// 此前 5 个加分点全都直接写 `p.houseCupPoints += n`，这个方法反而一个调用者
  /// 都没有。统一到这里之后 `reason` 会累计进来源明细，`/学院杯` 就能告诉玩家
  /// 这一年分数是从哪儿挣来的，而不是只列一份"有哪些加分途径"的静态说明。
  @override
  void addHouseCupPoints(int amount, String reason) {
    final p = player;
    if (p == null || amount == 0) return;
    p.houseCupPoints += amount;
    p.houseCupSources[reason] = (p.houseCupSources[reason] ?? 0) + amount;
    // 年度榜同步：玩家的学院行 = 基准 + 玩家本学年贡献，随贡献实时更新，
    // /学院杯 的榜单才不会被"学期初那个初始值"卡住。
    //
    // 必须同时排除空串：p.house 是 String?，但 mixin_response 从叙事里解析
    // 分院结果时走 `en ??= 首字母大写(matched)`，AI 一旦写出四院之外的词，
    // house 就会是个认不出来的值，houseDisplayName 回落到 '未分院'——
    // 那会在 houseCupYearly 里多出第 5 个 key，而 formatHouseCup 的奖牌表
    // 定长 4，按下标取就会 RangeError 崩溃。
    final house = houseKeyOrNull;
    if (house != null) {
      worldState.houseCupYearly[houseDisplayName(house)] =
          kHouseCupBaseScore + p.houseCupPoints;
    }
  }

  /// 懒初始化年度榜：四院都以 [kHouseCupBaseScore] 起步，并把玩家学院行
  /// 同步为「基准 + 玩家本学年贡献」。
  ///
  /// 老存档没有 houseCupYearly 字段，第一次读到是空表；玩家还没分院时
  /// （开场一路到分院帽前）不参与榜单，四院保持基准分。
  Map<String, int> _ensureHouseCupYearly() {
    final yearly = worldState.houseCupYearly;
    // 四院缺谁补谁（putIfAbsent 不动已有的行）：
    // 玩家可能先挣分把自家学院行写进去，再点开 /学院杯——
    // 不能因为表非空就把另外三院漏掉。
    if (yearly.length < kHouseNames.length) {
      for (final h in kHouseNames) {
        yearly.putIfAbsent(h, () => kHouseCupBaseScore);
      }
    }
    final p = player;
    final house = houseKeyOrNull;
    if (p != null && house != null) {
      yearly[houseDisplayName(house)] = kHouseCupBaseScore + p.houseCupPoints;
    }
    return yearly;
  }

  @override
  String formatHouseCup() {
    final p = player;
    if (p == null) return '';
    final houseKey = houseKeyOrNull;
    final myCn = houseDisplayName(houseKey, fallback: '（未分院）');
    final buf = StringBuffer('【学院杯】\n');
    if (houseKey == null) {
      buf.writeln('你还没有被分院，暂未参与学院杯竞争。');
      return buf.toString();
    }

    // 年度榜：四院实时排名。玩家的学院行已经由 _ensureHouseCupYearly 同步。
    final yearly = _ensureHouseCupYearly();
    final ranked = yearly.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const medal = ['🥇', '🥈', '🥉', '  '];
    buf.writeln('本学年四院累计（你的贡献已计入你的学院）：');
    for (var i = 0; i < ranked.length; i++) {
      final e = ranked[i];
      final isMine = e.key == myCn;
      final extra = isMine ? '（你 +${p.houseCupPoints}）' : '';
      // 越界保护：ranked 来自 houseCupYearly，正常是四院。但历史存档或
      // 异常数据可能让这张表多出一行（例如 '未分院'），按下标取定长奖牌表
      // 会 RangeError 直接崩在玩家点 /学院杯 的瞬间。宁可少一块奖牌。
      final badge = i < medal.length ? medal[i] : '  ';
      buf.writeln('$badge${isMine ? '★ ' : '  '}${e.key}：${e.value} 分$extra');
    }

    // 历届年度榜：让玩家看见七年榜单的走向
    if (worldState.houseCupYearHistory.isNotEmpty) {
      buf.writeln('\n历届年度榜：');
      worldState.houseCupYearHistory.forEach((year, summary) {
        buf.writeln('· $year：$summary');
      });
    }

    buf.writeln('\n你的本学年贡献：${p.houseCupPoints} 分');
    if (p.houseCupSources.isEmpty) {
      buf.writeln('可加分的途径：');
      buf.writeln(
        '· 魁地奇取胜 +${Balance.houseCupActivityPoints['quidditch_win']}，惜败 +5',
      );
      buf.writeln('· 巫师决斗获胜 +${Balance.houseCupActivityPoints['duel_win']}');
      buf.writeln(
        '· 禁林战胜危险生物 +${Balance.houseCupActivityPoints['forbidden_forest']}',
      );
      buf.writeln(
        '· 完成支线委托 +${Balance.houseCupActivityPoints['quest_complete']}',
      );
      buf.writeln('· 课堂表现优异 +${Balance.houseCupActivityPoints['classroom']}');
      buf.writeln('· 期末考试年级前十 +${Balance.houseCupActivityPoints['exam_top']}');
      buf.writeln(
        '· 日常：课堂上答对的问题、替同学解的围、'
        '还有你夜游被抓时扣掉的那些分（每天最多 +$kHouseNarrativeGainDailyCap）',
      );
    } else {
      final sources = p.houseCupSources.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      buf.writeln('本学年得分构成：');
      for (final e in sources) {
        // 扣分的时候"日常扣分 +-5"读不通
        final sign = e.value >= 0 ? '+' : '';
        buf.writeln('· ${e.key} $sign${e.value}');
      }
    }
    buf.writeln('\n学年结束时将结算排名，榜首学院获得学院杯。');
    buf.writeln(
      '其他学院也在暗自较劲——格兰芬多的勇气、斯莱特林的算计、'
      '拉文克劳的智慧、赫奇帕奇的踏实，各有各的赢法。',
    );
    return buf.toString();
  }

  /// 学年结算（由 mixin_systems 学年切换时调用）
  @override
  void settleHouseCup() {
    final p = player;
    // 未分院就不参与学院杯。注意这里不再有「零分拦截」：
    // 年度榜是四院全程累计的真实排名，玩家就算一分没挣，自己的学院也
    // 有基准分和对手在竞争，学年末该揭晓的榜单必须揭晓。
    if (p == null) return;
    // 未分院（含空串 / AI 写出的非四院名称）不参与结算。
    // 用 houseKeyOrNull 而不是 `p.house == null`：空串会被 houseDisplayName
    // 兜成「未分院」当成一支队伍写进榜单。
    final houseKey = houseKeyOrNull;
    if (houseKey == null) return;
    final myCn = houseDisplayName(houseKey);
    final yearly = _ensureHouseCupYearly();
    final ranked = yearly.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final rank = ranked.indexWhere((e) => e.key == myCn) + 1;

    // 记入历届年度榜（key=刚结束的学年，如 1991-1992）
    final winner = ranked.first.key;
    final summary = ranked
        .map((e) => e.key == winner ? '${e.key} 夺冠' : '${e.key} ${e.value}')
        .join('｜');
    worldState.houseCupYearHistory[worldState.academicYear] = summary;

    final buf = StringBuffer('【学院杯 · 学年结算】\n');
    for (var e in ranked) {
      buf.writeln('${e.key == myCn ? '★ ' : '  '}${e.key}：${e.value} 分');
    }
    // 净分为负的时候"赢得了 -20 分"读不通，而且那本来也不是一回事：
    // 一年下来净扣分，值得单独说一句，不该混在同一句话里。
    if (p.houseCupPoints > 0) {
      buf.writeln('\n你在本学年为$myCn 赢得了 ${p.houseCupPoints} 分。');
    } else if (p.houseCupPoints < 0) {
      buf.writeln(
        '\n你在本学年给$myCn 净扣掉了 ${-p.houseCupPoints} 分。'
        '没有人当众说起这件事，但账是记着的。',
      );
    } else {
      buf.writeln('\n你在本学年没有为$myCn 挣到分，但榜单还是照常揭晓了。');
    }

    if (rank == 1) {
      p.galleons += 50;
      p.playerReputation.add('leadership', 10);
      p.playerReputation.add('social', 6);
      p.houseReputation += 15;
      unlockAchievement('house_cup_winner');
      buf.writeln('\n$myCn 夺得学院杯！你站在欢呼的人群中央，彩带和掌声淹没了你。');
      buf.writeln('奖励：50 加隆 · 领导声望 +10 · 社交声望 +6 · 学院声望 +15');
    } else if (rank == 2) {
      p.galleons += 20;
      p.playerReputation.add('social', 4);
      p.houseReputation += 5;
      buf.writeln('\n$myCn 获得第二名，离学院杯一步之遥。你的贡献有目共睹。');
      buf.writeln('奖励：20 加隆 · 社交声望 +4 · 学院声望 +5');
    } else {
      p.playerReputation.add('social', 2);
      buf.writeln('\n$myCn 与学院杯失之交臂。队长拍拍你的肩：明年把金色奖杯搬回来。');
      buf.writeln('奖励：社交声望 +2');
    }
    // ===== Batch 11 · 社团 × 学院杯反向半环 =====
    // 本学年为社团挣的学院分（houseCupSources 里「社团·/社团任务·」前缀的
    // 正分）在结算时单独拎出来按档位追加「社团荣光」叙事与奖励。
    // 让「你属于什么」反过来成为学院杯里看得见的分量（规划第一梯队）。
    final clubCupContributed = clubContributedCupPoints(p.houseCupSources);
    if (clubCupContributed > 0) {
      final tier = clubCupTierFor(clubCupContributed);
      if (tier != null) {
        // 不依赖 memberClub（跨 mixin 非抽象成员不可见），直接查 clubId。
        final club = p.clubId == null ? null : clubById(p.clubId!);
        final clubName = club?.name ?? '你的社团';
        p.galleons += tier.galleons;
        p.houseReputation += tier.houseReputation;
        final note = tier.note
            .replaceAll(r'$club', clubName)
            .replaceAll(r'$points', '$clubCupContributed');
        buf.writeln();
        buf.writeln('【社团荣光 · $clubName】$note');
        if (tier.galleons > 0 || tier.houseReputation > 0) {
          final parts = <String>[
            if (tier.galleons > 0) '${tier.galleons} 加隆',
            if (tier.houseReputation > 0) '学院声望 +${tier.houseReputation}',
          ];
          buf.writeln('奖励：${parts.join(' · ')}');
        }
      }
    }
    p.houseCupPoints = 0;
    p.houseCupSources.clear();
    worldState.houseCupYearly.clear();
    notifications.add('🏆 学院杯学年结算：$myCn 排名第$rank 名');
    finishLocal(buf.toString());
  }
}
