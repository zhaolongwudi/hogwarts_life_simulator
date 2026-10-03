/// P13 猫头鹰来信系统 · 独立领域类（阶段2 抽取）。
///
/// 【抽取说明】全部「选信 + 落款 + 结算」逻辑自 `mixin_letter.dart` 迁入，
/// 成为一个不依赖 Provider 组合的领域服务类：显式声明依赖（[LetterDeps]），
/// 便于单测与未来替换 Provider 组合方式。`mixin_letter.dart` 保留为薄委托层，
/// 对外接口（GameProviderBase 抽象契约）不变，测试与叙事管线零改动。
library;

import 'dart:math';


import '../data/house_data.dart';
import '../data/letter_data.dart';
import '../models/game_systems.dart';
import '../models/npc.dart';
import '../models/player.dart';

/// 来信系统对外依赖的窄接口。
///
/// 抽取自 GameProviderBase 的对应成员；领域类只看得到这些，
/// 不再与整个 Provider 状态空间耦合。
abstract class LetterDeps {
  bool get letterEnabled;
  bool get clubEnabled;
  Player? get player;
  Map<String, NPC> get npcRegistry;

  /// 当前月份（魔法部公函投递窗口）。
  int get currentMonth;

  /// 当前绝对日序（敌对怨气打分用）。
  int get currentDayIndex;

  List<String> get notifications;
  int get turnCount;

  bool get hasPendingHappenstance;
  bool get hasPendingCompanionClimax;

  void addHouseCupPoints(int pts, String reason);
  void updateNpcAffection(String npcId, int delta,
      {required String reason, bool quiet = false});
  String joinClub(String clubId);

  /// 系统日期格式化（与 GameTime.formatDate 同口径）。
  String formatDate();
}

/// P13 猫头鹰来信领域系统。
class LetterSystem {
  LetterSystem(this.d);
  final LetterDeps d;

  /// 正待回的信 id。
  String? get pendingLetterId => d.player?.pendingLetterId;

  /// 是否有待回声的信。
  bool get hasPendingLetter => pendingLetterId != null;

  /// 最近一次收到来信的回合号（冷却用）。
  int get _letterLastTurn => d.player?.letterLastTurn ?? -1;

  /// 已送到的来信 id 集合（里程碑 once-only）。
  Set<String> get _received =>
      d.player?.receivedLetters.toSet() ?? const <String>{};

  /// 从已结识、在世、未毕业的 NPC 里解析这封信的落款人；无人可用返回 null。
  ///
  /// 指定了 [LetterDef.senderId] 的必须就是这位（且已结识）；未指定时：
  ///  - friendship/milestone：选好感最高、且不低于该信 minAffection 的朋友；
  ///  - rivalry：选怨气最重的对手（好感不高于 maxAffection）。
  ///  - reunion：好感达标且**已毕业**的旧友（毕业后仍可来信）。
  /// 尽量避开上一位寄信人，免得同一人连番刷屏。
  /// 机构/匿名信（`senderLabel` 非空）不查 NPC pool，直接返回 null 由上层走哨兵。
  NPC? letterSenderFor(LetterDef def) {
    if (def.senderLabel != null) return null; // 机构/匿名信：无需 NPC 落款
    final base = d.npcRegistry.values.where((n) => n.introduced && n.isAlive);
    final pool = (def.kind == LetterKind.reunion
            ? base.where((n) => n.graduated).toList()
            : base.where((n) => !n.graduated).toList())
        .toList();
    if (def.senderId != null) {
      for (final n in pool) {
        if (n.id == def.senderId) return n;
      }
      return null;
    }
    final day = d.currentDayIndex;
    if (def.kind == LetterKind.rivalry) {
      final hostile = pool
          .where((n) => n.affection <= (def.maxAffection ?? 0))
          .toList()
        ..sort((a, b) => b.rivalryScore(day).compareTo(a.rivalryScore(day)));
      if (hostile.isEmpty) return null;
      return _avoidRepeatSender(hostile);
    }
    final friendly = pool
        .where((n) => n.affection >= def.minAffection)
        .toList()
      ..sort((a, b) => b.affection.compareTo(a.affection));
    if (friendly.isEmpty) return null;
    return _avoidRepeatSender(friendly);
  }

