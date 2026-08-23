import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../services/rate_limiter.dart';
import '../data/pet_data.dart';
import '../providers/app_provider.dart';
import '../models/npc.dart';
import '../models/game_systems.dart';
import '../services/save_service.dart';
import '../services/deepseek_service.dart';
import '../data/cg_data.dart';
import '../utils/story_text_renderer.dart';
import '../services/npc_chat_service.dart';
import '../data/world_rules.dart';
import '../data/event_anchors.dart';
import '../models/player.dart';
import '../utils/prompt_sanitizer.dart';
import '../data/trait_data.dart';
import '../data/npc_data.dart';
import '../prompts/prompts.dart';
import '../models/long_term_memory.dart';
import '../data/course_data.dart';
import '../data/balance_constants.dart';
import '../data/goal_data.dart';
import '../data/wand_data.dart';
import '../services/ai_router.dart';
import '../models/world_state.dart';
import '../utils/crash_logger.dart';
import '../providers/game_provider_base.dart';

mixin GameCommandsMixin on GameProviderBase {
  void closeCommandPanel() {
    if (commandResult == null) return;
    commandResult = null;
    notifyListeners();
  }

  /// 本地指令解析（设定文档第X部分指令系统）

  bool handleLocalCommand(String command) {
    final p = player;
    if (p == null) return false;
    final parts = command.split(RegExp(r'\s+'));
    final cmd = parts[0];

    switch (cmd) {
      case '/状态':
        currentNarrative = _formatStatus();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/时间':
        currentNarrative = _formatTime();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/地图':
        currentNarrative = _formatMap();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/通知':
        currentNarrative = _formatNotifications();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/帮助':
        currentNarrative = _formatHelp();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/关系':
        currentNarrative = formatRelationships();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/恋爱':
        currentNarrative = formatLove();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/声望':
        currentNarrative = formatReputation();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/舆论':
      case '/传闻':
        currentNarrative = formatRumors();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/课程':
        currentNarrative = formatCourses();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/课堂':
        if (parts.length >= 2 && parts[1] == '互动') {
          classroomInteraction();
        } else {
          currentNarrative = '【课堂互动】\n输入 /课堂 互动 触发当前课堂的互动环节（教授提问、实践练习、同桌互动、随机意外）。\n\n当前课表见 /课程。';
          choices = [GameChoice(text: '返回', action: '继续')];
        }
        return true;

      case '/收藏':
        currentNarrative = formatCollection();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/日记':
        if (parts.length >= 2 && parts[1] == '统计') {
          currentNarrative = _formatDiaryStats();
        } else if (parts.length >= 3 && parts[1] == '重播') {
          currentNarrative = _replayCg(parts[2]);
        } else if (parts.length >= 2) {
          currentNarrative = _formatCgDetail(parts[1]);
        } else {
          currentNarrative = _formatDiary();
        }
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/档案':
        currentNarrative = _formatArchive();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/成就':
        currentNarrative = _formatAchievements();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/宠物':
        currentNarrative = _formatPet();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/信':
        handleLetterCommand(parts);
        return true;

      case '/血缘':
        currentNarrative = formatBloodRelatives();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/联动':
        currentNarrative = '【联动系统】\n当前时代：${eraLabel(appProvider.era)}\n'
            '联动系统允许你在特定节点与其他时代剧情产生关联（例如在子世代时遇到亲世代留下的物品或信件）。\n'
            '当前已触发的联动痕迹：\n${worldState.timelineBranches.isEmpty ? '暂无。' : worldState.timelineBranches.map((b) => '· $b').join('\n')}';
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/世界演化':
        currentNarrative = formatWorldEvolution();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/新NPC':
        generateNewNPC();
        return true;

      case '/恋爱等待':
      case '/恋爱 等待':
        currentNarrative = formatLoveWaiting();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/恋爱阶段':
        currentNarrative = formatLoveStages();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/关系网络':
      case '/关系 网络':
        if (parts.length >= 4) {
          currentNarrative = formatNpcRelationship(parts[2], parts[3]);
        } else {
          currentNarrative = '请输入两位NPC的名字：/关系网络 [NPC1] [NPC2]';
        }
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/骨科':
      case '/骨科状态':
        currentNarrative = formatBoneMode();
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/目标':
        if (parts.length >= 2 && (parts[1] == '进度' || parts[1] == 'progress')) {
          currentNarrative = formatGoalProgress();
          choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        }
        if (parts.length >= 2) {
          final arg = parts.sublist(1).join(' ');
          LifeGoal? goal;
          final idx = int.tryParse(arg);
          if (idx != null && idx >= 1 && idx <= lifeGoalCatalog.length) {
            goal = lifeGoalCatalog[idx - 1];
          } else {
            goal = goalById(arg) ?? goalByName(arg);
          }
          if (goal != null) {
            p.currentGoal = goal.name;
            currentNarrative = '✅ 已设定人生目标：${goal.name}\n'
                '『${goal.description}』\n\n'
                '这条目标将牵引后续剧情方向，但你仍可自由行动。\n'
                '输入 /目标 可重新查看或更换。';
          } else {
            currentNarrative = '未找到目标"$arg"。输入 /目标 查看全部目标。';
          }
        } else {
          currentNarrative = _formatGoals();
        }
        choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/结局':
      case '/终章':
        _startEndingSequence();
        return true;

      case '/cheat':
        _handleCheat(parts);
        return true;
    }
    return false;
  }

  // ==================== 作弊指令（设定 8.1-8.5） ====================

  void _handleCheat(List<String> parts) {
    final p = player;
    if (p == null) return;
    if (parts.length < 2) {
      currentNarrative = _formatCheatHelp();
      choices = [GameChoice(text: '返回', action: '继续')];
      return;
    }
    final sub = parts[1];

    switch (sub) {
      case '好感':
      case 'affection':
        if (parts.length >= 4) {
          final nameKey = parts[2];
          NPC? npc;
          for (final n in npcRegistry.values) {
            if (n.name.contains(nameKey)) { npc = n; break; }
          }
          npc ??= npcRegistry[nameKey];
          if (npc == null) {
            final allNames = npcRegistry.values.map((n) => n.name).join('、');
            currentNarrative = '未找到NPC "$nameKey"。可用：$allNames';
            break;
          }
          final delta = int.tryParse(parts[3]);
          if (delta != null) {
            npc.affection = (npc.affection + delta).clamp(-100, 100);
            currentNarrative = '已调整「${npc.name}」的好感度：${npc.affection}（${npc.affectionStage}）';
          }
        }
        break;

      case '资源':
      case 'resources':
        if (parts.length >= 4) {
          final amount = int.tryParse(parts[2]) ?? 0;
          switch (parts[3]) {
            case '魔力':
            case 'mp':
              p.magic = (p.magic + amount).clamp(0, 100);
              break;
            case '精神力':
            case 'sp':
              p.spirit = (p.spirit + amount).clamp(0, 100);
              break;
            case '饱食':
            case 'sat':
              p.satiety = (p.satiety + amount).clamp(0, 100);
              break;
            case '精力':
            case 'energy':
              p.energy = (p.energy + amount).clamp(0, 100);
              break;
            case '生命':
            case 'hp':
              p.health = (p.health + amount).clamp(0, 100);
              break;
          }
          currentNarrative = '资源已调整。';
        }
        break;

      case '声望':
      case 'reputation':
        if (parts.length >= 4) {
          final amount = int.tryParse(parts[2]) ?? 0;
          p.playerReputation.add(parts[3], amount);
          currentNarrative =
              '${p.playerReputation.labelOf(parts[3])} ${p.playerReputation.get(parts[3])}';
        }
        break;

      case '时间':
      case 'time':
        if (parts.length >= 3) {
          final days = int.tryParse(parts[2]);
          if (days != null) fastForwardTime(days);
          currentNarrative = '时间已推进 $days 天。\n${worldState.timestamp}';
        }
        break;

      case '骨科':
        if (parts.length >= 3 && parts[2] == '无视') {
          p.boneMode = true;
          unlockAchievement('bone_mode');
          notifications.add('⚠️ 骨科模式已开启：禁忌的大门已为你敞开');
          worldState.addNarrativeEvent('⚠️ 骨科模式已开启：禁忌限制解除');
          bumpImpactScore(0.1, debugReason: '开启骨科模式(世界线剧烈扰动)');
          currentNarrative =
              '【骨科模式已开启】三代内血亲的禁忌限制已解除，但这意味着你的选择将付出更沉重的代价。';
        } else {
          currentNarrative = '使用方式：/cheat 骨科 无视（开启骨科模式）';
        }
        break;

      case '舆论':
      case 'rumor':
        if (parts.length >= 3 && parts[2] == '重置') {
          p.rumors.clear();
          currentNarrative = '已清除所有舆论传闻。';
        } else if (parts.length >= 4 && parts[2] == '清除') {
          final key = parts.sublist(3).join(' ');
          final before = p.rumors.length;
          p.rumors.removeWhere((r) => r.contains(key));
          currentNarrative = '已清除 ${before - p.rumors.length} 条相关传闻。';
        } else {
          currentNarrative = '使用方式：/cheat 舆论 清除 <关键词> 或 /cheat 舆论 重置';
        }
        break;

      case '解锁CG':
      case 'cg':
        if (parts.length >= 3) {
          final cg = cgById(parts[2]);
          if (cg != null) {
            unlockCG(cg);
            currentNarrative = '已解锁 CG：${cg.name}';
          } else {
            currentNarrative = '未找到该 CG，可用：${allCgs().map((c) => c.id).take(10).join(', ')}...';
          }
        }
        break;

      default:
        currentNarrative = _formatCheatHelp();
    }
    choices = [GameChoice(text: '返回', action: '继续')];
  }

  String _formatCheatHelp() {
    return '''【作弊指令】
  /cheat 好感 <NPC名> <数值>  — 调整好感度
  /cheat 资源 <数值> <魔力|精神力|饱食|精力|生命>
  /cheat 声望 <数值> <academic|social|combat|moral|leadership|dark>
  /cheat 时间 <天数>
  /cheat 骨科 无视 — 开启骨科模式
  /cheat 舆论 清除 <关键词> — 清除相关传闻
  /cheat 舆论 重置 — 清空所有传闻
  /cheat 解锁CG <CG编号> — 解锁指定CG''';
  }

  // ==================== 生成新NPC（增强版：多人格+多样化） ====================

  String _formatStatus() {
    final p = player!;
    final w = worldState;
    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  《哈利·波特·魔法纪元·人生状态》')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln()
      ..writeln('【时间】${w.timestamp}')
      ..writeln('【年龄】${calculateAge()}岁')
      ..writeln('【血统】${bloodStatusLabel(p.bloodType)}')
      ..writeln('【身份】${p.birthIdentity ?? '未设定'}')
      ..writeln('【所在地】${w.currentLocation ?? '未知'}')
      ..writeln('【学院】${p.house ?? '未分院'} · ${p.grade ?? 1}年级')
      ..writeln('【职业】${p.initialTalent ?? '学生'}')
      ..writeln('【财富】💰 ${p.galleons}金加隆 · 🏦 ${p.bankGalleons}古灵阁')
      ..writeln('【家庭】${p.familyBackground ?? '未设定'}')
      ..writeln('【社会地位】学院声望${p.houseReputation} · 魔法界声望${p.wizardingReputation} · 阵营声望${p.factionReputation}')
      ..writeln()
      ..writeln('【生存状态】')
      ..writeln('❤️ 生命：${p.health}/100')
      ..writeln('🔮 魔力：${p.magic}/100')
      ..writeln('🧠 精神力：${p.spirit}/100')
      ..writeln('🍗 饱食度：${p.satiety}/100')
      ..writeln('⚡ 精力：${p.energy}/100')
      ..writeln()
      ..writeln('【魔法能力】')
      ..writeln('魔法资质：${p.magicAptitude ?? '普通'}')
      ..writeln('主修天赋：${p.initialTalent ?? '未设定'}')
      ..writeln('已学魔咒：${p.learnedSpells.isEmpty ? '尚未学会任何魔咒' : '${p.learnedSpells.length}个咒语'}')
      ..writeln()
      ..writeln('【学院四维】')
      ..writeln('勇气：${p.houseDimensions['courage']}  智慧：${p.houseDimensions['wisdom']}')
      ..writeln('忠诚：${p.houseDimensions['loyalty']}  野心：${p.houseDimensions['ambition']}')
      ..writeln()
      ..writeln('【政治倾向】${p.politicalTendency ?? '未设定'}')
      ..writeln('【模拟风格】${p.simulationStyle ?? '混合模式'}')
      ..writeln('【恋爱状态】${p.loveState.status}${p.loveState.partnerName != null ? '（${p.loveState.partnerName}）' : ''}')
      ..writeln('【世界线变动率】${(p.worldLineDeviation * 100).toStringAsFixed(1)}%')
      ..writeln()
      ..writeln('【当前目标】${p.currentGoal ?? '尚未设定目标'}');
    return buf.toString();
  }

  String _formatTime() {
    final w = worldState;
    return '【当前时间】\n${w.timestamp}\n'
        '学年：${w.academicYear}\n'
        '学期：${termLabel(w.term)}\n'
        '流速模式：${flowModeLabel(w.timeFlowMode)}\n'
        '${w.specialMarkers.isEmpty ? '' : '特殊标记：${w.specialMarkers.join(' ')}'}';
  }

  String _formatMap() {
    return '''【霍格沃茨地图】
  当前地点：${worldState.currentLocation ?? '九又四分之三站台 / 霍格沃茨特快'}

  已知区域：
  🏰 城堡主楼（大礼堂、各学院公共休息室、图书馆、教室）
  🧙 各学院公共休息室
  🌳 禁林（高年级或特定课程开放）
  🧪 地下教室（魔药学、斯莱特林公共休息室）
  🏟️ 魁地奇球场
  🏘️ 霍格莫德村（周末开放）
  🧹 天文塔
  📚 图书馆（含禁书区）

  各NPC当前位置：
  ${npcRegistry.values.where((n) => n.isAlive).take(6).map((n) => '· ${n.name}：${n.currentLocation}').join('\n')}''';
  }

  String _formatNotifications() {
    if (notifications.isEmpty) {
      return '【通知】\n暂无新通知。';
    }
    return '【通知】\n${notifications.reversed.take(10).map((n) => '· $n').join('\n')}';
  }

  String _formatHelp() {
    return '''【指令系统】
  /状态 — 查看角色完整状态
  /时间 — 查看当前时间与特殊标记
  /地图 — 查看霍格沃茨地图与NPC位置
  /通知 — 查看未读通知
  /帮助 — 查看指令说明
  /关系 — 查看所有NPC好感度与关系
  /恋爱 — 查看恋爱状态
  /声望 — 查看声望档案
  /舆论 — 查看校园里的传闻/谣言
  /课程 — 查看课程表与进度
  /课堂 互动 — 触发课堂互动（提问/练习/同桌/意外）
  /收藏 — 查看收藏品
  /日记 — 查看CG图鉴（/日记 统计·/日记 [编号]·/日记 重播 [编号]）
  /档案 — 查看角色完整档案
  /成就 — 查看成就
  /宠物 — 查看宠物状态
  /信 — 查看收到的信件（/信 读 [编号] · /信 回 [编号] [内容] · /信 寄 [NPC] [内容]）
  /新NPC — 生成一位新NPC（每学年限4次）
  /血缘 — 查看血缘亲属
  /联动 — 查看时代联动痕迹
  /目标 — 查看/设定人生目标（/目标 [编号]）
  /结局 — 生成终章报告
  /cheat — 作弊指令（详见 /cheat）''';
  }

  // ==================== 人生目标系统 ====================

  String _formatGoals() {
    final p = player;
    final current = p?.currentGoal;
    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  《人生目标》')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln()
      ..writeln('【当前目标】${(current == null || current.isEmpty) ? '尚未设定' : current}');
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

  void _startEndingSequence() {
    if (player == null) return;
    isLoading = true;
    loadingStage = '正在书写你的终章…';
    currentNarrative = '';
    choices = [];
    notifyListeners();
    unawaited(generateEnding());
  }

  String _formatDiary() {
    if (player!.cgRecords.isEmpty) {
      return '【日记 / CG图鉴】\n暂无解锁CG。在关键剧情节点将解锁专属CG。\n\n（输入 /日记 统计 查看进度；/日记 [编号] 查看详情）';
    }
    final buf = StringBuffer('【日记 / CG图鉴】（已解锁 ${player!.cgRecords.length}/${allCgs().length}）\n');
    for (final cg in allCgs()) {
      final rec = player!.cgRecords[cg.id];
      if (rec == null) continue;
      buf.writeln('· ${cg.id} ${cg.name}（${rec.unlockedDate}）');
    }
    return buf.toString();
  }

  /// CG 数量与等级分布（设定 7.5 /日记 统计）

  String _formatDiaryStats() {
    final unlocked = player!.cgRecords;
    final all = allCgs();
    final byStars = <int, int>{2: 0, 3: 0, 4: 0, 5: 0};
    final byChapter = <String, int>{};
    for (final cg in all) {
      if (unlocked.containsKey(cg.id)) {
        byStars[cg.stars] = (byStars[cg.stars] ?? 0) + 1;
        byChapter[cg.chapter] = (byChapter[cg.chapter] ?? 0) + 1;
      }
    }
    final buf = StringBuffer()
      ..writeln('【日记统计】')
      ..writeln('已解锁：${unlocked.length}/${all.length}')
      ..writeln()
      ..writeln('【等级分布】')
      ..writeln('★★ 二星：${byStars[2] ?? 0}')
      ..writeln('★★★ 三星：${byStars[3] ?? 0}')
      ..writeln('★★★★ 四星：${byStars[4] ?? 0}')
      ..writeln('★★★★★ 五星：${byStars[5] ?? 0}')
      ..writeln()
      ..writeln('【章节分布】');
    if (byChapter.isEmpty) {
      buf.writeln('（暂无）');
    } else {
      for (final e in byChapter.entries) {
        buf.writeln('· ${e.key}：${e.value}');
      }
    }
    return buf.toString();
  }

  /// 查看指定 CG 详情（设定 7.5 /日记 [编号]）

  String _formatCgDetail(String id) {
    final cg = cgById(id);
    if (cg == null) {
      return '未找到 CG「$id」。可用编号见 /日记。';
    }
    final rec = player!.cgRecords[cg.id];
    if (rec == null) {
      return '【${cg.id} ${cg.name}】🔒 尚未解锁\n'
          '章节：${cg.chapter}｜等级：${cg.starText}\n'
          '解锁条件：${cg.condition}';
    }
    return '【${cg.id} ${cg.name}】${cg.starText}\n'
        '章节：${cg.chapter}\n'
        '解锁条件：${cg.condition}\n'
        '解锁于：${rec.unlockedDate}';
  }

  /// 重播指定 CG（精简版，设定 7.5 /日记 重播）

  String _replayCg(String id) {
    final cg = cgById(id);
    if (cg == null) {
      return '未找到 CG「$id」。可用编号见 /日记。';
    }
    final rec = player!.cgRecords[cg.id];
    if (rec == null) {
      return '【${cg.id} ${cg.name}】尚未解锁，无法重播。\n解锁条件：${cg.condition}';
    }
    return '【重播 · ${cg.name}】${cg.starText}\n\n'
        '—— 记忆被重新点亮。\n\n'
        '你仿佛又回到了那一刻：旧羊皮纸与蜡烛的气味在空气里浮动，远处的钟声在石墙之间低低回荡，而「${cg.name}」的画面，如月光一般温柔地重新铺展在你眼前。\n\n'
        '（${cg.chapter}）解锁于 ${rec.unlockedDate}';
  }

  String _formatArchive() {
    final p = player!;
    return '''【角色完整档案】
  姓名：${p.name}｜性别：${p.gender.isEmpty ? '未设定' : p.gender}
  生日：${p.birthDay ?? '未设定'}｜出生年份：${p.birthYear}
  血统：${bloodStatusLabel(p.bloodType)}｜出生地：${p.birthLocation}
  学院：${p.house ?? '未分院'}｜年级：${p.grade ?? 1}
  性取向：${p.sexOrientation ?? '未设定'}
  魔杖：${p.wandId != null ? wandById(p.wandId!)?.name ?? p.wandId : '未选择'}
  宠物：${p.petName ?? '无'}
  外貌：${p.appearance ?? '未设定'}
  家族背景：${p.familyBackground ?? '未设定'}
  童年经历：${p.childhoodExperiences.isEmpty ? '未设定' : p.childhoodExperiences.join('；')}
  信仰与价值观：${p.beliefs ?? '未设定'}
  初始天赋：${p.initialTalent ?? '未设定'}
  性格特质：${p.personalityTraits.isEmpty ? '未设定' : p.personalityTraits.join('、')}
  当前目标：${p.currentGoal ?? '无'}''';
  }

  String _formatAchievements() {
    final unlocked = player!.achievements;
    final catalog = achievementCatalog;
    final buf = StringBuffer('【成就】（${unlocked.length}/${catalog.length}）\n');
    for (final a in catalog) {
      final has = unlocked.contains(a.id);
      buf.writeln('${has ? '✅' : '🔒'} ${a.name}${has ? ' — ${a.description}' : ''}');
    }
    return buf.toString();
  }

  String _formatPet() {
    final p = player!;
    if (p.petId == null && p.petName == null) {
      return '【宠物】\n你还没有宠物。可以去对角巷挑选一只猫头鹰、猫或蟾蜍。';
    }
    final def = p.petId != null ? petById(p.petId!) : null;
    final buf = StringBuffer('【宠物】\n');
    buf.writeln('名字：${p.petName ?? def?.name ?? '未命名'}');
    if (def != null) {
      buf.writeln('种类：${def.species}');
      buf.writeln('能力：${def.abilities.join('、')}');
      if (def.canTransform) buf.writeln('特性：可化人形（羁绊≥60后会触发人形互动）');
      buf.writeln('简介：${def.description.split('\n').first}');
    }
    buf.write('羁绊：${p.petBond}/100\n宠物可以帮你送信、在冒险中提供帮助。');
    return buf.toString();
  }

  // ==================== 信件互动系统 ====================

  /// 处理 /信 系列子指令：读 / 回 / 寄
}
