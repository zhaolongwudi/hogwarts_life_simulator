import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/player.dart';
import 'package:hogwarts_life_simulator/data/archetype_data.dart';
import 'package:hogwarts_life_simulator/screens/world_map_screen.dart';
import 'package:hogwarts_life_simulator/mixins/mixin_response.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';
import 'package:hogwarts_life_simulator/utils/npc_lookup.dart';
import 'package:hogwarts_life_simulator/data/provider_defaults.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/data/political_stance.dart';
import 'package:hogwarts_life_simulator/data/gift_rules.dart';
import 'package:hogwarts_life_simulator/data/item_data.dart';

void main() {
  group('GameTime 整天快进', () {
    test('跨月：1991-09-01 快进 31 天 → 1991-10-02', () {
      final t = GameTime(year: 1991, month: 9, day: 1);
      t.advanceDays(31);
      expect(t.year, 1991);
      expect(t.month, 10);
      expect(t.day, 2);
    });

    test('跨年：1991-12-01 快进 60 天 → 1992-01-30', () {
      final t = GameTime(year: 1991, month: 12, day: 1);
      t.advanceDays(60);
      expect(t.year, 1992);
      expect(t.month, 1);
      expect(t.day, 30);
    });

    test('闰年：1992-02-27 快进 2 天 → 1992-02-29', () {
      final t = GameTime(year: 1992, month: 2, day: 27);
      t.advanceDays(2);
      expect(t.month, 2);
      expect(t.day, 29);
    });

    test('快进后星期与按日期构造的结果一致（不发生漂移）', () {
      final t = GameTime(year: 1991, month: 9, day: 1);
      t.advanceDays(123);
      final fresh = GameTime(year: t.year, month: t.month, day: t.day);
      expect(t.weekday, fresh.weekday);
      expect(GameTime.weekdays[t.weekday], GameTime.weekdays[fresh.weekday]);
    });

    test('快进后时刻落在早晨（不是深夜）', () {
      final t = GameTime(year: 1991, month: 9, day: 1, hour: 23, minute: 45);
      t.advanceDays(1);
      expect(t.hour, 8);
      expect(t.minute, 0);
    });

    test('非正数不推进', () {
      final t = GameTime(year: 1991, month: 9, day: 1);
      t.advanceDays(0);
      t.advanceDays(-5);
      expect('${t.year}-${t.month}-${t.day}', '1991-9-1');
    });
  });

  group('正文清洗：结构化区块不得泄漏进叙事', () {
    test('9 种选项块标题全部剥离', () {
      const blocks = [
        '可选行动',
        '自由行动',
        '行动建议',
        '备选行动',
        '剧情选项',
        '下回合选择',
        '选择建议',
        '行动选项',
        '你可以',
      ];
      for (final b in blocks) {
        final text = '你推开大门。\n【$b】\nA. 向左走\nB. 向右走';
        final out = stripStructuredSections(text);
        expect(out.contains('A. 向左走'), isFalse, reason: '区块【$b】未被剥离');
        expect(out.contains('推开大门'), isTrue, reason: '正文被误删（区块【$b】）');
      }
    });

    test('toEnd=true 时截断区块之后的所有内容', () {
      final out = stripStructuredSections('正文。\n【剧情选项】\nA. x\nB. y',
          toEnd: true);
      expect(out.trim(), '正文。');
    });

    test('bareLabel=true 支持无【】的「可选行动：」写法', () {
      final out = stripStructuredSections(
        '正文。\n可选行动：\nA. x\n【声望变化】\n学术: +3',
        bareLabel: true,
      );
      expect(out.contains('A. x'), isFalse);
      expect(out.contains('正文'), isTrue);
    });
  });

  group('声望派生值', () {
        Player makePlayer(Reputation r) =>
            Player(
                name: '测试',
                birthYear: '1980',
                bloodType: '混血',
                birthLocation: '伦敦',
                playerReputation: r);

    test('魔法界声望 = 五维均值（黑魔法不计入）', () {
      final p = makePlayer(Reputation(
        academic: 60,
        social: 40,
        combat: 30,
        moral: 50,
        leadership: 20,
        dark: 100, // 恶名不应拉高"魔法界声望"
      ));
      expect(p.wizardingReputation, 40);
    });

    test('阵营声望 = 黑魔法 − 道德，且带倾向解读', () {
      final dark = makePlayer(Reputation(dark: 80, moral: 20));
      expect(dark.factionReputation, 60);
      final light = makePlayer(Reputation(dark: 10, moral: 90));
      expect(light.factionReputation, -80);
    });

    test('回归：旧实现里两个派生声望恒为 0（现已随六维变化）', () {
      final p = makePlayer(Reputation(academic: 100));
      expect(p.wizardingReputation, 20);
      expect(p.wizardingReputation, isNot(0));
    });
  });

  group('高收益活动每日上限（源码扫描）', () {
    final playSrc = File('lib/mixins/mixin_play.dart').readAsStringSync();
    final systemsSrc = File('lib/mixins/mixin_systems.dart').readAsStringSync();

    test('决斗必须有每日次数上限（否则声望/加隆可无限刷）', () {
      final duelBody = playSrc.substring(
        playSrc.indexOf('void duelNpc('),
        playSrc.indexOf('// ==================== 6. 禁林探险'),
      );
      expect(duelBody.contains("canDoDaily('duel')"), isTrue);
      expect(duelBody.contains("recordDailyActivity('duel')"), isTrue);
    });

    test('禁林必须有每日次数上限', () {
      final forestBody = playSrc.substring(
        playSrc.indexOf('void exploreForbiddenForest('),
      );
      expect(forestBody.contains("canDoDaily('forest')"), isTrue);
    });

    test('决斗时间开销不得再按「对话」计（10 分钟能刷一场）', () {
      expect(playSrc.contains("advanceTimeForAction('对话')"), isFalse);
      expect(playSrc.contains("advanceTimeForAction('决斗')"), isTrue);
    });

    test('上限表与计数实现都存在', () {
      expect(systemsSrc.contains('kDailyActivityLimits'), isTrue);
      expect(systemsSrc.contains('_rollDailyActivityIfNeeded'), isTrue);
    });
  });

  group('禁词表不得误伤常用中文词', () {
    final contSrc =
        File('lib/mixins/mixin_narrative_continuity.dart').readAsStringSync();

    test('「逻辑」不得出现在 crossIp 禁词表（三体角色是「罗辑」）', () {
      final start = contSrc.indexOf('const crossIp = <String>[');
      final end = contSrc.indexOf('];', start);
      final block = contSrc.substring(start, end);
      expect(block.contains("'逻辑'"), isFalse,
          reason: '「逻辑」是中文常用词，放在 critical 级会让几乎每回合叙事都被判违和');
      expect(block.contains("'罗辑'"), isTrue);
    });
  });

  _contentGroup();
  _contentCoverageGroup();
  _codeHygieneGroup();
  _mapLayoutGroup();
  _unwiredFeatureGroup();
  _providerDefaultsGroup();
  _settingsDedupGroup();
  _giftGivingGroup();
  _materialLootGroup();
}

