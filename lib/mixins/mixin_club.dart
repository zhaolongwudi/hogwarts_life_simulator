/// P14 校园社团系统：让「你属于什么」成为一条持续成长的线。
///
/// 【它解决什么问题】前几层——节庆/奇遇/羁绊/宠物/来信——讲的几乎都是「发生在
/// 你身上的事」，来了又散，留不下一个持续的身份。本层补上「归属感」：加入一个
/// 社团，此后你的每次离线行动只要对得上这个社团的干系事（决斗就切磋、魔药就熬
/// 制、魁地奇就练球、快讯就写稿），就为社团积累积分、逐级晋升（候补→活跃→骨干
/// →王牌→传奇）。晋升即回报：属性/学院杯分/声望，一句话旁白把那一刻的归属感
/// 钉进叙事。这是把「长期坚持同一件事」变成实在游戏内容的小引擎。
///
/// 数据全在 `club_data.dart`；本 mixin 只做三层事：
///   ① 匹配行动 → 记分（`maybeRunClubActivity`，自带冷却/互斥门控）；
///   ② 跨阶发奖（属性/学院分/声望，并旁白晋升时刻）；
///   ③ 面板（`formatClubPanel`）与加入/退出（`joinClub` / `leaveClub`）。
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/attribute_data.dart';
import '../data/club_data.dart';
import '../data/house_data.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';
import '../utils/npc_lookup.dart';

