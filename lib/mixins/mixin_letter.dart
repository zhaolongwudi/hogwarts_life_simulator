/// P13 猫头鹰来信系统：让「世界那边的人」在离线日常里主动惦记你。
///
/// 【它解决什么问题】现有书信 `/信 寄 /信 读` 只能由**玩家主动**发起，NPC
/// 从不主动开口。本层让已结识的 NPC 在离线回合格外地寄来一封猫头鹰信——
/// 不是发任务，而是像身边真的有人惦记着你：午后的一封闲聊、大病初愈后的
/// 挂念、乃至对手不请自来的挑衅。它补上的是奇遇（发生在"你"身上的事）与
/// 羁绊（你与某人的一岀戏）之外的第三块拼图：
///
///   ① 友情来信（friendship）：由好感到位的朋友寄来，会重播，给一点好感；
///   ② 敌对来信（rivalry）：由对你有怨气的对手寄来，会挖苦，也是世界的真实一角；
///   ③ 羁绊里程碑来信（milestone）：好感跨过关键门槛各演一次（演过不重播）。
///
/// 部分来信带着托付与牵挂，会进入「待回信」：下一回合玩家可用专属选项真正
/// 回一封信，寄信人读罢再给你一段回应（两段式，口径对齐奇遇/羁绊）。
/// 每封来信都会固化为存档，可经 `/信 读` 回看。数据全在 `letter_data.dart`；
/// 本 mixin 只做「选信 + 落款 + 结算」三层事。
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/house_data.dart';
import '../data/letter_data.dart';
import '../models/game_systems.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';