// ==================== 拉郎配 / 婚姻 / CG 可达性 ====================
// 这一组是"内容可达性"回归：数据里定义了的内容，游戏里必须有实际路径拿到。
// 之前 33 张 CG 里有 11 张（含全部 6 张拉郎配 CG）永远拿不到——
// 数据有、系统没有。这些测试就是防止这类"死内容"再次出现。

void _contentGroup() {
  group('内容可达性：每张 CG 都必须有解锁路径', () {
    final cgSrc = File('lib/data/cg_data.dart').readAsStringSync();
    final condSrc =
        File('lib/data/cg_unlock_conditions.dart').readAsStringSync();
    final allIds = RegExp(r"CgDef\(id: '([^']+)'")
        .allMatches(cgSrc)
        .map((m) => m.group(1)!)
        .toList();
    final condIds = RegExp(r"^\s*'(CG-[^']+)':\s*const", multiLine: true)
        .allMatches(condSrc)
        .map((m) => m.group(1)!)
        .toSet();

    // lib/ 下除 data/ 目录外的所有源码（data 里出现 id 只是数据定义，不算路径）
    final codeBuf = StringBuffer();
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('/data/')) continue;
      codeBuf.writeln(entity.readAsStringSync());
    }
    final code = codeBuf.toString();

    test('CG 数据表非空', () => expect(allIds.length, greaterThan(30)));

    for (final id in allIds) {
      test('$id 有解锁路径', () {
        final hasPath = condIds.contains(id) || code.contains(id);
        expect(hasPath, isTrue, reason: '$id 在数据表里定义了但游戏里拿不到');
      });
    }

    test('6 张拉郎配 CG 全部登记在 _shipCgIds', () {
      final relSrc = File('lib/mixins/mixin_relations.dart').readAsStringSync();
      final start = relSrc.indexOf('_shipCgIds = [');
      final end = relSrc.indexOf('];', start);
      final block = relSrc.substring(start, end);
      for (var i = 1; i <= 6; i++) {
        expect(block.contains('CG-LP-00$i'), isTrue);
      }
    });
  });

  group('拉郎配推进规则', () {
    final relSrc = File('lib/mixins/mixin_relations.dart').readAsStringSync();

    test('必须两人同时出现才加羁绊（防止挂机刷满）', () {
      final start = relSrc.indexOf('void advanceShippings(');
      final end = relSrc.indexOf('\n  }', start);
      final body = relSrc.substring(start, end);
      expect(body.contains('narrative.contains(s.npcA)'), isTrue);
      expect(body.contains('narrative.contains(s.npcB)'), isTrue);
    });

    test('撮合数量有上限', () {
      expect(relSrc.contains('shippings.length >= 5'), isTrue);
    });

    test('advanceShippings 每回合被调用（叙事落定后）', () {
      final respSrc = File('lib/mixins/mixin_response.dart').readAsStringSync();
      expect(respSrc.contains('advanceShippings('), isTrue);
    });
  });

  group('婚姻 / 生育链路', () {
    final relSrc = File('lib/mixins/mixin_relations.dart').readAsStringSync();
    final sysSrc = File('lib/mixins/mixin_systems.dart').readAsStringSync();
    final cmdSrc = File('lib/mixins/mixin_commands.dart').readAsStringSync();

    test('求婚 / 结婚 / 生育 / 家庭 四个指令都已注册', () {
      for (final c in ['求婚', '结婚', '生育', '家庭', '拉郎配']) {
        expect(cmdSrc.contains("primary: '$c'"), isTrue,
            reason: '/$c 指令未注册');
      }
    });

    test('孕期推进挂在世界时钟上（/快进 也能推进）', () {
      expect(sysSrc.contains('advancePregnancy()'), isTrue);
    });

    test('status 的「订婚」「结婚」有真实写入方', () {
      expect(relSrc.contains("love.status = '订婚'"), isTrue);
      expect(relSrc.contains("love.status = '结婚'"), isTrue);
    });

    test('第一个孩子解锁 CG-021', () {
      final start = relSrc.indexOf('void advancePregnancy()');
      final end = relSrc.indexOf('\n  }', start);
      final body = relSrc.substring(start, end);
      expect(body.contains("cgById('CG-021')"), isTrue);
    });

    test('成就目录包含 married / first_child / matchmaker', () {
      final gs = File('lib/models/game_systems.dart').readAsStringSync();
      for (final id in ['married', 'first_child', 'matchmaker']) {
        expect(gs.contains("id: '$id'"), isTrue);
      }
    });
  });

  group('存档往返：新字段不得丢', () {
    test('Player.children 有 toJson / fromJson', () {
      final p = File('lib/models/player.dart').readAsStringSync();
      expect(p.contains("'children': children.map((e) => e.toJson()).toList()"),
          isTrue);
      expect(p.contains("children: (json['children'] as List<dynamic>? ?? [])"),
          isTrue);
    });

    test('LoveState 婚姻/孕期字段有 toJson / fromJson', () {
      final gs = File('lib/models/game_systems.dart').readAsStringSync();
      for (final k in [
        "'engaged_date'",
        "'married_date'",
        "'married_abs_day'",
        "'pregnant_since_abs_day'",
      ]) {
        expect(gs.contains(k), isTrue, reason: '$k 未序列化');
      }
    });

    test('ChildRecord JSON 往返', () {
      final c = ChildRecord(
        name: '林星河',
        gender: '女',
        bornOn: '1998年3月2日',
        bornAbsDay: 1234,
        otherParentName: '赫敏',
        traits: ['好奇', '爱笑'],
      );
      final back = ChildRecord.fromJson(c.toJson());
      expect(back.name, '林星河');
      expect(back.gender, '女');
      expect(back.bornOn, '1998年3月2日');
      expect(back.bornAbsDay, 1234);
      expect(back.otherParentName, '赫敏');
      expect(back.traits, ['好奇', '爱笑']);
    });

    test('ShipRecord.keyOf 与顺序无关', () {
      expect(ShipRecord.keyOf('甲', '乙'), ShipRecord.keyOf('乙', '甲'));
      expect(ShipRecord.keyOf('甲', '乙'), isNot(ShipRecord.keyOf('甲', '丙')));
    });

    test('ShipRecord.copyWith 保留身份、只改数值', () {
      const s = ShipRecord(npcA: '甲', npcB: '乙', bond: 10, stage: 0);
      final s2 = s.copyWith(bond: 70, stage: 3);
      expect(s2.npcA, '甲');
      expect(s2.npcB, '乙');
      expect(s2.bond, 70);
      expect(s2.stage, 3);
      expect(s2.pairLabel, '甲 × 乙');
    });
  });
}
/// 内容覆盖度：数据层不该出现"整片空白"。
void _contentCoverageGroup() {
  group('内容覆盖度', () {
    test('12 个月每个月都有事件锚点（此前 3 月整月空白）', () {
      final src = File('lib/data/event_anchors.dart').readAsStringSync();
      final months = RegExp(r'month:\s*(\d+)')
          .allMatches(src)
          .map((m) => int.parse(m.group(1)!))
          .toSet();
      final missing = [
        for (var i = 1; i <= 12; i++)
          if (!months.contains(i)) i
      ];
      expect(missing, isEmpty, reason: '这些月份没有任何事件锚点：$missing');
    });

    test('事件锚点 id 不重复', () {
      final src = File('lib/data/event_anchors.dart').readAsStringSync();
      final ids = RegExp(r"id:\s*'([^']+)'")
          .allMatches(src)
          .map((m) => m.group(1)!)
          .toList();
      expect(ids.length, ids.toSet().length);
    });

    test('每个时代都有专属 NPC 阵容（first_war 此前全靠复刻掠夺者）', () {
      final src = File('lib/data/npc_data.dart').readAsStringSync();
      for (final listName in [
        'dumbledoreEraSeeds',
        'maraudersSeeds',
        'firstWarOriginals',
      ]) {
        final m = RegExp(
          '(?:const|final) List<NpcSeed> $listName = \\[(.*?)\n];',
          dotAll: true,
        ).firstMatch(src);
        expect(m, isNotNull, reason: '$listName 列表不存在');
        expect(m!.group(1)!.contains('NpcSeed('), isTrue,
            reason: '$listName 是空的');
      }
      // first_war 必须把原创名录挂进去，否则白写
      final eraMap = src.substring(src.indexOf('eraNpcSeeds = {'));
      expect(eraMap.contains('...firstWarOriginals'), isTrue);
    });

    test('NPC seed 的 id 全局唯一', () {
      final src = File('lib/data/npc_data.dart').readAsStringSync();
      final ids =
          RegExp(r"id: '([a-z0-9_]+)'").allMatches(src).map((m) => m.group(1)!);
      expect(ids.length, ids.toSet().length);
    });
  });

  group('礼物偏好：预设 NPC 不再全员空白', () {
    test('archetypeOfPersonality 能对每套人格给出原型', () {
      const cases = <List<String>, String>{
        ['勇敢', '直率']: '勇敢型',
        ['理性', '聪明']: '智慧型',
        ['善良', '温柔']: '温柔型',
        ['野心', '精明']: '野心型',
        ['忠诚', '正直']: '忠诚型',
        ['神秘', '内敛']: '神秘型',
        ['幽默', '乐观']: '幽默型',
        ['叛逆', '不羁']: '叛逆型',
      };
      for (final e in cases.entries) {
        expect(archetypeOfPersonality(e.key), e.value);
      }
      // 无命中时退回神秘型而不是抛错/返回空
      expect(archetypeOfPersonality(['???']), '神秘型');
    });

    test('每种原型都有非空礼物表', () {
      for (final a in kArchetypeGiftPrefs.keys) {
        expect(giftPrefsForArchetype(a).isNotEmpty, isTrue, reason: a);
      }
      // 未知原型也要有兜底
      expect(giftPrefsForArchetype('不存在的原型').isNotEmpty, isTrue);
    });

    test('装载预设 NPC 时会补礼物偏好', () {
      final initSrc = File('lib/mixins/mixin_init.dart').readAsStringSync();
      expect(initSrc.contains('giftPrefsForArchetype(archetypeOfPersonality('),
          isTrue);
    });
  });
}

