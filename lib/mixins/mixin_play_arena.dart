/// 竞技玩法子系统（r6-2 拆分自 mixin_play.dart）。
///
/// 覆盖：魁地奇比赛与球队训练、NPC 决斗与决斗社季度赛、魔药部限时配方、
/// 快讯社头版事件（框架2 四玩法）。全部为本地离线结算（零 AI 调用），
/// 通过 [GamePlayToolsMixin] 的通用工具落地数值与叙事。
library;

import '../data/house_data.dart';
import '../data/item_data.dart';
import '../data/rivalry_data.dart';
import '../data/wand_data.dart';
import '../data/club_minigames_data.dart';
import '../data/offline_extras_data.dart';
import '../models/npc.dart';
import '../models/player.dart';
import 'mixin_play_tools.dart';

mixin GamePlayArenaMixin on GamePlayToolsMixin {
  // ==================== 4. 魁地奇 ====================

  @override
  String formatQuidditch() {
    final p = player;
    if (p == null) return '';
    final broom = p.equipped['broom'];
    final buf = StringBuffer()
      ..writeln('【魁地奇】')
      ..writeln('位置：${p.qPosition}')
      ..writeln('技巧：${p.qSkill}/100')
      ..writeln('战绩：${p.qWins}胜 / ${p.qMatches}场')
      ..writeln('扫帚：${broom ?? '（未装备）'}');
    if (broom == null) {
      buf.writeln('\n⚠️ 参加比赛需要先装备一把飞天扫帚（对角巷购买后 /装备）。');
    } else {
      buf.writeln('\n输入 /魁地奇 比赛 开始一场比赛（每周一次，消耗 2 小时）。');
      buf.writeln('输入 /魁地奇 位置 <找球手|追球手|守门员|击球手> 调整位置。');
    }
    buf.writeln('\n赢下一场为学院赢得 30 分学院杯积分，输球也有 5 分。');
    return buf.toString();
  }

  @override
  void setQuidditchPosition(String pos) {
    const positions = ['找球手', '追球手', '守门员', '击球手'];
    final p = player!;
    if (!positions.contains(pos)) {
      finishLocal('位置可选：找球手/追球手/守门员/击球手。当前位置：${p.qPosition}');
      return;
    }
    p.qPosition = pos;
    finishLocal('【位置调整】\n你在队内试训后被安排为「$pos」。训练中你不断调整握法，$pos 的职责逐渐得心应手。');
  }

  @override
  void playQuidditch() {
    final p = player;
    if (p == null) return;
    // S11：周训练加成必须在本周比赛前先做周重置，否则跨周直接比赛
    // 仍享受上周训练加成（qTrainWeek 未清零 → 实力 +6）。设计承诺
    // 「训练加成仅限本周比赛；下周清零」（docs/魁地奇队训练设计.md:65）。
    _ensureTrainWeekReset();
    final broom = p.equipped['broom'];
    if (broom == null) {
      finishLocal('你还没有飞天扫帚！对角巷的「飞天扫帚·横扫」或「飞天扫帚·彗星」可以购买，买到后 /装备 即可参赛。');
      return;
    }
    if (p.qLastWeek == gameWeek) {
      finishLocal('本周你已经打过一场了，教练让你好好休息、加练技巧。下周再来吧。');
      return;
    }
    if (p.energy < 20) {
      finishLocal('你的精力所剩无几（${p.energy}/100），扫帚都握不太稳，先休息一晚吧。');
      return;
    }

    p.qLastWeek = gameWeek;
    advanceTimeForAction('魁地奇比赛');
    p.energy = (p.energy - 20).clamp(0, 100);
    p.qMatches++;

    // 双方实力
    final skill =
        p.qSkill +
        ((attr('flying') - 50) ~/ 3) +
        ((attr('reaction_time') - 50) ~/ 5) +
        (itemDefByName(broom)?.statBonus['flying'] ?? 0) +
        // 本周训练加成：每次训练 +3 实力（上限 2 次 → +6），
        // 兑现 docs/魁地奇队训练设计.md 的「训练→比赛联动」闭环（16b/16k 遗留断点）
        p.qTrainWeek * 3;
    final opponents = kHouseNames;
    final myHouseCn = houseDisplayName(p.house, fallback: '对手');
    // 修复：对手池必须排除自己学院，避免"格兰芬多 对 格兰芬多"的荒谬叙事
    final pool = opponents.where((h) => h != myHouseCn).toList();
    final opp = pool[random.nextInt(pool.length)];
    final myScore = 90 + skill ~/ 2 + random.nextInt(31);
    final oppScore = 70 + random.nextInt(81); // 对手 ~70-150
    final win = myScore >= oppScore;

    p.qSkill = (p.qSkill + 1 + random.nextInt(2)).clamp(0, 100);
    final buf = StringBuffer('【魁地奇比赛 · $myHouseCn 对 $opp】\n');
    buf.writeln(
      '哨声响起，$myHouseCn 队的${p.qPosition}——你，骑着$broom 冲上云霄。'
      '雨后的空气带着草屑和松脂味，金色飞贼在不远处闪烁。',
    );
    final posDetail = switch (p.qPosition) {
      '找球手' => '你在球场上盘旋，目光锁定那颗疾驰的金色飞贼，一个俯冲……',
      '追球手' => '鬼飞球在你腋下稳稳夹住，你闪开两名对方击球手的防守，奋力掷向球门。',
      '守门员' => '你守在三个圆环前，紧盯游走球与鬼飞球的轨迹，飞身扑救。',
      _ => '你抡起球棒，狠狠把游走球抽向对方阵型。',
    };
    buf.writeln(posDetail);
    buf.writeln('\n最终比分：$myHouseCn $myScore — $oppScore $opp');

    // P8：位置专属时刻（低概率点缀，不与赛果段叠加）
    if (random.nextInt(100) < 30) {
      final moment = kQuidditchPositionMoments[p.qPosition];
      if (moment != null) {
        buf.writeln();
        buf.writeln(
          fillQuidditchTemplate(
            moment.text,
            myHouse: myHouseCn,
            opp: opp,
            score: myScore,
            oppScore: oppScore,
            broom: broom,
          ),
        );
      }
    }

    // P8：赛果变体——胜负各 3 套叙事，替代固定句式
    final variant = kQuidditchResultVariants[random.nextInt(kQuidditchResultVariants.length)];
    if (win) {
      p.qWins++;
      p.playerReputation.add('combat', 6);
      p.playerReputation.add('social', 4);
      addHouseCupPoints(30, '魁地奇取胜');
      p.galleons += 15;
      buf.writeln();
      buf.writeln(
        fillQuidditchTemplate(
          variant.winBody,
          myHouse: myHouseCn,
          opp: opp,
          score: myScore,
          oppScore: oppScore,
          broom: broom,
        ),
      );
      buf.writeln('战斗声望 +6 · 社交声望 +4 · 学院杯积分 +30 · 队内奖金 15 加隆');
      unlockAchievement('first_quidditch_win');
    } else {
      addHouseCupPoints(5, '魁地奇惜败');
      p.galleons += 5;
      p.playerReputation.add('social', 2);
      buf.writeln();
      buf.writeln(
        fillQuidditchTemplate(
          variant.lossBody,
          myHouse: myHouseCn,
          opp: opp,
          score: myScore,
          oppScore: oppScore,
          broom: broom,
        ),
      );
      buf.writeln('虽败犹荣：社交声望 +2 · 学院杯积分 +5 · 辛苦费 5 加隆');
    }

    // P8：赛后事件（低概率收尾，给同一场胜负不同的余韵）
    if (random.nextInt(100) < 35) {
      final after = kQuidditchAfterEvents[random.nextInt(kQuidditchAfterEvents.length)];
      if (after.energyCost > 0) {
        p.energy = (p.energy - after.energyCost).clamp(0, 100);
      }
      buf.writeln();
      buf.writeln(
        fillQuidditchTemplate(
          after.text,
          myHouse: myHouseCn,
          opp: opp,
          score: myScore,
          oppScore: oppScore,
          broom: broom,
        ),
      );
    }
    buf.writeln('\n魁地奇技巧 +1~2（当前 ${p.qSkill}）');
    finishLocal(buf.toString());
  }

  // ==================== 5. 决斗 ====================

  @override
  void duelNpc(String? name) {
    final p = player;
    if (p == null) return;
    // 每日次数上限：旧实现无冷却，一场决斗只花 10 分钟 + 10 精力，
    // 赢了给 10~25 加隆 + 6~11 战斗声望 → 十几场就能把战斗声望刷满、
    // 加隆花不完，学院杯与声望系统全部失去意义。
    if (!canDoDaily('duel')) {
      finishLocal(
        '你今天已经比了 ${dailyLimitOf('duel')} 场决斗，手臂酸得连魔杖都快握不住了。'
        '麦格教授远远瞥了你一眼——再打下去就要被请去喝茶了。\n\n'
        '明天再来吧。',
      );
      return;
    }
    // 修复：决斗对象仅限在校生（grade >= 1），排除教职/成人（grade == 0）。
    // 旧实现只过滤 isAlive && !graduated，导致可以"决斗邓布利多/麦格教授"，
    // 违背"一年级打不过强者"的设计初衷与原著常识。
    final alive = npcRegistry.values
        .where((n) => n.isAlive && !n.graduated && n.grade >= 1)
        .toList();
    NPC? opponent;
    if (name != null && name.trim().isNotEmpty) {
      final kw = name.trim();
      for (final n in alive) {
        if (n.name.contains(kw)) {
          opponent = n;
          break;
        }
      }
      if (opponent == null) {
        finishLocal('没有找到可以挑战的「$kw」。输入 /决斗 随机挑战，或输入认识的同学生名。');
        return;
      }
    } else {
      if (alive.isEmpty) {
        finishLocal('眼前没有可以挑战的对象。');
        return;
      }
      opponent = alive[random.nextInt(alive.length)];
    }

    final oppPower =
        30 +
        opponent.reputation.combat +
        opponent.grade * 3 +
        random.nextInt(25);

    // 防崩坏：一年级无法正面对抗明显强大的对手
    if ((p.grade ?? 1) <= 1 && oppPower >= 75) {
      finishLocal(
        '你握着魔杖的手有些发冷——${opponent.name}的气场远远压过了你。'
        '一年级的新生正面对上这样的对手只有送人头的份。\n\n'
        '你决定把逃跑当成最明智的咒语。',
      );
      return;
    }
    if (p.energy < 10) {
      finishLocal('你太疲惫了（精力 ${p.energy}/100），连魔杖都举不太稳。改天再战吧。');
      return;
    }
    // 同一天里连续找同一个人决斗，对方也会烦（也防止刷好感）
    if (lastDuelOpponentId == opponent.id) {
      finishLocal(
        '${opponent.name} 摆了摆手：「今天已经比过一场了，改天吧。」\n\n'
        '你收拾魔杖，决定换个对手，或者等明天。',
      );
      return;
    }

    // 决斗按 60 分钟计（旧实现传的是'对话'，只推进 10 分钟）
    advanceTimeForAction('决斗');
    recordDailyActivity('duel');
    lastDuelOpponentId = opponent.id;
    p.energy = (p.energy - 10).clamp(0, 100);
    p.magic = (p.magic - 12).clamp(0, 100);

    // 施法成功率公式：熟练度 × 环境 × 心理 × 装备（简化本地判定）
    final mastery = (attr('dda') + attr('spell_understanding')) / 200;
    final env = 0.85 + random.nextDouble() * 0.3;
    final mental = (p.spirit / 100) * 0.5 + 0.5;
    final equipFactor = 1 + equipmentCastBonus() / 1000.0;
    // 杖芯在这里第一次真正生效：以前选什么杖芯对数值毫无影响，
    // 「冬青木·凤凰羽毛」和「山楂木·独角兽毛」只是两段不同的描述文字。
    final core = wandById(p.wandId ?? '')?.core;
    var castChance =
        (mastery * env * mental * equipFactor + wandCoreCastBonusFor(core))
            .clamp(0.05, 0.95);

    // 凤凰羽毛「有自主意识」：眼看要失手时，魔杖自己替你补了一下
    final phoenixSave =
        wandCoreHasWill(core) && castChance < phoenixClutchThreshold;
    if (phoenixSave) {
      castChance = (castChance + phoenixClutchBonus).clamp(0.05, 0.95);
    }

    final myPower = playerPower();
    final myScore = myPower * castChance + random.nextInt(16);
    final oppScore = oppPower * 0.6 + random.nextInt(21);
    final win = myScore >= oppScore;

    final buf = StringBuffer('【巫师决斗 · ${opponent.name}】\n');
    buf.writeln(
      '你们在场地中央互相致礼，${opponent.name}的眼神带着一丝跃跃欲试。'
      '你握紧魔杖，心跳与咒语几乎同时升起。',
    );
    if (phoenixSave) {
      buf.writeln(
        '就在你手心发滑的那一瞬，杖尖自己窜出一串你不曾念过的火花——'
        '凤凰羽毛的杖芯替你把这一咒补完了。',
      );
    }
    if (castChance < 0.4) {
      buf.writeln('你的前两记咒语都偏得离谱——紧张让魔杖尖的光晕抖得像风里的烛火。');
    } else if (castChance >= 0.75) {
      buf.writeln('咒语一个接一个精准地飞出去，观战的同学发出压低了的惊叹。');
    } else {
      buf.writeln('施法有来有回，你稳住了节奏，寻找着对方的破绽。');
    }

    if (win) {
      p.health = (p.health - 5 - random.nextInt(6)).clamp(1, 100);
      // 当日第 N 场递减：越往后对手越有准备、观战的人越少，收益自然下降。
      // 旧实现每场收益恒定，一天刷十几场就能吃满所有成长曲线。
      final nth = dailyCountOf('duel'); // 已 recordDailyActivity，1 表示当天第一场
      final decay = nth <= 1 ? 1.0 : (nth == 2 ? 0.6 : 0.3);
      final repGain = ((6 + random.nextInt(6)) * decay).round().clamp(1, 11);
      final reward = ((10 + random.nextInt(16)) * decay).round().clamp(1, 25);
      p.playerReputation.add('combat', repGain);
      p.playerReputation.add('moral', 2);
      addHouseCupPoints((10 * decay).round().clamp(1, 10), '决斗获胜');
      p.galleons += reward;
      // 打赢对方会让人更服气，但只加一次：反复刷同一个人不该刷出满好感
      if (!duelBeatenNpcIds.contains(opponent.id)) {
        duelBeatenNpcIds.add(opponent.id);
        updateNpcAffection(opponent.id, 2, reason: '决斗获胜');
        _maybeRivalFromDuel(opponent, margin: myScore - oppScore);
      }
      buf.writeln('\\n最后一击命中！${opponent.name} 踉跄着抬起魔杖认输。');
      // 决斗社季度赛（框架2）：胜利 +10 赛季积分（连胜第 2 场起 +2 加成，上限 +18），
      // 赛季积分与 clubPoints 独立存储、互不转换——季度赛是专属玩法。
      // 赛季重置判定在面板/领奖时统一做（见 showDuelSeasonPanel）。
      if (p.duelSeasonTerm != _currentDuelSeason) {
        p.duelSeasonTerm = _currentDuelSeason;
        p.duelSeasonPoints = 0;
        p.duelSeasonWins = 0;
        p.duelSeasonClaimedTier = 0;
      }
      // S8：赛季积分也纳入每日递减——当天第 2 场起衰减到 60%/30%，
      // 与加隆/声望/学院杯的防刷口径一致，堵住「一天狂打赛季积分」
      // 的最优策略（旧实现赛季积分恒定 +10/+12，与递减设计意图相反）。
      final seasonWinPoints =
          ((10 + (p.duelSeasonWins >= 1 ? 2 : 0)) * decay).round().clamp(1, 18);
      p.duelSeasonPoints += seasonWinPoints;
      p.duelSeasonWins += 1;
      p.duelSeasonWinsTotal += 1;
      buf.writeln('赛季积分 +$seasonWinPoints（当前 ${p.duelSeasonPoints}）');
      buf.writeln(
        '胜利：战斗声望 +$repGain · 道德声望 +2 · 学院杯 +${(10 * decay).round().clamp(1, 10)} · 赌注 $reward 加隆',
      );
      if (nth > 1) {
        buf.writeln('（今日第 $nth 场，对手已有准备，收获比第一场少）');
      }
      unlockAchievement('first_duel_win');
    } else {
      p.health = (p.health - 12 - random.nextInt(14)).clamp(0, 100);
      pendingDeathCause = '决斗落败，伤势过重';
      p.playerReputation.add('combat', 2 + random.nextInt(3));
      // 决斗社季度赛：落败 +2 参与分（鼓励继续打，不鼓励刷——有每日上限兜底）
      if (p.duelSeasonTerm != _currentDuelSeason) {
        p.duelSeasonTerm = _currentDuelSeason;
        p.duelSeasonPoints = 0;
        p.duelSeasonWins = 0;
        p.duelSeasonClaimedTier = 0;
      }
      p.duelSeasonPoints += 2;
      buf.writeln('赛季积分 +2（当前 ${p.duelSeasonPoints}）');
      buf.writeln('落败：战斗声望 +2~4 · 你受了些轻伤（生命 ${p.health}/100）');
    }
    finishLocal(buf.toString());
  }

  /// 输的人未必服气——抢别人风头是宿敌最自然的来源之一。
  ///
  /// 但要控制频率：打一圈下来全校都成宿敌，就没人可交朋友了。
  /// 所以只在这几件事同时成立时才记一笔：此前没结过仇、
  /// 掷骰通过，且赢得越悬殊越容易结仇。
  void _maybeRivalFromDuel(NPC opponent, {required num margin}) {
    final day = worldState.time.absoluteDayIndex;
    // 已经有仇的不再叠加：一场胜利不该直接把人顶到死敌
    if (opponent.rivalryTier(day) != RivalryTier.none) return;
    // 本来就不待见你的人更容易记仇；输得太难看也更难咽下
    var chance = opponent.affection < 20 ? 0.55 : 0.3;
    if (margin > 25) chance += 0.15;
    if (random.nextDouble() > chance) return;
    opponent.addGrudge(causeKeyFor(RivalryCause.outshone), '你在决斗里当众赢了他', day);
    opponent.tickRivalry(day);
    final line = '🙄 ${opponent.name}输得不太好看，这事儿他记住了';
    notifications.add(line);
    worldState.addNarrativeEvent(line, turn: turnCount);
  }
  // ==================== 决斗社 · 季度赛（框架2 新增） ====================
  /// 当前赛季标识：'first-1991-1992' / 'second-1991-1992' / 'summer-1992-1993'。
  String get _currentDuelSeason => '${worldState.term}-${worldState.academicYear}';
  /// S10：快讯社头版防重标记，改用「学期」稳定编码（弃用 String.hashCode）。
  ///
  /// 旧实现存 `academicYear.hashCode`：一学年 3 个 term 只能报道 1 次（语义
  /// 降级），且 Dart String.hashCode 不保证跨进程/跨版本稳定，落盘为 int 后
  /// App 重启可能算出不同值 → 防重标记静默失效。
  /// 新实现用 term 的固定整数编码（first=1/second=2/summer=3）：每学期变化、
  /// 跨重启稳定、保持 int 字段类型兼容老存档。
  int get _headlineSeasonKey => switch (worldState.term) {
        'second' => 2,
        'summer' => 3,
        _ => 1,
      };
  /// /决斗 赛季 面板：查看本赛季积分/胜场/档位 + 领奖。
  @override
  void showDuelSeasonPanel() {
    final p = player;
    if (p == null) return;
    // 赛季重置判定：duelSeasonTerm 与当前赛季不符 → 清空本赛季数据（保留累计胜场）
    if (p.duelSeasonTerm != _currentDuelSeason) {
      p.duelSeasonTerm = _currentDuelSeason;
      p.duelSeasonPoints = 0;
      p.duelSeasonWins = 0;
      p.duelSeasonClaimedTier = 0;
    }
    final seasonLabel = p.duelSeasonTerm.startsWith('first')
        ? '秋季赛'
        : p.duelSeasonTerm.startsWith('second')
            ? '春季赛'
            : '暑期赛';
    final buf = StringBuffer('【决斗社 · $seasonLabel】\n');
    buf.writeln('赛季：${p.duelSeasonTerm}');
    buf.writeln('赛季积分：${p.duelSeasonPoints} · 本赛季胜场：${p.duelSeasonWins}');
    buf.writeln('累计总胜场：${p.duelSeasonWinsTotal}（跨赛季保留）');
    buf.writeln('\n档位奖励（达标即可领，跳档只补差额）：');
    const tiers = [
      (points: 40, label: '新锐'),
      (points: 90, label: '精英'),
      (points: 150, label: '冠军'),
    ];
    for (final t in tiers) {
      final claimed = p.duelSeasonClaimedTier >= t.points;
      final unlocked = p.duelSeasonPoints >= t.points;
      buf.writeln(
        '· ${t.label}（${t.points} 分）'
        '${unlocked ? (claimed ? ' — 已领取 ✅' : ' — 可领取！输入 /决斗 赛季 领奖') : ''}',
      );
    }
    if (p.duelSeasonPoints >= 150 && p.duelSeasonClaimedTier < 150) {
      buf.writeln('\n输入 /决斗 赛季 领奖 领取当前最高档位奖励。');
    }
    finishLocal(buf.toString());
  }
  /// /决斗 赛季 领奖：按当前积分领取最高可领档位（跳档只补差额）。
  @override
  void claimDuelSeasonReward() {
    final p = player;
    if (p == null) return;
    if (p.duelSeasonTerm != _currentDuelSeason) {
      p.duelSeasonTerm = _currentDuelSeason;
      p.duelSeasonPoints = 0;
      p.duelSeasonWins = 0;
      p.duelSeasonClaimedTier = 0;
    }
    const tiers = [
      (points: 40, label: '新锐', club: 30, attr: 'reaction_time', attrGain: 3, cup: 2, rep: 0),
      (points: 90, label: '精英', club: 50, attr: 'courage', attrGain: 5, cup: 4, rep: 1),
      (points: 150, label: '冠军', club: 80, attr: 'spell_understanding', attrGain: 6, cup: 6, rep: 2),
    ];
    // S6：跳档补发。旧实现只取最高档且 claimedTier 直接跳到该档，
    // 首次领奖时积分 150 → 直接发冠军，新锐+精英两档奖励永久丢失。
    // 改为从低到高逐档发放，claimedTier 累加（已领过的档不再重复发）。
    final claimed = <(int, String)>[];
    for (final t in tiers) {
      if (p.duelSeasonPoints >= t.points && p.duelSeasonClaimedTier < t.points) {
        p.duelSeasonClaimedTier = t.points;
        p.clubPoints += t.club;
        final attrNow = (attr(t.attr) + t.attrGain).clamp(0, 100);
        p.attributes[t.attr] = attrNow;
        addHouseCupPoints(t.cup, '决斗社·$seasonLabelOf(p.duelSeasonTerm)');
        if (t.rep > 0) p.playerReputation.add('combat', t.rep);
        if (t.label == '冠军') {
          p.collection.add('duel_season_champion'); // 收藏品「决斗赛季冠军」
        }
        claimed.add((t.points, t.label));
      }
    }
    if (claimed.isEmpty) {
      finishLocal('【决斗社赛季】目前没有可领取的新档位。继续赢得决斗累积赛季积分吧！');
      return;
    }
    final buf = StringBuffer('【决斗社赛季 · 领奖】\n');
    for (final (pts, _) in claimed) {
      final t = tiers.firstWhere((e) => e.points == pts);
      buf.writeln('你领取了「${t.label}」档位奖励！');
      buf.writeln('· 社团积分 +${t.club}（当前 ${p.clubPoints}）');
      buf.writeln('· ${t.attr} +${t.attrGain}');
      buf.writeln('· 学院杯 +${t.cup}');
      if (t.rep > 0) buf.writeln('· 战斗声望 +${t.rep}');
      if (t.label == '冠军') buf.writeln('· 收藏品「决斗赛季冠军」已入册');
    }
    if (p.duelSeasonClaimedTier < 150 && p.duelSeasonPoints >= 150) {
      buf.writeln('\n你已达标「冠军」档，输入 /决斗 赛季 领奖 可继续领取。');
    }
    finishLocal(buf.toString());
  }
  /// 赛季中文名（'first' → 秋季赛 …）。
  String seasonLabelOf(String term) {
    if (term.startsWith('first')) return '秋季赛';
    if (term.startsWith('second')) return '春季赛';
    return '暑期赛';
  }
  // ==================== 魔药部 · 限时配方（框架2 新增） ====================
  /// 当前限时窗口（按世界月份判定，无则 null）。
  PotionWindow? _currentPotionWindow() => potionWindowForMonth(worldState.time.month);
  /// /魔药 配方：查看当前窗口可用配方（含材料消耗）。
  @override
  void showPotionRecipes() {
    final p = player;
    if (p == null) return;
    final win = _currentPotionWindow();
    if (win == null) {
      finishLocal('【魔药部 · 配方】\n本月（${worldState.time.month}月）没有限时配方窗口。'
          '\n窗口期：开学季（9月）/ 圣诞季（12月）/ 冲刺季（5月）。'
          '\n\n窗口开启时输入 /魔药 配方 查看当期配方，/魔药 酿造 <配方id> 开始酿造。');
      return;
    }
    final list = potionRecipesInWindow(kPotionWindows.indexOf(win));
    if (list.isEmpty) {
      finishLocal('【魔药部 · 配方】\n「${win.name}」（${win.month}月）窗口暂无配方。');
      return;
    }
    final buf = StringBuffer('【魔药部 · ${win.name}配方】\n');
    buf.writeln('本月是 ${win.name}（${win.month}月），以下配方限时开放：\n');
    for (final r in list) {
      final mats = r.materials.entries.map((e) => '${e.key}×${e.value}').join(' + ');
      buf.writeln('· ${r.id}｜${r.name} → ${r.productName}');
      buf.writeln('  材料：$mats｜10 精力｜30 分钟');
    }
    buf.writeln('\n输入 /魔药 酿造 <配方id> 开始酿造（成功率与魔药学熟练度相关）。');
    buf.writeln('酿造产出为一次性药水，进背包后用 /使用 生效，商店买不到。');
    finishLocal(buf.toString());
  }
  /// 魔药学熟练度对应的酿造成功率分档（设计 3.4）。
  int _brewSuccessRate(int potions) {
    if (potions >= 70) return 90;
    if (potions >= 50) return 75;
    return 60;
  }
  /// /魔药 酿造 <配方id>：消耗材料 + 10 精力 + 30 分钟，按成功率判定产出。
  @override
  void brewPotion(String recipeId) {
    final p = player;
    if (p == null) return;
    final win = _currentPotionWindow();
    if (win == null) {
      finishLocal('【魔药部】本月没有限时配方窗口，坩埚闲着也是闲着，等窗口期再来吧。');
      return;
    }
    PotionRecipeDef? recipe;
    for (final r in kPotionRecipes) {
      if (r.id == recipeId && r.windowIndex == kPotionWindows.indexOf(win)) {
        recipe = r;
        break;
      }
    }
    if (recipe == null) {
      showPotionRecipes();
      return;
    }
    // 材料检查
    for (final e in recipe.materials.entries) {
      if (!hasItem(e.key)) {
        finishLocal('【魔药部 · 酿造】\n材料不足：还缺「${e.key}」×${e.value}。\n'
            '去禁林采集（材料只能禁林获取），凑齐材料再来。');
        return;
      }
    }
    if (p.energy < 10) {
      finishLocal('你的精力所剩无几（${p.energy}/100），坩埚都端不稳，先休息吧。');
      return;
    }
    // 扣材料、扣精力、推进 30 分钟
    for (final e in recipe.materials.entries) {
      for (var i = 0; i < e.value; i++) {
        removeItem(e.key);
      }
    }
    p.energy = (p.energy - 10).clamp(0, 100);
    advanceTimeForAction('魔药酿造');
    // 成功率判定
    final rate = _brewSuccessRate(attr('potions'));
    final success = random.nextInt(100) < rate;
    final buf = StringBuffer('【魔药部 · 酿造 ${recipe.name}】\n');
    if (success) {
      addItem(recipe.productName, type: '药水',
          desc: '魔药部限时配方「${recipe.name}」酿造产出，/使用 生效，商店买不到。');
      p.potionBrewCounts[recipe.id] = (p.potionBrewCounts[recipe.id] ?? 0) + 1;
      p.potionBrewed.add(recipe.id);
      buf.writeln('你把材料依次投入沸腾的坩埚，火候拿捏得恰到好处。');
      buf.writeln('药液由浑浊渐渐变得澄澈——${recipe.productName} 酿成了！');
      buf.writeln('\n· 产出「${recipe.productName}」已放入背包（/使用 生效）');
      buf.writeln('· 该配方累计酿造 ${p.potionBrewCounts[recipe.id]} 次');
    } else {
      p.potionBrewCounts[recipe.id] = (p.potionBrewCounts[recipe.id] ?? 0) + 1;
      buf.writeln('药液在最后一刻泛起可疑的泡沫，颜色也偏了。');
      buf.writeln('这一锅失败了——材料搭进去了，但你对火候的理解又深了一分。');
      buf.writeln('\n· 魔药学经验 +5（失败也有收获）');
      p.attributes['potions'] = ((p.attributes['potions'] ?? 50) + 5).clamp(0, 100);
    }
    buf.writeln('\n（消耗 10 精力，推进 30 分钟）');
    finishLocal(buf.toString());
  }
  // ==================== 魁地奇队 · 训练（框架2 新增） ====================
  /// 周重置判定：本周（gameWeek）首次训练时清零 qTrainWeek 计数。
  void _ensureTrainWeekReset() {
    final p = player;
    if (p == null) return;
    if (p.qTrainLastWeek != gameWeek) {
      p.qTrainLastWeek = gameWeek;
      p.qTrainWeek = 0;
    }
  }
  /// /魁地奇 训练：位置专项训练，每周上限 2 次。
  @override
  void trainQuidditch() {
    final p = player;
    if (p == null) return;
    _ensureTrainWeekReset();
    if (p.qTrainWeek >= 2) {
      finishLocal('本周你已经训练 2 次了（${p.qTrainWeek}/2）。'
          '教练说贪多嚼不烂，下周再来吧。');
      return;
    }
    if (p.energy < 10) {
      finishLocal('你的精力所剩无几（${p.energy}/100），扫帚都握不太稳，先休息吧。');
      return;
    }
    final pos = p.qPosition;
    final moments = kQuidditchTrainMoments[pos];
    if (moments == null || moments.isEmpty) {
      finishLocal('【魁地奇训练】当前没有「$pos」的训练项目，先 /魁地奇 位置 换个位置吧。');
      return;
    }
    p.energy = (p.energy - 10).clamp(0, 100);
    advanceTimeForAction('魁地奇训练');
    p.qTrainWeek++;
    p.qTrainTotal++;
    p.qSkill = (p.qSkill + 1).clamp(0, 100);
    final attrKey = quidditchTrainAttrOf(pos);
    p.attributes[attrKey] = ((p.attributes[attrKey] ?? 50) + 1).clamp(0, 100);
    final moment = moments[random.nextInt(moments.length)].text;
    final buf = StringBuffer('【魁地奇 · 位置训练 · $pos】\n');
    buf.writeln(moment);
    buf.writeln('\n· 魁地奇技巧 +1（${p.qSkill}/100）');
    buf.writeln('· ${attrLabelZh(attrKey)} +1（${p.attributes[attrKey]}/100）');
    buf.writeln('· 本周训练 ${p.qTrainWeek}/2 次（每次为本周比赛 +3 实力，可叠加）');
    buf.writeln('· 累计训练 ${p.qTrainTotal} 次');
    if (p.qTrainTotal >= 10 && !p.collection.contains('training_master')) {
      unlockAchievement('training_master');
      buf.writeln('\n🏆 成就解锁：训练大师（累计训练 10 次）！');
    }
    finishLocal(buf.toString());
  }
  // ==================== 快讯社 · 头版事件（框架2 新增） ====================
  /// 当前学期内已完成奇遇（happenstanceLog 中 term 匹配当前学期）。
  List<HappenstanceLogEntry> _headlineCandidates() {
    final p = player;
    if (p == null) return const [];
    return p.happenstanceLog
        .where((e) => e.term == worldState.term)
        .toList();
  }
  /// /快讯 头版：查看本学期可报道的候选素材。
  @override
  void showHeadlineBoard() {
    final p = player;
    if (p == null) return;
    final cands = _headlineCandidates();
    final buf = StringBuffer('【快讯社 · 头版选题】\n');
    buf.writeln('学期：${_seasonLabelOfTerm(worldState.term)}');
    if (cands.isEmpty) {
      buf.writeln('\n本学期还没有可报道的奇遇经历。');
      buf.writeln('多在城堡里走走、触发并完成奇遇，学期末它们会成为头版素材。');
      buf.writeln('（本学期已报道 ${p.headlineCount} 次）');
      finishLocal(buf.toString());
      return;
    }
    buf.writeln('\n可选素材（来自你本学期的真实经历）：\n');
    for (var i = 0; i < cands.length; i++) {
      final c = cands[i];
      buf.writeln('· ${i + 1}.「${c.title}」');
      buf.writeln('  结局：${c.outcomeTitle}｜${c.outcomeText}');
    }
    buf.writeln('\n输入 /快讯 报道 <序号> <角度> 完成报道。');
    buf.writeln('角度：现场直击 / 深度调查 / 人情故事');
    if (p.headlineSeason == _headlineSeasonKey) {
      buf.writeln('\n（本学期已报道过，下学期才有下一次头版机会。）');
    }
    finishLocal(buf.toString());
  }
  /// /快讯 报道 <序号> <角度>：选定素材 + 角度结算效果。
  @override
  void reportHeadline(int index, String angle) {
    final p = player;
    if (p == null) return;
    final cands = _headlineCandidates();
    if (cands.isEmpty) {
      finishLocal('【快讯社】本学期还没有可报道的素材。先触发并完成一场奇遇吧。');
      return;
    }
    if (index < 0 || index >= cands.length) {
      showHeadlineBoard();
      return;
    }
    if (p.headlineSeason == _headlineSeasonKey) {
      finishLocal('【快讯社】本学期你已经发过一次头版了，下学期再抢头条吧。');
      return;
    }
    final cand = cands[index];
    const angles = ['现场直击', '深度调查', '人情故事'];
    if (!angles.contains(angle)) {
      finishLocal('【快讯社】报道角度可选：现场直击 / 深度调查 / 人情故事。');
      return;
    }
    // 赛季结算（设计 3.4）：按角度给不同奖励
    p.headlineSeason = _headlineSeasonKey;
    p.headlineCount++;
    final buf = StringBuffer('【快讯社 · 头版报道】\n');
    buf.writeln('你伏在案前，把「${cand.title}」写成一份头版报道。');
    switch (angle) {
      case '现场直击':
        p.clubPoints += 20;
        p.attributes['social'] = ((p.attributes['social'] ?? 50) + 2).clamp(0, 100);
        buf.writeln('\n· 现场直击：快讯社积分 +20，社交 +2');
        break;
      case '深度调查':
        p.clubPoints += 35;
        p.attributes['logic'] = ((p.attributes['logic'] ?? 50) + 3).clamp(0, 100);
        p.playerReputation.add('social', 3);
        buf.writeln('\n· 深度调查：快讯社积分 +35，逻辑 +3，社交声望 +3');
        break;
      case '人情故事':
        p.clubPoints += 35;
        p.attributes['social'] = ((p.attributes['social'] ?? 50) + 3).clamp(0, 100);
        p.playerReputation.add('social', 2);
        buf.writeln('\n· 人情故事：快讯社积分 +35，社交 +3，社交声望 +2');
        break;
    }
    buf.writeln('（累计头版报道 ${p.headlineCount} 次）');
    if (p.headlineCount >= 1 && !p.collection.contains('headline_reporter')) {
      unlockAchievement('headline_reporter');
      buf.writeln('\n🏆 成就解锁：快讯记者（完成第一次头版报道）！');
    }
    finishLocal(buf.toString());
  }
  /// 学期英文 key → 中文名。
  String _seasonLabelOfTerm(String term) {
    if (term == 'first') return '第一学期';
    if (term == 'second') return '第二学期';
    return '暑期';
  }
}
