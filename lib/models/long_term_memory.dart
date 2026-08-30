import 'package:flutter/foundation.dart';

/// 千回合级结构化长期记忆银行
/// ==========================================================
/// 设计目标：即使游戏进行到 1,000 / 10,000 回合，核心事实也绝不丢失。
///
/// 核心原则：
///   1. 永远不要让 LLM "压缩 / 摘要"这里的结构化条目——摘要必然是有损的
///   2. 这里的每条记录是"纯事实 + 重要性打分"，由代码解析后写入
///   3. Prompt 注入时按 T0/T1/T2 分层，有 token 预算限制时优先保留高分条目
///
/// 分层说明 (prompt 注入顺序，靠前永不丢)：
///   T0 核心事实 (30 条上限，永不丢)：玩家身份、家族秘密、宠物血统等身份级事实
///   T1 未完结事项 (30 条上限)：承诺、债务、约定、未完成任务、悬而未决的问题
///   T2 NPC 关键关系 (每个 NPC 1 条，永不过期，注入时按 |affection| 排序取前 N)
///   T3 世界事件银行 (按重要性 * 新鲜度打分，注入时取前 20~40 条，可过期但永不删除)
/// ==========================================================

/// 纯事实记录 —— 永不压缩。例如：
///   "主角实际姓'天'，是神圣二十八族古老家族成员，对外并非波特家血脉"
///   "主角体内魔力空洞的本质是古老的'虚无'属性，可以从环境直接汲取魔力"
///   "主角宠物是九尾狐'绯月'，来自东方神话，可化人形，对主角完全忠诚"
class KeyFactRecord {
  final String id;        // 去重用 (uuid 或简短 slug)
  final String fact;      // 事实本身，第三人称、纯陈述语气、50字以内一行写完
  final int importance;   // 1~10，10=身份级核心事实(永不淘汰)，5=重要事件结论，1=日常琐事
  final String timestamp; // 写入时间 (GameTime.format)，用于追溯
  final String? category; // 可选分类：identity/pet/ability/secret/asset/other
  final Set<String> npcIds; // 涉及的NPC id，用于场景相关注入时加权

  const KeyFactRecord({
    required this.id,
    required this.fact,
    required this.importance,
    required this.timestamp,
    this.category,
    this.npcIds = const {},
  });

  KeyFactRecord copyWith({
    String? id,
    String? fact,
    int? importance,
    String? timestamp,
    String? category,
    Set<String>? npcIds,
  }) =>
      KeyFactRecord(
        id: id ?? this.id,
        fact: fact ?? this.fact,
        importance: importance ?? this.importance,
        timestamp: timestamp ?? this.timestamp,
        category: category ?? this.category,
        npcIds: npcIds ?? this.npcIds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fact': fact,
        'importance': importance,
        'timestamp': timestamp,
        'category': category,
        'npc_ids': npcIds.toList(),
      };

  /// 写入时间戳对应的绝对天数（自 1991-01-01），供同分事实的稳定排序用。
  /// 解析失败返回 0（按最早处理）。避免在注入/淘汰时重复解析正则。
  int get absoluteDay => _estimateAbsoluteDay(timestamp);