  NPC? _avoidRepeatSender(List<NPC> candidates) {
    final last = d.player?.lastLetterSenderId;
    if (last == null || candidates.length < 2) return candidates.first;
    if (candidates.first.id == last) return candidates[1];
    return candidates.first;
  }

  /// 落款一位已结识 NPC：先解析回寄人，若寄信人已淡出则取存档里的寄信人。
  /// 机构/匿名信（senderLabel 非空）无 NPC 落款，一律返回 null。
  NPC? _senderOf(LetterDef def) {
    if (def.senderLabel != null) return null; // 机构/匿名信：无 NPC 可落款
    final from = letterSenderFor(def);
    if (from != null) return from;
    final id = d.player?.lastLetterSenderId;
    if (id != null) return d.npcRegistry[id];
    return null;
  }

  /// 命中一封本回合要寄来的信；无法收到返回空串并交付文本。
  ///
  /// 优先级：① 未收到且可落款的**最高门槛**里程碑来信（once、先补齐）;
  /// ② 否则在可落款的友情来信里随机一封（好感到位便有）；③ 否则敌对来信。
  /// 全程受开关/冷却/互斥门控。
  String maybeTriggerLetter({int? seed}) {
    if (!d.letterEnabled) return '';
    final p = d.player;
    if (p == null) return '';
    // 有在等的奇遇/羁绊/回信先处理完，不让新信抢戏。
    if (d.hasPendingHappenstance) return '';
    if (d.hasPendingCompanionClimax) return '';
    if (hasPendingLetter) return '';
    // 冷却：猫头鹰不会天天扑腾。
    if (d.turnCount - _letterLastTurn < kLetterCooldownTurns) return '';

    final rnd = Random(seed ?? d.turnCount);
    final received = _received;

    // 1) 未收里程碑：门槛越高越优先（先把重要的缘分补上）。
    final milestones = kLetters
        .where(
            (l) => l.kind == LetterKind.milestone && !received.contains(l.id))
        .toList()
      ..sort((a, b) => b.minAffection.compareTo(a.minAffection));
    for (final l in milestones) {
      final sender = letterSenderFor(l);
      if (sender != null) return _deliver(p, l, sender);
    }

    // 2) 魔法部公函：未收过的机构信，仅在学期节点月份投递（不抢日常来信的戏）。
    final nowMonth = d.currentMonth;
    final ministries = kLetters
        .where((l) =>
            l.kind == LetterKind.ministry &&
            !received.contains(l.id) &&
            (l.month == null || l.month == nowMonth))
        .toList()
      ..shuffle(rnd);
    for (final l in ministries) {
      if (senderLabelReady(l)) return _deliver(p, l, null);
    }

    // 3) 神秘信件：未收过的匿名彩蛋，低概率（不抢主线）。
    final mysteries = kLetters
        .where((l) => l.kind == LetterKind.mystery && !received.contains(l.id))
        .toList()
      ..shuffle(rnd);
    for (final l in mysteries) {
      if (rnd.nextDouble() < 0.15 && senderLabelReady(l)) {
        return _deliver(p, l, null);
      }
    }

    // 3.5) 社长邀请信（来信→社团）：未入该社 + 对应社长好感达标才投递。
    // 优先级在里程碑/公函/神秘之后、日常友情之前——牵线机会不抢重头戏，
    // 但先于泛泛暖场。已入社（含换社后）自动跳过；clubId 非空的信只投未入社玩家。
    // 仅在社团系统开启时投递（clubEnabled=false 的测试环境不干扰既有用例）。
    // 注意：letterSenderFor 对指定 senderId 的信只检查 NPC 是否在 pool（introduced
    // + alive + !graduated），不检查好感达标——这里需额外校验 minAffection。
    if (p.clubId == null && d.clubEnabled) {
      final clubInvites = kLetters
          .where((l) => l.clubId != null && !received.contains(l.id))
          .toList()
        ..shuffle(rnd);
      for (final l in clubInvites) {
        // 未入该社 + 社长（senderId）已结识且好感达标，才投这封邀请信。
        if (l.clubId == null || p.clubId == l.clubId) continue;
        final sender = letterSenderFor(l);
        if (sender == null) continue;
        // letterSenderFor 对 senderId 精确匹配不检查好感，这里补校验。
        if (sender.affection < l.minAffection) continue;
        return _deliver(p, l, sender);
      }
    }

    // 4) 友情来信：随机一封可落款的（会重播，靠好感门槛兜手感）。
    // 排除 clubId 非空的社长邀请信（那些走 3.5 专属分支，已入社后不再投）。
    final friends = kLetters
        .where((l) => l.kind == LetterKind.friendship && l.clubId == null)
        .toList()
      ..shuffle(rnd);
    for (final l in friends) {
      final sender = letterSenderFor(l);
      if (sender != null) return _deliver(p, l, sender);
    }

    // 5) 毕业旧友重联：有已毕业 NPC 在时随机一封（靠冷却兜手感）。
    final reunions =
        kLetters.where((l) => l.kind == LetterKind.reunion).toList()
          ..shuffle(rnd);
    for (final l in reunions) {
      final sender = letterSenderFor(l);
      if (sender != null) return _deliver(p, l, sender);
    }

    // 6) 敌对来信：有怨气对手在时随机一封。
    final rivals = kLetters.where((l) => l.kind == LetterKind.rivalry).toList()
      ..shuffle(rnd);
    for (final l in rivals) {
      final sender = letterSenderFor(l);
      if (sender != null) return _deliver(p, l, sender);
    }

    return '';
  }