/// 代码卫生：用源码扫描把"容易悄悄退化"的约束固定下来。
void _codeHygieneGroup() {
  /// 去掉行注释再扫描，否则注释里引用的旧代码会被当成真实代码。
  String stripComments(String src) => src
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'//.*$'), ''))
      .join('\n');

  group('好感度必须走统一入口', () {
    /// 白名单：这些地方直接写 npc.affection 是刻意且正确的
    /// - mixin_commands.dart：/作弊 好感（刻意绕过上限，已补状态同步）
    /// - mixin_systems.dart：一致性检查里的钳制与记恨上限修正
    const whitelist = <String>{
      'lib/mixins/mixin_commands.dart',
      'lib/mixins/mixin_systems.dart',
    };

    test('mixins/screens 下不得绕过 updateNpcAffection', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (!path.contains('/mixins/') && !path.contains('/screens/')) continue;
        if (whitelist.contains(path)) continue;
        final lines = stripComments(entity.readAsStringSync()).split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (!RegExp(r'\.affection\s*(\+=|-=|=)').hasMatch(line)) continue;
          if (line.contains('==') || line.contains('!=')) continue;
          if (RegExp(r'\.affection\s*[<>]=?').hasMatch(line)) continue;
          offenders.add(path + ':' + (i + 1).toString() + '  ' + line);
        }
      }
      expect(offenders, isEmpty,
          reason: '这些地方绕过了 updateNpcAffection：\n' + offenders.join('\n'));
    });

    test('/作弊 好感 在改数值后补了状态同步', () {
      final src = stripComments(
          File('lib/mixins/mixin_commands.dart').readAsStringSync());
      final i = src.indexOf("npc.affection = (npc.affection + delta)");
      expect(i, greaterThan(-1));
      final tail = src.substring(i, i + 400);
      expect(tail.contains('syncRelationshipLevel(npc)'), isTrue);
      expect(tail.contains('checkAffectionAchievements(npc)'), isTrue);
    });

    test('updateNpcAffection 仍是唯一写入管线', () {
      final src = File('lib/providers/game_provider.dart').readAsStringSync();
      expect(src.contains('void updateNpcAffection('), isTrue);
    });
  });

  group('存档调用不得静默丢弃', () {
    test('saveNow 不再用 _saveScheduled 直接 return', () {
      final src = stripComments(
          File('lib/providers/game_provider.dart').readAsStringSync());
      final start = src.indexOf('Future<void> saveNow() async {');
      final end = src.indexOf('\n  }', start);
      final body = src.substring(start, end);
      expect(body.contains('if (_saveScheduled) return;'), isFalse,
          reason: '在途自动存档会让手动存档被静默丢弃');
      expect(body.contains('await pending;'), isTrue);
    });

    test('所有不等待的 autoSave 都显式标注了 unawaited', () {
      final bare = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final src = stripComments(entity.readAsStringSync());
        for (final m in
            RegExp(r'^(\s*)autoSave\(\);', multiLine: true).allMatches(src)) {
          bare.add(entity.path.replaceAll(r'\', '/') +
              ' -> ' +
              m.group(0)!.trim());
        }
      }
      expect(bare, isEmpty, reason: '未标注的 autoSave()：\n' + bare.join('\n'));
    });
  });
}

