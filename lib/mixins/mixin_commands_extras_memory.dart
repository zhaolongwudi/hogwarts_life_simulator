import '../data/cg_data.dart';
import '../data/wand_data.dart';
import '../data/offline_extras_data.dart';
import '../data/festival_data.dart';
import 'mixin_commands.dart';

/// 指令格式化·记忆档案族（r10-5 拆分自 mixin_commands_extras.dart）。
///
/// 覆盖：日记 / CG回放 / 档案 / 收藏回忆 / 节日历等格式化输出。
mixin GameCommandsExtrasMemoryMixin on GameCommandsMixin {
String formatDiary() {
    if (player!.cgRecords.isEmpty) {
      return '【日记 / CG图鉴】\n暂无解锁CG。在关键剧情节点将解锁专属CG。\n\n（输入 /日记 统计 查看进度；/日记 [编号] 查看详情）';
    }
    final buf = StringBuffer(
      '【日记 / CG图鉴】（已解锁 ${player!.cgRecords.length}/${allCgs().length}）\n',
    );
    for (final cg in allCgs()) {
      final rec = player!.cgRecords[cg.id];
      if (rec == null) continue;
      buf.writeln('· ${cg.id} ${cg.name}（${rec.unlockedDate}）');
    }
    return buf.toString();
  }

  /// CG 数量与等级分布（设定 7.5 /日记 统计）

  String formatDiaryStats() {
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

  String formatCgDetail(String id) {
    final cg = cgById(id);
    if (cg == null) {
      return '未找到 CG「$id」。可用编号见 /日记。';
    }
    final rec = player!.cgRecords[cg.id];
    if (rec == null) {
      return '【${cg.id} ${cg.name}】🔒 尚未解锁\n'
          '章节：${cg.chapter}｜等级：${cg.starText}\n'
          '解锁条件：${cg.conditionText}';
    }
    return '【${cg.id} ${cg.name}】${cg.starText}\n'
        '章节：${cg.chapter}\n'
        '解锁条件：${cg.conditionText}\n'
        '解锁于：${rec.unlockedDate}';
  }

  /// 重播指定 CG（精简版，设定 7.5 /日记 重播）

  String replayCg(String id) {
    final cg = cgById(id);
    if (cg == null) {
      return '未找到 CG「$id」。可用编号见 /日记。';
    }
    final rec = player!.cgRecords[cg.id];
    if (rec == null) {
      return '【${cg.id} ${cg.name}】尚未解锁，无法重播。\n解锁条件：${cg.conditionText}';
    }
    return '【重播 · ${cg.name}】${cg.starText}\n\n'
        '—— 记忆被重新点亮。\n\n'
        '你仿佛又回到了那一刻：旧羊皮纸与蜡烛的气味在空气里浮动，远处的钟声在石墙之间低低回荡，而「${cg.name}」的画面，如月光一般温柔地重新铺展在你眼前。\n\n'
        '（${cg.chapter}）解锁于 ${rec.unlockedDate}';
  }

  String formatArchive() {
    final p = player!;
    return '''【角色完整档案】
  姓名：${p.name}｜性别：${p.gender.isEmpty ? '未设定' : p.gender}
  家族：第 ${p.generation} 代${p.generation > 1 ? '（传承局）' : ''}
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

  /// P8：NPC 回忆册——已收集的回忆支线（好感达标后聊天自动解锁）。
  String formatCollectedMemories() {
    final p = player;
    if (p == null) return '【回忆册】暂无数据。';
    final collected = p.collectedMemories.toSet();
    if (collected.isEmpty) {
      return '【回忆册 · 0/${kNpcMemories.length}】\n'
          '与朋友深聊（提升好感），他们会在合适的时机讲起自己的往事。\n\n'
          '提示：好感越高、聊得越多，解锁的回忆越多。';
    }
    final buf = StringBuffer('【回忆册】已收集 ${collected.length}/${kNpcMemories.length}\n');
    for (final m in kNpcMemories) {
      final npc = npcRegistry[m.npcId];
      final owner = npc?.name ?? m.npcId;
      if (collected.contains(m.id)) {
        buf.writeln('\n◈ $owner ·《${m.title}》');
        buf.writeln(m.text);
      }
    }
    final pendingCount = kNpcMemories.length - collected.length;
    if (pendingCount > 0) {
      buf.writeln('\n—— 还有 $pendingCount 段回忆等待解锁 ——');
      buf.writeln('多和朋友们聊天，好感达标后他们会主动讲起往事。');
    }
    return buf.toString();
  }

  /// P9：/节庆 —— 霍格沃茨年度节庆日历。
  /// 列全年节日，标注「已庆祝 / 待庆祝 / 今年已过」，并单独提示下一个待庆祝的节日。
  String formatFestivalCalendar() {
    final ws = worldState;
    final year = ws.academicYear;
    final todayKey = ws.time.month * 100 + ws.time.day;
    final buf = StringBuffer('【霍格沃茨节庆 · 本学年 $year】\n');
    buf.writeln('这些日子年复一年地降临，每个学年只能庆祝一次。');
    FestivalDef? next;
    var celebratedCount = 0;
    for (final f in kFestivals) {
      final celebrated = ws.festivalCelebratedAt[f.id] == year;
      if (celebrated) {
        celebratedCount++;
      }
      final String tag;
      if (celebrated) {
        tag = '已庆祝';
      } else if (f.dateKey > todayKey) {
        tag = '待庆祝';
        next ??= f;
      } else {
        tag = '今年已过';
      }
      buf.writeln('\n${celebrated ? '✅' : '⬜'} ${f.dateLabel} · ${f.name}（$tag）');
    }
    buf.writeln('\n\n—— 本学年已庆祝 $celebratedCount/${kFestivals.length} ——');
    if (next != null) {
      buf.writeln('下一个节日：${next.dateLabel} · ${next.name}');
      buf.writeln('到那天做点什么，会有好收获。');
    } else {
      buf.writeln('本学年该过的节庆都过完了，期待下一个学年。');
    }
    return buf.toString();
  }
}
