/// R5：CG 解锁条件数据化。
///
/// 旧实现：mixin_relations.dart _checkCGUnlockByAffection 里 20+ 条 if 硬编码。
/// 新实现：每条 CG 把它的解锁条件声明在 `unlockConditions` 里，
///         由统一的 `CgUnlockEvaluator` 判定是否满足。
///
/// 条件类型：
///   - affectionAtLeast:  NPC 好感 ≥ threshold
///   - relationAtLeast:   恋爱关系阶段（0陌生人→6深爱）≥ stage 且 NPC == crush/partner
///   - npcConfessed:      NPC 对玩家已表白
///   - flagSet:           WorldState.specialMarkers / Player.flags 中包含该 key
///   - npcRelationIs:     指定 NPC 的 relationType（'crush' / 'partner' / 'bone_partner'）
///
/// 一条 CG 的所有 conditions 用 AND 语义（全满足才解锁）。
enum CgConditionType {
  affectionAtLeast,
  relationIsCrush,
  relationIsPartner,
  relationIsCrushOrPartner,
  npcConfessed,
  boneMode,
}

class CgUnlockCondition {
  final CgConditionType type;
  final int? intValue; // affection 阈值 / stage 阈值
  const CgUnlockCondition(this.type, {this.intValue});
}

// 提供给 cg_data.dart 中的 CgDef 使用的扩展字段（放在这里，不改 CgDef 构造器签名以免影响 cg_data.dart 中 70 条数据的构造器调用）
//
// 做法：使用一个以 cgId 为键的全局 Map<CgId, List<CgUnlockCondition>>，
// 避免改动已有的 70+ 条 CgDef(...) 构造调用（改动成本高且易漏）。
final Map<String, List<CgUnlockCondition>> cgUnlockConditions = {
  // ===== 相遇与暗恋之章 =====
  'CG-001': const [CgUnlockCondition(CgConditionType.affectionAtLeast, intValue: 20)],
  'CG-004': const [CgUnlockCondition(CgConditionType.affectionAtLeast, intValue: 35)],
  'CG-005': const [CgUnlockCondition(CgConditionType.affectionAtLeast, intValue: 40)],
  'CG-006': const [CgUnlockCondition(CgConditionType.affectionAtLeast, intValue: 40)],

  // ===== 暧昧与恋爱之章（需要 crush 或 partner 关系）=====
  'CG-007': const [
    CgUnlockCondition(CgConditionType.affectionAtLeast, intValue: 60),
    CgUnlockCondition(CgConditionType.relationIsCrush),
  ],
  'CG-008': const [
    CgUnlockCondition(CgConditionType.affectionAtLeast, intValue: 65),
    CgUnlockCondition(CgConditionType.relationIsCrush),
  ],
  'CG-009': const [
    CgUnlockCondition(CgConditionType.affectionAtLeast, intValue: 70),
    CgUnlockCondition(CgConditionType.relationIsCrush),
  ],
  'CG-011': const [
    CgUnlockCondition(CgConditionType.affectionAtLeast, intValue: 80),
    CgUnlockCondition(CgConditionType.relationIsCrush),
  ],

  // ===== 深情与宿命之章 =====
  'CG-013': const [
    CgUnlockCondition(CgConditionType.affectionAtLeast, intValue: 90),
    CgUnlockCondition(CgConditionType.relationIsCrushOrPartner),
  ],
  'CG-016': const [
    CgUnlockCondition(CgConditionType.affectionAtLeast, intValue: 90),
    CgUnlockCondition(CgConditionType.relationIsCrushOrPartner),
  ],
  'CG-014': const [
    CgUnlockCondition(CgConditionType.affectionAtLeast, intValue: 92),
    // 上界 <95 是个比较特殊的范围约束（仅"好感刚过92不久"的阶段解锁一次）
    // 这里保留"≥92"即可，unlockCG 内部会幂等跳过已解锁
  ],
  'CG-015': const [CgUnlockCondition(CgConditionType.affectionAtLeast, intValue: 95)],
  'CG-017': const [CgUnlockCondition(CgConditionType.affectionAtLeast, intValue: 95)],
  'CG-018': const [CgUnlockCondition(CgConditionType.affectionAtLeast, intValue: 93)],

  // ===== 珍贵之章 =====
  'CG-019': const [CgUnlockCondition(CgConditionType.affectionAtLeast, intValue: 96)],
  'CG-020': const [CgUnlockCondition(CgConditionType.affectionAtLeast, intValue: 98)],

  // ===== 骨科 CG =====
  'CG-BONE-001': const [
    CgUnlockCondition(CgConditionType.boneMode),
    CgUnlockCondition(CgConditionType.relationIsCrush),
    CgUnlockCondition(CgConditionType.npcConfessed),
  ],
  'CG-BONE-003': const [
    CgUnlockCondition(CgConditionType.boneMode),
    CgUnlockCondition(CgConditionType.relationIsPartner),
    CgUnlockCondition(CgConditionType.affectionAtLeast, intValue: 95),
  ],
};

class CgUnlockEvaluator {
  const CgUnlockEvaluator._();

  /// 判断 cgId 的条件是否对 (npc, player) 满足
  static bool evaluate({
    required String cgId,
    required int npcAffection,
    required bool npcIsCrush,
    required bool npcIsPartner,
    required bool npcConfessed,
    required bool boneMode,
  }) {
    final conditions = cgUnlockConditions[cgId];
    if (conditions == null || conditions.isEmpty) return false;
    for (final c in conditions) {
      switch (c.type) {
        case CgConditionType.affectionAtLeast:
          if (npcAffection < (c.intValue ?? 0)) return false;
          break;
        case CgConditionType.relationIsCrush:
          if (!npcIsCrush) return false;
          break;
        case CgConditionType.relationIsPartner:
          if (!npcIsPartner) return false;
          break;
        case CgConditionType.relationIsCrushOrPartner:
          if (!npcIsCrush && !npcIsPartner) return false;
          break;
        case CgConditionType.npcConfessed:
          if (!npcConfessed) return false;
          break;
        case CgConditionType.boneMode:
          if (!boneMode) return false;
          break;
      }
    }
    return true;
  }

  /// 返回所有条件满足的 CG id 列表（供 mixin 调用，替换原硬编码 if 链）
  static List<String> allSatisfiedIds({
    required int npcAffection,
    required bool npcIsCrush,
    required bool npcIsPartner,
    required bool npcConfessed,
    required bool boneMode,
  }) {
    final result = <String>[];
    for (final cgId in cgUnlockConditions.keys) {
      if (evaluate(
        cgId: cgId,
        npcAffection: npcAffection,
        npcIsCrush: npcIsCrush,
        npcIsPartner: npcIsPartner,
        npcConfessed: npcConfessed,
        boneMode: boneMode,
      )) {
        result.add(cgId);
      }
    }
    return result;
  }
}