/// 地图标记布局：小屏上标记曾经整片叠在一起。
void _mapLayoutGroup() {
  /// 复刻 world_map_screen 的布局算法：画布按需撑开 → 垂直松弛防重叠。
  /// 与生产代码保持一致的两条关键规则：
  ///   1. canvasHeight = max(usableHeight, count * (boxH + gap))
  ///   2. 松弛用同一个 boxW/boxH
  List<MarkerBox> layoutMap(
    List<List<double>> xy, {
    required double mapWidth,
    required double canvasHeight,
    double boxW = 96,
    double boxH = 118,
  }) =>
      resolveMarkerOverlaps(
        [for (final p in xy) MarkerBox(mapWidth * p[0] - boxW / 2, 110 + p[1])],
        boxWidth: boxW,
        boxHeight: boxH,
        minTop: 110,
        maxLeft: mapWidth - boxW,
        maxTop: 110 + (canvasHeight - boxH).clamp(0.0, canvasHeight),
      );

  int overlapCount(List<MarkerBox> boxes, double w, double h) {
    var n = 0;
    for (var i = 0; i < boxes.length; i++) {
      for (var j = i + 1; j < boxes.length; j++) {
        if ((boxes[i].left - boxes[j].left).abs() < w &&
            (boxes[i].top - boxes[j].top).abs() < h) {
          n++;
        }
      }
    }
    return n;
  }

  group('地图标记防重叠', () {
    test('完全重合的两个标记会被推开', () {
      final out = layoutMap(
        [
          [0.5, 200],
          [0.5, 200],
        ],
        mapWidth: 360,
        canvasHeight: 400,
      );
      expect((out[0].top - out[1].top).abs(), greaterThan(0));
      expect(overlapCount(out, 96, 118), 0);
    });

    test('霍格沃茨 18 个地点在最挤的小屏上也能完全分开', () {
      // 真实场景复刻：18 个地点，其中若干 y 只差 0.02
      final xy = <List<double>>[
        for (var i = 0; i < 18; i++) [0.1 + (i % 5) * 0.2, i * 5.0],
      ];
      const boxH = 50.0; // 紧凑模式
      const boxW = 44.0;
      final canvas = 18 * (boxH + 6.0); // 画布按需撑开
      final out = layoutMap(
        xy,
        mapWidth: 360,
        canvasHeight: canvas,
        boxW: boxW,
        boxH: boxH,
      );
      expect(out.length, 18);
      expect(overlapCount(out, boxW, boxH), 0,
          reason: '撑开画布后仍应做到零重叠，否则标记点不中');
    });

    test('水平方向已错开的标记不会被无谓地垂直推挤', () {
      final out = layoutMap(
        [
          [0.0, 200],
          [0.95, 200],
        ],
        mapWidth: 600,
        canvasHeight: 800,
      );
      expect(out[1].top, 200 + 110); // 含 headerOffset
    });

    test('结果被约束在给定边界内', () {
      final out = resolveMarkerOverlaps(
        const [MarkerBox(-50, 0), MarkerBox(9999, 9999)],
        boxWidth: 96,
        boxHeight: 118,
        minTop: 110,
        maxLeft: 300,
        maxTop: 380,
      );
      for (final b in out) {
        expect(b.left, greaterThanOrEqualTo(0));
        expect(b.left, lessThanOrEqualTo(300));
        expect(b.top, greaterThanOrEqualTo(110));
        expect(b.top, lessThanOrEqualTo(380));
      }
    });

    test('空输入不炸', () {
      expect(
        resolveMarkerOverlaps(
          const <MarkerBox>[],
          boxWidth: 96,
          boxHeight: 118,
          minTop: 110,
          maxLeft: 300,
          maxTop: 380,
        ),
        isEmpty,
      );
    });

    test('结果确定（同输入同输出，不引入随机）', () {
      List<MarkerBox> run() => layoutMap(
            [
              [0.3, 40],
              [0.32, 50],
              [0.31, 45],
            ],
            mapWidth: 360,
            canvasHeight: 300,
          );
      final a = run();
      final b = run();
      for (var i = 0; i < a.length; i++) {
        expect(a[i].left, b[i].left);
        expect(a[i].top, b[i].top);
      }
    });
  });
}

// ==================== 建好却没接线的功能 ====================
// 这一轮扫描出一批"写了实现、零调用点"的成员。其中几个是完整功能
// （本地建议生成器、NPC 档案查看、学院杯记账），删掉可惜，接上才对。
// 本组锁住接线结果，防止哪天又被改回死代码。

/// 去掉行注释再扫描，否则注释里引用的旧代码会被当成真实代码。
String _stripComments(String src) => src
    .split('\n')
    .map((l) => l.replaceAll(RegExp(r'//.*$'), ''))
    .join('\n');

NPC _npc(String name) => NPC(id: name, name: name);

/// src 中第 offset 个字符位于第几行（0 基）。
int _lineOf(String src, int offset) =>
    offset < 0 ? -1 : src.substring(0, offset).split('\n').length - 1;