  /// 机构/匿名信（senderLabel 非空）是否具备投递条件（纯数据检查）。
  bool senderLabelReady(LetterDef def) =>
      def.senderLabel != null && def.senderLabel!.isNotEmpty;

  String _deliver(Player p, LetterDef def, NPC? sender) {
    // 署名：机构/匿名信用 senderLabel；其余用寄信人 NPC 名。
    final sign = sender?.name ?? def.senderLabel ?? '未知的寄信人';
    p.letterLastTurn = d.turnCount;
    if (sender != null) p.lastLetterSenderId = sender.id;
    if (def.onceOnly && !p.receivedLetters.contains(def.id)) {
      p.receivedLetters = List<String>.from(p.receivedLetters)..add(def.id);
    }
    if (def.replies.isNotEmpty) {
      p.pendingLetterId = def.id; // 进入「待回信」
    }
    // 结收入信效果。
    if (sender != null) {
      _applyLetterEffect(sender, def.effect, reason: '来信·${def.id}');
    } else {
      _applyLetterEffectAnonymous(def.effect, reason: '来信·${def.id}');
    }
    // 固化进存档信箱（/信 读 可回看）。
    _archiveLetter(sender: sign, def: def);

    final house = houseDisplayName(p.house ?? '', fallback: '霍格沃茨');
    final buf = StringBuffer();
    buf.writeln('———————🦉 猫头鹰来信 · $sign 🦉———————');
    buf.writeln(
        fillLetterText(def.scene, player: p.name, sender: sign, house: house));
    if (def.replies.isNotEmpty) {
      buf.writeln();
      buf.writeln('（信末留着一句等你回信的话——下一回合，你可以真正回一封。）');
    }
    return buf.toString().trim();
  }

  /// 机构/匿名信的效果结算（无好感维度，只给加隆/学院分/声望）。
  void _applyLetterEffectAnonymous(LetterEffect e, {required String reason}) {
    final p = d.player;
    if (p == null) return;
    if (e.galleons > 0) p.galleons += e.galleons;
    if (e.housePoints > 0) d.addHouseCupPoints(e.housePoints, reason);
    if (e.reputationDim != null && e.reputationValue != 0) {
      p.playerReputation.add(e.reputationDim!, e.reputationValue);
    }
  }

  /// 生成本回合「待回信」的专属选项。
  List<GameChoice> letterReplyChoicesForPending() {
    final id = d.player?.pendingLetterId;
    final def = id == null ? null : letterById(id);
    if (def == null || def.replies.isEmpty) return const [];
    return List<GameChoice>.generate(def.replies.length, (i) {
      return GameChoice(
        text: def.replies[i].title,
        action: '$kLetterActionPrefix${def.id}:$i',
      );
    });
  }

