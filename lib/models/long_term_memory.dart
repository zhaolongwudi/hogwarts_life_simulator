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

  const OpenLoopRecord({
    required this.id,
    required this.description,
    required this.status,
    required this.importance,
    required this.openedAt,
    this.closedAt,
    this.npcIds = const {},
    this.loopType,
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
  double score(int currentDayOfYear) {
    // 从 timestamp 简单解析日做衰减 (更严谨的可以转 GameTime)
    final ageDays = _estimateAgeDays(timestamp);
    final factor = (1.0 - ageDays / 365.0).clamp(0.2, 1.0);
    return importance * factor;
  }

  static int _estimateAgeDays(String ts) {
    // timestamp 形如 "1991年9月2日 星期一 23:25"，做一个很粗略的解析算天数差
    // 这里只是近似估计，不影响主流程，若解析失败就返回0（当成新事件）
    try {
      final m = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(ts);
      if (m == null) return 0;
      final y = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final d = int.parse(m.group(3)!);
      return (y - 1991) * 365 + (mo - 1) * 30 + d;
    } catch (_) {
      return 0;
    }
  }
}

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
    // 超过上限则删 importance 最低的，但永远保留 importance >= 8 的
    if (list.length > maxKeyFacts) {
      list.sort((a, b) => b.importance.compareTo(a.importance));
      while (list.length > maxKeyFacts) {
        final last = list.length - 1;
        if (list[last].importance >= 8) break; // 不能删核心事实
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
      // 用 score 排序，删分数最低的 (永远不删 importance >= 8 的)
      list.sort((a, b) {
        // 拿当前日期做粗略衰减用 0 号即可，因为只是相对比较
        return b.score(0).compareTo(a.score(0));
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