/// P13 猫头鹰来信 mixin。挂在 [GameProviderBase] 上。
mixin GameLetterMixin on GameProviderBase {
  bool get _letterOn => appProvider.letterEnabled;

  /// 正待回的信 id。
  String? get pendingLetterId => player?.pendingLetterId;

  /// 是否有待回声的信。
  @override
  bool get hasPendingLetter => pendingLetterId != null;

  /// 最近一次收到来信的回合号（冷却用）。
  int get _letterLastTurn => player?.letterLastTurn ?? -1;

  /// 已送到的来信 id 集合（里程碑 once-only）。
  Set<String> get _received =>
      player?.receivedLetters.toSet() ?? const <String>{};

  /// 从已结识、在世、未毕业的 NPC 里解析这封信的落款人；无人可用返回 null。
  ///
  /// 指定了 [LetterDef.senderId] 的必须就是这位（且已结识）；未指定时：
  ///  - friendship/milestone：选好感最高、且不低于该信 minAffection 的朋友；
  ///  - rivalry：选怨气最重的对手（好感不高于 maxAffection）。
  ///  - reunion：好感达标且**已毕业**的旧友（毕业后仍可来信）。
  /// 尽量避开上一位寄信人，免得同一人连番刷屏。
  /// 机构/匿名信（`senderLabel` 非空）不查 NPC pool，直接返回 null 由上层走哨兵。
  @visibleForTesting
  NPC? letterSenderFor(LetterDef def) {
    if (def.senderLabel != null) return null; // 机构/匿名信：无需 NPC 落款
    final base = npcRegistry.values.where((n) => n.introduced && n.isAlive);
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
    final day = worldState.time.absoluteDayIndex;
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
    final last = player?.lastLetterSenderId;
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
    final id = player?.lastLetterSenderId;
    if (id != null) return npcRegistry[id];
    return null;
  }

  /// 命中一封本回合要寄来的信；无法收到返回空串并交付文本。
  ///
  /// 优先级：① 未收到且可落款的**最高门槛**里程碑来信（once、先补齐）;
  /// ② 否则在可落款的友情来信里随机一封（好感到位便有）；③ 否则敌对来信。
  /// 全程受开关/冷却/互斥门控。
  @override
  String maybeTriggerLetter({int? seed}) {
    if (!_letterOn) return '';
    final p = player;
    if (p == null) return '';
    // 有在等的奇遇/羁绊/回信先处理完，不让新信抢戏。
    if (hasPendingHappenstance) return '';
    if (hasPendingCompanionClimax) return '';
    if (hasPendingLetter) return '';
    // 冷却：猫头鹰不会天天扑腾。
    if (turnCount - _letterLastTurn < kLetterCooldownTurns) return '';

    final rnd = Random(seed ?? turnCount);
    final received = _received;

    // 1) 未收里程碑：门槛越高越优先（先把重要的缘分补上）。
    final milestones = kLetters
        .where((l) => l.kind == LetterKind.milestone && !received.contains(l.id))
        .toList()
      ..sort((a, b) => b.minAffection.compareTo(a.minAffection));
    for (final l in milestones) {
      final sender = letterSenderFor(l);
      if (sender != null) return _deliver(p, l, sender);
    }

    // 2) 魔法部公函：未收过的机构信，按学期节点低频投递（不抢羁绊缘分）。
    final ministries = kLetters
        .where((l) => l.kind == LetterKind.ministry && !received.contains(l.id))
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

    // 4) 友情来信：随机一封可落款的（会重播，靠好感门槛兜手感）。
    final friends = kLetters.where((l) => l.kind == LetterKind.friendship).toList()
      ..shuffle(rnd);
    for (final l in friends) {
      final sender = letterSenderFor(l);
      if (sender != null) return _deliver(p, l, sender);
    }

    // 5) 毕业旧友重联：有已毕业 NPC 在时随机一封（靠冷却兜手感）。
    final reunions = kLetters.where((l) => l.kind == LetterKind.reunion).toList()
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
    p.letterLastTurn = turnCount;
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
    final p = player;
    if (p == null) return;
    if (e.galleons > 0) p.galleons += e.galleons;
    if (e.housePoints > 0) addHouseCupPoints(e.housePoints, reason);
    if (e.reputationDim != null && e.reputationValue != 0) {
      p.playerReputation.add(e.reputationDim!, e.reputationValue);
    }
  }

  /// 生成本回合「待回信」的专属选项。
  @override
  List<GameChoice> letterReplyChoicesForPending() {
    final id = player?.pendingLetterId;
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
  @override
  String tryResolveLetterReplyChoice(String action) {
    final p = player;
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
    p.pendingLetterId = null;

    final house = houseDisplayName(p.house ?? '', fallback: '霍格沃茨');
    final buf = StringBuffer();
    buf.writeln('———————🦉 你的回信 · 给 $sign 🦉———————');
    buf.writeln('【你回信道】${reply.title}');
    buf.writeln(
        fillLetterText(reply.text, player: p.name, sender: sign, house: house));
    return buf.toString().trim();
  }

  void _applyLetterEffect(NPC sender, LetterEffect e, {required String reason}) {
    final p = player;
    if (p == null) return;
    if (e.senderAffection != 0) {
      updateNpcAffection(sender.id, e.senderAffection, reason: reason, quiet: true);
    }
    if (e.galleons > 0) p.galleons += e.galleons;
    if (e.housePoints > 0) addHouseCupPoints(e.housePoints, reason);
    if (e.reputationDim != null && e.reputationValue != 0) {
      p.playerReputation.add(e.reputationDim!, e.reputationValue);
    }
  }

  /// 把收到的信固化进存档信箱（容量 50 封，与 `/信` 读写共用）。
  void _archiveLetter({required String sender, required LetterDef def}) {
    final p = player;
    if (p == null) return;
    final house = houseDisplayName(p.house ?? '', fallback: '霍格沃茨');
    final content =
        '${_kindLabel(def.kind)}\n${fillLetterText(def.scene, player: p.name, sender: sender, house: house)}';
    p.letters.add(Letter(
      id: 'L${DateTime.now().microsecondsSinceEpoch}',
      sender: sender,
      content: content,
      date: worldState.time.formatDate(),
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
    notifications.add('📬 收到来自 $sender 的信');
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