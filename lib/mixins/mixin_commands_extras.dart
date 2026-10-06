/// 命令扩展子系统（r6-3 拆分自 mixin_commands.dart）。
///
/// 覆盖：周计划（框架2 第62条）、守护神（第66条）、声望子命令、人生目标、
/// 终章/结局、信件互动。全部为命令 handler 与本地格式化（零 AI 调用），
/// 通过 on 链复用 [GameCommandsMixin] 的注册表与工具。
library;

import '../models/game_systems.dart';
import 'dart:async';
import '../data/pet_data.dart';
import '../data/pet_narrative_config.dart';
import '../data/command_registry.dart';
import '../data/goal_data.dart';
import '../data/course_data.dart';
import '../data/patronus_data.dart';
import '../data/attribute_data.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';
import '../utils/debug_log.dart';
import 'mixin_commands.dart';
import 'mixin_commands_extras_memory.dart';
import 'mixin_commands_extras_reputation.dart';

mixin GameCommandsExtrasMixin
    on GameCommandsMixin,
        GameCommandsExtrasMemoryMixin,
        GameCommandsExtrasReputationMixin {
  // ==================== 周计划（框架2 第62条 · 时间是一种资源） ====================

  /// /计划 指令：玩家声明「这一周以什么为主」，系统批量结算一周时间。
  /// 时间推进走 fastForwardTime（自动处理学年推进/月度演化/事件锚点/好感衰减），
  /// 再叠加对应的成长结算——玩家把时间花在哪，哪条线就会前进。
  void handlePlan(List<String> parts) {
    final p = player;
    if (p == null) return;
    final sub = parts.isEmpty ? '' : parts[0];

    switch (sub) {
      case '学习':
        _planStudy(p);
        break;
      case '社交':
        _planSocial(p);
        break;
      case '魁地奇':
        _planQuidditch(p);
        break;
      case '调查':
        _planInvestigate(p);
        break;
      case '放松':
        _planRest(p);
        break;
      case '打工':
        _planWork(p);
        break;
      default:
        currentNarrative =
            '【周计划】把一整周的时间投给一件事，系统批量结算。\n\n'
            '  /计划 学习 — 泡图书馆，学业属性成长\n'
            '  /计划 社交 — 经营关系，好感提升\n'
            '  /计划 魁地奇 — 训练技巧与体能\n'
            '  /计划 调查 — 探索禁林与城堡的秘密\n'
            '  /计划 放松 — 恢复精力与精神\n'
            '  /计划 打工 — 赚一周的零花钱\n\n'
            '（每周推进 7 天，中间的关键事件会自动进入通知）';
    }
  }

  void _planStudy(Player p) {
    const pool = [
      'spell_understanding',
      'transfiguration',
      'potions',
      'herbology',
      'theory',
      'memory',
    ];
    final gains = <String, int>{};
    for (final key in pool) {
      if (random.nextDouble() < 0.6) {
        gains[key] = 1 + random.nextInt(3); // 1~3
      }
    }
    gains.forEach((k, v) {
      // BUG-FIX: `+` 优先级高于 `??`，原来写成 (p.attributes[k] ?? 50 + v)
      // 等价于 p.attributes[k] ?? (50+v)，属性已存在时加成被整体丢弃。
      p.attributes[k] = ((p.attributes[k] ?? 50) + v).clamp(0, 100);
    });
    p.energy = (p.energy - 10).clamp(0, 100);
    _advanceWeek('学习');
    final line = gains.entries
        .map((e) => '${attributeLabel(e.key)} +${e.value}')
        .join('，');
    worldState.addNarrativeEvent('📚 这一周你几乎把时间都泡在了图书馆', turn: turnCount);
    currentNarrative =
        '这一周，你的生活节奏简单而充实：上午上课，下午图书馆，晚上在公共休息室的角落里'
        '翻书写作业。蜡烛的火焰在羊皮纸上投下晃动的影子，你偶尔抬头，看见窗外禁林的轮廓在夜色里沉默。\n\n'
        '一周下来，你明显感到自己在${gains.isEmpty ? '原地踏步——状态不太好，也许该换换节奏' : '进步'}'
        '${gains.isEmpty ? '' : '：$line'}。\n\n'
        '（时间推进一周）';
  }

  void _planSocial(Player p) {
    final candidates = npcRegistry.values
        .where((n) => n.isAlive && n.introduced)
        .toList();
    var affected = 0;
    final names = <String>[];
    if (candidates.isNotEmpty) {
      candidates.shuffle(random);
      final count = random.nextInt(3) + 1; // 1~3 位
      for (var i = 0; i < count && i < candidates.length; i++) {
        final npc = candidates[i];
        final delta = 1 + random.nextInt(2); // 1~2
        updateNpcAffection(npc.id, delta, reason: '周计划·社交', quiet: true);
        affected++;
        names.add('${npc.name}（+$delta）');
      }
    }
    p.attributes['social'] = (p.attributes['social'] ?? 50) + 2;
    p.energy = (p.energy - 10).clamp(0, 100);
    _advanceWeek('社交');
    worldState.addNarrativeEvent('☕ 这一周你忙于经营人际关系', turn: turnCount);
    currentNarrative =
        '你主动调整了这一周的重心：和同学一起吃饭、帮朋友跑腿、参加公共休息室的闲聊、'
        '给远方的人写信。魔法世界的人情冷暖，说到底也是靠一次次小小的来往织成的。\n\n'
        '${affected > 0 ? '一周下来，你们的关系更近了一些：${names.join('，')}。' : '这一周没什么特别的交集，但至少你让自己出现在了人群里。'}\n\n'
        '（时间推进一周）';
  }

  void _planQuidditch(Player p) {
    final qGain = 3 + random.nextInt(3); // 3~5
    p.qSkill = (p.qSkill + qGain).clamp(0, 100);
    p.attributes['flying'] = (p.attributes['flying'] ?? 50) + 2;
    p.attributes['reaction_time'] = (p.attributes['reaction_time'] ?? 50) + 1;
    p.energy = (p.energy - 25).clamp(0, 100);
    p.satiety = (p.satiety + 5).clamp(0, 100);
    _advanceWeek('魁地奇');
    worldState.addNarrativeEvent('🏏 这一周你在魁地奇球场挥汗如雨', turn: turnCount);
    currentNarrative =
        '这一周，魁地奇球场几乎成了你的第二个家。清晨的风里，你绕着球门做俯冲练习；'
        '傍晚的余晖中，你和队友磨合配合。扫帚的抛光油味混着青草的气息，是这一周最熟悉的味道。\n\n'
        '一周下来，你的魁地奇技巧 +$qGain，飞行能力也见长。\n\n'
        '（时间推进一周）';
  }

  void _planInvestigate(Player p) {
    p.attributes['observation'] = (p.attributes['observation'] ?? 50) + 2;
    p.attributes['theory'] = (p.attributes['theory'] ?? 50) + 1;
    p.attributes['magic_control'] = (p.attributes['magic_control'] ?? 50) + 1;
    p.energy = (p.energy - 15).clamp(0, 100);
    _advanceWeek('调查');
    // 小概率发现彩蛋：写一条随机传闻/事件
    final found = random.nextDouble() < 0.3;
    if (found) {
      final bits = [
        '图书馆禁书区的一本书里夹着一张泛黄的羊皮纸，上面的字迹已经模糊',
        '城堡某条密道的入口附近有一串新鲜的脚印，通向你们不该去的地方',
        '有同学在夜里听见走廊深处传来低低的歌声，没人说得清它来自哪里',
        '禁林边缘的树丛里，有什么东西在月光下闪了一下',
      ];
      final bit = bits[random.nextInt(bits.length)];
      worldState.addNarrativeEvent('🔍 调查发现：$bit', turn: turnCount);
      notifications.add('🔍 这周的调查有了点发现：$bit');
      currentNarrative =
          '这一周你像一只安静的猫，在霍格沃茨的角落里搜寻线索。图书馆、废弃教室、'
          '画像背后的走廊——你几乎把城堡的纹理摸了一遍。\n\n'
          '周三深夜，你发现：$bit\n\n'
          '（时间推进一周）';
    } else {
      worldState.addNarrativeEvent('🔍 这一周你在城堡里调查走访，没有特别的发现', turn: turnCount);
      currentNarrative =
          '这一周你像一只安静的猫，在霍格沃茨的角落里搜寻线索。图书馆、废弃教室、'
          '画像背后的走廊——你几乎把城堡的纹理摸了一遍。\n\n'
          '遗憾的是，这一周并没有惊天动地的发现。城堡的古老秘密，从来不会轻易向人敞开。\n\n'
          '（时间推进一周）';
    }
  }

  void _planRest(Player p) {
    p.energy = (p.energy + 45).clamp(0, 100);
    p.spirit = (p.spirit + 35).clamp(0, 100);
    p.satiety = (p.satiety + 25).clamp(0, 100);
    _advanceWeek('放松');
    worldState.addNarrativeEvent('🛋️ 这一周你好好休息了一番', turn: turnCount);
    currentNarrative =
        '你决定这一周不为任何事奔忙：睡到自然醒，和同学去霍格莫德喝黄油啤酒，'
        '在城堡外的草地上晒晒太阳，晚上窝在休息室的扶手椅里发呆。\n\n'
        '一周下来，身心都得到了喘息。\n\n'
        '（时间推进一周）';
  }

  void _planWork(Player p) {
    final income = 150 + random.nextInt(100); // 150~249 加隆
    p.galleons += income;
    p.energy = (p.energy - 20).clamp(0, 100);
    p.attributes['social'] = (p.attributes['social'] ?? 50) + 1;
    _advanceWeek('打工');
    worldState.addNarrativeEvent('🪙 这一周你接了一份短工', turn: turnCount);
    currentNarrative =
        '这一周你把自己卖给了一份短工——跑腿、整理货架、帮忙照看摊位，'
        '偶尔还要应付难缠的顾客。腰酸背痛是免不了的，但每天晚上数着西可和纳特入睡的感觉，'
        '也不算太糟。\n\n'
        '一周下来，你赚了 💰 $income 加隆。\n\n'
        '（时间推进一周）';
  }

  void _advanceWeek(String focus) {
    final before = worldState.time.format();
    fastForwardTime(7);
    final after = worldState.time.format();
    debugLog('📅 周计划[$focus]：$before → $after');
  }

  // ==================== 守护神（框架2 第66条） ====================

  /// /守护神 状态 ｜ /守护神 尝试
  void handlePatronus(List<String> parts) {
    final p = player;
    if (p == null) return;
    final sub = parts.isEmpty ? '状态' : parts[0];

    switch (sub) {
      case '状态':
        currentNarrative = _formatPatronusStatus();
        break;
      case '尝试':
        _patronusAttempt(p);
        break;
      default:
        currentNarrative =
            '【守护神】未知子命令「$sub」。\n'
            '可用：/守护神 状态 ｜ /守护神 尝试';
    }
  }

  String _formatPatronusStatus() {
    final p = player!;
    final buf = StringBuffer('【守护神】\n');
    if (p.patronus != null && p.patronus!.isNotEmpty) {
      final f = patronusFormByName(p.patronus!);
      buf.writeln('形态：${p.patronus}');
      if (f != null) buf.writeln(f.description);
      buf.writeln(
        '\n守护神是灵魂的映照。它可能随着你人生的巨变而改变——'
        '但此刻，它就是你的模样。',
      );
      return buf.toString();
    }
    final grade = p.grade ?? 1;
    final emotion = p.attributes['emotional_stability'] ?? 50;
    final knowsSpell = p.learnedSpells.containsKey('守护神咒');
    buf.writeln('你还没有属于自己的守护神。');
    if (grade < 5 && !knowsSpell) {
      buf.writeln(
        '\n守护神咒是高年级（五年级起）的黑魔法防御术咒语——'
        '你的魔法还不够成熟，强行尝试只会让杖尖凝出一缕毫无形状的银雾。',
      );
    } else {
      buf.writeln(
        '\n你已经掌握了守护神咒的基础，但召唤成形守护神'
        '需要内心深处的幸福记忆与稳定的情绪。',
      );
      if (emotion < 60) {
        buf.writeln(
          '\n（情绪稳定度 $emotion/100——你的内心还不够平静，'
          '建议先学会在混乱中稳住自己。）',
        );
      } else {
        buf.writeln('\n（情绪稳定度 $emotion/100，可以尝试：/守护神 尝试）');
      }
    }
    return buf.toString();
  }

  void _patronusAttempt(Player p) {
    final grade = p.grade ?? 1;
    final knowsSpell = p.learnedSpells.containsKey('守护神咒');
    if (grade < 5 && !knowsSpell) {
      currentNarrative =
          '你举起魔杖，拼尽全力回想快乐的记忆，念出「Expecto Patronum！」——\n\n'
          '杖尖只飘出一缕不成形的银雾，转瞬即逝。\n\n'
          '守护神咒是高年级的领域。你的魔法还不够成熟，强行尝试只会让自己头晕目眩。\n\n'
          '（五年级后可学习守护神咒，再作尝试。）';
      p.spirit = (p.spirit - 10).clamp(0, 100);
      return;
    }
    final emotion = p.attributes['emotional_stability'] ?? 50;
    if (emotion < 60) {
      currentNarrative =
          '你努力回想快乐的记忆，但思绪总是被焦虑和杂念打断。'
          '银雾在杖尖聚了又散，始终无法成形。\n\n'
          '守护神是心灵的映照——内心不平静，它就无处可依。'
          '（情绪稳定度 $emotion/100，需 ≥60）';
      p.spirit = (p.spirit - 10).clamp(0, 100);
      return;
    }
    // 尝试召唤：成功概率由情绪稳定 + 魔法控制 + DDA 决定
    final emotionScore = emotion;
    final control = p.attributes['magic_control'] ?? 50;
    final dda = p.attributes['dda'] ?? 50;
    final chance =
        (0.5 +
                (emotionScore - 60) / 200 +
                (control - 50) / 200 +
                (dda - 50) / 200)
            .clamp(0.3, 0.9);
    p.spirit = (p.spirit - 15).clamp(0, 100);
    if (random.nextDouble() <= chance) {
      final form = resolvePatronusForm(
        personality: p.personalityTraits,
        house: p.house ?? '',
        beliefs: p.beliefs ?? '',
        dice: random.nextDouble(),
      );
      p.patronus = form;
      worldState.addNarrativeEvent('✨ 你的守护神成形了：$form', turn: turnCount);
      notifications.add('✨ 你的守护神成形了：$form');
      final f = patronusFormByName(form);
      currentNarrative =
          '这一次，你没有费力去想快乐的记忆。\n\n'
          '你只是闭上眼，让某个早已刻进心底的画面浮现——'
          '然后，杖尖喷涌出耀眼的白光。\n\n'
          '光芒凝聚成形：$form。${f?.description ?? ''}\n\n'
          '它绕着你奔跑了一圈，然后停在你面前，静静地看着你。'
          '你知道，从今往后，无论黑暗多深，你都不再是独自一人。';
    } else {
      worldState.addNarrativeEvent('🌫️ 守护神尝试失败：银雾聚了又散', turn: turnCount);
      currentNarrative =
          '白光从杖尖涌出，但始终凝不成形。银雾在空气中徘徊片刻，'
          '像一个欲言又止的词，然后散去了。\n\n'
          '你放下魔杖，喘了口气。还差一点——也许是记忆还不够清晰，'
          '也许是情绪还不够纯粹。\n\n'
          '（提升情绪稳定度与魔法控制后，再来尝试。）';
    }
  }

  // ==================== 声望子命令（框架1 7.3） ====================


  String formatGoals() {
    final p = player;
    final current = p?.currentGoal;
    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  《人生目标》')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln()
      ..writeln(
        '【当前目标】${(current == null || current.isEmpty) ? '尚未设定' : current}',
      );
    if (current != null && current.isNotEmpty) {
      final g = goalByName(current);
      if (g != null) {
        buf.writeln('  『${g.description}』');
      }
    }
    buf
      ..writeln()
      ..writeln('【可选目标】（输入 /目标 [编号] 设定）');
    for (int i = 0; i < lifeGoalCatalog.length; i++) {
      final g = lifeGoalCatalog[i];
      buf.writeln('${i + 1}. ${g.name}（${g.category}）— ${g.description}');
    }
    if (current != null && current.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('💡 输入 /目标 进度 查看当前目标的毕业条件达成情况。');
    }
    return buf.toString();
  }

  // ==================== 终章 / 结局 ====================

  void startEndingSequence() {
    if (player == null) return;
    isLoading = true;
    loadingStage = '正在书写你的终章…';
    currentNarrative = '';
    clearStreamingPreview();
    choices = [];
    notifyListeners();
    unawaited(generateEnding());
  }


  /// P2#11：/档案 回忆 —— 人生大事记。
  ///
  /// 没有自建"回忆"表：大事记的原料是 recentNarrativeEvents（最多保留 20 条），
  /// 这里把最近的成长痕迹按时间倒序摊开，再补上收藏/成就/恋爱等一眼能看到的
  /// 累积数字，让"回忆"不只是流水账。
  String formatMemories() {
    final p = player;
    final buf = StringBuffer('【人生回忆】');
    if (p == null) {
      buf.writeln('\n还没有人生可言——先创建角色吧。');
      return buf.toString();
    }
    buf.writeln(
      '\n第 ${p.grade ?? 1} 学年 · ${p.house ?? '未分院'} · 第 $turnCount 回合',
    );
    final events = worldState.recentNarrativeEvents.take(12).toList();
    if (events.isEmpty) {
      buf.writeln('\n还没有值得写进回忆的事。去经历点什么吧。');
    } else {
      buf.writeln('\n—— 最近的人生切片 ——');
      for (final e in events) {
        final t = e.turn;
        final when = e.at != null
            ? '${e.at!.month}月${e.at!.day}日'
            : (t != null ? '第$t回合' : '');
        buf.writeln('· ${when.isEmpty ? '' : '[$when] '}${e.text}');
      }
    }
    // 奇遇痕迹小节（设计文档 3.4.1：/档案 回忆 追加奇遇小节，
    // 按时间倒序列出已沉淀奇遇 title + outcomeTitle + 周数）。
    final happenstances = p.happenstanceLog;
    if (happenstances.isNotEmpty) {
      buf.writeln('\n—— 奇遇回忆 ——');
      final recent = happenstances.reversed.take(10).toList();
      for (final h in recent) {
        final termLabel = h.term == 'first'
            ? '第一学期'
            : h.term == 'second'
                ? '第二学期'
                : '暑期';
        buf.writeln(
          '· [第${h.week}周·$termLabel] 「${h.title}」→ ${h.outcomeTitle}',
        );
      }
      if (happenstances.length > 10) {
        buf.writeln('……等共 ${happenstances.length} 场奇遇');
      }
    }
    // 一眼可见的积累
    buf.writeln('\n—— 一路走来 ——');
    buf.writeln('· 收藏：${p.collection.length} 件');
    buf.writeln('· 成就：${p.achievements.length} 项');
    // 奇遇声望展示注入（设计文档 3.5：纯展示性注入，不改声望数值）
    final hCount = p.happenstanceLog.length;
    if (hCount >= 15) {
      buf.writeln('· 奇遇经历：$hCount 场——城堡的每个角落都认得你');
    } else if (hCount >= 5) {
      buf.writeln(
        '· 奇遇经历：$hCount 场——你有 $hCount 段不期而遇的经历，'
        '它们塑造了你的行事风格',
      );
    }
    final love = p.loveState;
    if (love.status != '单身') {
      buf.writeln('· 感情：${love.status}（${love.partnerName ?? '?'}）');
    }
    buf.writeln('\n（输入 /恋爱 历史 回看感情线，/日记 重播 CG）');
    return buf.toString();
  }

  /// P2#11：/时间 日程 —— 本周安排与最近事件。
  String formatDailySchedule() {
    final p = player;
    if (p == null) return '【日程】\n尚未创建角色。';
    final buf = StringBuffer('【日程】');
    buf.writeln(
      '\n${worldState.time.formatDate()}'
      '（第 ${worldState.academicYear} 学年 · 第 ${worldState.term} 学期）',
    );
    // 课程：必修 + 选修
    final required = requiredCourses.map((c) => c.name).take(4).join('、');
    final electives = electiveCourses.map((c) => c.name).take(3).join('、');
    buf.writeln('\n本周课程：');
    buf.writeln('· 必修：$required${requiredCourses.length > 4 ? ' 等' : ''}');
    if (electives.isNotEmpty) {
      buf.writeln('· 选修：$electives');
    }
    buf.writeln('\n输入 /计划 学习|社交|魁地奇|调查|放松 把一整周投给一件事。');
    final events = worldState.recentNarrativeEvents.take(5).toList();
    if (events.isNotEmpty) {
      buf.writeln('\n最近发生：');
      for (final e in events) {
        buf.writeln('· ${e.text}');
      }
    }
    return buf.toString();
  }

  String formatAchievements() {
    final unlocked = player!.achievements;
    final catalog = achievementCatalog;
    final buf = StringBuffer('【成就】（${unlocked.length}/${catalog.length}）\n');
    for (final a in catalog) {
      final has = unlocked.contains(a.id);
      buf.writeln(
        '${has ? '✅' : '🔒'} ${a.name}${has ? ' — ${a.description}' : ''}',
      );
    }
    return buf.toString();
  }

  String formatPet() {
    final p = player!;
    if (p.petId == null && p.petName == null) {
      // 以前这里让人「去对角巷挑选」，但商店里没宠物卖，是条死路。
      // 现在 /宠物 购买 真能买，把清单直接列出来。
      return '【宠物】\n你还没有宠物。\n\n${formatPetShop()}';
    }
    final def = p.petId != null ? petById(p.petId!) : null;
    // R8：使用 petNarrativeConfig 去除「九尾灵狐羁绊≥60 化形」硬编码
    final cfg = p.petId != null ? petNarrativeConfig(p.petId!) : null;
    final buf = StringBuffer('【宠物】\n');
    buf.writeln('名字：${p.petName ?? def?.name ?? '未命名'}');
    if (def != null) {
      buf.writeln('种类：${def.species}');
      buf.writeln('能力：${def.abilities.join('、')}');
      if (cfg != null && cfg.bondGatedTransform) {
        buf.writeln(
          '特性：可化人形（羁绊≥${cfg.specialInteractionBondThreshold}后会触发人形互动）',
        );
      } else if (def.canTransform) {
        buf.writeln('特性：可化人形');
      }
      buf.writeln('简介：${def.description.split('\n').first}');
    }
    buf.write('羁绊：${p.petBond}/100\n');
    buf.writeln('互动：/宠物 喂食 ｜ /宠物 玩耍 ｜ /宠物 训练（喂食每日一次，玩耍/训练每日共一次）');
    final canTransformHint = (cfg?.bondGatedTransform ?? false)
        ? '${def?.species ?? '特殊宠物'}在羁绊≥${cfg?.specialInteractionBondThreshold ?? 60} 时会化为人形。'
        : '特殊宠物会在羁绊达到阈值后触发专属互动。';
    buf.writeln('羁绊≥40 时宠物可在决斗/探险中助战；$canTransformHint');
    return buf.toString();
  }

  // ==================== 信件互动系统 ====================

  /// 处理 /信 系列子指令：读 / 回 / 寄
  void closeCommandPanel() {
    if (commandResult == null) return;
    commandResult = null;
    notifyListeners();
  }

  /// 本地指令解析（设定文档第X部分指令系统）
  ///
  /// R1：优先走 CommandRegistry（数据驱动路由，自动生成帮助），
  /// 找不到匹配时 fallback 到旧 switch-case（双活方案确保平滑迁移）。

  @override
  bool handleLocalCommand(String command) {
    final p = player;
    if (p == null) return false;
    ensureCommandsRegistered();
    final parts = command.split(RegExp(r'\s+'));
    final cmd = parts[0];

    // 去掉前导 "/"，匹配注册表
    final slashless = cmd.startsWith('/') ? cmd.substring(1) : cmd;
    final registry = CommandRegistry.instance;
    final def = registry.find(slashless);
    if (def != null) {
      final ctx = CommandContext(parts.sublist(1), this as GameProviderBase);
      return def.handler(ctx);
    }

    // 未注册指令：给出候选提示，但**不覆盖当前剧情**。
    //
    // choices 只留一条「返回」是为了命中 processChoice 的 isPanelOutput 判定：
    // 命中后错误提示会进 commandResult 面板，而 currentNarrative / choices 被还原成
    // 输入前的样子，玩家关掉面板即可接着玩。
    // 早先这里把候选指令直接塞进 choices（3 条候选 + 1 条「查看全部指令」），
    // 于是 isPanelOutput 判定失败，错误提示被当成事件类指令永久覆写剧情，
    // 而玩家点任何一条候选都会继续触发新指令 —— 输错指令就等于丢掉当前一整段剧情。
    // 候选指令仍写在提示正文里（formatUnknownCommand 已逐条列出），信息没丢。
    if (cmd.startsWith('/')) {
      // 第16轮G：较长的「指令」大概率是玩家误加 / 的自由行动文本
      // （如 "/握紧魔杖起身准备出发"），降级为自由行动（返回 false 走
      // processChoice 叙事路径，那里会去掉 / 前缀）。
      // 短命令名（如 /状态统 拼错）保留候选提示。
      if (slashless.length >= 6) return false;
      // 第16轮E：清空 lastPlayerAction，避免下次 AI 把"/握紧魔杖..."原样
      // 当选项返回（A./握紧魔杖...）——玩家点选项又触发新一轮 → 死循环。
      lastPlayerAction = '';
      currentNarrative = formatUnknownCommand(slashless);
      choices = [GameChoice(text: '返回', action: '继续')];
      return true;
    }
    return false;
  }

  /// 未知指令提示：按「前缀/包含/编辑距离」给出最接近的几条候选，
  /// 比直接返回 false（把 /状态统计 当成自由行动文本发给 AI）友好得多。
  List<CommandDef> suggestCommands(String input) {
    final scored = <(CommandDef, int)>[];
    for (final c in CommandRegistry.instance.all) {
      var best = 1 << 30;
      for (final name in [c.primary, ...c.aliases]) {
        final n = name.replaceAll(' ', '');
        final s = input.replaceAll(' ', '');
        final d = n.startsWith(s) || s.startsWith(n)
            ? 0
            : (n.contains(s) || s.contains(n) ? 1 : levenshtein(s, n));
        if (d < best) best = d;
      }
      if (best <= 3) scored.add((c, best));
    }
    scored.sort((a, b) => a.$2.compareTo(b.$2));
    return scored.map((e) => e.$1).toList();
  }

  String formatUnknownCommand(String input) {
    final suggestions = suggestCommands(input);
    final buf = StringBuffer()..writeln('❓ 没有「/$input」这条指令。');
    if (suggestions.isNotEmpty) {
      buf.writeln('\n你是不是想输入：');
      for (final c in suggestions.take(4)) {
        buf.writeln('  /${c.primary} — ${c.helpText}');
      }
    } else {
      buf.writeln(
        '\n输入 /帮助 查看全部可用指令。'
        '\n如果你想把这段话当成自由行动交给 AI，请把开头的「/」去掉。',
      );
    }
    return buf.toString();
  }

  /// 标准编辑距离（候选词都很短，O(n·m) 完全够用）
  int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var cur = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        cur[j] = [
          prev[j] + 1,
          cur[j - 1] + 1,
          prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        ].reduce((x, y) => x < y ? x : y);
      }
      final t = prev;
      prev = cur;
      cur = t;
    }
    return prev[b.length];
  }
}