void _unwiredFeatureGroup() {
  group('「换一批」本地建议已接线', () {
    test('叙事页选项区存在调用点', () {
      final src = _stripComments(
          File('lib/screens/game/game_narrative_tab.dart').readAsStringSync());
      expect(src.contains('generateMoreSuggestions()'), isTrue,
          reason: 'generateMoreSuggestions 一度零调用，90 行分场景选项白放着');
    });

    test('生成器是同步的，不套无意义的 isLoading', () {
      final src =
          _stripComments(File('lib/mixins/mixin_narrative.dart').readAsStringSync());
      final i = src.indexOf('void generateMoreSuggestions()');
      expect(i, greaterThan(-1),
          reason: '本地生成为同步操作，包 async+isLoading 不会渲染任何一帧');
      final body = src.substring(i, i + 300);
      expect(body.contains('isLoading = true'), isFalse);
      expect(body.contains('notifyListeners()'), isTrue);
    });

    test('去重正则已提到循环外编译', () {
      final src =
          _stripComments(File('lib/mixins/mixin_narrative.dart').readAsStringSync());
      expect(src.contains('static final RegExp _collapseWs'), isTrue,
          reason: '原先 RegExp 写在 where 回调里，每个候选短语都重新编译一次正则');
      final gen = src.substring(src.indexOf('_generateLocalSuggestions() {'));
      expect(gen.contains('replaceAll(RegExp('), isFalse);
    });
  });

  group('/查看 NPC 档案', () {
    final cmdSrc = _stripComments(
        File('lib/mixins/mixin_commands.dart').readAsStringSync());
    final sysSrc =
        _stripComments(File('lib/mixins/mixin_systems.dart').readAsStringSync());

    test('命令已注册且带别名', () {
      expect(cmdSrc.contains("primary: '查看'"), isTrue);
      expect(cmdSrc.contains("'打听'"), isTrue);
      expect(cmdSrc.contains('formatCharacterDossier'), isTrue);
    });

    test('基类有声明，跨 mixin 调用才能解析', () {
      final base = _stripComments(
          File('lib/providers/game_provider_base.dart').readAsStringSync());
      expect(base.contains('formatCharacterDossier('), isTrue);
    });

    test('可见性判定仍然生效（没见过的 NPC 不给看）', () {
      final i = sysSrc.indexOf('String formatCharacterDossier(');
      expect(i, greaterThan(-1));
      final body = sysSrc.substring(i, i + 1200);
      expect(body.contains('_isNPCVisible'), isTrue);
      expect(body.contains('素不相识'), isTrue);
    });

    test('原著魔杖 canonWandFor 已接上', () {
      expect(sysSrc.contains('canonWandFor(npc.name)'), isTrue,
          reason: 'canonWandFor 此前零调用，6 位原著角色的魔杖设定没人用');
    });
  });

  group('NPC 查名只有一份实现', () {
    test('不再有手写的 nameMatchScore 取最高分循环', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        // 统一实现本身与模型层的打分函数不算
        if (path.endsWith('lib/utils/npc_lookup.dart')) continue;
        if (path.endsWith('lib/models/npc.dart')) continue;
        final src = _stripComments(entity.readAsStringSync());
        if (src.contains('nameMatchScore')) offenders.add(path);
      }
      expect(offenders, isEmpty,
          reason: '按名查找应统一走 findNpcByKeyword。散落的实现曾让同一个名字'
              '在不同入口命中不同的 NPC：\n' + offenders.join('\n'));
    });

    test('findNpcByKeyword 能靠姓氏命中', () {
      // 「斯内普」是姓氏，靠 NPC.allNames 的姓氏推导命中
      final npc = findNpcByKeyword(
        [_npc('西弗勒斯·斯内普'), _npc('哈利·波特')],
        '斯内普',
      );
      expect(npc, isNotNull);
      expect(npc!.name, '西弗勒斯·斯内普');
    });

    test('查不到返回 null，不造假 NPC', () {
      final npc = findNpcByKeyword([_npc('哈利·波特')], '伏地魔');
      expect(npc, isNull);
    });
  });

  group('学院杯记账', () {
    test('不得再有裸写 houseCupPoints 的加分点', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        final src = _stripComments(entity.readAsStringSync());
        final lines = src.split('\n');
        // addHouseCupPoints 本身就是那唯一一处允许的写入，跳过它的方法体
        final start = src.indexOf('void addHouseCupPoints(');
        final end =
            start < 0 ? -1 : src.indexOf('\n  }', start);
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (!RegExp(r'\.houseCupPoints\s*\+=').hasMatch(line)) continue;
          if (start >= 0 && i >= _lineOf(src, start) && i <= _lineOf(src, end)) {
            continue;
          }
          offenders.add('$path:${i + 1}  $line');
        }
      }
      expect(offenders, isEmpty,
          reason: '学院杯加分必须走 addHouseCupPoints(amount, reason)，'
              '否则来源明细统计不到：\n' + offenders.join('\n'));
    });

    test('addHouseCupPoints 会记录来源', () {
      final src =
          _stripComments(File('lib/mixins/mixin_play.dart').readAsStringSync());
      final i = src.indexOf('void addHouseCupPoints(');
      final body = src.substring(i, i + 300);
      expect(body.contains('houseCupSources[reason]'), isTrue);
    });

    test('学年结算会清空来源明细', () {
      final src =
          _stripComments(File('lib/mixins/mixin_play.dart').readAsStringSync());
      final i = src.indexOf('void settleHouseCup()');
      final body = src.substring(i, src.indexOf('_finishLocal', i));
      expect(body.contains('p.houseCupPoints = 0;'), isTrue);
      expect(body.contains('houseCupSources.clear()'), isTrue);
    });

    test('来源明细能存进存档并读回', () {
      final p = Player(
        id: 't',
        name: '测试',
        birthYear: '1980',
        bloodType: '混血',
        birthLocation: '伦敦',
        house: 'Gryffindor',
        houseCupPoints: 35,
        houseCupSources: {'魁地奇取胜': 30, '决斗获胜': 5},
      );
      final json = p.toJson();
      expect(json['house_cup_sources'], isA<Map>());
      final back = Player.fromJson(json);
      expect(back.houseCupPoints, 35);
      expect(back.houseCupSources['魁地奇取胜'], 30);
      expect(back.houseCupSources['决斗获胜'], 5);
    });
  });
}

// ==================== AI 提供商默认值 ====================
// 出厂模型/端点原先散在 6 处且互相打架（Agnes 一边 turbo 一边 flash），
// 已收敛到 lib/data/provider_defaults.dart。本组防止副本复活。

