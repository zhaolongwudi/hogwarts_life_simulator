/// 正典事件注入与叙事净化工具（r8-1 拆分自 mixin_narrative.dart）。
///
/// 覆盖：`injectCanonEventLocally`（分院仪式等原著节点在离线模式的
/// 本地注入，零 token）、`truncateNarrativeContext`、`factConflictsWithAuthority`
/// 与两条预编译正则。主干 [GameNarrativeMixin] 声明 `on GameNarrativeCanonMixin`
/// 后直接调用（跨 mixin 走 on 链，遵守 ADR-001）。行为零变化。
library;

import '../providers/game_provider_base.dart';
import '../data/canon_events.dart';
import '../models/story_progress.dart';
import '../data/pet_data.dart';
import '../utils/debug_log.dart';

mixin GameNarrativeCanonMixin on GameProviderBase {
  // ==================== 分院仪式（本地逻辑，不消耗 token） ====================
  void injectCanonEventLocally() {
    final p = player;
    if (p == null) return;

    final t = worldState.time;
    final due = dueCanonEvents(
      year: t.year,
      month: t.month,
      grade: p.grade ?? 1,
      era: worldState.era,
      firedIds: worldState.firedAnchorIds,
      limit: 1,
    );
    if (due.isEmpty) return;

    final event = due.first;

    // 【剧情模式白名单抑制（批次 5）】
    // 若当前剧情步的 canonRefId 正好声明讲述这条节点，就不再贴 📖 旁白块
    // ——那段原著由剧情文本讲述（有情境、分支与后果），重复贴块玩家会
    // 把同一件事读到两遍。`firedAnchorIds` 照写：节点视为已消费，
    // 之后任何路径都不会再对它注入。
    //
    // 【为什么是防御层】当前分发下，剧情模式的全部回合（含自由行动降级
    // 与结局后行动）都走 `_runStoryTurn`，本函数只被**沙盒模式**的离线
    // 回合调用，这段分支平时不会执行。它是给未来改动的保险：若有人把
    // 剧情回合重新接回普通离线回合，这里保证「已由剧情讲述」优先于
    // 「旁白注入」。防回归由 test/canon_story_dedup_test.dart 钉死。
    if (storyProgress.active) {
      final step = findStoryStep(
        storyProgress.bookId,
        storyProgress.chapterId,
        storyProgress.stepId,
      );
      if (step != null && step.canonRefId == event.id) {
        worldState.firedAnchorIds.add(event.id);
        lastCanonEventTitle = null;
        lastCanonEventDirective = null;
        debugLog(
          '📖 原著节点 ${event.id} 由剧情步 ${step.id} 讲述，跳过旁白注入',
        );
        return;
      }
    }

    worldState.firedAnchorIds.add(event.id);

    final block = '📖 ${event.title}\n${event.directive}';
    if (!currentNarrative.contains(event.title)) {
      currentNarrative = '$currentNarrative\n\n$block';
    }
    notifications.add('📖 ${event.title}');
    worldState.addNarrativeEvent('📖 ${event.title}', turn: turnCount);

    // 把刚触发的节点名记下来，供 buildFallbackChoices 生成「有针对性的选项」。
    // 为什么不在选项侧重新过滤一遍：buildFallbackChoices 拿不到「本回合
    // 触发的是哪条」，再跑一次 dueCanonEvents 会因为 id 已被写进
    // firedAnchorIds 而返回空。所以由触发方单向告知。
    lastCanonEventTitle = event.title;
    lastCanonEventDirective = event.directive;

    debugLog('📖 原著节点注入: ${event.id}（${event.bookRef}）');
  }

  String truncateNarrativeContext(String narrative, int maxChars) {
    if (narrative.length <= maxChars) return narrative;
    final cut = snapCutToBoundary(narrative, narrative.length - maxChars);
    return '…（前情略）${narrative.substring(cut)}';
  }

  /// 第16轮G：T0 核心事实与 Player 权威设定冲突检测（过滤历史错误摘要污染）。
  /// 保守匹配，只拦已知的硬冲突，避免误伤其他事实：
  ///  - 宠物物种错：玩家契约宠物是九尾灵狐，事实却写"猫头鹰绯月"
  ///  - 哈利特征张冠李戴：主角非哈利，事实却写"闪电形伤疤"
  bool factConflictsWithAuthority(String fact) {
    final p = player;
    if (p == null || fact.isEmpty) return false;
    final isHarry = p.name.toLowerCase() == '哈利' || p.name.contains('波特');
    // 宠物冲突：权威宠物是狐类，事实却写猫头鹰（绯月不是猫头鹰）
    if (p.petId != null && p.petId!.isNotEmpty) {
      final pd = petById(p.petId!);
      final species = pd?.species ?? '';
      if (species.contains('狐') && fact.contains('猫头鹰')) {
        return true;
      }
    }
    // 闪电形伤疤：哈利专属（主角的疤不是闪电形，家庭设定红线）
    if (!isHarry && fact.contains('闪电形') && fact.contains('伤疤')) {
      return true;
    }
    return false;
  }

  /// 命令分发切词（parseAction 每回合，预编译）。
  static final RegExp reWhitespaceNarrative = RegExp(r'\s+');

  /// 选项文本去前缀非正文噪声（processChoice 每回合，预编译）。
  static final RegExp reLeadingNonTextNarrative =
      RegExp(r'^[^\u4e00-\u9fa5A-Za-z]*');
}
