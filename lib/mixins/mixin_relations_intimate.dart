/// 亲密关系子系统（r6-4 拆分自 mixin_relations.dart）。
///
/// 覆盖：骨科模式状态与推进（achievement id 'bone_mode' 序列化协议，
/// 永不可改名）、NPC 主动表白机制。与主关系链双向独立：零 AI 调用、
/// 私有符号全自包含，仅通过 [GameRelationsMixin] 的 on 链复用基础工具。
library;

import '../data/course_data.dart';
import '../data/house_data.dart';
import '../data/world_rules.dart';
import '../data/cg_data.dart';
import '../data/game_config_rules.dart';
import '../data/balance_constants.dart';
import '../data/collectible_data.dart';
import '../utils/debug_log.dart';
import '../models/game_systems.dart';
import '../models/npc.dart';
import '../models/player.dart';
import 'mixin_relations.dart';

mixin GameRelationsIntimateMixin on GameRelationsMixin {
  // ==================== 骨科模式状态 ====================

  @override
  String formatBoneMode() {
    if (player == null) return '【骨科模式】\n尚未创建角色。';
    final bloodRel = player!.bloodRelatives;
    final buf = StringBuffer(
      player!.boneMode
          ? '【骨科模式】已开启\n允许与血缘亲属发展浪漫关系。\n\n'
          : '【骨科模式】已关闭\n无法与血缘亲属发展浪漫关系。\n\n',
    );
    if (bloodRel.isEmpty) {
      buf.writeln('当前血缘亲属列表：（暂无记录）');
    } else {
      buf.writeln('当前血缘亲属列表：');
      for (final name in bloodRel.take(10)) {
        final npc = npcRegistry.values.firstWhere(
          (n) =>
              n.name == name || name.contains(n.name) || n.name.contains(name),
          orElse: () => NPC(id: '', name: name, house: ''),
        );
        final extra = npc.house.isNotEmpty ? ' · ${npc.house}' : '';
        buf.writeln('· $name$extra');
      }
      if (bloodRel.length > 10) buf.writeln('  ……等共 ${bloodRel.length} 位');
    }
    return buf.toString();
  }

  /// 阵营倾向的文字解读，让「阵营声望」这个派生数字有实际含义
  String _factionLeanLabel(int lean) {
    if (lean >= 40) return '（黑暗阵营一方颇有名气）';
    if (lean >= 15) return '（被黑暗势力注意到）';
    if (lean <= -40) return '（凤凰社一方的可靠盟友）';
    if (lean <= -15) return '（偏向邓布利多一方）';
    return '（尚未明确站位）';
  }

  @override
  String formatReputation() {
    final rep = player!.playerReputation;
    final p = player!;
    return '''【声望档案】
  学术声望：${rep.academic}（${reputationGrade(rep.academic)}）
  社交声望：${rep.social}（${reputationGrade(rep.social)}）
  战斗声望：${rep.combat}（${reputationGrade(rep.combat)}）
  道德声望：${rep.moral}（${reputationGrade(rep.moral)}）
  领导声望：${rep.leadership}（${reputationGrade(rep.leadership)}）
  黑魔法声望：${rep.dark}（${reputationGrade(rep.dark)}）

  学院声望：${p.houseReputation}
  魔法界声望：${p.wizardingReputation}（五维均值，黑魔法不计入）
  阵营声望：${p.factionReputation}${_factionLeanLabel(p.factionReputation)}
  （阵营声望 = 黑魔法声望 − 道德声望）''';
  }

  /// 舆论/传闻系统（设定文档 7.3 / 第十三部分）

  @override
  String formatRumors() {
    final rumors = player!.rumors;
    if (rumors.isEmpty) {
      return '【舆论】\n目前校园里还没有关于你的传闻。你只是个普通学生——至少现在还是。';
    }
    final buf = StringBuffer('【舆论 / 传闻】\n');
    for (final r in rumors) {
      buf.writeln('· $r');
    }
    buf.writeln('\n（输入 /cheat 舆论 清除 可删除传闻）');
    return buf.toString();
  }

  /// 追加一条传闻（去重 + 保留最近 20 条，避免无限膨胀）
  /// 传闻内容支持模板变量，可自动融入 NPC 名称和地点

  @override
  void addRumor(String text) {
    final p = player;
    if (p == null) return;
    if (p.rumors.contains(text)) return;
    p.rumors.insert(0, text);
    p.rumorDates[text] = worldState.time.absoluteDayIndex;
    if (p.rumors.length > 20) {
      p.rumors.removeRange(20, p.rumors.length);
      p.rumorDates.removeWhere((k, _) => !p.rumors.contains(k));
    }
  }

  @override
  String formatCourses() {
    final era = appProvider.era;
    final buf = StringBuffer('【课程系统】\n必修课：\n');
    for (final c in requiredCourses) {
      buf.writeln('· ${c.name}（${professorName(c.id, c.professor, era)}）');
    }
    buf.writeln('\n选修课（三年级起，至少选2门）：');
    for (final c in electiveCourses) {
      buf.writeln('· ${c.name}（${professorName(c.id, c.professor, era)}）');
    }
    buf.writeln('\n（输入 /课堂 互动 进入当前课堂的互动环节）');
    return buf.toString();
  }

  /// 课堂互动（设定 10.3，全程本地判定，零 token 消耗）

  @override
  void classroomInteraction() {
    final p = player;
    if (p == null) return;
    // 每日上限 + 成本：课堂互动有实打实的收益（声望/熟练度/好感），
    // 不限次数就能一天刷满——和决斗/禁林一样按天封顶。
    if (!canDoDaily('classroom')) {
      currentNarrative =
          '今天的课已经上得够多了。你的笔记写满了三页羊皮纸，'
          '再待在教室里也只是让墨水瓶空得更快。\n\n（课堂互动每日上限 3 次，明天再来）';
      choices = [GameChoice(text: '返回', action: '继续')];
      return;
    }
    if (p.energy < 10) {
      currentNarrative =
          '你太累了，连魔杖都快握不稳——这种状态上课只会被教授点名批评。'
          '先休息恢复精力吧。\n\n（精力不足 10）';
      choices = [GameChoice(text: '返回', action: '继续')];
      return;
    }
    recordDailyActivity('classroom');
    p.energy = (p.energy - 8).clamp(0, 100);
    advanceTimeForAction('上课');
    final roll = random.nextInt(100);
    String result;

    if (roll < 40) {
      // 教授提问：影响学术声望
      final correct = random.nextBool();
      if (correct) {
        p.playerReputation.add('academic', 2);
        // 【Bug 3 修复 · 2026-09-21】原来 classroomInteraction 完全不给学院杯加分，
        // 导致 table 里写的 "课堂 +3/+8" 只是纸上数字——玩家七年累计的学院分永远
        // 追不上 rival 按天累加的 baseline。这里把「教授点头」这一类正向结果接上
        // Balance.houseCupActivityPoints['classroom'] 的实际加分路径。仅给成功分支
        // 加分；答错不奖、意外也不奖——保留稀有回报的价值感。
        final classPts = Balance.houseCupActivityPoints['classroom'] ?? 0;
        if (classPts > 0) addHouseCupPoints(classPts, '课堂·教授赞赏');
        result =
            '【课堂互动 · 教授提问】\n'
            '教授的目光扫过教室，最后停在你身上，抛出一个刁钻的问题。\n'
            '你略一思索，给出了答案。教室里响起几声低低的惊叹，教授罕见地点了点头。\n'
            '\n学术声望 +2　·　${houseDisplayName(p.house ?? '', fallback: '霍格沃茨')} $classPts 分';
      } else {
        result =
            '【课堂互动 · 教授提问】\n'
            '教授突然点你的名。你心头一跳，答案卡在喉咙里，最后只好摇了摇头。\n'
            '几个同学投来同情的目光，你决定下次好好预习。\n'
            '\n（本次无变化）';
      }
    } else if (roll < 70) {
      // 实践操作：影响技能熟练度
      const skills = ['魔咒学', '变形术', '魔药学', '草药学'];
      const skillAttrs = {
        '魔咒学': 'spell_understanding',
        '变形术': 'transfiguration',
        '魔药学': 'potions',
        '草药学': 'herbology',
      };
      final skill = skills[random.nextInt(skills.length)];
      final attr = skillAttrs[skill]!;
      p.attributes[attr] = ((p.attributes[attr] ?? 50) + 1).clamp(0, 100);
      // 【Bug 3 修复】同一策略：实操成功也归学院杯（稳定积累型）。
      final classPts = Balance.houseCupActivityPoints['classroom'] ?? 0;
      if (classPts > 0) addHouseCupPoints(classPts, '课堂·实操出色');
      result =
          '【课堂互动 · 实践操作】\n'
          '你握紧魔杖，全神贯注地练习$skill。魔杖尖端的光芒稳定而流畅，眼前的材料随着你的咒语乖巧地变化。\n'
          '\n$skill 熟练度 +1　·　${houseDisplayName(p.house ?? '', fallback: '霍格沃茨')} $classPts 分';
    } else if (roll < 90) {
      // 同桌互动：影响 NPC 好感
      final alive = npcRegistry.values.where((n) => n.isAlive).toList();
      if (alive.isNotEmpty) {
        final npc = alive[random.nextInt(alive.length)];
        final delta = 1 + random.nextInt(2); // +1 ~ +2
        updateNpcAffection(npc.id, delta, reason: '课堂同桌');
        result =
            '【课堂互动 · 同桌】\n'
            '趁教授转身，${npc.name}悄悄递来一张纸条，上面写着刚才没听懂的笔记要点。\n'
            '你冲对方感激地笑了笑。\n'
            '\n与 ${npc.name} 的好感 +$delta';
      } else {
        result = '【课堂互动 · 同桌】\n你环顾四周，身边的座位空着，只得独自琢磨刚才的内容。';
      }
    } else {
      // 特殊意外：R12 使用 classAccidentPool（支持科目筛选 + 通用池，去除「斯内普教授」硬编码特判）
      // 注意：WorldState 没有持久化 currentCourse 字段（玩家可以任何时间点调用 /课堂 互动），
      //       此处从全量课程表里随机抽 1 门课名作为"当前课"做科目筛选，和同函数"实践操作"分支保持一致。
      final all = allCourses();
      final currentCourse = all[random.nextInt(all.length)].name;
      final candidates = classAccidentPool.where((e) {
        if (e.subjectFilter.isEmpty) return true;
        return e.subjectFilter.any(
          (k) => currentCourse.contains(k) || k.contains(currentCourse),
        );
      }).toList();
      final pool = candidates.isNotEmpty ? candidates : classAccidentPool;
      final text = pool[random.nextInt(pool.length)].text;
      result = '【课堂互动 · 意外】\n$text\n\n（一段课堂上的小插曲，世界线纹丝不动）';
    }

    currentNarrative = result;
    choices = [GameChoice(text: '继续', action: '继续')];
  }

  @override
  String formatCollection() {
    final p = player;
    if (p == null) return '你还没有开始收集。';
    final buf = StringBuffer(
      '【收藏】'
      '（${p.collection.length}/${kCollectibleCatalog.length}）\n',
    );
    if (p.collection.isEmpty) {
      // 以前的空态文案许诺了两件根本拿不到的东西：「巧克力蛙画片」（当时
      // 没有掉落逻辑）和「日记本」（这个东西在任何地方都不存在）。改成写
      // 实：只说真的有来源的那几样。
      buf.writeln('还一件都没有。可以这么开始：');
      buf.writeln('· 吃一只「巧克力蛙」，包装里会附赠著名巫师画片；');
      buf.writeln('· 去对角巷买「魁地奇徽章」，买下就收进册子；');
      buf.writeln('· 进 /禁林 转转，运气好能捡到独角兽尾毛。');
      return buf.toString();
    }
    for (final series in collectibleSeries) {
      final all = collectiblesInSeries(series);
      final owned = all.where((c) => p.collection.contains(c.id)).toList();
      buf.writeln();
      buf.writeln('【$series】${owned.length}/${all.length}');
      for (final c in all) {
        final has = p.collection.contains(c.id);
        buf.writeln(
          '${has ? '✅' : '🔒'} ${has ? c.name : '？？？'}'
          '${has ? '　${c.starText}' : ''}',
        );
      }
    }
    final unknown = p.collection
        .where((id) => collectibleById(id) == null)
        .toList();
    if (unknown.isNotEmpty) {
      buf.writeln();
      buf.writeln('（有 ${unknown.length} 件旧存档里的收藏品已不在目录中）');
    }
    return buf.toString();
  }

  /// [parts] 为「去掉 /信 命令本身」后的子参数列表，parts[0] 即子命令。
  @override
  void handleLetterCommand(List<String> parts) {
    void back() {
      choices = [GameChoice(text: '返回', action: '继续')];
    }

    if (parts.isEmpty) {
      currentNarrative = _formatLetters();
      back();
      return;
    }

    switch (parts[0]) {
      case '读':
        final idx = int.tryParse(parts.length > 1 ? parts[1] : '');
        currentNarrative = idx == null
            ? '【信件】\n请输入信件编号：/信 读 [编号]'
            : _formatLetterDetail(idx);
        back();
        return;
      case '回':
        final idx = int.tryParse(parts.length > 1 ? parts[1] : '');
        if (idx == null) {
          currentNarrative = '【回信】\n请输入：/信 回 [编号] [回信内容]';
        } else {
          final content = parts.length > 2 ? parts.sublist(2).join(' ') : '';
          currentNarrative = _replyToLetter(idx, content);
        }
        back();
        return;
      case '寄':
        final name = parts.length > 1 ? parts[1] : '';
        final content = parts.length > 2 ? parts.sublist(2).join(' ') : '';
        currentNarrative = name.isEmpty
            ? '【寄信】\n请输入：/信 寄 [NPC名字] [信件内容]'
            : _sendLetterToNpc(name, content);
        back();
        return;
      default:
        currentNarrative = _formatLetters();
        back();
        return;
    }
  }

  String _formatLetters() {
    final letters = player!.letters;
    if (letters.isEmpty) {
      return '【信件】\n暂无信件。\n\n你可以通过猫头鹰给某人寄信：/信 寄 [NPC名字] [内容]';
    }
    final buf = StringBuffer()
      ..writeln('【信件】共 ${letters.length} 封（✉ 表示未读）')
      ..writeln();
    for (int i = 0; i < letters.length; i++) {
      final l = letters[i];
      final mark = l.read ? '　' : '✉';
      buf.writeln('[$mark ${i + 1}] ${l.sender}（${l.date}）');
      final preview = l.content.length > 26
          ? '${l.content.substring(0, 26)}…'
          : l.content;
      buf.writeln('      $preview');
      buf.writeln();
    }
    buf.writeln('用法：/信 读 [编号] · /信 回 [编号] [内容] · /信 寄 [NPC名字] [内容]');
    return buf.toString();
  }

  String _formatLetterDetail(int index) {
    final letters = player!.letters;
    if (index < 1 || index > letters.length) {
      return '【信件】\n没有第 $index 封信。当前共 ${letters.length} 封。';
    }
    final l = letters[index - 1];
    l.read = true;
    return '【书信】\n寄信人：${l.sender}\n日期：${l.date}\n\n${l.content}';
  }

  /// 寄信给 NPC（本地逻辑，不消耗 AI token）

  String _sendLetterToNpc(String npcName, String content) {
    final p = player;
    if (p == null) return '【寄信】\n尚未创建角色。';
    if (content.trim().isEmpty) {
      return '【寄信】\n请写明信件内容：/信 寄 [$npcName] [信件内容]';
    }

    NPC? npc;
    for (final n in npcRegistry.values) {
      if (n.name.contains(npcName) || npcName.contains(n.name)) {
        npc = n;
        break;
      }
    }
    if (npc == null) {
      return '【寄信】\n你没有找到名叫「$npcName」的人。可输入 /关系 查看已认识的NPC。';
    }
    if (!npc.isAlive) {
      return '【寄信】\n${npc.name}已经无法收到你的信了……';
    }

    // 寄信耗时（猫头鹰往返）
    worldState.time.advanceMinutes(15);

    // 信件是低成本的维系方式：好感小幅提升
    final stage = affectionStageFor(npc.affection);
    int change = 1;
    if (stage == '友好' || stage == '信任') change = 2;
    if (stage == '亲密' || stage == '深爱' || stage == '灵魂伴侣') change = 3;
    updateNpcAffection(npc.id, change, reason: '寄信联络');

    // 对方回信（本地模板，不消耗 AI token）
    _addLetter(sender: npc.name, content: _generateLetterReply(npc));

    final warm = stage == '死敌' || stage == '宿怨' || stage == '反感'
        ? '（对方似乎并不领情）'
        : '（你们的关系似乎更近了一点）';
    return '【寄信】\n你把写好的信交给猫头鹰，目送它振翅飞向${npc.name}。$warm\n\n几天后，猫头鹰带回了回信——输入 /信 读 查看最新一封。';
  }

  /// 回信给某封信的寄信人

  String _replyToLetter(int index, String content) {
    final letters = player!.letters;
    if (index < 1 || index > letters.length) {
      return '【回信】\n没有第 $index 封信。当前共 ${letters.length} 封。';
    }
    final letter = letters[index - 1];
    letter.read = true;
    return _sendLetterToNpc(letter.sender, content);
  }

  /// 添加一封来信
  /// 上限保护：最多保留 50 封信，超出时优先删除最旧的已读信件
  void _addLetter({required String sender, required String content}) {
    player!.letters.add(
      Letter(
        id: 'L${DateTime.now().microsecondsSinceEpoch}',
        sender: sender,
        content: content,
        date: worldState.time.formatDate(),
      ),
    );
    if (player!.letters.length > 50) {
      // 优先删除最旧的已读信件；若全部未读则删除最旧的
      final readIdx = player!.letters.indexWhere((l) => l.read);
      if (readIdx >= 0) {
        player!.letters.removeAt(readIdx);
      } else {
        player!.letters.removeAt(0);
      }
    }
    notifications.add('📬 收到来自 $sender 的信');
  }

  /// 根据好感阶段生成 NPC 回信（本地模板）

  String _generateLetterReply(NPC npc) {
    final stage = affectionStageFor(npc.affection);
    final name = npc.name;
    switch (stage) {
      case '死敌':
      case '宿怨':
      case '反感':
        return '（$name读完你的信后，随手把它揉成一团扔进了壁炉。）\n你对$name的来信，只换来了冷冰冰的沉默。';
      case '冷漠':
      case '中立':
        return '几天后，一只猫头鹰送来$name的回信，措辞礼貌而疏远：\n「来信收悉，谢谢。祝好。」';
      case '好感':
      case '友好':
        return '$name的回信语气轻快：\n「收到你的信啦，很高兴。等我忙完这阵子，我们在礼堂一起喝杯南瓜汁吧。」';
      case '信任':
      case '亲密':
        return '$name的回信写得很长，字里行间透着真诚与信任，末了还留了一句：「有什么心事，随时告诉我。」';
      case '深爱':
      case '灵魂伴侣':
        return '$name的回信字迹微微颤抖，情意几乎溢出纸面：「你的信我读了一遍又一遍……等见面时，我有话想亲口对你说。」';
      default:
        return '几天后，$name简短地回了信。';
    }
  }

  @override
  String formatBloodRelatives() {
    if (player!.bloodRelatives.isEmpty) {
      return '【血缘】\n未设定血缘亲属关系。三代内血亲不可攻略（除非开启骨科模式）。';
    }
    return '【血缘】\n${player!.bloodRelatives.join('、')}\n${player!.boneMode ? '（骨科模式已开启，禁忌限制解除）' : '（三代内血亲不可攻略）'}';
  }

  /// 月度世界演化报告（第47章）

  @override
  String formatWorldEvolution() {
    final w = worldState;
    final eraName = eraLabel(appProvider.era);
    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  《月度世界演化报告》')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln()
      ..writeln('【当前时代】$eraName')
      ..writeln('【时间】${w.timestamp}')
      ..writeln('【学年】${w.academicYear}')
      ..writeln()
      ..writeln('【九大文明支柱状态】');
    for (int i = 0; i < kCivilizationPillars.length; i++) {
      buf.writeln('  ${i + 1}. ${kCivilizationPillars[i]}');
    }
    buf
      ..writeln()
      ..writeln('【世界五层结构】');
    for (final layer in kWorldLayers) {
      buf.writeln('  $layer');
    }
    buf
      ..writeln()
      ..writeln('【区域危险度】');
    for (final zone in kDangerZones) {
      buf.writeln('  $zone');
    }
    buf
      ..writeln()
      ..writeln('【货币体系】$kCurrencyRate')
      ..writeln()
      ..writeln('【当前地点】${w.currentLocation ?? '未知'}')
      ..writeln('【天气】${w.weather ?? '晴朗'}')
      ..writeln()
      ..writeln('【近期世界事件】')
      ..writeln(
        w.recentEvents.isEmpty
            ? '暂无记录'
            : w.recentEvents.map((e) => '· ${e.text}').join('\n'),
      )
      ..writeln()
      ..writeln('【世界线变动率】${(player?.worldLineDeviation ?? 0) * 100}%')
      ..writeln()
      ..writeln('【终极原则】');
    for (final principle in kUltimatePrinciples) {
      buf.writeln('  $principle');
    }
    return buf.toString();
  }

  @override
  String formatAffections({int maxEntries = 8}) {
    final list =
        player == null
              ? const <NPC>[]
              : npcRegistry.values
                    .where(
                      (n) =>
                          n.introduced &&
                          (n.affection.abs() >= 30 ||
                              player!.relationships.containsKey(n.id)),
                    )
                    .toList()
          ..sort((a, b) => b.affection.compareTo(a.affection));
    if (list.isEmpty) return '暂无深入关系';
    final entries = list
        .take(maxEntries)
        .map((n) => '${n.name}(${n.affection})')
        .join('、');
    if (list.length > maxEntries) return '$entries 等${list.length}人';
    return entries;
  }

  // ==================== NPC 主动表白机制 ====================

  /// 恋爱链路接线：记录一次浪漫事件（表白机制要求暧昧期≥2次浪漫事件）。
  /// 只记录发生在暧昧/亲密阶段或已确定恋爱关系中的互动，纯友情不算。
  @override
  void recordRomanticEventFor(NPC npc) {
    final p = player;
    if (p == null) return;
    final love = p.loveState;
    final stage = love.stageFor(npc.name);
    if (love.status == '恋爱' && love.partnerId == npc.id) {
      love.recordRomanticEvent(npc.name);
      return;
    }
    if (stage == '暧昧' || stage == '亲密') {
      love.recordRomanticEvent(npc.name);
      worldState.addNarrativeEvent(
        '💗 你和${npc.name}之间多了一段心动回忆。',
        turn: turnCount,
      );
    }
  }

  @override
  void checkNPCConfessions() {
    final p = player;
    if (p == null || p.loveState.status != '单身') return;
    if (p.loveState.awaitingConfession) return;

    for (final n in npcRegistry.values) {
      n.isConsideringConfession = false;
    }

    // 【Bug 6 修复 · 2026-09-21】原来「好感≥85 + 暧昧阶段 + romanticEvents≥2 + crushMatureDays≥14」
    // 是**五个 AND 全满足**才进入掷骰——30 天无互动起走 affectionDriftPerWeekMin~Max 衰减 1~2/周，
    // 攒 85 的过程中断联就掉；即使不断联，也要精确命中两次"浪漫事件"关键词才算通过。
    // 「努力几十小时仍被前置卡死」正是原报告 Bug 6 描述的挫败感来源。
    //
    // 现在的策略：
    //   - 硬门槛只留两条真稀缺：affection ≥ 85 + stage ∈ {暧昧, 亲密}
    //     （这两条已经足够保证 NPC 不会随便向玩家表白）
    //   - romanticEvents 改为**软门槛**：不再一票否决，而是作为掷骰时的**概率乘数**
    //     ——0 次 ×0.3 / 1 次 ×0.7 / ≥2 次 ×1.0。玩家能感觉"关系越深表白越早落地"，
    //     但不会被"我明明已经很努力了却凑不够 2 次浪漫事件"这种数字陷阱挡住。
    //   - crushMatureDays 同样保持软行为（沿用旧逻辑：只有 currentCrushName==n.name
    //     时才强校验窗口，否则视为已成熟）。
    final currentDay = worldState.time.absoluteDayIndex;
    final candidates = npcRegistry.values.where((n) {
      if (!n.isAlive ||
          n.affection < Balance.confessionMinAffection ||
          n.confessed) {
        return false;
      }
      // 取向双向校验：NPC 喜欢玩家性别 且 玩家喜欢 NPC 性别（详见 NPC.orientationMatches）
      if (!NPC.orientationMatches(
        npcGender: n.gender,
        npcOrientation: n.sexOrientation,
        playerGender: p.gender,
        playerOrientation: p.sexOrientation,
      )) {
        return false;
      }
      // 检查关系阶段（真正的稀缺门槛之一）
      final stage = p.loveState.stageFor(n.name);
      if (stage != '暧昧' && stage != '亲密') return false;
      // crushMatureDays 仅在明确挂着这条 crush 线时强校验窗口
      if (p.loveState.currentCrushName == n.name &&
          !p.loveState.isCrushMature(currentDay)) {
        return false;
      }
      // 【Bug 6 修复】romanticEvents 从硬门槛降级为概率乘数（在下方使用）
      return true;
    }).toList();

    if (candidates.isEmpty) return;

    // 融合版：概率触发（基础20% + 条件达标加成）
    double triggerProb = Balance.confessionBaseProbability;
    // 好感超过90%时概率增加
    for (final c in candidates) {
      if (c.affection >= Balance.confessionHighAffectionThreshold) {
        triggerProb += Balance.confessionHighAffectionBonus;
      }
    }
    // 【Bug 6 修复】romanticEvents 概率乘数：关系深度直接反映在触发概率上。
    // 旧的硬门槛会让"零浪漫事件但高好感"永远进不了候选池；现在只是概率打对折。
    final romEvents = p.loveState.romanticEventsFor(candidates.first.name);
    final romanceMultiplier = romEvents >= Balance.confessionMinRomanticEvents
        ? 1.0
        : (romEvents == 1
            ? 0.7
            : 0.3); // 0 次：0.3（还允许偶发表白，不至于堵死）
    triggerProb *= romanceMultiplier;
    triggerProb = triggerProb.clamp(0.0, Balance.confessionMaxProbability);

    if (random.nextDouble() > triggerProb) {
      // 标记"正在考虑"
      final npc = candidates[random.nextInt(candidates.length)];
      npc.isConsideringConfession = true;
      // 悬而未决的时刻 → CG-CF-003（沉默的等待）。
      // 这张 4 星卡此前也完全拿不到：只有真正表白成功/被拒才有 CG，
      // 「考虑中」这个状态从来没有对应奖励。
      unlockCG(cgById('CG-CF-003'));
      return;
    }

    // 选择好感最高的候选者（更合理的表白对象）
    candidates.sort((a, b) => b.affection.compareTo(a.affection));
    final npc = candidates.first;
    npc.isConsideringConfession = true;

    final originalNarrative = currentNarrative;
    currentNarrative =
        (originalNarrative.isEmpty ? '' : '$originalNarrative\n\n') +
        _buildConfessionNarrative(npc, p);
    choices = [
      GameChoice(text: '接受这份心意', action: '接受${npc.name}的表白'),
      GameChoice(text: '婉拒，但保持朋友关系', action: '婉拒${npc.name}，希望保持朋友关系'),
    ];
    p.loveState.awaitingConfession = true;
    p.loveState.consideringNpcName = npc.name;
  }

  /// 融合版表白叙事：根据NPC人格生成不同风格

  String _buildConfessionNarrative(NPC npc, Player p) {
    final personality = npc.personality;
    final traits = personality.join('');

    // 根据NPC特质选择表白风格
    if (traits.contains('勇敢') || traits.contains('直率')) {
      return '${npc.name}鼓起勇气走到你面前，眼睛里闪烁着坚定的光。\n\n'
          '"${p.name}，我有件事藏在心里很久了。" 他/她深吸一口气，\n'
          '"我喜欢你。不是一时兴起，是真的想和你在一起。"\n\n'
          '走廊里的烛光轻轻摇曳，你的心跳似乎漏了一拍。';
    } else if (traits.contains('理性') || traits.contains('聪明')) {
      return '${npc.name}似乎经过了一番深思熟虑才找到你。\n\n'
          '"${p.name}，我一直在想，该怎么说这件事才合适。" 他/她的声音平稳，\n'
          '"经过这么久的相处，我确定——我想和你在一起。不是因为冲动，而是因为我想认真地走下去。"\n\n'
          '理性的话语下，是一颗同样在跳动的心。';
    } else if (traits.contains('害羞') || traits.contains('内向')) {
      return '${npc.name}的脸涨得通红，低着头不敢看你。\n\n'
          '"${p.name}…我…" 他/她的声音很小，几乎被风声盖过，\n'
          '"我喜欢你…可以吗？"\n\n'
          '月光下，${npc.name}的耳朵尖都红了，你第一次发现原来害羞的人表白时这么可爱。';
    } else {
      return '${npc.name}站在你面前，深深地吸了一口气。\n\n'
          '"${p.name}，有件事我想让你知道。" 他/她的眼神认真而温柔，\n'
          '"我喜欢你。如果你愿意，我想和你一起走下去。"\n\n'
          '夜风拂过，一切仿佛都在等待你的回答。';
    }
  }

  /// 处理表白回应

  /// 恋爱关系确立时结算一次社交声望（设定 13.3）。
  ///
  /// loveReputationEffects 这张表此前没有任何地方读它——和谁谈恋爱在声望上
  /// 完全等价，"跟纯血至上的老师谈"与"同学院的青梅竹马"代价一样。而这个
  /// 世界的偏见恰恰是设定里反复强调的东西。
  ///
  /// 只在关系确立（'恋爱'）时结算一次：订婚和结婚是同一段关系的延续，不重复
  /// 计第二次，否则同一桩恋事会被罚两遍。
  void _applyLoveReputation(NPC npc) {
    final p = player;
    if (p == null) return;
    final ctx = LovePairContext(
      playerHouse: p.house,
      npcHouse: npc.house,
      playerBlood: p.bloodType,
      npcBlood: npc.bloodStatus,
      npcIsStaff: npc.grade == 0,
      playerStance: p.politicalTendency ?? '',
      npcBloodSupremacist: npc.bloodSupremacist,
    );

    var delta = 0;
    final detail = <String>[];
    for (final e in loveReputationEffects) {
      if (!loveEffectApplies(e, ctx)) continue;
      final v = e.min + random.nextInt(e.max - e.min + 1);
      delta += v;
      detail.add('${e.type} ${v > 0 ? '+' : ''}$v');
    }
    if (delta == 0) return;

    // 最极端的情况（跨学院的纯血至上老师 + 血统不纯 + 立场对立）能叠到 -55，
    // 而声望量程是 0~100，一次打到底就没法玩了。封个顶。
    delta = delta.clamp(-30, 10);
    // 框架1 §13.3 表头是「学院声望变化」：恋爱对声望的代价应落在学院声望上。
    // 历史问题：这里写的是 social（社交声望），而 UI 的「学院声望」只被学院杯
    // 结算改动——玩家跨学院恋爱后学院声望纹丝不动，文档与执行两套口径。
    p.houseReputation = (p.houseReputation + delta).clamp(0, 100);
    final sign = delta > 0 ? '+' : '';
    notifications.add(
      '💬 你和${npc.name}在一起的消息传开了：学院声望 $sign$delta'
      '（${detail.join('、')}）',
    );
    worldState.addNarrativeEvent(
      '💬 关于你和${npc.name}的传闻改变了旁人的看法（学院声望 $sign$delta）',
      turn: turnCount,
    );
  }

  @override
  void resolveConfession(bool accepted, String npcName) {
    final p = player;
    if (p == null) return;
    late final NPC npc;
    try {
      npc = npcRegistry.values.firstWhere((n) => n.name == npcName);
    } catch (_) {
      try {
        npc = npcRegistry.values.firstWhere(
          (n) => n.name.contains(npcName) || npcName.contains(n.name),
        );
      } catch (e) {
        debugLog('[mixin_relations] NPC 定位失败，跳过: $e');
        return;
      }
    }
    npc.confessed = true;
    npc.isConsideringConfession = false;
    p.loveState.awaitingConfession = false;
    p.loveState.consideringNpcName = null;

    if (accepted) {
      p.loveState.status = '恋爱';
      p.loveState.partnerId = npc.id;
      p.loveState.partnerName = npc.name;
      p.loveState.history.add({
        'date': worldState.timestamp,
        'event': '接受了${npc.name}的表白',
      });
      unlockCG(cgById('CG-010'));
      unlockCG(cgById('CG-CF-001'));
      if (p.boneMode) unlockCG(cgById('CG-BONE-002'));
      unlockAchievement('first_confession');
      unlockAchievement('in_love');
      notifications.add('💕 你与${npc.name}开始了恋爱！');
      worldState.addNarrativeEvent('💕 你与${npc.name}开始了恋爱！', turn: turnCount);
      addRumor('你与${npc.name}正在交往的消息，像野火一样传遍了霍格沃茨。');
      bumpImpactScore(
        npc.isCanon ? 0.08 : 0.04,
        debugReason: '接受${npc.name}表白${npc.isCanon ? '(原著NPC)' : ''}',
      );
      _applyLoveReputation(npc);
      currentNarrative =
          '你点了点头，${npc.name}的眼睛瞬间亮了起来，像被月光点亮。\n\n'
          '他/她握住你的手，声音里带着掩饰不住的喜悦："真的吗？太好了……"\n\n'
          '你们在月色下相视而笑，霍格沃茨的钟声在远处敲响，仿佛在为这段感情祝福。';
    } else {
      updateNpcAffection(npc.id, -5, reason: '婉拒表白');
      unlockCG(cgById('CG-CF-002'));
      addRumor('听说${npc.name}向你表白，却被你拒绝了。');
      bumpImpactScore(
        npc.isCanon ? 0.03 : 0.015,
        debugReason: '婉拒${npc.name}表白',
      );
      currentNarrative =
          '你温和地摇了摇头。${npc.name}的眼神黯淡了一下，但很快挤出一个微笑。\n\n'
          '"我明白了……那我们，还是朋友吧？"\n\n'
          '他/她松开手，向你露出一个勉强却真心的笑容。月光依旧明亮，只是空气里多了一丝惆怅。';
    }
    choices = [GameChoice(text: '继续', action: '继续')];
  }
}