void _providerDefaultsGroup() {
  group('提供商默认值只有一份', () {
    // 两个设置页已瘦身为 SettingsBody 的壳，helper 随之收进 body 里。
    const files = [
      'lib/providers/app_provider.dart',
      'lib/screens/settings/settings_body.dart',
      'lib/screens/settings/settings_provider_card.dart',
    ];

    /// 去掉行注释再扫描，否则注释里引用的旧值会被当成真实代码。
    String strip(String src) => src
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'//.*$'), ''))
        .join('\n');

    test('任何文件都不再写死 baseUrl', () {
      final offenders = <String>[];
      for (final path in files) {
        final src = strip(File(path).readAsStringSync());
        for (final m in RegExp(r'https://[a-z.\-]+').allMatches(src)) {
          offenders.add('$path -> ${m.group(0)}');
        }
      }
      expect(offenders, isEmpty,
          reason: '端点地址应统一在 kProviderDefaults 里：\n${offenders.join('\n')}');
    });

    test('免费/付费模型清单必须是总表的子集', () {
      // 这两份是给设置页做分组展示的策展清单，允许单独维护，
      // 但绝不能列出 kProviderDefaults 里没有的模型——
      // 否则玩家会选到一个下拉里存在、实际却发不出去的模型。
      final app = AppProvider();
      for (final p in AiProvider.values) {
        final all = defaultsForProvider(p.name).models;
        for (final m in app.freeModelsFor(p)) {
          expect(all.contains(m), isTrue,
              reason: '${p.name} 的免费清单含 $m，但出厂列表里没有它');
        }
        for (final m in app.popularPaidModelsFor(p)) {
          expect(all.contains(m), isTrue,
              reason: '${p.name} 的付费清单含 $m，但出厂列表里没有它');
        }
      }
    });

    test('四个文件的默认值 helper 都委托给了 defaultsForProvider', () {
      for (final path in files) {
        final src = strip(File(path).readAsStringSync());
        expect(src.contains('defaultsForProvider'), isTrue, reason: path);
      }
    });

    test('kProviderDefaults 覆盖全部三个提供商', () {
      for (final p in ['deepseek', 'agnes', 'sensenova']) {
        final d = defaultsForProvider(p);
        expect(d.model, isNotEmpty, reason: p);
        expect(d.models, isNotEmpty, reason: p);
        expect(d.baseUrl, startsWith('https://'), reason: p);
        expect(d.chatPath, isNotEmpty, reason: p);
        expect(d.displayName, isNotEmpty, reason: p);
        expect(d.tagline, isNotEmpty, reason: p);
      }
    });

    test('出厂默认模型必须在可选列表中', () {
      for (final p in ['deepseek', 'agnes', 'sensenova']) {
        final d = defaultsForProvider(p);
        expect(d.models.contains(d.model), isTrue,
            reason: '$p 的默认模型 ${d.model} 不在可选列表里，'
                '设置页会显示一个下拉里根本不存在的选项');
      }
    });

    test('AiConfig 工厂返回的模型与出厂默认一致', () {
      // 这是原先的实际 bug：AiConfig.agnes 用 turbo，fallback 用 flash，
      // 界面显示的和请求发出去的不是同一个模型
      expect(AiConfig.agnes('k').model, defaultsForProvider('agnes').model);
      expect(AiConfig.deepseek('k').model, defaultsForProvider('deepseek').model);
      expect(AiConfig.sensenova('k').model,
          defaultsForProvider('sensenova').model);
    });

    test('AiConfig 工厂的端点与出厂默认一致', () {
      expect(AiConfig.agnes('k').baseUrl, defaultsForProvider('agnes').baseUrl);
      expect(AiConfig.deepseek('k').baseUrl,
          defaultsForProvider('deepseek').baseUrl);
      expect(AiConfig.sensenova('k').baseUrl,
          defaultsForProvider('sensenova').baseUrl);
    });

    test('未知 provider 回落到 deepseek，不抛异常', () {
      expect(defaultsForProvider('nope').model,
          defaultsForProvider('deepseek').model);
    });
  });
}

// ==================== 设置页去重 ====================
// settings_screen 与 game_settings_tab 此前各有一份 460 行、逐行 86% 相同的
// 正文。改一个开关要改两处，且已经漏过（剧情回放只存在于 Tab，从手机主页进
// 设置的用户根本看不到）。现在两边共用 SettingsBody，本组防止副本复活。

void _settingsDedupGroup() {
  group('设置页只有一份正文', () {
    const body = 'lib/screens/settings/settings_body.dart';
    const callers = [
      'lib/screens/settings_screen.dart',
      'lib/screens/game/game_settings_tab.dart',
    ];

    test('两份设置页都改为复用 SettingsBody', () {
      for (final f in callers) {
        final src = File(f).readAsStringSync();
        expect(src.contains('settings_body.dart'), isTrue,
            reason: '$f 没有引用 settings_body.dart，正文又被复制了一份');
      }
    });

    test('设置正文只存在于 SettingsBody', () {
      // '🤖 AI 服务配置' 是正文第一个区块的标题，是副本最明显的指纹
      final offenders = <String>[];
      for (final f in _allLibFiles()) {
        if (f == body) continue;
        if (File(f).readAsStringSync().contains('🤖 AI 服务配置')) {
          offenders.add(f);
        }
      }
      expect(offenders, isEmpty,
          reason: '设置正文被复制到：$offenders。应改为复用 SettingsBody');
    });

    test('两份设置页都不再各自维护政治立场样式', () {
      // 原先两边各写一份 _stanceDesc/_stanceIcon/_stanceColor，共 6×3 个分支
      for (final f in callers) {
        final src = File(f).readAsStringSync();
        for (final fn in ['_stanceDesc', '_stanceIcon', '_stanceColor']) {
          expect(src.contains(fn), isFalse,
              reason: '$f 又定义了 $fn，应改为读 lib/data/political_stance.dart');
        }
      }
    });

    test('独立设置页现在也有剧情回放入口', () {
      // SettingsBody 默认打开剧情回放，且入口在共享正文里，两边都能看到
      final src = File(body).readAsStringSync();
      expect(src.contains('StoryHistoryScreen'), isTrue,
          reason: '剧情回放入口从共享正文里消失了');
      expect(src.contains('showStoryReplay'), isTrue);
    });

    test('「开始新游戏」的退栈行为可配置', () {
      // 独立设置页需要额外 pop 退出，Tab 内不需要。差异必须走回调而不是复制正文
      final src = File('lib/screens/settings_screen.dart').readAsStringSync();
      expect(src.contains('onAfterNewGame'), isTrue,
          reason: '独立设置页没有传 onAfterNewGame，确认新游戏后不会退出设置页');
      final tabSrc = File('lib/screens/game/game_settings_tab.dart')
          .readAsStringSync()
          .split('\n')
          .map((l) => l.replaceAll(RegExp(r'//.*$'), ''))
          .join('\n');
      expect(tabSrc.contains('onAfterNewGame'), isFalse,
          reason: 'Tab 内传了 onAfterNewGame，会把整个 Tab 栈弹掉');
    });

    test('两个设置页文件都瘦到 30 行以内', () {
      for (final f in callers) {
        final lines = File(f).readAsLinesSync().length;
        expect(lines, lessThan(30),
            reason: '$f 有 $lines 行，正文似乎又被塞回来了');
      }
    });
  });

  group('政治立场只有一份定义', () {
    test('名称常量表与完整定义逐项一致', () {
      // kPoliticalStanceNames 为了能在 const 上下文使用而写死，
      // 靠这条断言保证它没和 kPoliticalStances 漂移
      expect(kPoliticalStanceNames.length, kPoliticalStances.length);
      for (var i = 0; i < kPoliticalStances.length; i++) {
        expect(kPoliticalStanceNames[i], kPoliticalStances[i].name,
            reason: '第 $i 项不一致：常量表 ${kPoliticalStanceNames[i]} vs '
                '定义 ${kPoliticalStances[i].name}');
      }
    });

    test('六个立场都有描述、图标与配色', () {
      final seen = <String>{};
      final argbs = <int>{};
      for (final s in kPoliticalStances) {
        expect(s.desc.isNotEmpty, isTrue, reason: '${s.name} 缺描述');
        expect(s.iconKey.isNotEmpty, isTrue, reason: '${s.name} 缺图标');
        expect(seen.add(s.name), isTrue, reason: '立场名重复：${s.name}');
        expect(argbs.add(s.argb), isTrue, reason: '配色重复：${s.name}');
      }
      expect(kPoliticalStances.length, 6);
    });

    test('立场中文名只出现在 data 层', () {
      const dataFile = 'lib/data/political_stance.dart';
      final offenders = <String>[];
      for (final f in _allLibFiles()) {
        if (f == dataFile) continue;
        final src = File(f).readAsStringSync();
        for (final name in kPoliticalStanceNames) {
          // 允许出现在注释里（说明性文字），只拦代码
          final code = src
              .split('\n')
              .map((l) => l.replaceAll(RegExp(r'//.*$'), ''))
              .join('\n');
          if (code.contains("'$name'")) offenders.add('$f -> $name');
        }
      }
      expect(offenders, isEmpty,
          reason: '政治立场名在 data 层之外被硬编码：$offenders');
    });

    test('未知立场名回落到默认而不是抛异常', () {
      expect(stanceFor('不存在的立场').name, kDefaultPoliticalStance);
      expect(stanceFor('血统平等').desc, isNotEmpty);
    });

    test('默认立场本身必须在列表里', () {
      expect(kPoliticalStanceNames.contains(kDefaultPoliticalStance), isTrue,
          reason: '默认立场 $kDefaultPoliticalStance 不在可选列表里，'
              '设置页会高亮一个不存在的选项');
    });
  });
}

