// 批次19（F42 测试规模再平衡）：从 progression_fix_test.dart 下沉出来的
// 「数据一致性 / 编号标签 / 内容可达性」cluster。
//
// 原先这些 _xxxGroup() 全部住在一个 3,042 行的文件里（约占全部测试 19%），
// 本文件按语义域拆出后，单体文件回到正常规模、聚焦清晰。
//
// 说明：_allLibFiles / _codeOnly 是各类「lib 下不得再出现手写副本」扫描共用的
// 两个小工具函数，为保证本文件自足、不跨文件 import 私有符号，这里保守地
// 复制一份（两行级的小函数，复制的维护成本远低于强行抽共享模块）。
//
// game 对照：本文件只做「数据表自洽 + 标签单一来源」的纯逻辑断言，
// 不触碰玩法 / UI / 叙事链路，因此安全性高，拆分本身不改任何产品逻辑。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/player.dart';
import 'package:hogwarts_life_simulator/data/attribute_data.dart';
import 'package:hogwarts_life_simulator/data/blood_status.dart';
import 'package:hogwarts_life_simulator/data/course_data.dart';
import 'package:hogwarts_life_simulator/data/event_anchors.dart';
import 'package:hogwarts_life_simulator/data/gift_rules.dart';
import 'package:hogwarts_life_simulator/data/archetype_data.dart';
import 'package:hogwarts_life_simulator/data/house_data.dart';
import 'package:hogwarts_life_simulator/data/item_data.dart';
import 'package:hogwarts_life_simulator/data/locations.dart';
import 'package:hogwarts_life_simulator/data/quest_data.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _giftGivingGroup();
  _materialLootGroup();
  _eventAnchorGroup();
  _houseNameGroup();
  _bloodStatusGroup();
  _attributeLabelGroup();
  _questTypeLabelGroup();
  _statusOccupationGroup();
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

/// 读一个源文件并去掉整行注释。
String _codeOnly(String path) {
  final lines = File(path).readAsStringSync().split('\n');
  final out = <String>[];
  for (final line in lines) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//')) continue;
    out.add(line);
  }
  return out.join('\n');
}

