/// 学年主线：升年级、考试结算、毕业与教职（r7-4 拆分自 mixin_systems.dart）。
///
/// 【拆分说明】学年推进（`_checkSchoolYearTransition`）、年级晋升（`_promoteNpcs` /
/// `_onSchoolYearStart`）、O.W.L./N.E.W.T. 考试结算（`_settleExams`）、毕业结算
/// （`_settleGraduation`）与教职线（教师好感 / 校长 / 教职邀约 / 教职年度结算）
/// 从 2250 行的 mixin_systems 迁入本文件。
/// `GameSystemsMixin` 声明 `on GameAcademicYearMixin`（跨 mixin 走 on 链，遵守
/// ADR-001），`GameProvider` 的 with 列表中 academic_year 在 systems 之前。
/// 行为零变化：所有成员仍是 GameProvider 上的实例成员，测试契约不变。
library;

import '../models/game_systems.dart';
import '../data/monthly_event_data.dart';
import '../data/ending_review_data.dart';
import '../data/balance_constants.dart';
import '../data/goal_data.dart';
import '../data/exam_data.dart';
import '../data/faculty_data.dart';
import '../providers/game_provider_base.dart';
import '../utils/debug_log.dart';
import 'mixin_game_save.dart';

mixin GameAcademicYearMixin on GameProviderBase, GameSaveSystemMixin {
  bool _facultyOfferPending = false;

  /// 教职邀约是否待决（UI 用）
  @override
  bool get pendingFacultyOffer => _facultyOfferPending;

  List<(String, bool)> evaluateGoalRequirement(GoalRequirement req) {
    final p = player;
    if (p == null) return [];
    final lines = <(String, bool)>[];
    if (req.reputationDim != null) {
      final cur = p.playerReputation.get(req.reputationDim!);
      lines.add((
        '${p.playerReputation.labelOf(req.reputationDim!)} ≥ ${req.reputationMin}（当前 $cur）',
        cur >= req.reputationMin,
      ));
    }
    if (req.attributeKey != null) {
      final cur = p.attributes[req.attributeKey!] ?? 0;
      lines.add((
        '${attrLabel(req.attributeKey!)} ≥ ${req.attributeMin}（当前 $cur）',
        cur >= req.attributeMin,
      ));
    }
    if (req.wealthMin > 0) {
      final cur = p.galleons + p.bankGalleons;
      lines.add(('资产 ≥ ${req.wealthMin} 加隆（当前 $cur）', cur >= req.wealthMin));
    }
    if (req.deepRelationsMin > 0) {
      final cur = npcRegistry.values
          .where((n) => n.isAlive && n.affection >= 50)
          .length;
      lines.add((
        '深厚羁绊（好感≥50）≥ ${req.deepRelationsMin} 人（当前 $cur）',
        cur >= req.deepRelationsMin,
      ));
    }
    if (req.worldLineMin > 0) {
      final cur = p.worldLineDeviation;
      lines.add((
        '世界线变动率 ≥ ${(req.worldLineMin * 100).toStringAsFixed(0)}%（当前 ${(cur * 100).toStringAsFixed(1)}%）',
        cur >= req.worldLineMin,
      ));
    }
    return lines;
  }

  int _schoolYearStartFor(int year, int month) {
    return month >= 9 ? year : year - 1;
  }

  /// 学年切换检测：当进入新的学年（9月）时，推进玩家与 NPC 年级

  void checkSchoolYearTransition(int oldMonth, int oldYear) {
    final p = player;
    if (p == null) return;
    final t = worldState.time;

    final newStart = _schoolYearStartFor(t.year, t.month);
    if (lastSchoolYearStart == 0) {
      // 首次初始化追踪（不触发晋升）
      lastSchoolYearStart = newStart;
      return;
    }
    if (newStart <= lastSchoolYearStart) return;

    // 跨越了一个或多个学年
    final yearsPassed = newStart - lastSchoolYearStart;
    lastSchoolYearStart = newStart;

    // 玩家已毕业则不再推进年级，但教职与正式职业要照常走年结：
    // 任教年限、年薪、晋升考核都挂在九月这个节点上。
    if (worldState.graduated) {
      _settleFacultyYear(yearsPassed);
      settleCareerYear(yearsPassed);
      updateAcademicYearLabel();
      return;
    }

    final oldGrade = p.grade ?? 1;
    final newGrade = oldGrade + yearsPassed;

    if (newGrade > 7) {
      // 毕业
      // 先结算最后一学年的学院杯：原本这条分支直接毕业，导致七年级全年
      // 攒下的 houseCupPoints 永不结算、永不清零，house_cup_winner 成就
      // 在最后一年也无法达成。同届 NPC 同样需要走一次晋升/毕业。
      _promoteNpcs(yearsPassed);
      settleHouseCup();
      p.grade = 7;
      // 七年级末的 N.E.W.T（终极巫师等级考试）与最后一次期末考
      _settleExams('Y7');
      _settleExams('NEWT', newt: true);
      onPlayerGraduated(oldGrade);
    } else {
      p.grade = newGrade;
      _promoteNpcs(yearsPassed);
      _onSchoolYearStart(newGrade);
    }
    updateAcademicYearLabel();
  }

  /// 更新学年标签（如 1992-1993）

  @override
  void updateAcademicYearLabel() {
    final t = worldState.time;
    final start = _schoolYearStartFor(t.year, t.month);
    worldState.academicYear = '$start-${start + 1}';
    // 学期：9-12月第一学期，1-6月第二学期，7-8月暑假
    if (t.month >= 9) {
      worldState.term = 'first';
    } else if (t.month <= 6) {
      worldState.term = 'second';
    } else {
      worldState.term = 'summer';
    }
  }

  /// 推进所有在校生 NPC 年级，七年级以上者毕业离校

  void _promoteNpcs(int yearsPassed) {
    final graduatedNames = <String>[];
    for (final npc in npcRegistry.values) {
      if (npc.grade <= 0) continue; // 教职/成人不推进
      if (npc.graduated) continue;
      npc.grade += yearsPassed;
      if (npc.grade > 7) {
        npc.graduated = true;
        npc.grade = 7;
        graduatedNames.add(npc.name);
      }
    }
    if (graduatedNames.isNotEmpty) {
      notifications.add(
        '🎓 ${graduatedNames.take(5).join('、')}${graduatedNames.length > 5 ? '等' : ''} 已从霍格沃茨毕业',
      );
      worldState.addNarrativeEvent(
        '🎓 一批高年级学生毕业了：${graduatedNames.take(5).join('、')}',
        turn: turnCount,
      );
    }
  }

  /// 新学年开始的叙事与通知

  void _onSchoolYearStart(int newGrade) {
    final p = player;
    if (p == null) return;
    // 学年结算：上一学年的学院杯排名揭晓（只结算有贡献的玩家）
    settleHouseCup();
    notifications.add('🏫 新学年开始：你升入了$newGrade年级');

    // ====== 期末考试成绩结算（框架2 第60条：考试真实存在） ======
    // 上一学年末的期末考成绩此时揭晓。成绩由平时熟练度主导，
    // 全科优秀的概率极低——差生不会因为过了一个暑假就变天才。
    _settleExams('Y${newGrade - 1}');
    if (newGrade == 6) {
      // 五年级末的 O.W.L（普通巫师等级考试）
      _settleExams('OWL', owl: true);
    }

    // ====== 学年里程碑：注入学年特有的事件叙事 ======
    {
      final milestoneText = schoolYearEventText(newGrade, seed: turnCount);
      if (milestoneText != null) {
        notifications.add('📜 $milestoneText');
        worldState.addNarrativeEvent(
          '📜 第$newGrade学年里程碑：$milestoneText',
          turn: turnCount,
        );
      }
    }

    worldState.addNarrativeEvent(
      '🏫 ${worldState.time.year}年9月，你升入$newGrade年级',
      turn: turnCount,
    );
    worldState.addMarker('⏳新学年');
    // 学年子目标：从 SubGoal 池抽一条作为本学年的记忆锚点（此前整个池是死数据）。
    // 注入 AI 指令让这一年有方向感，但不强制——玩家仍可自由行动。
    try {
      final sub = selectYearGoal(
        newGrade,
        seed: turnCount,
        currentGoalName: player?.currentGoal,
        recentGoalIds: player?.recentYearGoalIds ?? const [],
      );
      // 记录到近期已选列表（FIFO，最多 3 个），供下次排除
      final p = player;
      if (p != null) {
        p.recentYearGoalIds.add(sub.id);
        if (p.recentYearGoalIds.length > 3) {
          p.recentYearGoalIds.removeAt(0);
        }
      }
      if (sub.steeringHint.isNotEmpty) {
        pendingAnchorDirective = (pendingAnchorDirective ?? '').isEmpty
            ? sub.steeringHint
            : '$pendingAnchorDirective\n${sub.steeringHint}';
        notifications.add('🎯 本学年方向：${sub.label}');
      }
    } catch (e) {
      // 子目标池为空/异常时降级，不影响学年推进，但留痕
      debugLog('[mixin_systems] 子目标池降级: $e');
    }
    // 新学年重置原创NPC生成计数（通过清理标记实现每学年限额）
    debugLog('🎓 学年推进：玩家升入$newGrade年级');
  }

  // ==================== 考试成绩结算（框架2 第60条） ====================

  /// 结算一场考试：按玩家当前熟练度 + 临场随机算出各科成绩，写入
  /// player.examRecords[key]，并发通知。同 key 已结算过则不重复覆盖
  /// （一场考试一辈子只有一次成绩，重读档也不该变）。
  void _settleExams(String key, {bool owl = false, bool newt = false}) {
    final p = player;
    if (p == null) return;
    if (p.examRecords.containsKey(key)) return;

    final records = settleExams(
      playerAttrs: p.attributes,
      nextDouble: random.nextDouble,
      owl: owl,
      newt: newt,
    );
    p.examRecords[key] = records;
    final s = examSummary(records);

    final buf = StringBuffer();
    if (owl) {
      buf.writeln('📜 【O.W.L. 普通巫师等级考试成绩揭晓】');
      worldState.addNarrativeEvent(
        '📜 O.W.L. 考试成绩揭晓：${s.oCount}个O，${s.eCount}个E',
        turn: turnCount,
      );
    } else if (newt) {
      buf.writeln('📜 【N.E.W.T. 终极巫师等级考试成绩揭晓】');
      worldState.addNarrativeEvent(
        '📜 N.E.W.T. 考试成绩揭晓：${s.oCount}个O，${s.eCount}个E',
        turn: turnCount,
      );
    } else {
      buf.writeln('📜 【第$key 学年期末考试成绩揭晓】');
      worldState.addNarrativeEvent(
        '📜 $key 学年期末考试成绩揭晓：${s.oCount}个O，${s.eCount}个E',
        turn: turnCount,
      );
    }
    buf.writeln(formatExamSheet(records));
    if (s.oCount >= 3) {
      buf.writeln('\n🏅 ${s.oCount} 个「O」——全年级都听说过你的名字了。');
      p.playerReputation.add('academic', 8);
    } else if (s.aPlusCount >= 6) {
      buf.writeln('\n📖 大部分科目都拿到了 A 以上，教授们对你印象不错。');
      p.playerReputation.add('academic', 4);
    } else if (s.aPlusCount <= 2) {
      buf.writeln('\n⚠️ 成绩单不太好看。教授们看你的眼神里多了几分欲言又止。');
      p.playerReputation.add('academic', -3);
    }
    notifications.add(buf.toString());
  }

  /// 玩家毕业（七年级结束）
  ///
  /// 【为什么是公开方法】剧情模式走完第七部时会从 `GameNarrativeMixin`
  /// 调过来（那条路径触达不到 `_checkSchoolYearTransition` 的九月判定，
  /// 详见 `_finishStory` 里的说明）。跨 mixin 调用必须经由基类声明，
  /// 所以这里是 `onPlayerGraduated` 而不是 `_onPlayerGraduated`。
  ///
  /// 【为什么把 `graduated = true` 收进来】原先这个置位散在调用点
  /// （`_checkSchoolYearTransition` 的九月分支里），于是走剧情模式那条
  /// 新入口时会出现"成就解锁了但 worldState.graduated 还是 false"的
  /// 半吊子状态——`updateAcademicYearLabel`、教职年结、`/联动` 的时间轴
  /// 分支都读这个字段，口径必须只有一处。
  @override
  void onPlayerGraduated(int oldGrade) {
    worldState.graduated = true;
    _settleGraduation(oldGrade);
  }

  void _settleGraduation(int oldGrade) {    final p = player;
    if (p == null) return;
    notifications.add('🎓 你从霍格沃茨毕业了！七年的魔法生涯画上句点。');
    worldState.addNarrativeEvent(
      '🎓 ${worldState.time.year}年，你从霍格沃茨毕业',
      turn: turnCount,
    );
    worldState.addMarker('🎓毕业');
    // 毕业是世界线上最明确的不可逆节点：从此不再跟着学年走。
    // timelineBranches 此前一次都没被写过（只有测试在调用 addTimelineBranch），
    // 而 /联动 又把它显示给玩家，于是那一栏永远只有「暂无。」。
    worldState.addTimelineBranch(
      '${worldState.time.year} 年从霍格沃茨毕业，人生轨迹自此不再跟着既定的学年走',
      snapshot: worldSnapshot(),
    );
    debugLog('🎓 玩家毕业（原$oldGrade年级）');
    // 毕业结算：评估人生目标达成情况并生成结算报告
    _graduationSettlement();
    // 职业引导：毕业不是结局——用成绩与名声去叩开职业的大门
    notifications.add('💼 毕业不是结局：/职业 列表 看看你七年攒下的成绩能叩开哪扇门');
  }
  void _graduationSettlement() {
    final p = player;
    if (p == null) return;

    unlockAchievement('graduated');

    final goal = p.currentGoal != null ? goalByName(p.currentGoal!) : null;
    final reqLines = goal != null
        ? evaluateGoalRequirement(goal.requirement)
        : <(String, bool)>[];
    final goalMet = reqLines.isNotEmpty && reqLines.every((e) => e.$2);
    if (goalMet) {
      unlockAchievement('goal_achieved');
    }

    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  🎓 毕业结算 · ${p.name}')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln();

    if (goal != null) {
      buf.writeln('【人生目标】${goal.name}');
      for (final (label, met) in reqLines) {
        buf.writeln('  ${met ? '✅' : '❌'} $label');
      }
      buf.writeln(
        goalMet
            ? '\n🏆 目标达成！你在霍格沃茨的七年，画上了一个方向明确的句号。'
            : '\n这个目标尚未完全达成——但毕业不是终点，你的人生仍可以继续书写。',
      );
    } else {
      buf.writeln('【人生目标】未设定——你的七年平静而真实地流淌而过。');
    }

    final rep = p.playerReputation;
    final deepCount = npcRegistry.values
        .where((n) => n.isAlive && n.affection >= 50)
        .length;
    buf
      ..writeln()
      ..writeln('【七年统计】')
      ..writeln(
        '· 声望：学术${rep.academic}｜社交${rep.social}｜战斗${rep.combat}｜道德${rep.moral}｜领导${rep.leadership}',
      )
      ..writeln('· 资产：${p.galleons + p.bankGalleons} 加隆')
      ..writeln('· 深厚羁绊：$deepCount 人')
      ..writeln('· 世界线变动率：${(p.worldLineDeviation * 100).toStringAsFixed(1)}%')
      ..writeln('· 成就：${p.achievements.length} / ${achievementCatalog.length}')
      ..writeln();

    // 学业总评：与官方毕业期望对比（growthExpectation 此前从未被读过）
    buf.writeln('【学业总评】');
    var metCount = 0;
    var totalCount = 0;
    for (final e in Balance.growthExpectation.entries) {
      // 'charms' 是课程键，对应属性键 spell_understanding
      final attrKey = e.key == 'charms' ? 'spell_understanding' : e.key;
      final cur = p.attributes[attrKey] ?? 50;
      final exp = e.value['graduate'] ?? 50;
      totalCount++;
      final ok = cur >= exp;
      if (ok) metCount++;
      buf.writeln('  ${ok ? '✅' : '▫️'} ${attrLabel(attrKey)}：$cur（毕业期望 $exp）');
    }
    buf.writeln(
      metCount >= totalCount * 0.7
          ? '\n你拿着这份成绩单，可以理直气壮地叩开大多数职业的大门。'
          : '\n部分科目未达到毕业期望——但人生不只有成绩单，你还有别的路。',
    );
    buf.writeln();
    buf.writeln('输入 /结局 可生成完整终章评语，或继续你的毕业后人生。');

    // 回望：把七年编成一篇能读的文章。
    //
    // 上面那一屏全是数字——声望、资产、成就——全对，
    // 但读完之后你不知道这七年发生了什么。玩家花几十个小时走完的七年，
    // 最后一屏不该是一张成绩单。
    final review = formatEndingReview(buildEndingReview(endingFactsOf(p)));
    if (review.isNotEmpty) {
      buf
        ..writeln()
        ..writeln(review);
    }

    // 够格的话，把留校邀请挂到结算报告末尾。
    // 放在这儿而不是通知里：毕业那一刻玩家正在读七年总账，
    // 顺手就能看到「你被留下了」，比弹一条转瞬即逝的通知有分量。
    _maybeOfferFacultyPosition(buf);

    // 追加到当前剧情之后，保留本回合叙事
    currentNarrative = currentNarrative.isEmpty
        ? buf.toString().trim()
        : '$currentNarrative\n\n${buf.toString().trim()}';
    worldState.addNarrativeEvent(
      '🎓 毕业结算完成${goalMet ? '·人生目标达成' : ''}',
      turn: turnCount,
    );
  }

  /// 在职教授的名字 → 好感。教授的 grade 是 0（学生是 1-7）。
  Map<String, int> _teacherAffections() {
    final out = <String, int>{};
    for (final n in npcRegistry.values) {
      if (!n.isAlive) continue;
      if (n.grade != 0) continue; // 学生
      if (n.affection <= 0) continue; // 关系不好就不算"愿意推荐你"
      out[n.name] = n.affection;
    }
    return out;
  }

  @override
  FacultyEligibility evaluateFacultyOffer() {
    final p = player;
    final rep = p?.playerReputation;
    if (p == null || rep == null) {
      return const FacultyEligibility(
        eligible: false,
        checks: [],
        startingRank: FacultyRank.none,
        subject: '魔咒学',
        allies: [],
      );
    }
    return evaluateFacultyEligibility(
      academic: rep.academic,
      moral: rep.moral,
      dark: rep.dark,
      attributes: p.attributes,
      teacherAffections: _teacherAffections(),
    );
  }

  /// 当代在任校长的名字；认不出来就返回 null（由文案退回「校方」）。
  ///
  /// 不能写死"邓布利多"——1892 年他自己还是一年级新生，
  /// 2020 年他已经逝世二十多年。
  String? _headmasterName() {
    for (final n in npcRegistry.values) {
      if (!n.isAlive || n.grade != 0) continue;
      final aliases = <String>{n.name};
      if (n.name.contains('邓布利多') || aliases.any((a) => a.contains('校长'))) {
        return n.name;
      }
    }
    return null;
  }

  /// 毕业时挂上留校邀请。够格才挂；不够格的一个字都不提——
  /// 事后再告诉玩家「你当年差 3 点学术声望」纯属给人添堵。
  void _maybeOfferFacultyPosition(StringBuffer report) {
    final p = player;
    if (p == null) return;
    if (p.facultyOfferDeclined || p.facultyRankId != null) return;

    final e = evaluateFacultyOffer();
    if (!e.eligible) return;

    _facultyOfferPending = true;
    final line = facultyOfferLineFor(
      e: e,
      headmasterName: _headmasterName(),
      playerName: p.name,
    );
    report
      ..writeln()
      ..writeln('──────────────────────────────')
      ..writeln(line)
      ..writeln()
      ..writeln('输入 /教职 接受 或 /教职 婉拒。');
  }

  @override
  String resolveFacultyOffer(bool accept) {
    final p = player;
    if (p == null) return '尚未创建角色。';
    if (p.facultyRankId != null) {
      return '你已经在霍格沃茨任教了。';
    }
    if (p.facultyOfferDeclined) {
      return '那封信你当年已经回绝了。有些门一旦关上就不会再开第二次。';
    }

    final e = evaluateFacultyOffer();

    if (!accept) {
      p.facultyOfferDeclined = true;
      _facultyOfferPending = false;
      final buf = StringBuffer()
        ..writeln('【婉拒留校】')
        ..writeln()
        ..writeln(kFacultyDeclineLine);
      worldState.addNarrativeEvent('婉拒了霍格沃茨的留校邀请', turn: turnCount);
      notifyListeners();
      return buf.toString();
    }

    if (!e.eligible) {
      _facultyOfferPending = false;
      return '邀请已经失效了——这一年的教席安排已经定了。';
    }

    final rank = rankDefFor(e.startingRank);
    p.facultyRankId = rank.id;
    p.facultySubject = e.subject;
    p.facultyServiceYears = 0;
    p.currentJobTitle = '霍格沃茨${rank.title}';
    _facultyOfferPending = false;

    // 预付半年薪水：刚毕业的人总得先安顿下来
    final advance = rank.annualPay ~/ 2;
    p.galleons += advance;

    worldState.addNarrativeEvent(
      '🎓 留校任教：${e.subject}${rank.title}',
      turn: turnCount,
    );
    // 和毕业、成婚一样，这是回不了头的节点
    worldState.addTimelineBranch(
      '${worldState.time.year} 年留校任教，任「${e.subject}」${rank.title}',
      snapshot: worldSnapshot(),
    );
    notifications.add('🏫 你留下了，教${e.subject}');

    final buf = StringBuffer()
      ..writeln('【留校任教】${e.subject}·${rank.title}')
      ..writeln()
      ..writeln(rank.duty)
      ..writeln()
      ..writeln('预付半年薪水：$advance 加隆。')
      ..writeln()
      ..writeln('推荐你的教授：${e.allies.join('、')}。')
      ..writeln('往后每年九月会结算年薪并考核晋升（/教职 查看进度）。')
      ..writeln()
      ..writeln(
        '明天你就要从行李里翻出当年自己那本课本了——'
        '只是这一次，站在讲台上的是你。',
      );

    notifyListeners();
    return buf.toString();
  }

  /// 每年九月：发年薪、加一年服务期、考核晋升。
  ///
  /// [yearsPassed] 是这次学年切换跨过的年数（/快进 可能一次跨好几年）。
  void _settleFacultyYear(int yearsPassed) {
    final p = player;
    final rankId = p?.facultyRankId;
    if (p == null || rankId == null) return;
    final cur = rankDefById(rankId);
    if (cur == null) return;

    p.facultyServiceYears += yearsPassed;
    p.galleons += cur.annualPay * yearsPassed;

    final rep = p.playerReputation;
    final next = promotionFor(
      current: cur.rank,
      serviceYears: p.facultyServiceYears,
      academic: rep.academic,
      leadership: rep.leadership,
    );
    if (next == null) return;

    p.facultyRankId = next.id;
    p.currentJobTitle = '霍格沃茨${next.title}';
    notifications.add('🏫 晋升为${next.title}');
    worldState.addNarrativeEvent(
      '🏫 晋升：${p.facultySubject ?? ''}${next.title}',
      turn: turnCount,
    );
    worldState.addTimelineBranch(
      '${worldState.time.year} 年晋升为「${p.facultySubject ?? ''}」${next.title}',
      snapshot: worldSnapshot(),
    );
  }
}