  factory KeyFactRecord.fromJson(Map<String, dynamic> json) => KeyFactRecord(
        id: json['id'] as String,
        fact: json['fact'] as String,
        importance: (json['importance'] as num?)?.toInt() ?? 5,
        timestamp: json['timestamp'] as String? ?? '',
        category: json['category'] as String?,
        npcIds: (json['npc_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ??
            const {},
      );
}

/// 未完结事项 —— 承诺、债务、约定、未完成任务、悬而未决问题
/// 这类东西如果丢了，剧情就会"说话不算话"，AI 会遗忘承诺过的事情。
/// 完结后把 status 改成 done，并保留一段时间做历史参考。
class OpenLoopRecord {
  final String id;
  final String description; // 比如 "斯内普答应为'虚无'属性保密，不向邓布利多汇报"
  final String status;      // open / done / dropped
  final int importance;     // 1~10
  final String openedAt;    // 起始时间戳
  final String? closedAt;   // 关闭时间戳
  final Set<String> npcIds; // 涉及NPC
  final String? loopType;   // promise/debt/quest/appointment/question/grudge
  /// 开启时的游戏回合数，用于计算「已悬而未决多少回合」的超期提醒。
  /// 旧存档没有该字段，读档时按 0 处理（视为很久以前开启）。
  final int openedTurn;

  const OpenLoopRecord({
    required this.id,
    required this.description,
    required this.status,
    required this.importance,
    required this.openedAt,
    this.closedAt,
    this.npcIds = const {},
    this.loopType,
    this.openedTurn = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'status': status,
        'importance': importance,
        'opened_at': openedAt,
        'closed_at': closedAt,
        'npc_ids': npcIds.toList(),
        'loop_type': loopType,
        'opened_turn': openedTurn,
      };

  factory OpenLoopRecord.fromJson(Map<String, dynamic> json) => OpenLoopRecord(
        id: json['id'] as String,
        description: json['description'] as String,
        status: (json['status'] as String?) ?? 'open',
        importance: (json['importance'] as num?)?.toInt() ?? 5,
        openedAt: json['opened_at'] as String? ?? '',
        closedAt: json['closed_at'] as String?,
        npcIds: (json['npc_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ??
            const {},
        loopType: json['loop_type'] as String?,
        openedTurn: (json['opened_turn'] as num?)?.toInt() ?? 0,
      );
}

/// NPC 关系核心档案 (每个 NPC 1 条，永不摘要压缩)
/// 替代"让 LLM 在摘要里记住和斯内普的关系"这种脆弱方法。
class NpcRelationshipAnchor {
  final String npcId;
  final String firstMeeting;      // 第一次见面时的关键事实 (永不删除)
  final List<String> keyMoments;  // 关键转折点 (最多8条，旧的不删，只取最新8条注入)
  final List<String> secretsShared; // 互相交换过的秘密 (永不删除，除非反水)
  final List<String> promisesExchanged; // 互相承诺的事 (可与OpenLoop重复，这里仅作为NPC维度索引)
  final String currentStage;       // 自由文本: 陌生/认识/普通朋友/好友/暧昧/情侣/敌对/师生/恩人 等
  final int lastUpdatedTurn;       // 最后一次更新的回合号，用于注入时新鲜度加权

  const NpcRelationshipAnchor({
    required this.npcId,
    required this.firstMeeting,
    this.keyMoments = const [],
    this.secretsShared = const [],
    this.promisesExchanged = const [],
    this.currentStage = '陌生',
    this.lastUpdatedTurn = 0,
  });

  NpcRelationshipAnchor copyWith({
    String? npcId,
    String? firstMeeting,
    List<String>? keyMoments,
    List<String>? secretsShared,
    List<String>? promisesExchanged,
    String? currentStage,
    int? lastUpdatedTurn,
  }) =>
      NpcRelationshipAnchor(
        npcId: npcId ?? this.npcId,
        firstMeeting: firstMeeting ?? this.firstMeeting,
        keyMoments: keyMoments ?? this.keyMoments,
        secretsShared: secretsShared ?? this.secretsShared,
        promisesExchanged: promisesExchanged ?? this.promisesExchanged,
        currentStage: currentStage ?? this.currentStage,
        lastUpdatedTurn: lastUpdatedTurn ?? this.lastUpdatedTurn,
      );

  Map<String, dynamic> toJson() => {
        'npc_id': npcId,
        'first_meeting': firstMeeting,
        'key_moments': keyMoments,
        'secrets_shared': secretsShared,
        'promises_exchanged': promisesExchanged,
        'current_stage': currentStage,
        'last_updated_turn': lastUpdatedTurn,
      };

  factory NpcRelationshipAnchor.fromJson(Map<String, dynamic> json) =>
      NpcRelationshipAnchor(
        npcId: json['npc_id'] as String,
        firstMeeting: json['first_meeting'] as String? ?? '',
        keyMoments: (json['key_moments'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        secretsShared: (json['secrets_shared'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        promisesExchanged: (json['promises_exchanged'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        currentStage: (json['current_stage'] as String?) ?? '陌生',
        lastUpdatedTurn:
            (json['last_updated_turn'] as num?)?.toInt() ?? 0,
      );
}

/// 世界事件银行 —— 每个事件结构化 + 重要性打分 + 时间戳 + 参与人
/// 即使有 1000 条，存储 JSON 也不过几 MB。
/// Prompt 注入时按 score = importance * recencyFactor(时间衰减) 取前 20~40 条。
class WorldEventRecord {
  final String id;
  final String timestamp;     // GameTime.format
  final String title;         // 短标题 10字以内
  final String description;   // 纯事实 60字以内
  final int importance;       // 1~10 (10=伏地魔回归，1=天气变化)
  final String category;      // ministry/hogwarts/economy/dark/wizarding/personal
  final Set<String> npcIds;   // 涉及NPC
  final String? location;     // 发生地点
  final List<String> consequences; // 已经产生的后续影响 (防止AI忘记因果链)

  const WorldEventRecord({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.description,
    required this.importance,
    required this.category,
    this.npcIds = const {},
    this.location,
    this.consequences = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp,
        'title': title,
        'description': description,
        'importance': importance,
        'category': category,
        'npc_ids': npcIds.toList(),
        'location': location,
        'consequences': consequences,
      };

  factory WorldEventRecord.fromJson(Map<String, dynamic> json) =>
      WorldEventRecord(
        id: json['id'] as String,
        timestamp: json['timestamp'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        importance: (json['importance'] as num?)?.toInt() ?? 3,
        category: (json['category'] as String?) ?? 'wizarding',
        npcIds: (json['npc_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ??
            const {},
        location: json['location'] as String?,
        consequences: (json['consequences'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );

  /// 事件的新鲜度加权分数：importance * (1 - ageDays/365) ，最低也保留 importance * 0.2
  /// currentAbsoluteDay = 当前游戏时间的绝对天数（自 1991-01-01 起），
  /// 与 GameTime.absoluteDayIndex 使用同一公式，保证衰减计算一致。
  double score(int currentAbsoluteDay) {
    final eventDay = _estimateAbsoluteDay(timestamp);
    final ageDays = currentAbsoluteDay - eventDay;
    final factor = (1.0 - ageDays / 365.0).clamp(0.2, 1.0);
    return importance * factor;
  }
}

/// 从 timestamp（形如 "📅 1991年9月2日 星期一 23:25"）解析出绝对天数
/// （自 1991-01-01 起），与 GameTime.absoluteDayIndex 使用同一公式。
///
/// 以前这里只算 `(y-1991)*365`，漏掉了 1991~y 之间的闰日：1993 年起差 1 天、
/// 1997 年起差 2 天，注释写着「保持一致」实际并不一致。现在改为闭式累计
/// 闰年数，与 GameTime.absoluteDayIndex 的逐闰年累计对齐。解析失败返回 0。
int _estimateAbsoluteDay(String ts) {
  try {
    final m = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(ts);
    if (m == null) return 0;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    int dayOfYear = d;
    for (int i = 1; i < mo; i++) {
      dayOfYear += days[i - 1];
    }
    if (mo > 2 && _isLeapYear(y)) {
      dayOfYear += 1;
    }
    // 1991..y-1 之间的闰年数（闭式：leapsBefore(n) = n/4 - n/100 + n/400）
    int leapsBefore(int yy) =>
        (yy - 1) ~/ 4 - (yy - 1) ~/ 100 + (yy - 1) ~/ 400;
    return (y - 1991) * 365 + (leapsBefore(y) - leapsBefore(1991)) + dayOfYear;
  } catch (_) {
    return 0;
  }
}

bool _isLeapYear(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

class LongTermMemory {
  final List<KeyFactRecord> keyFacts;          // T0
  final List<OpenLoopRecord> openLoops;        // T1
  final Map<String, NpcRelationshipAnchor> relationshipAnchors; // T2: npcId -> anchor
  final List<WorldEventRecord> worldEvents;    // T3

  LongTermMemory({
    this.keyFacts = const [],
    this.openLoops = const [],
    this.relationshipAnchors = const {},
    this.worldEvents = const [],
  });

  // ====== 写入 API ======
  LongTermMemory addKeyFact(KeyFactRecord record, {int maxKeyFacts = 100}) {
    // 先按 id 去重，若 importance 更高则覆盖
    final list = List<KeyFactRecord>.from(keyFacts);
    final existingIdx = list.indexWhere((r) => r.id == record.id);
    if (existingIdx >= 0) {
      final old = list[existingIdx];
      if (record.importance >= old.importance) {
        list[existingIdx] = record;
      }
    } else {
      list.add(record);
    }
    // 超过上限则淘汰，只给 10 分（身份级核心事实）永久豁免。
    //
    // 以前是「importance >= 8 永久豁免」：死亡/结婚/出生这类剧情事实由
    // importanceForFact 判成 9 分，永不淘汰，跑得越久记忆越臃肿；且排序键
    // 只有 importance，大量 9 分并列 + Dart 不稳定排序 → 「永不遗忘的核心
    // 事实」每回合换一批，玩家发现 AI 记住了莫名其妙的旧事、忘了刚发生的大事。
    //
    // 现在 9 分及以下按「重要性 × 新鲜度」打分（与 T3 世界事件同一套衰减），
    // 旧的自动提取事实会随时间让位给新的。排序仍要补稳定的次级键：Dart 的
    // List.sort 不保证稳定性，同分时按插入顺序倒序排（后写入靠前），
    // 淘汰从尾部砍，也就是优先保留近期发生的事。
    if (list.length > maxKeyFacts) {
      final now = _estimateAbsoluteDay(record.timestamp);
      double keepScore(KeyFactRecord r) {
        if (r.importance >= 10) return double.infinity;
        final day = _estimateAbsoluteDay(r.timestamp);
        // 缺时间戳（解析失败）不误杀：按全分保留
        if (day <= 0 || now <= 0) return r.importance * 1.0;
        final factor = (1.0 - (now - day) / 365.0).clamp(0.2, 1.0);
        return r.importance * factor;
      }

      final order = <KeyFactRecord, int>{
        for (var i = 0; i < list.length; i++) list[i]: i,
      };
      list.sort((a, b) {
        final c = keepScore(b).compareTo(keepScore(a));
        if (c != 0) return c;
        return (order[b] ?? 0).compareTo(order[a] ?? 0);
      });
      while (list.length > maxKeyFacts) {
        final last = list.length - 1;
        if (list[last].importance >= 10) break; // 身份级核心事实不删
        list.removeLast();
      }
    }
    return LongTermMemory(
      keyFacts: list,
      openLoops: openLoops,
      relationshipAnchors: relationshipAnchors,
      worldEvents: worldEvents,
    );
  }

  LongTermMemory addOrUpdateOpenLoop(OpenLoopRecord record, {int maxLoops = 100}) {
    final list = List<OpenLoopRecord>.from(openLoops);
    final idx = list.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      list[idx] = record;
    } else {
      list.add(record);
    }
    if (list.length > maxLoops) {
      // 优先保留 status=open 且 importance 高的
      list.sort((a, b) {
        final aScore = (a.status == 'open' ? 1000 : 0) + a.importance;
        final bScore = (b.status == 'open' ? 1000 : 0) + b.importance;
        return bScore.compareTo(aScore);
      });
      list.removeRange(maxLoops, list.length);
    }
    return LongTermMemory(
      keyFacts: keyFacts,
      openLoops: list,
      relationshipAnchors: relationshipAnchors,
      worldEvents: worldEvents,
    );
  }

  LongTermMemory upsertRelationshipAnchor(NpcRelationshipAnchor anchor) {
    final map = Map<String, NpcRelationshipAnchor>.from(relationshipAnchors);
    final existing = map[anchor.npcId];
    if (existing == null) {
      map[anchor.npcId] = anchor;
    } else {
      // 合并：保留旧 keyMoments 里不在新列表中的部分，新的追加到后面
      final mergedMoments = <String>[
        ...existing.keyMoments,
        ...anchor.keyMoments.where((m) => !existing.keyMoments.contains(m)),
      ];
      // 最多保留 12 条 keyMoments (太长也没用)，只留最新的
      final trimmed = mergedMoments.length > 12
          ? mergedMoments.sublist(mergedMoments.length - 12)
          : mergedMoments;
      map[anchor.npcId] = existing.copyWith(
        firstMeeting:
            anchor.firstMeeting.isNotEmpty ? anchor.firstMeeting : existing.firstMeeting,
        keyMoments: trimmed,
        secretsShared: <String>[
          ...existing.secretsShared,
          ...anchor.secretsShared
              .where((s) => !existing.secretsShared.contains(s)),
        ],
        promisesExchanged: <String>[
          ...existing.promisesExchanged,
          ...anchor.promisesExchanged
              .where((p) => !existing.promisesExchanged.contains(p)),
        ],
        currentStage:
            anchor.currentStage != '陌生' ? anchor.currentStage : existing.currentStage,
        lastUpdatedTurn: anchor.lastUpdatedTurn > existing.lastUpdatedTurn
            ? anchor.lastUpdatedTurn
            : existing.lastUpdatedTurn,
      );
    }
    return LongTermMemory(
      keyFacts: keyFacts,
      openLoops: openLoops,
      relationshipAnchors: map,
      worldEvents: worldEvents,
    );
  }

  LongTermMemory addWorldEvent(WorldEventRecord record, {int maxEvents = 500}) {
    final list = List<WorldEventRecord>.from(worldEvents);
    final idx = list.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      list[idx] = record;
    } else {
      list.add(record);
    }
    if (list.length > maxEvents) {
      // 用 score 排序，删分数最低的。
      // 以前淘汰路径用 score(0)：对 1991 年之后的任何事件 ageDays 恒为负，
      // 衰减因子被 clamp 恒吃成 1.0 → score ≡ importance，旧事件永不淘汰，
      // 500 条后全部同分，淘汰谁由不稳定排序决定——T3 退化成「化石库」。
      // 现在用新写入事件的时间戳当作「当前天」（写入即当前游戏时间），
      // 衰减真实生效：越旧的事件分数越低，自动让位给新的。
      final now = _estimateAbsoluteDay(record.timestamp);
      list.sort((a, b) {
        return b.score(now).compareTo(a.score(now));
      });
      while (list.length > maxEvents) {
        final last = list.length - 1;
        if (list[last].importance >= 8) break;
        list.removeLast();
      }
    }
    return LongTermMemory(
      keyFacts: keyFacts,
      openLoops: openLoops,
      relationshipAnchors: relationshipAnchors,
      worldEvents: list,
    );
  }

  // ====== 序列化 ======
  Map<String, dynamic> toJson() => {
        'key_facts': keyFacts.map((e) => e.toJson()).toList(),
        'open_loops': openLoops.map((e) => e.toJson()).toList(),
        'relationship_anchors':
            relationshipAnchors.map((k, v) => MapEntry(k, v.toJson())),
        'world_events': worldEvents.map((e) => e.toJson()).toList(),
      };

  factory LongTermMemory.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return LongTermMemory();
    }
    try {
      return LongTermMemory(
        keyFacts: (json['key_facts'] as List<dynamic>?)
                ?.map((e) => KeyFactRecord.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        openLoops: (json['open_loops'] as List<dynamic>?)
                ?.map((e) => OpenLoopRecord.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        relationshipAnchors: (json['relationship_anchors']
                    as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(
                    k,
                    NpcRelationshipAnchor.fromJson(
                        Map<String, dynamic>.from(v as Map)))) ??
            const {},
        worldEvents: (json['world_events'] as List<dynamic>?)
                ?.map((e) => WorldEventRecord.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
      );
    } catch (e) {
      // 迁移/损坏时宁可返回空记忆也不要让读档崩溃
      debugPrint('LongTermMemory.fromJson 失败: $e');
      return LongTermMemory();
    }
  }
}
