/// 家族传承子系统（r6-5 拆分自 mixin_systems.dart）。
///
/// 覆盖：结婚/子嗣/世代传承/家族遗产（框架2 世代玩法）。全部本地结算
/// （零 AI 调用），通过 on 链复用 [GameSystemsMixin] 的时间推进与
/// NPC 初始化工具。
library;

import 'dart:async';
import '../data/rivalry_data.dart';
import '../data/faculty_data.dart';
import '../data/legacy_data.dart';
import 'mixin_game_save.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';
import 'mixin_systems.dart';

mixin GameFamilyLegacyMixin on GameProviderBase, GameSaveSystemMixin {
  // ==================== 家族传承 ====================

  /// 某个孩子现在几岁
  int childAgeOf(ChildRecord child) =>
      (worldState.time.absoluteDayIndex - child.bornAbsDay) ~/ 365;

  /// 够格接棒的孩子：年满入学年龄（11 岁）
  @override
  List<ChildRecord> heirsOfAge() {
    final p = player;
    if (p == null) return const [];
    return p.children
        .where((c) => childAgeOf(c) >= kHeirEntranceAge)
        .toList(growable: false);
  }

  /// 配偶的血统。找不到就当混血——总比凭空冒出个纯血强。
  String _spouseBloodTypeOf(String name) {
    for (final n in npcRegistry.values) {
      if (n.name == name) return n.bloodStatus;
    }
    return 'halfblood';
  }

  /// 为某个孩子算出一份传承清单
  LegacyCarryover buildLegacyFor(ChildRecord child) {
    final p = player!;
    final rep = p.playerReputation;
    final surname = child.name.isNotEmpty
        ? child.name[0]
        : (p.name.isNotEmpty ? p.name[0] : '林'); // 坏档兜底：空名不能越界
    final spouseBlood = _spouseBloodTypeOf(child.otherParentName);

    // 世交：父母处得好的人，孩子开局就认识
    final affections = <String, int>{};
    for (final n in npcRegistry.values) {
      if (n.isAlive) affections[n.name] = n.affection;
    }
    // 世仇：宿敌（hostile 及以上）会把梁子传下去
    final today = worldState.time.absoluteDayIndex;
    final rivals = npcRegistry.values
        .where(
          (n) =>
              n.isAlive &&
              n.introduced &&
              n.rivalryTier(today).index >= RivalryTier.hostile.index,
        )
        .map((n) => n.name)
        .toList(growable: false);

    final age = childAgeOf(child);
    final startYear = worldState.time.year - (age - kHeirEntranceAge);
    final inheritance = inheritedWealth(p.galleons + p.bankGalleons);
    final summary = summarizeParent(
      parentName: p.name,
      academic: rep.academic,
      combat: rep.combat,
      moral: rep.moral,
      dark: rep.dark,
      leadership: rep.leadership,
      wasFaculty: p.facultyRankId != null,
      worldLinePercent: (p.worldLineDeviation * 100).round(),
    );

    return LegacyCarryover(
      heirName: child.name,
      heirGender: child.gender,
      surname: surname,
      bloodType: mixBloodType(p.bloodType, spouseBlood, random.nextInt(100)),
      familyBackground: buildFamilyBackground(
        surname: surname,
        parentName: p.name,
        parentSummary: summary,
        rivals: rivals,
        inheritance: inheritance,
      ),
      reputation: inheritedReputation(
        academic: rep.academic,
        social: rep.social,
        combat: rep.combat,
        moral: rep.moral,
        leadership: rep.leadership,
        dark: rep.dark,
      ),
      allies: inheritedAllies(affections),
      rivals: rivals,
      inheritance: inheritance,
      parentName: p.name,
      startYear: startYear,
      parentSummary: summary,
    );
  }

  @override
  String formatLegacy() {
    final p = player;
    if (p == null) return '尚未创建角色。';

    // 传承闭环：显示家族代数（第 1 代不标注，传承局从第 2 代起）
    final genTag = p.generation > 1 ? '　第 ${p.generation} 代' : '';

    if (p.children.isEmpty) {
      return '【传承】$genTag\n你还没有孩子。\n'
          '结婚之后可以备孕，等孩子长到 $kHeirEntranceAge 岁，'
          '就能把这一生交给他。';
    }

    final heirs = heirsOfAge();
    if (heirs.isEmpty) {
      final buf = StringBuffer()
        ..writeln('【传承】还没有人够年纪接棒')
        ..writeln();
      for (final c in p.children) {
        final age = childAgeOf(c);
        buf.writeln(
          '· ${c.name}（${c.gender}）$age 岁，'
          '还差 ${kHeirEntranceAge - age} 年到入学年龄',
        );
      }
      buf
        ..writeln()
        ..writeln('用 /快进 把时间推到他收到录取通知书那年。');
      return buf.toString();
    }

    final buf = StringBuffer()
      ..writeln('【传承】')
      ..writeln();
    for (final c in heirs) {
      final legacy = buildLegacyFor(c);
      buf
        ..writeln(
          '· ${c.name}（${c.gender}，${childAgeOf(c)} 岁）'
          '　${bloodStatusLabel(legacy.bloodType)}',
        )
        ..writeln('  带走：${legacy.inheritance} 加隆')
        ..writeln(
          '  声望：学术${legacy.reputation['academic']}'
          '｜社交${legacy.reputation['social']}'
          '｜战斗${legacy.reputation['combat']}'
          '｜道德${legacy.reputation['moral']}'
          '｜领导${legacy.reputation['leadership']}',
        );
      if (legacy.hasAllies) {
        buf.writeln(
          '  世交 ${legacy.allies.length} 人：'
          '${legacy.allies.keys.take(3).join('、')}'
          '${legacy.allies.length > 3 ? '等' : ''}',
        );
      }
      if (legacy.hasRivals) {
        // 这一栏要单独成行并且放在最后——它是整份清单里最该被看见的东西
        buf.writeln(
          '  ⚠ 世仇 ${legacy.rivals.length} 人：'
          '${legacy.rivals.take(3).join('、')}'
          '${legacy.rivals.length > 3 ? '等' : ''}'
          '——你结下的梁子会跟着这个姓传下去',
        );
      }
      buf.writeln();
    }
    buf
      ..writeln('输入 /传承 名字 把这一生交给他。')
      ..writeln(
        '这会开一局新的：剧情从头开始，'
        '但你的姓、你的血统、你结下的梁子会跟着走。',
      );
    return buf.toString();
  }

  /// 把传承来的世交与世仇落到 NPC 身上。
  ///
  /// 必须在 `initializeNPCsByEra()` 之后调——名字对不上的话，
  /// 这两栏会静默地什么都不生效，玩家永远不会知道自己继承了什么。
  ///
  /// 这里**刻意不走** `updateNpcAffection`：那是一条「一次好感变化」的管线，
  /// 会记本周增量、撞周上限（30）、记事件、发通知、甚至触发成就。
  /// 而传承写的是**开局初始值**——它不占本周额度，也不该在开始界面
  /// 弹出一串「本周好感已达上限」。继承上限 35 比周上限 30 还高，
  /// 走统一入口会先被砍一刀，那传承就名不副实了。
  @override
  void applyLegacyRelations(LegacyCarryover legacy) {
    final day = worldState.time.absoluteDayIndex;
    for (final npc in npcRegistry.values) {
      final inherited = legacy.allies[npc.name];
      if (inherited != null) {
        npc.affection = inherited;
        npc.maxAffectionReached = inherited;
        npc.introduced = true; // 你从小就认识他
        continue;
      }
      if (legacy.rivals.contains(npc.name)) {
        // 宿敌分靠 grudges 推，一次「积怨」是 18 分（grudge 档门槛 15）。
        // 七成的梁子传下来，正好够让孩子一进校门就被人另眼相看——
        // 但还不至于开局就有人要他的命，那是上一代自己的分量。
        npc.affection = -20;
        npc.introduced = true;
        npc.addGrudge('accumulated', '父辈的旧账', day);
      }
    }
  }

  @override
  Future<bool> startLegacy(String childName) async {
    final p = player;
    if (p == null) return false;
    ChildRecord? heir;
    for (final c in heirsOfAge()) {
      if (c.name == childName) heir = c;
    }
    if (heir == null) return false;

    final legacy = buildLegacyFor(heir);
    // 传承闭环：家族代数 +1——孩子是"第 N+1 代"，多周目有了刻度。
    // initializeGame 重建 player 后赋值（父辈代数在重建前先取出）。
    final parentGeneration = p.generation;
    await initializeGame(
      name: legacy.heirName,
      bloodStatus: legacy.bloodType,
      birthLocation: p.birthLocation,
      personalityTraits: heir.traits.take(3).toList(),
      gender: legacy.heirGender,
      familyBackground: legacy.familyBackground,
      legacy: legacy,
    );
    player!.generation = parentGeneration + 1;
    return true;
  }

  @override
  String formatFaculty() {
    final p = player;
    if (p == null) return '尚未创建角色。';
    final rankId = p.facultyRankId;

    if (rankId == null) {
      final e = evaluateFacultyOffer();
      final buf = StringBuffer()..writeln('【教职】尚未任教');
      if (p.facultyOfferDeclined) {
        buf
          ..writeln()
          ..writeln('你婉拒过霍格沃茨的留校邀请。那扇门不会再开第二次。');
        return buf.toString();
      }
      if (!worldState.graduated) {
        buf
          ..writeln()
          ..writeln('毕业时若够格，会收到留校邀请。目前差在：');
      } else {
        buf
          ..writeln()
          ..writeln('你没能拿到那封邀请信。差在：');
      }
      for (final (label, ok) in e.checks) {
        buf.writeln('${ok ? '✅' : '⬜'} $label');
      }
      buf
        ..writeln()
        ..writeln(
          '你最拿得出手的一门课是「${e.subject}」。'
          '它就是你将来会被问到的那门课。',
        );
      if (e.allies.isNotEmpty) {
        buf.writeln('愿意替你说话的教授：${e.allies.join('、')}。');
      }
      return buf.toString();
    }

    final def = rankDefById(rankId);
    if (def == null) return '教职数据缺失（职级已下线），请联系开发者。';
    final buf = StringBuffer()
      ..writeln('【教职】${p.facultySubject ?? ''}·${def.title}')
      ..writeln('任教年限：${p.facultyServiceYears} 年　年薪：${def.annualPay} 加隆')
      ..writeln()
      ..writeln(def.duty)
      ..writeln()
      ..writeln('【晋升】')
      ..writeln(
        promotionHintFor(
          current: def.rank,
          serviceYears: p.facultyServiceYears,
          academic: p.playerReputation.academic,
          leadership: p.playerReputation.leadership,
        ),
      );
    return buf.toString();
  }


  /// 好感维系衰减：关系不经营是会淡的。
  ///
  /// 第九次审查前，好感只有「沉淀」（涨得慢）没有「维系」（不联系会回落），
  /// 玩家可以把一排 NPC 刷到 85+ 然后放着不管——集邮式社交，
  /// 关系网后期失真，也跟「NPC 有自己的生活」的设定矛盾。
  ///
  /// 规则（常量在 Balance）：
  ///  - 连续 [Balance.affectionDriftIdleDays] 天没有任何好感互动后，
  ///    每个游戏周自然转淡 1~2 点；
  ///  - 只淡正好感，且在 [Balance.affectionDriftFloor]（「好感」段下沿）停住：
  ///    会变生分，不会淡回素不相识；
  ///  - 豁免：持有「信任锁」的（老朋友不联系也不会变陌生）、
  ///    当前恋人、未登场的、已去世的、负好感（记恨不随时间消，那是宿敌系统的事）；
  ///  - 快进跨多周时按实际跨过的周数结算，但每人每次最多补 4 周，
  ///    防止一次长跳过把一段关系直接跳没。

  /// 传闻衰减：旧闻（超过 30 个游戏日）从传闻列表里淡出。


  /// [e] 的互斥伙伴里，有没有谁是在 [kMutuallyExclusiveMonths] 个月内刚播过的。

  /// [e] 本次是否不该参与抽取（自身重复冷却 + 互斥窗口）。



}