// ==================== 事件锚点 / 已知地点 ====================
void _eventAnchorGroup() {
  group('事件锚点表数据完整性', () {
    test('锚点 id 不重复', () {
      final seen = <String>{};
      final dup = <String>[];
      for (final a in eventAnchors) {
        if (!seen.add(a.id)) dup.add(a.id);
      }
      expect(dup, isEmpty, reason: '重复 id 会导致后一条永远触发不了：$dup');
    });

    test('月份与年级都在合法范围', () {
      for (final a in eventAnchors) {
        expect(a.month, inInclusiveRange(1, 12),
            reason: '${a.id} 月份 ${a.month} 不在 1-12');
        if (a.grade != null) {
          expect(a.grade, inInclusiveRange(1, 7),
              reason: '${a.id} 年级 ${a.grade} 不在 1-7');
        }
      }
    });

    test('时段窗口没有写反', () {
      for (final a in eventAnchors) {
        if (a.minHour == null || a.maxHour == null) continue;
        expect(a.minHour! <= a.maxHour!, isTrue,
            reason: '${a.id} 时段 ${a.minHour}-${a.maxHour} 是空区间，永远触发不了');
        expect(a.minHour, inInclusiveRange(0, 23), reason: '${a.id} minHour 越界');
        expect(a.maxHour, inInclusiveRange(0, 23), reason: '${a.id} maxHour 越界');
      }
    });

    test('位置约束能匹配到已知地点', () {
      // 反例：requiredLocation 写了个错别字（比如"特快列车"写成"特快车"），
      // 这条锚点就永远等不到玩家"到达"那个地方
      final bad = <String>[];
      for (final a in eventAnchors) {
        final req = a.requiredLocation;
        if (req == null) continue;
        if (!locationKeywordResolvable(req)) bad.add('${a.id} → $req');
      }
      expect(bad, isEmpty,
          reason: '这些锚点要求的位置在地点表里不存在，永远触发不了：$bad');
    });

    test('每个月都有锚点（学年节奏不出现整月空窗）', () {
      final months = eventAnchors.map((a) => a.month).toSet();
      final missing = [
        for (var m = 1; m <= 12; m++)
          if (!months.contains(m)) m,
      ];
      expect(missing, isEmpty, reason: '这几个月没有任何事件锚点：$missing');
    });

    test('一年级九月入学锚点的时段窗口覆盖得到特快抵达', () {
      // 开局 9月1日 10:45 在国王十字，特快 11 点发车、12-14 点到霍格莫德。
      // 这条锚点专门钉住：窗口既不能早到车还没开，也不能晚到玩家已下車。
      final a = eventAnchors.firstWhere((x) => x.id == 'g1_sep_arrival');
      expect(a.month, 9);
      expect(a.grade, 1);
      expect(a.requiredLocation, '特快');
      expect(a.minHour, 12, reason: '11 点才发车，12 点前不该描写抵达');
      expect(a.maxHour, greaterThanOrEqualTo(14),
          reason: '12-14 点才到霍格莫德，窗口关太早会漏掉抵达');
    });

    test('时段窗口被大跨度时间跳跃跨过去时依然能触发', () {
      // 睡觉一次推进 480 分钟。如果只判断落地那一刻的小时数，
      // 11 点上床、19 点起床就把 [12,15] 这个窗口整个跨过去了。
      final fired = <String>{};
      final hit = anchorsFor(
        month: 9,
        grade: 1,
        era: 'harry_same',
        firedIds: fired,
        hour: 19,
        hourFrom: 11,
        dayDelta: 0,
        currentLocation: '霍格沃茨特快列车',
      );
      expect(hit.map((a) => a.id), contains('g1_sep_arrival'));
    });

    test('还没到窗口就是不该触发', () {
      // 反向保护：区间匹配不能宽到失去意义，10:45 车还没开
      final hit = anchorsFor(
        month: 9,
        grade: 1,
        era: 'harry_same',
        firedIds: <String>{},
        hour: 11,
        hourFrom: 10,
        dayDelta: 0,
        currentLocation: '霍格沃茨特快列车',
      );
      expect(hit.map((a) => a.id), isNot(contains('g1_sep_arrival')));
    });
  });

  group('已知地点表', () {
    test('主名不重复', () {
      final names = kLocationNames;
      expect(names.toSet().length, names.length);
    });

    test('每条都有至少一个别名', () {
      for (final (name, aliases) in kKnownLocations) {
        expect(aliases, isNotEmpty, reason: '$name 没有任何别名，匹配不到叙事文本');
      }
    });

    test('别名能解析回主名', () {
      for (final (name, aliases) in kKnownLocations) {
        for (final alias in aliases) {
          expect(resolveLocationName('你来到了$alias。'), name,
              reason: '别名「$alias」没有解析回「$name」');
        }
      }
    });

    test('主名本身也能命中', () {
      for (final name in kLocationNames) {
        expect(resolveLocationName(name), isNotNull,
            reason: '主名「$name」自己都没法解析');
      }
    });
  });
}

// ==================== 学院名只有一份 ====================
// 学院 key→中文名 原先有 5 份手写副本（mixin_init / mixin_play 三处 /
// UiHelpers.getHouseLabel），且各自默认值还不一样。改一个译名要改 5 个地方。

void _houseNameGroup() {
  group('学院名映射只有一份', () {
    test('lib 下不再有手写的学院名 switch', () {
      final offenders = <String>[];
      for (final f in _allLibFiles()) {
        final src = File(f).readAsStringSync();
        for (final key in kHouseKeys) {
          // 「'Gryffindor' => '格兰芬多'」这种按 key 分支的写法才要拦；
          // 数据文件里出现中文院名是正常的（那是映射表本身）
          if (src.contains("'$key' => '")) offenders.add('$f → $key');
        }
      }
      expect(offenders, isEmpty,
          reason: '又有人手写了学院名分支，应改用 houseDisplayName()：$offenders');
    });

    test('中英文互为逆运算', () {
      for (final key in kHouseKeys) {
        final cn = houseDisplayName(key);
        expect(houseKeyByDisplayName(cn), key, reason: '$cn 反查不回 $key');
        expect(houseKeyByDisplayName(key), key, reason: '$key 英文 key 反查失败');
      }
    });

    test('默认值按调用方语境走', () {
      // 四处调用方原本的默认值分别是 '对手' / '（未分院）' / 原 key / '格兰芬多'
      expect(houseDisplayName(null), '未分院');
      expect(houseDisplayName(''), '未分院');
      expect(houseDisplayName('Gryffindor', fallback: '对手'), '格兰芬多');
      expect(houseDisplayName('Unknown', fallback: '对手'), '对手');
      expect(houseDisplayName('Unknown', fallback: '（未分院）'), '（未分院）');
    });

    test('大小写不敏感（老存档和 NPC 数据里两种都有）', () {
      expect(houseDisplayName('gryffindor'), '格兰芬多');
      expect(houseDisplayName('SLYTHERIN'), '斯莱特林');
    });

    test('kHouseNames 与 kHouseKeys 顺序一致', () {
      expect(kHouseNames, hasLength(kHouseKeys.length));
      for (var i = 0; i < kHouseKeys.length; i++) {
        expect(kHouseNames[i], houseDisplayName(kHouseKeys[i]));
      }
    });
  });
}