/// lib 下所有 dart 文件，相对包根。
List<String> _allLibFiles() {
  final out = <String>[];
  void walk(Directory d) {
    for (final e in d.listSync(followLinks: false)) {
      if (e is Directory) {
        walk(e);
      } else if (e is File && e.path.endsWith('.dart')) {
        out.add(e.path);
      }
    }
  }

  walk(Directory('lib'));
  return out;
}

// ==================== 送礼玩法 ====================
// giftPrefs 此前是一条完整的死链：数据被生成、被写进存档，但没有任何地方
// 读过它；「赠送礼物（一般/喜欢/挚爱）」三条规则也一次都没被引用。送礼
// 退化成被动好感推断里的一个关键词（+1~+2），送什么完全不影响结果。

void _giftGivingGroup() {
  group('送礼判定', () {
    const prefs = {'旧书': 8, '花束': 7, '手写贺卡': 5, '巧克力蛙': 2};

    test('分档与原型表的分值分布吻合', () {
      expect(evaluateGift(prefs, '旧书').reaction, GiftReaction.beloved);
      expect(evaluateGift(prefs, '花束').reaction, GiftReaction.liked);
      expect(evaluateGift(prefs, '手写贺卡').reaction, GiftReaction.liked);
      expect(evaluateGift(prefs, '巧克力蛙').reaction, GiftReaction.neutral);
      expect(evaluateGift(prefs, '龙血').reaction, GiftReaction.unknown);
    });

    test('三档正反馈的区间落在设定 11.2 的范围内', () {
      for (final v in [
        evaluateGift(prefs, '旧书'),
        evaluateGift(prefs, '花束'),
        evaluateGift(prefs, '巧克力蛙'),
      ]) {
        expect(v.minGain, greaterThan(0));
        expect(v.maxGain, greaterThanOrEqualTo(v.minGain));
      }
    });

    test('送偏了不掉好感', () {
      // 花钱花物品去试探偏好，为探索本身扣分太苛刻
      final v = evaluateGift(prefs, '完全不在表里的东西');
      expect(v.reaction, GiftReaction.unknown);
      expect(v.minGain, greaterThanOrEqualTo(0));
    });

    test('空偏好表一律最低档，不用平均值糊弄', () {
      expect(evaluateGift({}, '巧克力蛙').reaction, GiftReaction.unknown);
    });

    test('判定幅度与 affectionChangeRules 一致', () {
      // 设定表会被写进给 AI 的提示词，两边对不上会出现
      // 「AI 写得情深义重、数值只涨 1 点」的割裂
      expect(giftRuleMismatches(), isEmpty,
          reason: giftRuleMismatches().join('；'));
    });

    test('ruleName 能在设定表里找到对应项', () {
      for (final r in GiftReaction.values) {
        if (r == GiftReaction.unknown) continue; // 无感档是本地补充，设定表里没有
        final v = GiftVerdict(reaction: r, score: 8, minGain: 1, maxGain: 2);
        expect(
          affectionChangeRules.any((e) => e.type == v.ruleName),
          isTrue,
          reason: '${v.ruleName} 不在 affectionChangeRules 里',
        );
      }
    });

    test('topWishes 按分值降序', () {
      expect(topWishes(prefs), ['旧书', '花束', '手写贺卡']);
      expect(topWishes(prefs, limit: 1), ['旧书']);
    });
  });

  group('送礼数据必须对得上物品目录', () {
    test('每个原型偏好的每件礼物都能买到', () {
      // 这是此前的实际 bug：偏好表写着「魁地奇徽章」「花束」「羽毛笔」，
      // 但目录里一样都没有，玩家送不出任何一件 NPC 真心喜欢的东西
      final missing = <String>[];
      for (final entry in kArchetypeGiftPrefs.entries) {
        for (final name in entry.value.keys) {
          if (itemDefByName(name) == null) {
            missing.add('${entry.key} -> $name');
          }
        }
      }
      expect(missing, isEmpty,
          reason: '这些礼物不在 kItemCatalog 里，玩家永远送不出：$missing');
    });

    test('每个原型至少有一件挚爱档（8分）礼物', () {
      // 没有挚爱档，送礼的天花板就只有「喜欢」的 5~8 分
      for (final entry in kArchetypeGiftPrefs.entries) {
        expect(entry.value.values.any((v) => v >= 8), isTrue,
            reason: '${entry.key} 没有挚爱档礼物');
      }
    });

    test('材料也能当礼物送出去', () {
      // 禁林采集是材料唯一产出途径，此前材料没有任何消耗途径
      final withMaterial = kArchetypeGiftPrefs.values
          .expand((m) => m.keys)
          .where((n) => itemDefByName(n)?.type == '材料')
          .toSet();
      expect(withMaterial.length, greaterThanOrEqualTo(3),
          reason: '偏好材料的原型太少，材料依然会堆在背包里');
    });

    test('礼物在目录里有独立的类型，UI 也能分组', () {
      expect(kItemCatalog.where((d) => d.type == '礼物').length,
          greaterThanOrEqualTo(10));
      final inv = File('lib/screens/shop/inventory_screen.dart').readAsStringSync();
      expect(inv.contains("'礼物',"), isTrue,
          reason: '背包分类列表里没有「礼物」，新加的礼物玩家筛不到');
    });
  });

  group('装备槽位有升级空间', () {
    test('每个装备槽至少两件可选', () {
      // 此前 hat 和 amulet 各只有 1 件，买了就到头，装备系统在这两个槽
      // 位上等于不存在
      final bySlot = <String, int>{};
      for (final d in kItemCatalog.where((d) => d.isEquippable)) {
        bySlot[d.equipSlot!] = (bySlot[d.equipSlot] ?? 0) + 1;
      }
      for (final slot in bySlot.keys) {
        expect(bySlot[slot], greaterThanOrEqualTo(2),
            reason: '$slot 槽只有 ${bySlot[slot]} 件，没有选择余地');
      }
      expect(bySlot.keys.toSet(), containsAll(['robe', 'hat', 'amulet', 'broom']));
    });

    test('同槽内高价装备的属性加成不低于低价装备', () {
      final bySlot = <String, List<ItemDef>>{};
      for (final d in kItemCatalog.where((d) => d.isEquippable)) {
        (bySlot[d.equipSlot!] ??= []).add(d);
      }
      int total(ItemDef d) =>
          d.statBonus.values.fold(0, (a, b) => a + b) + d.combatBonus + d.castBonus;
      for (final entry in bySlot.entries) {
        final sorted = entry.value.toList()..sort((a, b) => a.price.compareTo(b.price));
        for (var i = 1; i < sorted.length; i++) {
          expect(total(sorted[i]), greaterThanOrEqualTo(total(sorted[i - 1])),
              reason: '${entry.key} 槽：${sorted[i].name}(${sorted[i].price}) 比 '
                  '${sorted[i - 1].name}(${sorted[i - 1].price}) 贵却没有更强');
        }
      }
    });
  });

  group('送礼命令已接线', () {
    test('命令表里注册了送礼', () {
      final src = File('lib/mixins/mixin_commands.dart').readAsStringSync();
      expect(src.contains("primary: '送礼'"), isTrue);
      expect(src.contains('giveGift'), isTrue);
    });

    test('giveGift 在基类里有声明', () {
      // 跨 mixin 文件调用需要基类声明，否则编译不过
      final src = File('lib/providers/game_provider_base.dart').readAsStringSync();
      expect(src.contains('String giveGift('), isTrue);
    });

    test('消耗物品走共享实现而不是各自 indexWhere', () {
      final ops = File('lib/utils/inventory_ops.dart').readAsStringSync();
      expect(ops.contains('removeOneItem'), isTrue);
      // mixin_relations 送礼时必须调用它
      final rel = File('lib/mixins/mixin_relations.dart').readAsStringSync();
      expect(rel.contains('removeOneItem('), isTrue);
    });
  });
}