  /// 结算一封待回的信。action 形如 `信:<id>:<idx>`；不匹配时按中性兜底（中间项）。
  /// 返回需要追加进叙事的回信文块；无待回信时返回空串。
  String tryResolveLetterReplyChoice(String action) {
    final p = d.player;
    if (p == null) return '';
    final defId = p.pendingLetterId;
    if (defId == null) return '';
    final def = letterById(defId);
    if (def == null || def.replies.isEmpty) {
      p.pendingLetterId = null;
      return '';
    }
    // 落款：有 NPC 用 NPC；机构/匿名信用 senderLabel 兜底。
    final sender = _senderOf(def);
    final sign = sender?.name ?? def.senderLabel ?? '未知的寄信人';
    int? index;
    if (action.startsWith(kLetterActionPrefix)) {
      final parts = action.split(':');
      if (parts.length >= 3 && parts[1] == def.id) {
        index = int.tryParse(parts[2]);
        if (index != null && (index < 0 || index >= def.replies.length)) {
          index = null;
        }
      }
    }
    index ??= def.replies.length ~/ 2; // 中性兜底：中间项
    final reply = def.replies[index];
    if (sender != null) {
      _applyLetterEffect(sender, reply.effect, reason: '回信·${def.id}');
    } else {
      _applyLetterEffectAnonymous(reply.effect, reason: '回信·${def.id}');
    }
    // 社长邀请信：「好，我加入<社团>」选项 → 直接入社（复用 joinClub 链路，
    // 内部已含同好注入 A：入社即与 attendees 结谊 +5）。入社结果追加进回信文本。
    final clubJoinBuf = StringBuffer();
    if (def.clubId != null && p.clubId != def.clubId) {
      final title = reply.title;
      if (title.startsWith('好，我加入')) {
        final joined = d.joinClub(def.clubId!);
        clubJoinBuf.writeln();
        clubJoinBuf.writeln(joined);
      }
    }
    p.pendingLetterId = null;

    final house = houseDisplayName(p.house ?? '', fallback: '霍格沃茨');
    final buf = StringBuffer();
    buf.writeln('———————🦉 你的回信 · 给 $sign 🦉———————');
    buf.writeln('【你回信道】${reply.title}');
    buf.writeln(
        fillLetterText(reply.text, player: p.name, sender: sign, house: house));
    if (clubJoinBuf.isNotEmpty) {
      buf.write(clubJoinBuf.toString());
    }
    return buf.toString().trim();
  }

  void _applyLetterEffect(NPC sender, LetterEffect e,
      {required String reason}) {
    final p = d.player;
    if (p == null) return;
    if (e.senderAffection != 0) {
      d.updateNpcAffection(sender.id, e.senderAffection,
          reason: reason, quiet: true);
    }
    if (e.galleons > 0) p.galleons += e.galleons;
    if (e.housePoints > 0) d.addHouseCupPoints(e.housePoints, reason);
    if (e.reputationDim != null && e.reputationValue != 0) {
      p.playerReputation.add(e.reputationDim!, e.reputationValue);
    }
  }

  /// 把收到的信固化进存档信箱（容量 50 封，与 `/信` 读写共用）。
  void _archiveLetter({required String sender, required LetterDef def}) {
    final p = d.player;
    if (p == null) return;
    final house = houseDisplayName(p.house ?? '', fallback: '霍格沃茨');
    final content =
        '${_kindLabel(def.kind)}\n${fillLetterText(def.scene, player: p.name, sender: sender, house: house)}';
    p.letters.add(Letter(
      id: 'L${DateTime.now().microsecondsSinceEpoch}',
      sender: sender,
      content: content,
      date: d.formatDate(),
    ));
    if (p.letters.length > 50) {
      // 优先删最旧的已读；全未读则删最旧。
      final readIdx = p.letters.indexWhere((l) => l.read);
      if (readIdx >= 0) {
        p.letters.removeAt(readIdx);
      } else {
        p.letters.removeAt(0);
      }
    }
    d.notifications.add('📬 收到来自 $sender 的信');
  }

  String _kindLabel(LetterKind kind) {
    switch (kind) {
      case LetterKind.friendship:
        return '友情来信';
      case LetterKind.rivalry:
        return '敌对来信';
      case LetterKind.milestone:
        return '羁绊来信';
      case LetterKind.ministry:
        return '魔法部公函';
      case LetterKind.mystery:
        return '神秘来信';
      case LetterKind.reunion:
        return '旧友来信';
    }
  }
}
