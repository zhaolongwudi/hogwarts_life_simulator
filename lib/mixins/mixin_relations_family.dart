/// 婚姻家庭与媒合子系统（r6-9 拆分自 mixin_relations.dart）。
///
/// 覆盖：婚姻与家庭（结婚/子嗣/家庭事件）、拉郎配（撮合 NPC 配对）。
/// 通过 on 链复用 [GameRelationsMixin] 的 NPC 查找与好感工具。
library;

import '../models/game_systems.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../utils/npc_lookup.dart';
import 'mixin_relations.dart';

mixin GameRelationsFamilyMixin on GameRelationsMixin {
  // ==================== 婚姻与家庭 ====================
  //
  // 补齐此前完全缺失的链路：求婚 → 订婚 → 结婚 → 备孕 → 分娩 → 子女。
  // LoveState.status 一直预留着「订婚 / 结婚」两个取值，但全项目没有任何代码
  // 写入它们，所以 CG-021（第一个孩子的啼哭，5 星）永远拿不到。
  // 现在这条线既能解锁 CG-021，也让恋爱线在毕业后还有长期目标。

  /// 孕期长度（游戏内天数）。取 120 天而不是现实里的 280 天：
  /// 7 学年约 2555 天，280 天意味着几乎只能在毕业后才生得出，节奏太拖。
  static const int kPregnancyDays = 120;

  /// 求婚门槛：确定恋爱关系 + 好感足够深 + 至少五年级
  static const int kProposeMinAffection = 95;
  static const int kProposeMinGrade = 5;

  /// 求婚。返回非空表示失败原因（调用方直接展示）。
  @override
  String? proposeMarriage() {
    final p = player;
    if (p == null) return '还没有角色数据。';
    final love = p.loveState;
    if (love.status == '订婚') return '你们已经订婚了，下一步是 /结婚。';
    if (love.status == '结婚') return '你们已经结婚了。';
    if (love.status != '恋爱') {
      return '求婚需要先确定恋爱关系（当前：${love.status}）。';
    }
    final npc = findNpcByName(love.partnerName ?? '');
    if (npc == null) return '找不到你的恋人，可能这段关系已经断了。';
    if (npc.affection < kProposeMinAffection) {
      return '${npc.name} 还没有准备好（好感 ${npc.affection} < $kProposeMinAffection）。'
          '再多一起经历一些事吧。';
    }
    if ((p.grade ?? 1) < kProposeMinGrade) {
      return '你才 ${p.grade} 年级，谈婚论嫁还太早了（需要 $kProposeMinGrade 年级以上）。';
    }

    love.status = '订婚';
    love.engagedDate = worldState.timestamp;
    love.history.add({
      'date': worldState.timestamp,
      'event': '向${npc.name}求婚，对方答应了',
    });
    notifications.add('💍 你向${npc.name}求婚，对方红着脸答应了');
    worldState.addNarrativeEvent('💍 与${npc.name}订婚', turn: turnCount);
    bumpImpactScore(
      npc.isCanon ? 0.06 : 0.03,
      debugReason: '与${npc.name}订婚${npc.isCanon ? '(原著NPC)' : ''}',
    );
    notifyListeners();
    return null;
  }

  /// 举行婚礼。返回非空表示失败原因。
  @override
  String? holdWedding() {
    final p = player;
    if (p == null) return '还没有角色数据。';
    final love = p.loveState;
    if (love.status == '结婚') return '你们已经结婚了。';
    if (love.status != '订婚') return '需要先 /求婚 才能结婚（当前：${love.status}）。';

    final partnerName = love.partnerName ?? '你的爱人';
    love.status = '结婚';
    love.marriedDate = worldState.timestamp;
    love.marriedAbsDay = worldState.time.absoluteDayIndex;
    love.history.add({
      'date': worldState.timestamp,
      'event': '与$partnerName举行了婚礼',
    });
    unlockAchievement('married');
    notifications.add('💒 你与$partnerName 在亲友的祝福中举行了婚礼');
    worldState.addNarrativeEvent('💒 与$partnerName 结婚', turn: turnCount);
    worldState.addTimelineBranch(
      '与$partnerName 成婚：一条原作里不存在的家族线从这里开始',
      snapshot: worldSnapshot(),
    );
    addRumor('$partnerName 和你在霍格沃茨举行了婚礼，这件事被念叨了整整一个学期。');
    bumpImpactScore(0.08, debugReason: '结婚：$partnerName');
    notifyListeners();
    return null;
  }

  /// 备孕。返回非空表示失败原因。
  @override
  String? tryConceive() {
    final p = player;
    if (p == null) return '还没有角色数据。';
    final love = p.loveState;
    if (love.status != '结婚') return '需要先结婚（当前：${love.status}）。';
    if (love.pregnantSinceAbsDay != null) return '已经怀着了，安心养胎吧。';

    love.pregnantSinceAbsDay = worldState.time.absoluteDayIndex;
    notifications.add('🤰 你们决定要一个孩子');
    bumpImpactScore(0.03, debugReason: '备孕');
    notifyListeners();
    return null;
  }

  /// 每次世界时钟推进后调用：孕期到期则分娩。
  ///
  /// 只在这里判定（而不是在 /生育 里直接生），是为了让 /快进 也能推进孕期——
  /// 否则玩家必须手动点 120 次行动才能等到孩子出生。
  @override
  void advancePregnancy() {
    final p = player;
    if (p == null) return;
    final love = p.loveState;
    final since = love.pregnantSinceAbsDay;
    if (since == null) return;
    final elapsed = worldState.time.absoluteDayIndex - since;
    if (elapsed < kPregnancyDays) return;

    final partnerName = love.partnerName ?? '你的爱人';
    final gender = random.nextBool() ? '女' : '男';
    final child = ChildRecord(
      name: _generateChildName(partnerName),
      gender: gender,
      bornOn: worldState.timestamp,
      bornAbsDay: worldState.time.absoluteDayIndex,
      otherParentName: partnerName,
      traits: _rollChildTraits(),
    );
    p.children.add(child);
    love.pregnantSinceAbsDay = null;
    love.history.add({
      'date': worldState.timestamp,
      'event': '${child.name}出生了',
    });

    // 第一个孩子 → CG-021（此前全项目无任何解锁路径）
    if (p.children.length == 1) {
      unlockCG(cgById('CG-021'));
      unlockAchievement('first_child');
    }
    notifications.add('👶 ${child.name}出生了（$gender）');
    worldState.addNarrativeEvent('👶 ${child.name}出生', turn: turnCount);
    addRumor('听说你和$partnerName 的孩子出生了，名字叫${child.name}。');
    bumpImpactScore(0.1, debugReason: '生育：${child.name}');
    notifyListeners();
  }

  String _generateChildName(String partnerName) {
    final givenPools = <String>[
      '星河',
      '砚清',
      '知微',
      '云舒',
      '南枝',
      '照野',
      '闻笛',
      '疏桐',
      '衔烛',
      '琅玕',
      '拾光',
      '望舒',
      '予安',
      '岁禾',
      '向晚',
      '斯年',
      '清和',
      '砚舟',
      '拂衣',
    ];
    final given = givenPools[random.nextInt(givenPools.length)];
    // 姓氏取玩家的姓（取名字首字），避免生成出与双方都无关的第三姓
    final surname = (player?.name.isNotEmpty ?? false) ? player!.name[0] : '林';
    return '$surname$given';
  }

  List<String> _rollChildTraits() {
    final pool = <String>[
      '好奇',
      '安静',
      '倔强',
      '体贴',
      '胆大',
      '细心',
      '爱笑',
      '内向',
      '早慧',
      '黏人',
      '固执',
      '温和',
    ];
    final picked = <String>[];
    final count = 1 + random.nextInt(2);
    for (var i = 0; i < count; i++) {
      final t = pool[random.nextInt(pool.length)];
      if (!picked.contains(t)) picked.add(t);
    }
    return picked;
  }

  /// 家庭面板（/家庭）
  @override
  String formatFamily() {
    final p = player;
    final buf = StringBuffer('【家庭】\n');
    if (p == null) {
      buf.writeln('还没有角色数据。');
      return buf.toString();
    }
    final love = p.loveState;
    buf.writeln('感情状态：${love.status}');
    if (love.partnerName != null) {
      buf.writeln('伴侣：${love.partnerName}');
    }
    if (love.engagedDate != null) buf.writeln('订婚于：$love.engagedDate');
    if (love.marriedDate != null) {
      buf.writeln('结婚于：${love.marriedDate}');
      final days = worldState.time.absoluteDayIndex - (love.marriedAbsDay ?? 0);
      buf.writeln('婚后第 $days 天');
    }

    final since = love.pregnantSinceAbsDay;
    if (since != null) {
      final elapsed = worldState.time.absoluteDayIndex - since;
      final pct = (elapsed / kPregnancyDays * 100).clamp(0, 100).round();
      buf.writeln('\n🤰 怀孕中：$elapsed / $kPregnancyDays 天（$pct%）');
      final bar = (pct / 10).round();
      buf.writeln('   [${'█' * bar}${'░' * (10 - bar)}]');
    }

    if (p.children.isEmpty) {
      buf.writeln('\n还没有孩子。');
    } else {
      buf.writeln('\n👶 子女 ${p.children.length} 人：');
      for (final c in p.children) {
        buf.writeln('· ${c.name}（${c.gender}）· 生于 ${c.bornOn}');
        buf.writeln(
          '  另一半：${c.otherParentName}'
          '${c.traits.isNotEmpty ? ' · 性情：${c.traits.join('、')}' : ''}',
        );
      }
    }

    buf.writeln('\n可用：/求婚 ｜ /结婚 ｜ /生育 ｜ /家庭');
    return buf.toString();
  }

  // ==================== 拉郎配（撮合 NPC） ====================

  /// 开始撮合一对 NPC。返回非空表示失败原因（调用方直接展示）。
  @override
  String? startShipping(String nameA, String nameB) {
    final p = player;
    if (p == null) return '还没有角色数据。';
    final a = findNpcByName(nameA);
    final b = findNpcByName(nameB);
    if (a == null) return '没找到「$nameA」。';
    if (b == null) return '没找到「$nameB」。';
    if (a.id == b.id) return '不能把同一个人配成一对。';
    if (p.shippings.any((s) => s.key == ShipRecord.keyOf(a.name, b.name))) {
      return '你已经在撮合「${a.name} × ${b.name}」了。';
    }
    if (p.shippings.length >= 5) {
      return '你同时撮合的配对太多了（上限 5 对）。先放手一对吧。';
    }
    p.shippings.add(ShipRecord(npcA: a.name, npcB: b.name));
    notifications.add('💞 你开始留意 ${a.name} 与 ${b.name} 之间的气氛');
    notifyListeners();
    return null;
  }

  @override
  void stopShipping(int index) {
    final p = player;
    if (p == null || index < 0 || index >= p.shippings.length) return;
    final s = p.shippings.removeAt(index);
    notifications.add('💔 你不再撮合「${s.pairLabel}」');
    notifyListeners();
  }

  /// 每回合叙事落定后推进配对羁绊：两人必须同时出现在本回合叙事中才算进展，
  /// 只提其中一个名字不加分（否则玩家挂机也能刷满）。
  @override
  void advanceShippings(String narrative) {
    final p = player;
    if (p == null || p.shippings.isEmpty || narrative.isEmpty) return;
    for (var i = 0; i < p.shippings.length; i++) {
      final s = p.shippings[i];
      if (!narrative.contains(s.npcA) || !narrative.contains(s.npcB)) continue;
      final gain = 3 + random.nextInt(4); // 3~6
      final bond = (s.bond + gain).clamp(0, 100);
      final stage = _shipStageFor(bond);
      p.shippings[i] = s.copyWith(bond: bond, stage: stage);
      if (stage > s.stage) {
        _unlockShipCg(stage);
        notifications.add('💞 「${s.pairLabel}」的关系有了新的进展（羁绊 $bond）');
        if (stage >= 1) unlockAchievement('matchmaker');
      }
    }
  }

  /// 羁绊 → 拉郎配阶段（对应 CG-LP-001 ~ CG-LP-006 的门槛 60/65/70/75/80/90）
  int _shipStageFor(int bond) {
    if (bond >= 90) return 6;
    if (bond >= 80) return 5;
    if (bond >= 75) return 4;
    if (bond >= 70) return 3;
    if (bond >= 65) return 2;
    if (bond >= 60) return 1;
    return 0;
  }

  static const List<String> _shipCgIds = [
    'CG-LP-001',
    'CG-LP-002',
    'CG-LP-003',
    'CG-LP-004',
    'CG-LP-005',
    'CG-LP-006',
  ];

  void _unlockShipCg(int stage) {
    if (stage < 1 || stage > _shipCgIds.length) return;
    unlockCG(cgById(_shipCgIds[stage - 1]));
  }

  @override
  String formatShippings() {
    final p = player;
    final buf = StringBuffer('【拉郎配】\n');
    if (p == null || p.shippings.isEmpty) {
      buf.writeln(
        '你还没有撮合任何人。\n'
        '输入 /拉郎配 [甲] [乙] 开始留意两个人的关系，'
        '当他们在同一段剧情里同时出现时，羁绊会逐步加深并解锁专属CG。',
      );
      return buf.toString();
    }
    for (var i = 0; i < p.shippings.length; i++) {
      final s = p.shippings[i];
      // P2#15：把拉郎配六档（60/65/70/75/80/90）与玩家侧好感十一档
      // 收口到同一把尺——直接复用 affectionStageFor 给羁绊值贴档位标签，
      // 玩家不再面对两套互不相认的"好感标尺"。
      final stageLabel = affectionStageFor(s.bond);
      buf.writeln('\n${i + 1}. ${s.pairLabel}');
      buf.writeln('   羁绊 ${s.bond}/100 · 阶段 ${s.stage}/6 · $stageLabel');
      final barLen = (s.bond / 10).round();
      buf.writeln('   [${'\u2588' * barLen}${'\u2591' * (10 - barLen)}]');
    }
    buf.writeln('\n（羁绊与好感共用 0~100 一把尺：50 信任、70 亲密、85 深爱、95 灵魂伴侣）');
    buf.writeln('\n/拉郎配 [甲] [乙] 撮合 ｜ /拉郎配 放弃 [编号] 放手');
    return buf.toString();
  }

  /// 按名字/别名/姓氏查 NPC（统一实现见 lib/utils/npc_lookup.dart）。
  /// 旧版本只比 name 的精确与包含，忽略 aliases，玩家输别名常常查不到人。
  NPC? findNpcByName(String name) =>
      findNpcByKeyword(npcRegistry.values, name);
}