// ==================== 材料产出分层 ====================
// 此前禁林采集是在 4 种材料里均匀取一，跑十趟拿到的东西大同小异，
// 「去禁林翻树根」很快就没有可期待的东西了。

void _materialLootGroup() {
  group('材料产出分档', () {
    test('常见与稀有两个池子不重叠', () {
      final overlap =
          kRareLootMaterials.toSet().intersection(kCommonLootMaterials.toSet());
      expect(overlap, isEmpty,
          reason: '这些材料同时出现在两个池子里：$overlap');
    });

    test('池子里的每个名字都能在目录里找到', () {
      for (final n in [...kCommonLootMaterials, ...kRareLootMaterials]) {
        expect(itemDefByName(n), isNotNull, reason: '$n 不在 kItemCatalog 里');
      }
    });

    test('稀有材料的售价比常见材料高一截', () {
      int price(String n) => itemDefByName(n)!.price;
      final commonMax =
          kCommonLootMaterials.map(price).reduce((a, b) => a > b ? a : b);
      final rareMin =
          kRareLootMaterials.map(price).reduce((a, b) => a < b ? a : b);
      expect(rareMin, greaterThan(commonMax),
          reason: '稀有材料最低价 $rareMin 应该高于常见材料最高价 $commonMax');
    });

    test('低 roll 出稀有、高 roll 出常见', () {
      expect(kRareLootMaterials.contains(rollLootMaterial(0)), isTrue);
      expect(kRareLootMaterials.contains(rollLootMaterial(149)), isTrue);
      expect(kCommonLootMaterials.contains(rollLootMaterial(150)), isTrue);
      expect(kCommonLootMaterials.contains(rollLootMaterial(999)), isTrue);
    });

    test('稀有率与实际分布一致', () {
      var rare = 0;
      const samples = 1000;
      for (var i = 0; i < samples; i++) {
        if (kRareLootMaterials.contains(rollLootMaterial(i))) rare++;
      }
      expect(rare, kRareLootRatePerThousand,
          reason: '稀有材料实际占 ${rare / 10}%，与设定的 '
              '${kRareLootRatePerThousand / 10}% 不符');
    });

    test('禁林采集已经用上分档而不是直接摇常见池', () {
      final src = File('lib/mixins/mixin_play.dart').readAsStringSync();
      expect(src.contains('rollLootMaterial('), isTrue,
          reason: '采集点还在直接摇 kCommonLootMaterials，稀有材料永远出不来');
    });

    test('稀有产出有区别于常见的叙事反馈', () {
      // 拿到稀有材料和拿到一撮独角兽毛，文本不该一样
      final src = File('lib/mixins/mixin_play.dart').readAsStringSync();
      final at = src.indexOf('rollLootMaterial(');
      final around = src.substring(at, at + 700);
      expect(around.contains('rare'), isTrue);
      expect(around.contains('屏住'), isTrue);
    });
  });
}