/// P14 社团 mixin。挂在 [GameProviderBase] 上。
mixin GameClubMixin on GameProviderBase {
  bool get _clubOn => appProvider.clubEnabled;

  /// 当前所属社团（未加入返回 null）。
  @visibleForTesting
  ClubDef? memberClub() {
    final p = player;
    if (p == null || p.clubId == null) return null;
    return clubById(p.clubId!);
  }

  /// 当前阶下标（0 = 初入的候补）。
  int clubRankOf({ClubDef? club, int? points}) {
    final c = club ?? memberClub();
    if (c == null) return 0;
    final pts = points ?? (player?.clubPoints ?? 0);
    return c.rankIndexFor(pts);
  }

  /// 加入一个社团（含换社）。返回需要写入面板的文本。
  /// rawId 为社团 id；未知 id 时回到无参面板并提示。
  String joinClub(String rawId) {
    final club = clubById(rawId);
    if (club == null) {
      return '没有叫「$rawId」的社团。可选：'
          '${kClubs.map((c) => '${c.name}（/${c.id}）').join('、')}。';
    }
    final p = player;
    if (p == null) return '还没有可归属的人生——先创建角色吧。';
    if (p.clubId == club.id) {
      return '你已经是「${club.icon} ${club.name}」的成员了。';
    }
    final wasMember = p.clubId != null;
    p.clubId = club.id;
    p.clubPoints = 0; // 换社清零
    p.clubLastTurn = -1;
    // 批次 C（16d）同好注入·注入点 A：入社即与社团成员结下同好之谊（一次性）。
    // 只对新社 attendees 生效——换社时旧社此前已加过，不重复叠加。
    // 走 updateNpcAffection 统一入口（game_provider_base.dart:809），
    // 周/月好感上限与衰减由既有数值层统一兜底，零新增字段零迁移。
    final incomingGains = <String>[];
    for (final attendeeName in club.attendees) {
      final attendee = findNpcByKeyword(npcRegistry.values, attendeeName);
      if (attendee == null) continue;
      updateNpcAffection(attendee.id, 5, reason: '加入${club.name}，与同好结谊');
      incomingGains.add(attendee.name);
    }
    final rank = club.ranks.first;
    final buf = StringBuffer()
      ..writeln('【加入社团 · ${club.icon} ${club.name}】')
      ..writeln('${club.tagline}。')
      ..writeln(club.description)
      ..writeln()
      ..writeln('你签下了名字，成为${club.attendees.join('、')}的同好，'
          '以「${rank.name}」之身入社。');
    // 批次 C（16d）同好注入·旁白补充：入社把同好关系织进叙事。
    if (incomingGains.isNotEmpty) {
      buf.writeln();
      buf.writeln('入社之谊已记下——${incomingGains.join('、')}对你的亲近感，'
          '因这同好之名悄然加深（好感 +5/人）。');
    }
    // 入社即落地「候补」阶的欢迎加成（属性/学院分/声望）。
    final welcome = _rankBonusLines(club, 0);
    if (welcome.isNotEmpty) buf.writeln('\n$welcome');
    buf.writeln(
        '往后的离线日常里，多做与社团相关的干系事，就能积累积分逐步晋升。');
    if (wasMember) {
      buf.writeln();
      buf.writeln('（换社后积分清零——此前攒下的晋升就此告别。）');
    }
    notifications.add('🏰 加入社团：${club.name}');
    return buf.toString().trim();
  }

  /// 退出社团（清零并回到未加入状态）。
  String leaveClub() {
    final p = player;
    if (p == null || p.clubId == null) return '你还没有加入任何社团。';
    final club = clubById(p.clubId!);
    p.clubId = null;
    p.clubPoints = 0;
    p.clubLastTurn = -1;
    final gone = club != null ? '${club.name}的${club.ranks.first.name}生涯作罢' : '社团生涯';
    notifications.add('🏰 退出社团：你离开了\n$gone');
    return '你走出了会堂，$gone。门口的老成员没有多留你，只是说了句：'
        '「随时回来。」';
  }

  /// 命中本回合的一次「为社团出力」行动并结算积分与跨越晋升。
  /// action 为玩家本回合的离线行动文本；未命中或受门控返回空串。
  @override
  String maybeRunClubActivity(String action) {
    if (!_clubOn) return '';
    final p = player;
    if (p == null || p.clubId == null) return '';
    final club = clubById(p.clubId!);
    if (club == null) return '';
    // 有在等的奇遇/羁绊/回信先处理完，不让社团活动抢正戏。
    if (hasPendingHappenstance) return '';
    if (hasPendingCompanionClimax) return '';
    if (hasPendingLetter) return '';
    // 门控顺序：先关键词命中再扣日预算（未命中的探索不该消耗次数）。
    if (!club.activityKeywords.any(action.contains)) return '';
    // Batch 5 · Issue #7 统一口径：以"每日剩余次数"替代旧的 6 回合冷却；
    // 数值见 kDailyActivityLimits['club_activity']。
    if (!canDoDaily('club_activity')) return '';

    final rnd = Random(turnCount);
    final gain = 10 + rnd.nextInt(6); // 10~15，确定性随机
    final beforePoints = p.clubPoints;
    final prevRank = club.rankIndexFor(beforePoints);
    p.clubPoints += gain;
    recordDailyActivity('club_activity');
    // 批次 C（16d）同好注入·注入点 B：周常为社团出力，与同好们的情谊细水长流。
    // 每次 +1（周上限 2），上限由 updateNpcAffection 数值层（getAffectionGainLimit
    // + affectionGainedThisWeek）自动兜底——超出即截断为 0，无需新增字段。
    // 放在 recordDailyActivity 之后：天然跟随「每日社团活动次数」门控。
    for (final attendeeName in club.attendees) {
      final attendee = findNpcByKeyword(npcRegistry.values, attendeeName);
      if (attendee == null) continue;
      updateNpcAffection(attendee.id, 1, reason: '与${club.name}同好共事');
    }
    p.clubLastTurn = turnCount; // deprecated since Batch 5 · Issue #7；仅为存档兼容。
    final newRank = club.rankIndexFor(p.clubPoints);

    final house = houseDisplayName(p.house ?? '', fallback: '霍格沃茨');
    // P18 社团 × 学院杯联动：为社团出力也为学院挣 1 分（「你属于什么」也有
    // 让学院骄傲的分量）。来源写入 houseCupSources，/学院杯 来源明细可见。
    addHouseCupPoints(1, '社团·${club.name}');
    final buf = StringBuffer();
    if (newRank > prevRank) {
      // 跨过了一阶甚至多阶：逐阶发奖与旁白。
      buf.writeln('———————🏰 社团动向 · ${club.icon} ${club.name} 🏰———————');
      buf.writeln('你为 ${club.name} 出力，社团积分 +$gain '
          '（${p.clubPoints}）。为 $house 挣得 1 学院分。这一笔，正好把你在社团里的分量顶了上去。');
      for (var r = prevRank + 1; r <= newRank; r++) {
        buf.writeln();
        buf.writeln(_rankBonusLines(club, r));
      }
      buf.writeln();
      buf.writeln('天，$house 的礼堂钟声响起——你在 ${club.name} 又高了一级。');
    } else {
      // 未跨阶：报积分与离下一阶的距离。
      final next = newRank + 1 < club.ranks.length
          ? club.ranks[newRank + 1]
          : null;
      buf.writeln('———————🏰 社团活动 · ${club.icon} ${club.name} 🏰———————');
      buf.writeln('你把今天的${club.activityKeywords.first}尽心做了，'
          '为 ${club.name} 攒下 $gain 积分，也为 $house 挣得 1 学院分。');
      if (next != null) {
        final remain = next.points - p.clubPoints,
            total = next.points;
        buf.writeln('当前积分 ${p.clubPoints}/$total，还差 $remain 晋升'
            '「${next.name}」。贵在细水长流。');
      } else {
        buf.writeln('${club.name} 的${club.ranks.last.name}之位你已登顶，'
            '往后每一分，都是传奇添的注脚。');
      }
    }
    return buf.toString().trim();
  }

  /// /社团 面板：未加入 → 罗列四个社团供挑选；已加入 → 展示身份/进度/涨分窍门。
  String formatClubPanel() {
    final p = player;
    if (p == null) return '还没有可归属的人生——先创建角色吧。';
    final club = memberClub();
    final buf = StringBuffer('【校·园·社·团】');
    if (club == null) {
      buf.writeln('\n找一个愿意收留你的社团——往后的离线行动对得上社团干系事，'
          '就能积累积分、逐步晋升。');
      for (final c in kClubs) {
        buf.writeln('\n${c.icon} ${c.name}（/社团 ${c.id}）');
        buf.writeln('　「${c.tagline}」');
        buf.writeln('　${c.description}');
      }
      buf.writeln('\n\n用「/社团 <id>」入社。加入后再用「/社团 退出」离开。');
      return buf.toString();
    }
    final idx = clubRankOf(club: club);
    final rank = club.ranks[idx];
    buf.writeln('\n当前成员：${club.icon} ${club.name} ——「${club.tagline}」');
    buf.writeln('身份：${rank.name} · 社团积分 ${p.clubPoints}');
    final next = idx + 1 < club.ranks.length ? club.ranks[idx + 1] : null;
    if (next != null) {
      final remain = next.points - p.clubPoints, total = next.points;
      buf.writeln('晋升进度：$total 分中已有 ${p.clubPoints}，'
          '还差 $remain 到「${next.name}」。');
      final pct = (p.clubPoints / total * 100).floor().clamp(0, 100);
      final bar = StringBuffer()
        ..writeAll(List.filled(pct ~/ 10, '▰'))
        ..writeAll(List.filled(10 - pct ~/ 10, '▱'));
      buf.writeln('[$bar] $pct%');
    } else {
      buf.writeln('你已是${club.ranks.last.name}——传奇之上，唯有继续添注脚。');
    }
    buf.writeln('\n同好：${club.attendees.join('、')}');
    buf.writeln('\n涨分窍门：离线行动里带上「${club.activityKeywords.take(3).join('」或「')}」'
        '这类干系事，就能为社团供分。');
    buf.writeln('（想换一摊子干？用 /社团 退出 重新挑。）');
    return buf.toString();
  }

  String? _repLabel(String dim) {
    const m = {
      'academic': '学识',
      'social': '社交',
      'combat': '战斗',
      'moral': '道德',
      'leadership': '领导',
      'dark': '黑暗',
    };
    return m[dim];
  }

  /// 落地某一阶的全部加成并返回该阶的旁白文块（供入社/跨阶复用）。
  /// 会真实写入 player 状态（属性/学院分/声望）。
  String _rankBonusLines(ClubDef club, int rankIndex) {
    final rank = club.ranks[rankIndex];
    final p = player;
    if (p == null) return '';
    final house = houseDisplayName(p.house ?? '', fallback: '霍格沃茨');
    final buf = StringBuffer()..writeln('◆ 晋升 · ${club.name}「${rank.name}」◆');
    buf.writeln(fillClubText(rank.bonuses.isNotEmpty
        ? rank.bonuses.first.note
        : '你在 ${club.name} 往前走了一步，成了「${rank.name}」。',
        club: club.name, rank: rank.name));
    for (final b in rank.bonuses) {
      if (b.attrKey != null && b.attrValue != 0) {
        _gainAttr(p, b.attrKey!, b.attrValue);
        buf.writeln('· ${attributeLabel(b.attrKey!)} +${b.attrValue}');
      }
      if (b.housePoints > 0) {
        addHouseCupPoints(b.housePoints, '${club.name}·${rank.name}');
        buf.writeln('· 为 $house 赢得 ${b.housePoints} 学院分');
      }
      if (b.reputationDim != null && b.reputationValue != 0) {
        p.playerReputation.add(b.reputationDim!, b.reputationValue);
        buf.writeln(
            '· 声望（${_repLabel(b.reputationDim!)}）+${b.reputationValue}');
      }
    }
    // P16 社团晋升回访信：晋升到「王牌」或「传奇」时，同好里已结识的 NPC
    // 会寄来一封回访信（只入叙事，不落存档信箱，避免信件膨胀）。
    if (rankIndex >= 3) {
      final visitor = _pickFriendForRankUp(club);
      if (visitor != null) {
        buf.writeln();
        buf.writeln('🦉 一只猫头鹰落在你肩头，衔着一封「${visitor.name}」的信：');
        final note = switch (rankIndex) {
          3 => '「我在会堂里听到你的名字被大家喊起来了。说实话，我早就知道你会走到这一步——'
              '只是没想到会这么快。改天一起喝一杯黄油啤酒，庆祝你成了${club.name}的王牌。」',
          _ => '「今晚${club.name}的会堂为你点了灯，我这封信代表所有同好：你值得。'
              '多年以后的新人翻开社史，会读到你的名字——而我，会告诉他们我认识你。」',
        };
        buf.writeln(note);
      }
    }
    return buf.toString();
  }

  /// 属性增长（封顶 100）；与后果引擎的口径一致（静默落档，回合末统一保存）。
  void _gainAttr(Player player, String key, int gain) {
    player.attributes[key] =
        ((player.attributes[key] ?? 50) + gain).clamp(0, 100);
  }

  /// P16：从社团同好里挑一位「已结识且在世」的 NPC 作为晋升回访信的寄信人。
  /// 无人可选返回 null（回访信不出现，不影响晋升本身）。
  NPC? _pickFriendForRankUp(ClubDef club) {
    final introduced = npcRegistry.values
        .where((n) => n.introduced && n.isAlive && !n.graduated)
        .toList();
    for (final name in club.attendees) {
      for (final n in introduced) {
        if (n.name == name) return n;
      }
    }
    // 同好无人登场 → 从已结识 NPC 里随便挑一位关系好的凑数（保持归属感）。
    if (introduced.isNotEmpty) {
      introduced.sort((a, b) => b.affection.compareTo(a.affection));
      return introduced.first;
    }
    return null;
  }

  // ==================== P15 跨回合社团任务 ====================

  /// 当前接取的任务模板；未接取返回 null。
  @visibleForTesting
  ClubTaskDef? currentClubTask() {
    final p = player;
    if (p == null || p.clubTaskId == null) return null;
    return clubTaskById(p.clubTaskId!);
  }

  /// /社团 任务 面板：列出当前社团的任务，展示接取状态与进度。
  String clubTaskPanel() {
    final p = player;
    if (p == null) return '还没有可归属的人生——先创建角色吧。';
    final club = memberClub();
    if (club == null) return '你还没有加入任何社团，先「/社团 <id>」入社吧。';
    final tasks = clubTasksFor(club.id);
    if (tasks.isEmpty) return '${club.name} 暂时没有任务可接。';
    final buf = StringBuffer('【${club.icon} ${club.name} · 社团任务】');
    final current = currentClubTask();
    for (final t in tasks) {
      buf.writeln();
      buf.writeln('—— ${t.title} ——');
      buf.writeln(t.desc);
      buf.writeln('要求：为社团出力 ${t.requiredRounds} 回合 · '
          '奖励：社团积分 +${t.clubPointsReward}'
          '${t.attrKey != null && t.attrValue > 0 ? ' · ${attributeLabel(t.attrKey!)} +${t.attrValue}' : ''}');
      if (current?.id == t.id) {
        buf.writeln('【进行中】进度 ${p.clubTaskProgress}/${t.requiredRounds}'
            '（接于第 ${p.clubTaskIssuedTurn} 回合）');
        if (p.clubTaskProgress >= t.requiredRounds) {
          buf.writeln('✔ 已完成！用「/社团 任务 完成」领奖。');
        } else {
          buf.writeln('多做与干系事相符的行动即可推进。');
        }
      } else {
        buf.writeln('用「/社团 任务 接取 ${t.id}」接下这条。');
      }
    }
    buf.writeln('\n（同一时间只能进行一条任务；换任务用「/社团 任务 接取 <id>」，'
        '进度会清零。）');
    return buf.toString();
  }

  /// 接取一条社团任务。返回面板文本；非法 id / 未入社 / 任务不属于本社时提示。
  String acceptClubTask(String rawId) {
    final p = player;
    if (p == null) return '还没有可归属的人生——先创建角色吧。';
    final club = memberClub();
    if (club == null) return '你还没有加入任何社团，先「/社团 <id>」入社吧。';
    final t = clubTaskById(rawId);
    if (t == null || t.clubId != club.id) {
      return '没有叫「$rawId」的社团任务。当前 ${club.name} 可选：'
          '${clubTasksFor(club.id).map((x) => x.id).join('、')}。';
    }
    final prev = currentClubTask();
    if (prev?.id == t.id && p.clubTaskProgress > 0) {
      return '你已经在进行「${t.title}」了（进度 ${p.clubTaskProgress}/${t.requiredRounds}）。';
    }
    p.clubTaskId = t.id;
    p.clubTaskProgress = 0;
    p.clubTaskIssuedTurn = -1; // -1 = 尚未推进过（接取当回合即可推进）
    p.clubTaskClaimed = false;
    notifications.add('📋 社团任务接取：${t.title}');
    final buf = StringBuffer('【接取任务 · ${t.title}】')
      ..writeln(t.desc)
      ..writeln('要求：为社团出力 ${t.requiredRounds} 回合。')
      ..writeln('此后每回合的离线行动只要与干系事相符，任务进度就会 +1。')
      ..writeln('攒够后回来用「/社团 任务 完成」领奖。');
    return buf.toString().trim();
  }

  /// 由离线管线在 P14 段调用：玩家本回合行动命中社团干系事时推进任务进度。
  /// 与日常记分（maybeRunClubActivity）共享 "以日为颗粒度" 的预算口径：
  /// 任务推进计入 `kDailyActivityLimits['club_task']`，日常记分计入
  /// `kDailyActivityLimits['club_activity']`。两条链路各自预算互不占用，
  /// 所以同一次命中可以既推进任务也拿日常分——但每天都不能无限量刷。
  /// 返回一段进度提示文本；无进行中任务 / 行动不匹配 / 已完成未领奖时不推进。
  String advanceClubTaskForAction(String action) {
    final p = player;
    final club = memberClub();
    final t = currentClubTask();
    if (p == null || club == null || t == null || t.clubId != club.id) {
      return '';
    }
    if (!club.activityKeywords.any(action.contains)) return '';
    // 有在等的奇遇/羁绊/回信先处理完，不让任务提示抢正戏（与日常记分同门控）。
    if (hasPendingHappenstance) return '';
    if (hasPendingCompanionClimax) return '';
    if (hasPendingLetter) return '';
    if (p.clubTaskProgress >= t.requiredRounds) {
      // 已完成未领奖：不再推进，但提示领奖。
      return '📋 社团任务「${t.title}」已完成！用「/社团 任务 完成」领奖。';
    }
    // 任务推进的日预算门槛（Batch 5 · Issue #7 统一口径）。旧字段
    // `clubTaskIssuedTurn` 已不再用于判定，仅保留展示接取时长用途。
    if (!canDoDaily('club_task')) return '';
    p.clubTaskProgress++;
    recordDailyActivity('club_task');
    p.clubTaskIssuedTurn = turnCount;
    if (p.clubTaskProgress >= t.requiredRounds) {
      return '📋 社团任务「${t.title}」进度达成！用「/社团 任务 完成」领奖。';
    }
    return '📋 社团任务「${t.title}」进度 ${p.clubTaskProgress}/${t.requiredRounds}。';
  }

  /// 领取已完成任务的奖励。返回领奖文本；未完成 / 未接取时提示。
  String claimClubTask() {
    final p = player;
    if (p == null) return '还没有可归属的人生——先创建角色吧。';
    final club = memberClub();
    if (club == null) return '你还没有加入任何社团。';
    final t = currentClubTask();
    if (t == null) return '当前没有进行中的社团任务，用「/社团 任务」查看可接任务。';
    if (p.clubTaskProgress < t.requiredRounds) {
      return '「${t.title}」还没完成（进度 ${p.clubTaskProgress}/${t.requiredRounds}），'
          '再多做几回合与干系事相符的行动吧。';
    }
    // 结算奖励：大额社团积分（不触发跨阶发奖——日常记分已带晋升逻辑，这里只加数值）。
    p.clubPoints += t.clubPointsReward;
    if (t.attrKey != null && t.attrValue > 0) {
      _gainAttr(p, t.attrKey!, t.attrValue);
    }
    // P18 社团 × 学院杯联动：任务完成也为学院挣 3 分（社团的荣光也是学院的）。
    addHouseCupPoints(3, '社团任务·${t.title}');
    p.clubTaskClaimed = true;
    // 领奖后清空接取，回到可接新任务状态。
    p.clubTaskId = null;
    p.clubTaskProgress = 0;
    p.clubTaskIssuedTurn = -1;
    final house = houseDisplayName(p.house ?? '', fallback: '霍格沃茨');
    final buf = StringBuffer('【任务完成 · ${club.icon} ${t.title}】')
      ..writeln(fillClubText(t.rewardNote, club: club.name, rank: club.ranks.first.name))
      ..writeln()
      ..writeln('社团积分 +${t.clubPointsReward}（当前 ${p.clubPoints}）');
    if (t.attrKey != null && t.attrValue > 0) {
      buf.writeln('${attributeLabel(t.attrKey!)} +${t.attrValue}');
    }
    buf.writeln('为 $house 挣得 3 学院分，也为自己挣了口气。');
    notifications.add('🏰 社团任务完成：${t.title}');
    return buf.toString().trim();
  }

  /// 放弃当前任务（进度清零，回到可接新任务）。
  String abandonClubTask() {
    final p = player;
    if (p == null) return '还没有可归属的人生——先创建角色吧。';
    final t = currentClubTask();
    if (t == null) return '当前没有进行中的社团任务。';
    p.clubTaskId = null;
    p.clubTaskProgress = 0;
    p.clubTaskIssuedTurn = -1;
    p.clubTaskClaimed = false;
    notifications.add('📋 社团任务放弃：${t.title}');
    return '你搁下了「${t.title}」。社长没有多问——任务栏空着，随时可以换一条。';
  }
}