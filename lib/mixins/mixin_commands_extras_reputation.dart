import '../data/exam_data.dart';
import '../models/game_systems.dart';
import 'mixin_commands.dart';

/// 指令格式化·声望与考试族（r10-5 拆分自 mixin_commands_extras.dart）。
///
/// 覆盖：恋爱声望 / NPC 声望档案 / 声望排行 / 考试记录等格式化输出。
mixin GameCommandsExtrasReputationMixin on GameCommandsMixin {
/// /声望 恋爱 —— 恋爱关系的声望影响明细
  String formatLoveReputation() {
    final p = player;
    if (p == null) return '尚未开始游戏。';
    final love = p.loveState;
    final buf = StringBuffer('【恋爱声望影响】（设定 13.3）\n');
    for (final e in loveReputationEffects) {
      buf.writeln(
        '· ${e.type}：${e.min >= 0 ? '+' : ''}${e.min} ~ ${e.max >= 0 ? '+' : ''}${e.max}',
      );
    }
    buf.writeln(
      '（多档可叠加，实际结算封顶 -30 ~ +10；'
      '同学院恋爱是唯一正向项，师生恋代价最重）',
    );
    // 当前关系的命中情况（partnerName / currentCrushName 用局部变量提升，
    // 避免「守卫与断言分离」——原来依赖 14 行外的 || 守卫给 ?? 兜底分支加 !）
    final partnerName = love.partnerName;
    final crushName = love.currentCrushName;
    if (partnerName != null || crushName != null) {
      final npcName = partnerName ?? crushName;
      if (npcName == null) return buf.toString();
      final npc = cheatFindNpc(npcName);
      if (npc != null) {
        final ctx = LovePairContext(
          playerHouse: p.house ?? '',
          npcHouse: npc.house,
          playerBlood: p.bloodType,
          npcBlood: npc.bloodStatus,
          npcIsStaff: npc.grade <= 0,
          playerStance: p.politicalTendency ?? '',
          npcBloodSupremacist: npc.bloodSupremacist,
        );
        buf.writeln();
        buf.writeln('【当前关系 · $npcName】');
        var hit = false;
        for (final e in loveReputationEffects) {
          if (loveEffectApplies(e, ctx)) {
            buf.writeln(
              '  ⚡ 命中「${e.type}」：${e.min >= 0 ? '+' : ''}${e.min} ~ ${e.max >= 0 ? '+' : ''}${e.max}',
            );
            hit = true;
          }
        }
        if (!hit) buf.writeln('  当前关系不触发任何声望惩罚。');
      }
    } else {
      buf.writeln('\n（当前单身，暂无关系判定。）');
    }
    return buf.toString();
  }

  /// /声望 NPC [名字] —— 指定 NPC 的声望档案
  String formatNpcReputation(String nameKey) {
    final npc = cheatFindNpc(nameKey);
    if (npc == null) {
      return '未找到NPC "$nameKey"。可用：${cheatAllNpcNames()}';
    }
    final r = npc.reputation;
    final buf = StringBuffer('【${npc.name} · 声望档案】\n');
    for (final dim in Reputation.dimensions) {
      final v = r.get(dim);
      buf.writeln('· ${r.labelOf(dim)}：$v（${reputationGrade(v)}）');
    }
    return buf.toString();
  }

  /// /声望 NPC 列表 —— 所有已认识 NPC 的声望摘要
  String formatNpcReputationList() {
    final buf = StringBuffer('【NPC声望摘要】（已登场）\n');
    final list = npcRegistry.values.where((n) => n.introduced).toList()
      ..sort((a, b) => b.reputation.social.compareTo(a.reputation.social));
    if (list.isEmpty) {
      buf.writeln('（还没有结识任何人。）');
      return buf.toString();
    }
    for (final n in list) {
      final r = n.reputation;
      buf.writeln(
        '· ${n.name}：学术${r.academic} 社交${r.social} 战斗${r.combat}'
        ' 道德${r.moral} 领导${r.leadership} 黑魔法${r.dark}',
      );
    }
    return buf.toString();
  }

  /// /声望 NPC 排名 [维度] —— 按指定维度排名
  String formatNpcReputationRanking(String dim) {
    final norm = dim.startsWith('黑') ? 'dark' : dim;
    final valid = Reputation.dimensions.contains(norm);
    if (!valid) {
      return '未知维度「$dim」。维度：academic(学术)、social(社交)、combat(战斗)、moral(道德)、leadership(领导)、dark(黑魔法)';
    }
    final list = npcRegistry.values.where((n) => n.introduced).toList()
      ..sort(
        (a, b) => b.reputation.get(norm).compareTo(a.reputation.get(norm)),
      );
    final label = list.isEmpty ? '' : list.first.reputation.labelOf(norm);
    final buf = StringBuffer('【$label · 排名】（已登场 ${list.length} 人）\n');
    for (var i = 0; i < list.length && i < 10; i++) {
      final n = list[i];
      buf.writeln('${i + 1}. ${n.name}：${n.reputation.get(norm)}');
    }
    return buf.toString();
  }

  // ==================== 人生目标系统 ====================

  /// 考试成绩单展示（/课程 成绩）
  String formatExamRecords() {
    final p = player;
    if (p == null) return '尚未开始游戏。';
    final records = p.examRecords;
    if (records.isEmpty) {
      return '【考试成绩】\n还没有任何考试成绩——学年结束时（9月升学年结算）会揭晓期末成绩，'
          '五年级末还有 O.W.L.，七年级末有 N.E.W.T.。\n\n'
          '平时上课（/课堂 互动）、学习魔咒、认真对待学业，都会让成绩变得更好看。';
    }
    final buf = StringBuffer('╔══════════════════════════════════════╗\n')
      ..writeln('  《学业成绩册》')
      ..writeln('╚══════════════════════════════════════╝');
    // 学年成绩
    for (var i = 1; i <= 7; i++) {
      final key = 'Y$i';
      final r = records[key];
      if (r == null) continue;
      final s = examSummary(r);
      buf.writeln();
      buf.writeln(
        '【第$i 学年期末】${s.oCount}O / ${s.eCount}E / ${s.aPlusCount} 及格以上',
      );
      buf.writeln(formatExamSheet(r));
    }
    // 大考
    for (final key in ['OWL', 'NEWT']) {
      final r = records[key];
      if (r == null) continue;
      final s = examSummary(r);
      buf.writeln();
      buf.writeln(
        '【${key == 'OWL' ? 'O.W.L. 普通巫师等级考试（五年级末）' : 'N.E.W.T. 终极巫师等级考试（七年级末）'}】'
        ' ${s.oCount}O / ${s.eCount}E / ${s.aPlusCount} 及格以上',
      );
      buf.writeln(formatExamSheet(r));
      if (s.oCount >= 3) {
        buf.writeln('🏅 这份成绩单足以叩开绝大多数高阶职业的大门。');
      } else if (s.aPlusCount >= 6) {
        buf.writeln('📖 稳健的成绩，多数常规职业都会接纳你。');
      } else {
        buf.writeln('⚠️ 成绩平平——部分要求苛刻的职业会对你关上大门。');
      }
    }
    return buf.toString();
  }
}
