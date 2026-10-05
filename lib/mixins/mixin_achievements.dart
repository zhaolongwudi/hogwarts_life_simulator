/// 成就检查族（r7-5 拆分自 mixin_relations.dart）。
///
/// 覆盖：好感/CG/技能/世界线/战争英雄/探索/富豪/书虫/社交/羁绊/背叛/月度演化/
/// 世代画师/收集者/关系大师/时间大师共 16 个检查入口与 `checkAllAchievements`
/// 总调度。成就解锁本体 `unlockAchievement` 仍留在 [GameRelationsMixin]（全库
/// 10+ 个 mixin 调用，不宜随迁）。`GameRelationsMixin` 声明
/// `on GameAchievementsMixin`（跨 mixin 走 on 链，遵守 ADR-001）。行为零变化。
library;

import '../models/npc.dart';
import '../models/game_systems.dart';
import '../data/cg_data.dart';
import '../data/cg_unlock_conditions.dart';
import '../data/era_data.dart';
import '../data/attribute_data.dart';
import '../providers/game_provider_base.dart';

mixin GameAchievementsMixin on GameProviderBase {
  int get totalWealth {
    final p = player;
    if (p == null) return 0;
    return p.galleons + p.bankGalleons;
  }

  @override
  void unlockAchievement(String id) {
    final p = player;
    if (p == null) return;
    if (p.achievements.contains(id)) return;
    final ach = achievementCatalog.firstWhere(
      (a) => a.id == id,
      orElse: () => Achievement(id: id, name: id, description: ''),
    );
    p.achievements.add(id);
    notifications.add('🏆 解锁成就：${ach.name}');
    worldState.addNarrativeEvent('🏆 解锁成就：${ach.name}', turn: turnCount);
  }

  @override
  void checkAffectionAchievements(NPC npc) {
    // 门槛问好感阶段表要，不在代码里另写一个 20——描述写的是「关系达到
    // 好感」，阶段表的区间一改，成就跟着变，不会出现文案和判定对不上。
    if (npc.affection >= affectionStageMin('好感')) {
      unlockAchievement('first_friend');
    }
    checkCGUnlockByEvaluator(npc);
  }

  /// R5：好感→CG 解锁统一入口（由 CgUnlockEvaluator 做数据驱动判定）
  /// 旧实现：20+ 条 if 硬编码散在 `checkCGUnlockByAffection` 里；
  /// 新实现：新增 CG = 加 1 条 CgUnlockCondition，零代码改动。
  void checkCGUnlockByEvaluator(NPC npc) {
    final p = player;
    if (p == null) return;
    final aff = npc.affection;
    final isCrush = p.loveState.currentCrushName == npc.name;
    final isPartner = p.loveState.partnerId == npc.id;

    final cgIds = CgUnlockEvaluator.allSatisfiedIds(
      npcAffection: aff,
      npcIsCrush: isCrush,
      npcIsPartner: isPartner,
      npcConfessed: npc.confessed,
      boneMode: p.boneMode,
    );
    for (final cgId in cgIds) {
      unlockCG(cgById(cgId));
    }
  }

  @override
  void checkSkillAchievements() {
    final p = player;
    if (p == null) return;
    // 「优等生」判的是学业熟练度（课程表会提升的那几项属性）。
    //
    // 旧实现查的是 learnedSpells 的等级，而咒语等级当年只有一个写入点、
    // 且写进去就是 1，于是这条成就永远差 89 点。咒语系统补齐之后等级倒是
    // 能涨了，但成就名写的是「技能熟练度」，指的本来是课程属性，不该跟着
    // 咒语表走——两件事分清楚，各查各的。
    for (final key in kStudyAttributeKeys) {
      if ((p.attributes[key] ?? 0) >= 90) {
        unlockAchievement('honor_student');
        return;
      }
    }
  }

  @override
  void checkWorldChangerAchievement() {
    final p = player;
    if (p == null) return;
    // 双条件判据：玩家影响力(>=0.5) 与 世界线偏移(>=0.1) 同时满足才解锁
    // 防止只靠时间堆积或只改一条剧情线就拿成就——需要真正从 NPC 关系/原著事件/关键锚点三路都撼动世界
    if (p.worldLineDeviation >= 0.1 && worldState.playerImpactScore >= 0.5) {
      unlockAchievement('world_changer');
    }
  }

  @override
  void checkWarHeroAchievement() {
    final p = player;
    if (p == null) return;
    final combat = p.playerReputation.get('combat');
    if (combat >= 80) {
      unlockAchievement('war_hero');
    }
  }

  void _checkExplorerAchievement() {
    final p = player;
    if (p == null) return;
    // 记录当前地点到访问历史（若不同）
    final loc = worldState.currentLocation?.trim();
    if (loc != null && loc.isNotEmpty) {
      worldState.visitedLocations.add(loc);
    }
    if (worldState.visitedLocations.length >= 5) unlockAchievement('explorer');
  }

  void _checkRichWizardAchievement() {
    final p = player;
    if (p == null) return;
    // 小富翁=累计持有 ≥1500 加隆（player.dart默认500+节俭特质+100=约600开局）
    // 原门槛100完全无意义，500还是开局秒解——1500要求玩家通过打工/交易真正积累财富。
    if (totalWealth >= 1500) unlockAchievement('rich_wizard');
  }

  void _checkBookwormAchievement() {
    final p = player;
    if (p == null) return;
    if (p.learnedSpells.length >= 10) unlockAchievement('bookworm');
  }

  void _checkSocialButterflyAchievement() {
    final p = player;
    if (p == null) return;
    // 社交蝴蝶=真正结识过的NPC ≥ 10 位（introduced=true，必须剧情中正式见面/产生过互动）
    // 不再用"NPC总数≥10"——NPC注册表初始化就有几十个，开局秒解锁是bug。
    final friendCount = npcRegistry.values
        .where((n) => n.isAlive && n.introduced)
        .length;
    if (friendCount >= 10) unlockAchievement('social_butterfly');
  }

  void _checkDeepRelationshipAchievement() {
    for (final npc in npcRegistry.values) {
      if (npc.affection >= 80) {
        unlockAchievement('deep_relationship');
        return;
      }
    }
  }

  void _checkBetrayalSurvivorAchievement() {
    for (final npc in npcRegistry.values) {
      if (npc.hasGrudge && npc.affection > npc.maxAffectionReached * 0.8) {
        unlockAchievement('betrayal_survivor');
        return;
      }
    }
  }

  void _checkMonthlyEvolutionAchievement() {
    if (worldState.recentEvents
            .where((e) => e.text.contains('月度世界演化'))
            .length >=
        3) {
      unlockAchievement('monthly_evolution');
    }
  }

  void checkGenerationArtistAchievement() {
    final count = npcRegistry.values.where((n) => n.isGenerated).length;
    if (count >= 5) unlockAchievement('generation_artist');
  }

  void _checkCGCollectorAchievement() {
    final p = player;
    if (p == null) return;
    if (p.cgRecords.length >= 10) unlockAchievement('cg_collector');
  }

  void _checkRelationshipMasterAchievement() {
    final highAffectionCount = npcRegistry.values
        .where((n) => n.affection >= 60)
        .length;
    if (highAffectionCount >= 3) unlockAchievement('relationship_master');
  }

  void _checkTimeMasterAchievement() {
    // 修复：起始年份必须取自当前时代的 EraDef，不能硬编码 1991。
    // 旧实现导致 1892 时代永远无法解锁（年份差为负）、2020 时代开局即解锁。
    final startYear = eraDefByEra(appProvider.era).startYear;
    final currentYear = worldState.time.year;
    if (currentYear - startYear >= 2) unlockAchievement('time_master');
  }

  @override
  void checkAllAchievements() {
    checkSkillAchievements();
    checkWorldChangerAchievement();
    checkWarHeroAchievement();
    _checkExplorerAchievement();
    _checkRichWizardAchievement();
    _checkBookwormAchievement();
    _checkSocialButterflyAchievement();
    _checkDeepRelationshipAchievement();
    _checkBetrayalSurvivorAchievement();
    _checkMonthlyEvolutionAchievement();
    checkGenerationArtistAchievement();
    _checkCGCollectorAchievement();
    _checkRelationshipMasterAchievement();
    _checkTimeMasterAchievement();
  }
}
