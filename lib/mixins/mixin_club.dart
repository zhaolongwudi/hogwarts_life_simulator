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
import '../models/player.dart';
import '../providers/game_provider_base.dart';

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
    final rank = club.ranks.first;
    final buf = StringBuffer()
      ..writeln('【加入社团 · ${club.icon} ${club.name}】')
      ..writeln('${club.tagline}。')
      ..writeln(club.description)
      ..writeln()
      ..writeln('你签下了名字，成为${club.attendees.join('、')}的同好，'
          '以「${rank.name}」之身入社。');
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
    // 冷却：同一处干系事不会每个回合都被点亮。
    if (turnCount - p.clubLastTurn < kClubCooldownTurns) return '';
    if (!club.activityKeywords.any(action.contains)) return '';

    final rnd = Random(turnCount);
    final gain = 10 + rnd.nextInt(6); // 10~15，确定性随机
    final beforePoints = p.clubPoints;
    final prevRank = club.rankIndexFor(beforePoints);
    p.clubPoints += gain;
    p.clubLastTurn = turnCount;
    final newRank = club.rankIndexFor(p.clubPoints);

    final house = houseDisplayName(p.house ?? '', fallback: '霍格沃茨');
    final buf = StringBuffer();
    if (newRank > prevRank) {
      // 跨过了一阶甚至多阶：逐阶发奖与旁白。
      buf.writeln('———————🏰 社团动向 · ${club.icon} ${club.name} 🏰———————');
      buf.writeln('你为 ${club.name} 出力，社团积分 +$gain '
          '（${p.clubPoints}）。这一笔，正好把你在社团里的分量顶了上去。');
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
          '为 ${club.name} 攒下 $gain 积分。');
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
    return buf.toString();
  }

  /// 属性增长（封顶 100）；与后果引擎的口径一致（静默落档，回合末统一保存）。
  void _gainAttr(Player player, String key, int gain) {
    player.attributes[key] =
        ((player.attributes[key] ?? 50) + gain).clamp(0, 100);
  }
}