// ==================== 血统标签只有一份 ====================
// 血统 key→中文名 原先有 4 份手写副本：mixin_systems.bloodStatusLabel（13 项）、
// intro_screen._bloodLabels（11 项，其中「默然者」还多带「（高风险）」）、
// intro_screen._bloodDescriptions、mixin_systems._bloodLabel（NPC 侧别称版）。
// 玩家在问卷里看到的名字和写进存档、显示在状态栏上的名字可以对不上。

void _bloodStatusGroup() {
  group('血统标签只有一份', () {
    test('lib 下不再有手写的血统标签分支', () {
      final offenders = <String>[];
      for (final f in _allLibFiles()) {
        if (f.endsWith('data/blood_status.dart')) continue; // 映射表本身
        final src = File(f).readAsStringSync();
        for (final key in kBloodStatusLabels.keys) {
          // 「'muggleborn': '麻瓜出身'」/「'pure' || 'pureblood' => '纯血'」
          // 这类按 key 分支的写法才要拦
          if (src.contains("'$key': '") || src.contains("'$key' => '")) {
            offenders.add('$f → $key');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: '又有人手写了血统标签分支，应改用 blood_status.dart：$offenders');
    });

    test('问卷可选项都有标签和说明', () {
      expect(kBloodStatusOptions, isNotEmpty);
      for (final key in kBloodStatusOptions) {
        expect(kBloodStatusLabels.containsKey(key), isTrue,
            reason: '$key 可选但没有中文名');
        final desc = kBloodStatusDescriptions[key];
        expect(desc, isNotNull, reason: '$key 没有问卷说明');
        expect(desc!.trim(), isNotEmpty, reason: '$key 的说明是空的');
      }
    });

    test('问卷可选项不重复且都是规范 key', () {
      final seen = <String>{};
      for (final key in kBloodStatusOptions) {
        expect(seen.add(key), isTrue, reason: '$key 在可选项里重复了');
        expect(kBloodStatusAliases.containsKey(key), isFalse,
            reason: '$key 是别称，不该直接放进可选项');
      }
    });

    test('风险标注不会泄漏到游戏内文案', () {
      // 「（高风险）」只属于问卷 UI。状态栏/档案/AI prompt 走 bloodStatusLabelOf，
      // 那里必须干干净净——否则玩家会在状态栏上看到「默然者（高风险）」。
      for (final key in kBloodStatusLabels.keys) {
        expect(bloodStatusLabelOf(key), isNot(contains('高风险')),
            reason: '$key 的游戏内文案混进了问卷专属标注');
      }
      for (final key in kBloodStatusRisky) {
        expect(bloodStatusOptionLabel(key), contains('高风险'));
      }
      // 非高风险血统两种写法一致
      expect(bloodStatusOptionLabel('muggleborn'), bloodStatusLabelOf('muggleborn'));
    });

    test('未知 key 原样返回（比显示「未知」好排查）', () {
      expect(bloodStatusLabelOf('half_giant'), '半巨人');
      expect(bloodStatusLabelOf('some_new_blood'), 'some_new_blood');
    });

    test('NPC 侧认别称，unknown 显示「血统不明」', () {
      expect(npcBloodStatusLabel('pure'), '纯血');
      expect(npcBloodStatusLabel('pureblood'), '纯血');
      expect(npcBloodStatusLabel('half'), '混血巫师');
      expect(npcBloodStatusLabel('halfblood'), '混血巫师');
      expect(npcBloodStatusLabel('muggle'), '麻瓜出身');
      expect(npcBloodStatusLabel('muggleborn'), '麻瓜出身');
      expect(npcBloodStatusLabel('unknown'), '血统不明');
      expect(npcBloodStatusLabel(''), '血统不明');
      // 幽灵（宾斯教授）是 NPC 侧专属取值，也要有正经译名
      expect(npcBloodStatusLabel('ghost'), '幽灵');
      // 完全没见过的 key 沿用原值，不下断言式翻译
      expect(npcBloodStatusLabel('zombie'), 'zombie');
    });

    test('npc_data 里用到的血统都能翻出来', () {
      // 兜底：将来往 NPC 数据里加血统时，忘了补标签表会在这里炸出来
      final src = File('lib/data/npc_data.dart').readAsStringSync();
      final re = RegExp(r"bloodStatus: *'([^']+)'");
      final used = <String>{};
      for (final m in re.allMatches(src)) {
        used.add(m.group(1)!);
      }
      expect(used, isNotEmpty, reason: '没扫到 bloodStatus 字段，正则该更新了');
      for (final key in used) {
        final label = npcBloodStatusLabel(key);
        expect(label, isNot(contains('bloodStatus')), reason: 'NPC 血统 $key 没翻出来');
      }
      // 除了 unknown（本来就该显示「血统不明」），其余都应该有正经译名
      for (final key in used) {
        if (key == 'unknown') continue;
        expect(kBloodStatusLabels.containsKey(key), isTrue,
            reason: 'NPC 数据用了血统 $key，但标签表里没有它');
      }
    });
  });
}

// ==================== 属性标签只有一份 ====================
// 属性 key→中文名 原先两份且互相矛盾：
//   potions        attrLabel「魔药」     vs _attrLabelZh「魔药学」
//   magic_control  attrLabel「魔法控制」 vs _attrLabelZh「魔力控制」
//   observation    attrLabel「观察力」   vs _attrLabelZh「洞察力」
// 玩家在物品加成/宠物训练里看到一套名字，在任务需求/AI 上下文里看到另一套。

void _attributeLabelGroup() {
  group('属性标签只有一份', () {
    test('lib 下不再有手写的属性标签表', () {
      // 注意不能只查「某个 key 出现了手写分支」——'social' 在声望表里也有
      // （'social': '社交声望'），那是另一套词汇。真正的第二份属性表会同时
      // 覆盖一堆属性 key，所以用「≥3 个属性 key 被手写映射」当判据。
      final offenders = <String>[];
      for (final f in _allLibFiles()) {
        if (f.endsWith('data/attribute_data.dart')) continue; // 映射表本身
        final src = File(f).readAsStringSync();
        final hits = <String>[];
        for (final key in kAttributeLabels.keys) {
          if (src.contains("'$key': '") || src.contains("'$key' => '")) {
            hits.add(key);
          }
        }
        if (hits.length >= 3) offenders.add('$f → $hits');
      }
      expect(offenders, isEmpty,
          reason: '又有人手抄了一份属性标签表，应改用 attributeLabel()：$offenders');
    });

    test('标签表与 Player 的默认属性表逐键对齐', () {
      // 属性 key 集合的权威在 Player._defaultAttributes。少一个 key 就是
      // 某个属性永远显示英文，多一个就是表已经漂了。
      final src = File('lib/models/player.dart').readAsStringSync();
      final block = RegExp(
        r'_defaultAttributes = \{(.*?)\};',
        dotAll: true,
      ).firstMatch(src);
      expect(block, isNotNull, reason: '没找到 _defaultAttributes，正则该更新了');
      final re = RegExp(r"'([a-z_]+)': *\d+");
      final keys = <String>{};
      for (final m in re.allMatches(block!.group(1)!)) {
        keys.add(m.group(1)!);
      }
      expect(keys, hasLength(kAttributeLabels.length),
          reason: '属性 key 集合不一致');
      for (final key in keys) {
        expect(kAttributeLabels.containsKey(key), isTrue,
            reason: 'Player 有属性 $key，标签表里没有');
      }
      for (final key in kAttributeLabels.keys) {
        expect(keys.contains(key), isTrue, reason: '标签表里的 $key 不是真属性');
      }
    });

    test('学业属性集合与课程表一致', () {
      final used = allCourses().map((c) => c.attribute).toSet();
      expect(used, kStudyAttributeKeys,
          reason: '课程会提升的属性变了，kStudyAttributeKeys 要跟着改');
      // 学业属性必须都是真属性（否则「上课」时注入的会是裸 key）
      for (final key in kStudyAttributeKeys) {
        expect(kAttributeLabels.containsKey(key), isTrue,
            reason: '$key 不是合法属性');
      }
    });

    test('矛盾译名已按课程名/MP 口径统一', () {
      expect(attributeLabel('potions'), '魔药学'); // 课程名就是「魔药学」
      expect(attributeLabel('magic_control'), '魔力控制'); // UI 上 MP 叫「魔力」
      expect(attributeLabel('observation'), '观察力'); // 保护神奇生物课的属性
    });

    test('未知 key 原样返回', () {
      expect(attributeLabel('intuition'), '直觉');
      expect(attributeLabel('not_an_attr'), 'not_an_attr');
    });
  });
}

// ==================== 委托类型标签只有一份 ====================

void _questTypeLabelGroup() {
  group('委托类型标签只有一份', () {
    test('lib 下不再有手写的委托类型 switch', () {
      final offenders = <String>[];
      for (final f in _allLibFiles()) {
        if (f.endsWith('data/quest_data.dart')) continue;
        final src = File(f).readAsStringSync();
        for (final key in kQuestTypeLabels.keys) {
          if (src.contains("'$key' => '")) offenders.add('$f → $key');
        }
      }
      expect(offenders, isEmpty,
          reason: '又有人手写了委托类型分支，应改用 questTypeLabel()：$offenders');
    });

    test('模板里用到的类型都有译名', () {
      for (final t in kQuestTemplates) {
        expect(kQuestTypeLabels.containsKey(t.type), isTrue,
            reason: '委托 ${t.id} 的 type=${t.type} 没有中文名');
      }
    });

    test('未知类型回落到「委托」而不是裸 key', () {
      expect(questTypeLabel('gather'), '收集');
      expect(questTypeLabel('defeat'), '讨伐');
      expect(questTypeLabel('pet'), '培养');
      expect(questTypeLabel('escort'), '委托');
    });
  });
}

// ==================== /状态 的「职业」不能是天赋 ====================
// /状态 里「【职业】」打的是 p.initialTalent，和下面「主修天赋」是同一个
// 字段——玩家看到的「职业」其实是自己的天赋。打工是散工、没有持久化岗位，
// 所以加了 currentJobTitle：在校显示学生，毕业后用最近一次打工的岗位。

void _statusOccupationGroup() {
  group('/状态 的职业字段', () {
    test('「职业」不再直接显示 initialTalent', () async {
      // 行为断言替代源码扫描：真实 GameProvider 上经 /状态 命令真跑 _formatStatus。
      // 给玩家塞一个独有的天赋值，/状态 后：
      //  1. 【职业】行必须是「学生」身份，绝不出现这个天赋值；
      //  2. 天赋只该出现在「主修天赋」那一行。
      final gp = await makeGame();
      gp.player!.initialTalent = '档案测试天赋';
      gp.handleLocalCommand('/状态');
      final text = gp.currentNarrative!;
      // 【职业】行：未毕业 → 「霍格沃茨N年级学生」
      expect(text, contains('年级学生'), reason: '职业行没有显示在校身份');
      expect(text, isNot(contains('档案测试天赋')),
          reason: '职业行又把天赋当职业显示了');
      // 主修天赋：真出现在专属行
      expect(text, contains('主修天赋：档案测试天赋'),
          reason: '主修天赋那一行没有显示天赋');
    });

    test('毕业后会显示最近岗位，没打过工显示待业', () {
      final src = _codeOnly('lib/mixins/mixin_commands.dart');
      expect(src, contains('worldState.graduated'), reason: '职业要按是否毕业分流');
      expect(src, contains('currentJobTitle'), reason: '毕业后要用最近岗位');
      expect(src, contains('待业'));
    });

    test('acceptJob 会记下岗位名', () {
      final src = _codeOnly('lib/mixins/mixin_relations.dart');
      final body = RegExp(
        r'int acceptJob\(String jobId\) \{(.*?)\n  \}',
        dotAll: true,
      ).firstMatch(src);
      expect(body, isNotNull, reason: '没找到 acceptJob，正则该更新了');
      expect(body!.group(1)!, contains('currentJobTitle'),
          reason: 'acceptJob 没写 currentJobTitle，毕业后职业永远是「待业」');
    });

    test('currentJobTitle 有 JSON 往返（老存档读不到就是 null，不炸）', () {
      final p = Player(
        name: '测试',
        birthYear: '1980',
        bloodType: 'muggleborn',
        birthLocation: '伦敦',
        currentJobTitle: '魔法部文员',
      );
      final json = p.toJson();
      expect(json['current_job_title'], '魔法部文员');
      expect(Player.fromJson(json).currentJobTitle, '魔法部文员');
      // 老存档没有这个字段
      final old = Map<String, dynamic>.from(json)..remove('current_job_title');
      expect(Player.fromJson(old).currentJobTitle, isNull);
    });
  });
}

// ==================== 送礼玩法 ====================
// giftPrefs 此前是一条完整的死链：数据被生成、被写进存档，但没有任何地方
// 读过它；「赠送礼物（一般/喜欢/挚爱）」三条规则也一次都没被引用。

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