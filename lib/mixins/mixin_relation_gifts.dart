/// 送礼与室友子系统（阶段 r4-2 拆分自 mixin_relations.dart）。
///
/// 【拆分说明】好感调整（adjustAffection / syncRelationshipLevel）、送礼
/// （giveGift，礼物判定走 gift_rules）、室友系统（roommates /
/// ensureRoommateNpcs / 面板 / 聊天 / 早起）约 245 行，从 2635 行的
/// mixin_relations 迁入本文件。GameRelationsMixin 声明
/// on GameRelationGiftsMixin（跨 mixin 走 on 链，遵守 ADR-001），
/// GameProvider 的 with 列表中 gifts 在 relations 之前。
/// 行为零变化：所有成员仍是 GameProvider 上的实例成员，测试契约不变。
library;


import '../models/npc.dart';
import '../data/gift_rules.dart';
import '../data/house_data.dart';
import '../data/locations.dart';
import '../utils/npc_lookup.dart';
import '../utils/inventory_ops.dart';
import '../data/item_data.dart';
import '../providers/game_provider_base.dart';

/// 好感调整 / 送礼 / 室友系统。挂在 [GameProviderBase] 上。
mixin GameRelationGiftsMixin on GameProviderBase {

  // ==================== 时间推进 ====================

  void adjustAffection(String npcId, int delta, {String? reason}) {
    updateNpcAffection(npcId, delta, reason: reason);
    final npc = npcRegistry[npcId];
    if (npc != null) {
      checkLocks(npc);
      syncRelationshipLevel(npc);
    }
  }

  @override
  void syncRelationshipLevel(NPC npc) {
    final p = player;
    if (p == null) return;
    final rel = p.relationships[npc.id];
    if (rel != null) {
      // 好感度的量程是 −100~+100（记恨会打成负数），这里若截到 0~100，
      // 「/查看」里就会出现「Lv.0 ｜ 好感 −40（反感）」这样自相矛盾的显示。
      rel.level = npc.affection.clamp(-100, 100);
    }
  }

  // ==================== 送礼 ====================

  /// 把背包里的一件东西送给某位 NPC。
  ///
  /// giftPrefs 数据此前被生成、被存档，却从没被读过——送礼只是被动好感
  /// 推断里的一个关键词（+1~+2），送什么完全不影响结果。这里把它接上。
  @override
  String giveGift(String npcKeyword, String itemName) {
    final p = player;
    if (p == null) return '你还没有开始游戏。';

    final kw = npcKeyword.trim();
    final gift = itemName.trim();
    if (kw.isEmpty || gift.isEmpty) {
      return '【送礼】\n用法：/送礼 [名字] [物品]，例如 /送礼 赫敏 旧书\n'
          '（只写名字则列出对方可能喜欢的东西）';
    }

    final npc = findNpcByKeyword(npcRegistry.values, kw);
    if (npc == null) {
      return '【送礼】\n你不认识叫「$kw」的人。';
    }
    // P2#13：死人收不了礼——法则五要求死亡有实感，而不是假装没发生
    if (!npc.isAlive) {
      return '【送礼】\n${npc.name}已经无法收下你的礼物了……';
    }

    // 只写名字：给个提示，不消耗任何东西
    if (!hasItem(p.inventory, gift)) {
      final owned = p.inventory
          .where(
            (e) =>
                itemDefByName(e.name)?.type == '礼物' ||
                itemDefByName(e.name)?.type == '材料',
          )
          .map((e) => e.name)
          .toSet()
          .toList();
      final buf = StringBuffer('【送礼 · ${npc.name}】\n');
      if (gift.isEmpty) {
        buf.writeln('你想送点什么？');
      } else {
        buf.writeln('你身上没有「$gift」。');
      }
      if (owned.isEmpty) {
        buf.writeln('你身上没有任何能拿得出手的东西——去对角巷转转吧。');
      } else {
        buf.writeln('你身上有：${owned.join('、')}');
      }
      return buf.toString().trimRight();
    }

    final verdict = evaluateGift(npc.giftPrefs, gift);
    final delta =
        verdict.minGain + random.nextInt(verdict.maxGain - verdict.minGain + 1);

    removeOneItem(p.inventory, gift);
    adjustAffection(npc.id, delta, reason: verdict.ruleName);

    final buf = StringBuffer('【送礼 · ${npc.name}】\n');
    switch (verdict.reaction) {
      case GiftReaction.beloved:
        buf.writeln(
          '你把$gift递过去。${npc.name}愣了一下，随即笑得很亮：'
          '「你怎么知道我想要这个？」',
        );
        buf.writeln('（${verdict.ruleName}，好感 +$delta → ${npc.affection}）');
      case GiftReaction.liked:
        buf.writeln(
          '${npc.name}把$gift翻来覆去看了两遍，收进袍子口袋：'
          '「挺合我心意的，谢了。」',
        );
        buf.writeln('（${verdict.ruleName}，好感 +$delta → ${npc.affection}）');
      case GiftReaction.neutral:
        buf.writeln(
          '${npc.name}道了谢，把$gift随手搁在一边——'
          '不算讨厌，也说不上喜欢。',
        );
        buf.writeln('（${verdict.ruleName}，好感 +$delta → ${npc.affection}）');
      case GiftReaction.unknown:
        buf.writeln(
          '${npc.name}礼貌地收下$gift，但你没看出他有多高兴。'
          '也许该换一样试试。',
        );
        buf.writeln('（好感 +$delta → ${npc.affection}）');
        final wishes = topWishes(npc.giftPrefs, limit: 2);
        if (wishes.isNotEmpty) {
          buf.writeln('（听说${npc.name}更中意这类东西：${wishes.join('、')}）');
        }
    }
    return buf.toString().trimRight();
  }

  // ==================== 室友系统（框架2 §31 · 批次C 逻辑层） ====================
  /// 当前玩家的 dormId（惰性推导）：玩家学院 + 性别 → 宿舍标识。
  /// 老档缺省 null → 首次进宿舍时由 [ensureRoommateNpcs] 赋值。
  String? get playerDormId {
    final p = player;
    if (p == null || p.house == null) return null;
    final houseKey = normalizeHouseKey(p.house!);
    if (houseKey == null) return null;
    final genderKey = (p.gender == '男') ? 'boys' : 'girls';
    // dormId 统一小写（'gryffindor_boys'）：与 _generateRoommateNpc 的
    // switch 小写 houseKey、测试预置 NPC 的小写 dormId 保持同一套格式。
    return '${houseKey.toLowerCase()}_$genderKey';
  }

  /// 同 dormId 的 NPC 即「室友」（不含玩家自己）。
  @override
  List<NPC> roommates() {
    final did = playerDormId;
    if (did == null) return const [];
    return npcRegistry.values
        .where((n) => n.dormId == did && n.isAlive && !n.graduated)
        .toList();
  }

  /// 入舍时惰性补室友：首次进入宿舍（player.dormId 为空）时，
  /// 按玩家学院+性别生成 1~2 位同宿舍 NPC 并赋 dormId。
  /// 复用 isGenerated 现成链路（老档零迁移，进宿舍才触发）。
  @override
  void ensureRoommateNpcs() {
    final p = player;
    if (p == null) return;
    final did = playerDormId;
    if (did == null) return;
    p.dormId = did;
    final existing = roommates();
    if (existing.isNotEmpty) return; // 已有室友，不再补
    final count = random.nextInt(2) + 1; // 1~2 位
    for (var i = 0; i < count; i++) {
      final npc = _generateRoommateNpc(did);
      if (npc != null) {
        npcRegistry[npc.id] = npc;
      }
    }
    currentNarrative =
        '🛏️ 你回到宿舍，认识了新室友：${roommates().map((n) => n.name).join('、')}。';
    notifyListeners();
  }

  /// 生成一位同宿舍的生成 NPC（室友）。
  NPC? _generateRoommateNpc(String did) {
    final p = player;
    if (p == null) return null;
    final isMale = did.endsWith('_boys');
    final givenNames = isMale
        ? ['西奥多', '塞巴斯蒂安', '艾德里安', '卡斯珀', '伊万', '诺亚', '奥利弗', '利奥', '马库斯', '朱利安', '塞缪尔', '内森']
        : ['塞西莉亚', '艾拉', '薇奥拉', '罗莎琳', '埃洛伊斯', '伊莎贝拉', '莉莉安', '海伦娜', '卡珊德拉', '奥利维亚', '克洛伊', '斯嘉丽'];
    final surnames = [
      '布莱克', '隆巴顿', '洛夫古德', '迪戈里', '波特', '马尔福', '沙比尼',
      '韦斯莱', '克鲁姆', '安德森', '塞尔温', '罗斯', '阿什福德', '格雷',
    ];
    final houseKey = did.split('_').first;
    final houseLabel = switch (houseKey) {
      'gryffindor' => '格兰芬多',
      'slytherin' => '斯莱特林',
      'ravenclaw' => '拉文克劳',
      'hufflepuff' => '赫奇帕奇',
      _ => '霍格沃茨',
    };
    final name = '${givenNames[random.nextInt(givenNames.length)]}·${surnames[random.nextInt(surnames.length)]}';
    final id =
        'roommate_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(100000)}';
    final gender = isMale ? '男' : '女';
    final npc = NPC(
      id: id,
      name: name,
      gender: gender,
      house: houseKey,
      grade: p.grade ?? 1,
      dormId: did,
      currentLocation: kDormLocation,
      isGenerated: true,
      introduced: true,
      affection: 30, // 室友起步好感略高于路人
      personality: isMale
          ? ['直率', '热情', '幽默']
          : ['温柔', '体贴', '细腻'],
      appearance: isMale ? '高挑，笑容明亮' : '清秀，眼神温和',
      generatedProfile: '$houseLabel·室友｜与你同宿舍同年级',
    );
    return npc;
  }

  /// /室友 列表：显示同宿舍室友 + 好感/状态。
  @override
  String formatRoommatePanel() {
    final rm = roommates();
    if (rm.isEmpty) {
      return '🛏️ 你还没有室友。回宿舍一趟，会遇见同宿舍的同学。';
    }
    final buf = StringBuffer('🛏️ 你的室友（${rm.length} 位）：\n');
    for (final n in rm) {
      buf.writeln('· ${n.name}｜好感 ${n.affection}｜${n.affectionStage}');
    }
    buf.writeln('\n/室友 聊天 和室友聊聊｜/室友 早起 让室友叫你起床');
    return buf.toString().trimRight();
  }

  /// /室友 聊天：随机一段深夜小剧场，好感 +1（冷却 3 回合）。
  @override
  String roommateChat() {
    final rm = roommates();
    if (rm.isEmpty) return '你还没有室友，回宿舍先认识一下吧。';
    final npc = rm[random.nextInt(rm.length)];
    final sinceLast = turnCount - lastRoommateChatTurn;
    if (lastRoommateChatTurn != -1 && sinceLast < 3) {
      return '你们刚聊过不久（冷却中，再等 ${3 - sinceLast} 回合）。';
    }
    lastRoommateChatTurn = turnCount;
    updateNpcAffection(npc.id, 1, reason: '室友聊天');
    final lines = [
      '你和${npc.name}窝在各自的床上，有一搭没一搭地聊着最近的课业。',
      '熄灯后${npc.name}压低声音，和你分享今天走廊上听到的八卦。',
      '${npc.name}翻了个身，问你周末要不要一起去霍格莫德。',
      '你们聊到很晚，${npc.name}说起自己暑假里的趣事，笑得停不下来。',
    ];
    final line = lines[random.nextInt(lines.length)];
    currentNarrative = '💬 $line\n（与${npc.name}好感 +1）';
    return currentNarrative;
  }

  /// /室友 早起：室友催起（概率性），早起 +1 精力。
  @override
  String roommateWakeUp() {
    final rm = roommates();
    if (rm.isEmpty) return '你还没有室友，回宿舍先认识一下吧。';
    final npc = rm[random.nextInt(rm.length)];
    final p = player;
    if (random.nextDouble() < 0.5) {
      if (p != null) {
        updateNpcAffection(npc.id, 1, reason: '室友早起互动');
        p.energy = p.energy < 100 ? p.energy + 1 : 100;
      }
      currentNarrative =
          '🌅 ${npc.name}一把掀开你的被子：「再不起来要赶不上早餐了！」'
          '\n你被拽起来，精神好了些。（精力 +1，${npc.name}好感 +1）';
    } else {
      currentNarrative =
          '🌅 你其实早就醒了，${npc.name}打着哈欠说：「起这么早，难得。」';
    }
    return currentNarrative;
  }
}
