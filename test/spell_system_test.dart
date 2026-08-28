import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/attribute_data.dart';
import 'package:hogwarts_life_simulator/data/collectible_data.dart';
import 'package:hogwarts_life_simulator/data/item_data.dart';
import 'package:hogwarts_life_simulator/data/spell_data.dart';
import 'package:hogwarts_life_simulator/data/time_cost_rules.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';

void main() {
  group('咒语表自洽', () {
    test('咒语名不重复', () {
      final names = spellCatalog.map((s) => s.name).toList();
      expect(names.toSet().length, names.length,
          reason: '重名的咒语在 learnedSpells 里会互相覆盖');
    });

    test('咒文的中文名与拉丁名都不为空', () {
      for (final s in spellCatalog) {
        expect(s.name.trim().isNotEmpty, isTrue);
        expect(s.incantation.trim().isNotEmpty, isTrue);
      }
    });

    test('关联属性都是合法属性键', () {
      final bad = spellCatalog
          .where((s) => !kAttributeLabels.containsKey(s.attribute))
          .map((s) => '${s.name} → ${s.attribute}')
          .toList();
      expect(bad, isEmpty,
          reason: '这些咒语挂了不存在的属性，等级上限会算不出来：$bad');
    });

    test('年级与难度都在合理区间', () {
      for (final s in spellCatalog) {
        expect(s.minGrade, inInclusiveRange(1, 7),
            reason: '${s.name} 的 minGrade 越界：${s.minGrade}');
        expect(s.difficulty, inInclusiveRange(1, 5),
            reason: '${s.name} 的 difficulty 越界：${s.difficulty}');
      }
    });

    test('每个年级都有可学的咒语', () {
      for (var g = 1; g <= 7; g++) {
        expect(spellsLearnableAt(g), isNotEmpty,
            reason: '$g 年级一个能学的咒语都没有');
      }
    });

    test('一年级能学的咒语里没有不可饶恕咒与守护神咒', () {
      // 一致性检查器（mixin_narrative_continuity 的 R5_spell_power_creep）
      // 把 learnedSpells 当白名单：学会了才允许叙事里出现。要是守护神咒一
      // 年级就能学，那条检查直接失效。
      const forbidden = ['守护神咒', '夺魂咒', '钻心咒', '杀戮咒'];
      final leaked = spellsLearnableAt(1)
          .where((s) => forbidden.contains(s.name))
          .map((s) => s.name)
          .toList();
      expect(leaked, isEmpty, reason: '一年级不该能学到：$leaked');
    });

    test('spellByName 认中文名、简称与拉丁咒文', () {
      expect(spellByName('漂浮咒')?.name, '漂浮咒');
      expect(spellByName('漂浮')?.name, '漂浮咒');
      expect(spellByName('Expelliarmus')?.name, '缴械咒');
      expect(spellByName('expelliarmus')?.name, '缴械咒');
      expect(spellByName('Lumos')?.name, '照明咒');
      expect(spellByName('不存在的咒语'), isNull);
      expect(spellByName(''), isNull);
    });

    test('等级上限跟着熟练度走且封在 100', () {
      const s = SpellDef(
        name: '测试咒',
        incantation: 'Testus',
        category: SpellCategory.general,
        minGrade: 1,
        difficulty: 1,
        attribute: 'spell_understanding',
        effect: '',
      );
      expect(s.levelCapFor(0), 10);
      expect(s.levelCapFor(50), 60);
      expect(s.levelCapFor(95), 100);
      expect(s.levelCapFor(200), 100);
      // 单调不减
      var last = -1;
      for (var a = 0; a <= 100; a++) {
        final cap = s.levelCapFor(a);
        expect(cap, greaterThanOrEqualTo(last));
        last = cap;
      }
    });

    test('学习门槛随难度递增，且不超过属性上限', () {
      for (final s in spellCatalog) {
        expect(s.requiredAttribute, inInclusiveRange(30, 100),
            reason: '${s.name} 的学习门槛 ${s.requiredAttribute} 不合理');
      }
      final byDifficulty = <int, Set<int>>{};
      for (final s in spellCatalog) {
        byDifficulty.putIfAbsent(s.difficulty, () => <int>{}).add(s.requiredAttribute);
      }
      for (var d = 2; d <= 5; d++) {
        final lower = byDifficulty[d - 1];
        final cur = byDifficulty[d];
        if (lower == null || cur == null) continue;
        expect(cur.reduce((a, b) => a < b ? a : b),
            greaterThan(lower.reduce((a, b) => a > b ? a : b)),
            reason: '难度 $d 的学习门槛没有比难度 ${d - 1} 更高');
      }
    });
  });

  group('咒语系统真的接上了', () {
    test('learnedSpells 的写入点不止一处', () {
      // 曾经全项目只有一处写入（用《标准咒语书》时塞一条漂浮咒 Lv.1），
      // 玩家再没有第二个能学的咒、也没有任何办法把等级从 1 提上去。
      // 成就「书虫」（学会 10 个魔咒）因此永远差 9 个。
      var writes = 0;
      for (final f in _allLibFiles()) {
        final src = _codeOnly(f);
        writes += RegExp(r'learnedSpells\[[^\]]*\]\s*=').allMatches(src).length;
        writes += RegExp(r'learnedSpells\.(putIfAbsent|addAll|addEntries|update|remove)')
            .allMatches(src)
            .length;
      }
      expect(writes, greaterThanOrEqualTo(3),
          reason: 'learnedSpells 只有 $writes 处写入，咒语系统又退回空壳了');
    });

    test('/咒语 命令的三个子命令都真实存在', () {
      final src = _codeOnly('lib/mixins/mixin_commands.dart');
      expect(src.contains("primary: '咒语'"), isTrue);
      for (final call in ['m.learnSpell(', 'm.practiseSpell(', 'm.formatSpells()']) {
        expect(src.contains(call), isTrue, reason: '/咒语 没有接到 $call');
      }
    });

    test('练咒与学咒都计入了每日上限表', () {
      final src = _codeOnly('lib/mixins/mixin_systems.dart');
      expect(RegExp(r"'spell':\s*\d+").hasMatch(src), isTrue,
          reason: 'kDailyActivityLimits 里没有练咒的次数上限');
      expect(RegExp(r"'learn_spell':\s*\d+").hasMatch(src), isTrue,
          reason: 'kDailyActivityLimits 里没有学新咒的次数上限');
    });

    test('学与练各自推进合理的时间', () {
      // 「练习魔咒」曾经落到默认 15 分钟：一天 3 次只花 45 分钟，
      // 学业节奏整个垮掉（练咒还顺带推进熟练度）。
      expect(resolveActionCost('学习魔咒'), 120);
      expect(resolveActionCost('练习魔咒'), 60);
      // 一个不命中任何规则的动作，走默认时长
      expect(resolveActionCost('阿不福思的镜子'), kDefaultActionMinutes);
    });

    test('咒语一览里报的每日次数与上限表一致', () {
      final limits = _codeOnly('lib/mixins/mixin_systems.dart');
      final m = RegExp(r"'spell':\s*(\d+)").firstMatch(limits);
      expect(m, isNotNull);
      final play = _codeOnly('lib/mixins/mixin_play.dart');
      expect(play.contains("dailyLimitOf('spell')"), isTrue,
          reason: '一览里写的次数不是从上限表取的');
    });
  });

  group('成就的门槛与描述对得上', () {
    // (成就 id, 描述里承诺的数字, 判定代码里实际比较的字面量)
    //
    // 三列放一起是有意的：以前「描述写一套、判定写另一套」出过好几次——
    // 「时间行者」写「超过1年」判定却是 >= 2；「战争英雄」写「参与关键战
    // 役」，而这个游戏根本没有战役事件；「优等生」写「技能熟练度」却去查
    // 一个上限恒为 1 的咒语等级。任何一侧改动都会让这条测试失败。
    const rows = <(String, String, String)>[
      ('explorer', '5', '>= 5'),
      ('rich_wizard', '1500', '>= 1500'),
      ('bookworm', '10', '>= 10'),
      ('social_butterfly', '10', '>= 10'),
      ('deep_relationship', '80', '>= 80'),
      ('honor_student', '90', '>= 90'),
      ('monthly_evolution', '3', '>= 3'),
      ('generation_artist', '5', '>= 5'),
      ('cg_collector', '10', '>= 10'),
      ('relationship_master', '3', '>= 3'),
      ('time_master', '2', '>= 2'),
      ('war_hero', '80', '>= 80'),
      ('world_changer', '10', '>= 0.1'),
      // 「红娘」不在这张表里：描述写的是羁绊值 60，判定比的是配对阶段
      // stage >= 1，中间隔着 _shipStageFor。那条桥另有单测盯着。
    ];

    for (final row in rows) {
      test('${row.$1}：描述写 ${row.$2}，判定是 ${row.$3}', () {
        final ach = achievementCatalog.firstWhere(
          (a) => a.id == row.$1,
          orElse: () => throw StateError('成就表里没有 ${row.$1}'),
        );
        final stated = RegExp(r'\d+').firstMatch(ach.description)?.group(0);
        expect(stated, row.$2,
            reason: '「${ach.name}」的描述改了数字（现在是 $stated），'
                '同步更新本表；或者判定改了，改第三列。');

        final body = _checkBodyFor(row.$1);
        expect(body, isNotNull, reason: '找不到 unlockAchievement(${row.$1}) 所在的函数');
        expect(body!.contains(row.$3), isTrue,
            reason: '「${ach.name}」的判定里找不到「${row.$3}」：\n$body');
      });
    }
  });

  group('成就不再指向不存在的玩法', () {
    test('没有任何成就描述提到游戏里不存在的系统', () {
      // 曾经「战争英雄」写的是「参与关键战役」，而全项目连一个战役事件都
      // 没有——玩家照着描述去打，打完发现条件对不上。
      const deadPromises = ['战役', '关键战役'];
      final offenders = <String>[];
      for (final a in achievementCatalog) {
        for (final w in deadPromises) {
          if (a.description.contains(w)) {
            offenders.add('${a.id}（${a.name}）：${a.description}');
          }
        }
      }
      expect(offenders, isEmpty, reason: '这些成就承诺了不存在的玩法：$offenders');
    });

    test('「书虫」要求的咒语数量在咒语表里够得着', () {
      final ach = achievementCatalog.firstWhere((a) => a.id == 'bookworm');
      final need = int.parse(RegExp(r'\d+').firstMatch(ach.description)!.group(0)!);
      expect(spellCatalog.length, greaterThanOrEqualTo(need),
          reason: '咒语只有 ${spellCatalog.length} 个，学不到 $need 个');
      expect(spellsLearnableAt(2).length, greaterThanOrEqualTo(need),
          reason: '二年级可学的咒语不足 $need 个，「书虫」要等到高年级才拿得到');
    });

    test('「优等生」查的是学业属性而不是咒语等级', () {
      final body = _checkBodyFor('honor_student');
      expect(body, isNotNull);
      expect(body!.contains('kStudyAttributeKeys'), isTrue,
          reason: '判的不是学业熟练度：\n$body');
      expect(body.contains('learnedSpells'), isFalse,
          reason: '又回去查咒语等级了：\n$body');
    });

    test('「第一位朋友」的门槛问的是好感阶段表', () {
      final body = _checkBodyFor('first_friend');
      expect(body, isNotNull);
      expect(body!.contains('affectionStageMin('), isTrue,
          reason: '门槛写死在代码里，阶段表一改就对不上描述：\n$body');
    });

    test('「红娘」描述里的羁绊值确实对应判定用的阶段', () {
      final ach = achievementCatalog.firstWhere((a) => a.id == 'matchmaker');
      final bond = int.parse(RegExp(r'\d+').firstMatch(ach.description)!.group(0)!);
      final body = _checkBodyFor('matchmaker');
      expect(body, isNotNull);
      final stage = RegExp(r'stage\s*>=\s*(\d+)').firstMatch(body!);
      expect(stage, isNotNull, reason: '判定里找不到 stage >= N：\n$body');
      // 羁绊 → 阶段的映射在 mixin_relations._shipStageFor，这里直接从源码
      // 读出「阶段 N 的门槛」，确认描述写的羁绊值落在这一档上。
      final src = _codeOnly('lib/mixins/mixin_relations.dart');
      final need = int.parse(stage!.group(1)!);
      final thresholds =
          RegExp(r'if \(bond >= (\d+)\) return (\d+);').allMatches(src).map((m) {
        return (int.parse(m.group(1)!), int.parse(m.group(2)!));
      }).where((e) => e.$2 == need);
      expect(thresholds, isNotEmpty,
          reason: '_shipStageFor 里没有 stage $need 这一档');
      expect(thresholds.map((e) => e.$1).reduce((a, b) => a < b ? a : b), bond,
          reason: '描述写羁绊 $bond，但 stage $need 的门槛不是 $bond');
    });
  });

  group('收藏品不再是空的许诺', () {
    test('收藏品 id 不重复', () {
      final ids = kCollectibleCatalog.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('每一件收藏品都至少有一个真实的获取途径', () {
      // /收藏 曾经永远显示「暂无收藏品。在冒险中收集独特物品，如巧克力蛙
      // 画片、日记本等」——而全项目对 collection 的写入一处都没有。这句提
      // 示承诺了两件根本拿不到的东西。现在反过来钉住：目录里不许出现拿不
      // 到的条目。
      final libSrc = <String, String>{};
      for (final f in _allLibFiles()) {
        libSrc[f] = _codeOnly(f);
      }
      bool reachable(String id) => libSrc.values.any((src) => src.contains("'$id'"));

      final orphans = <String>[];
      for (final c in kCollectibleCatalog) {
        // 画片系列走「使用某物品随机掉落」，靠系列名而不是逐个 id 命中
        final bySeries = collectibleSeriesForUse.values.contains(c.series);
        final byPurchase = collectibleForPurchase.containsValue(c.id);
        if (!reachable(c.id) && !bySeries && !byPurchase) {
          orphans.add('${c.id}（${c.name}）');
        }
      }
      expect(orphans, isEmpty,
          reason: '这些收藏品没有任何获取途径，/收藏 里会永远锁着：$orphans');
    });

    test('会掉收藏品的物品在物品表里买得到', () {
      for (final name in collectibleSeriesForUse.keys) {
        expect(itemDefByName(name), isNotNull,
            reason: '物品表里没有「$name」，掉了也没人吃得到');
      }
      for (final name in collectibleForPurchase.keys) {
        expect(itemDefByName(name), isNotNull,
            reason: '物品表里没有「$name」，商店里买不到');
      }
    });

    test('画片系列确实非空，否则巧克力蛙什么也不掉', () {
      for (final entry in collectibleSeriesForUse.entries) {
        expect(collectiblesInSeries(entry.value), isNotEmpty,
            reason: '系列「${entry.value}」是空的');
      }
    });

    test('/收藏 的空态文案不再许诺拿不到的东西', () {
      final src = _codeOnly('lib/mixins/mixin_relations.dart');
      final body = src.substring(src.indexOf('String formatCollection()'));
      final empty = body.substring(0, body.indexOf('return buf.toString();'));
      expect(empty.contains('日记本'), isFalse,
          reason: '「日记本」在任何地方都不存在，不该再出现在提示里');
      expect(empty.contains('巧克力蛙'), isTrue,
          reason: '巧克力蛙是唯一稳定的收藏品来源，得告诉玩家');
    });

    test('收藏品的来源分散在开局/分院/购买/掉落，不是只有一处', () {
      // 写入本身收在 addCollectible 一个漏斗里（好事），所以这里数的是调用
      // 点：来源只有一处的话，玩家错过这一次就再也拿不到了。
      var sites = 0;
      var seriesDrops = 0;
      for (final f in _allLibFiles()) {
        final src = _codeOnly(f);
        // 购买那条传的是变量而不是字面量，所以数调用次数而不是字符串字面量，
        // 再减掉方法自身的声明。
        sites += RegExp(r'addCollectible\(').allMatches(src).length -
            RegExp(r'bool addCollectible\(').allMatches(src).length;
        seriesDrops += RegExp(r'_addCollectibleFromSeries\(').allMatches(src).length;
      }
      expect(sites, greaterThanOrEqualTo(5),
          reason: 'addCollectible 只有 $sites 个调用点，收集玩法的来源太单一');
      expect(seriesDrops, greaterThanOrEqualTo(1),
          reason: '没有任何地方走「使用物品掉落收藏品」这条线');
    });
  });
}


// ==================== 扫描工具 ====================

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

/// 去掉整行 `//` 注释。注释里经常引用旧代码，不剥掉会误报。
String _codeOnly(String path) {
  final lines = File(path).readAsStringSync().split('\n');
  final out = <String>[];
  for (final line in lines) {
    if (line.trimLeft().startsWith('//')) continue;
    out.add(line);
  }
  return out.join('\n');
}

/// 取出 `unlockAchievement('<id>')` 所在方法的函数体。
///
/// 用缩进判断函数边界：类方法都是 2 空格起，遇到缩进 ≤ 2 的 `}` 就是结束。
/// 只看顶层 `}`（曾经这么写过）会把下一个方法也算进来。
String? _checkBodyFor(String achievementId) {
  for (final path in _allLibFiles()) {
    // 必须剥掉注释：我们习惯在注释里写「旧实现查的是 learnedSpells…」，
    // 不剥的话「优等生不再查咒语等级」这类断言会被自己的注释打脸。
    final lines = _codeOnly(path).split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].contains("unlockAchievement('$achievementId')")) continue;
      if (path.endsWith('game_systems.dart')) continue; // 成就表自身
      var start = i;
      while (start > 0) {
        final raw = lines[start];
        final t = raw.trimLeft();
        final indent = raw.length - t.length;
        if (indent <= 2 &&
            (t.startsWith('void ') ||
                t.startsWith('String ') ||
                t.startsWith('bool ') ||
                t.startsWith('int ') ||
                t.startsWith('double '))) {
          break;
        }
        start--;
      }
      final end = <String>[];
      for (var j = start; j < lines.length; j++) {
        final raw = lines[j];
        final t = raw.trimLeft();
        if (j > start && t.startsWith('}') && (raw.length - t.length) <= 2) break;
        end.add(lines[j]);
      }
      return end.join('\n');
    }
  }
  return null;
}
