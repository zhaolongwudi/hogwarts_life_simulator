import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/legacy_data.dart';

void main() {
  // ============================================================
  // 血统混合
  // ============================================================
  group('血统混合', () {
    test('双纯血：血脉稳定，85% 仍是纯血', () {
      expect(mixBloodType('pureblood', 'pureblood', 0), 'pureblood');
      expect(mixBloodType('pureblood', 'pureblood', 84), 'pureblood');
      expect(mixBloodType('pureblood', 'pureblood', 85), 'halfblood');
      expect(mixBloodType('pureblood', 'pureblood', 99), 'halfblood');
    });

    test('一纯一混：多数混血，少数随低的那一方', () {
      expect(mixBloodType('pureblood', 'halfblood', 0), 'halfblood');
      expect(mixBloodType('halfblood', 'pureblood', 79), 'halfblood');
      expect(mixBloodType('pureblood', 'halfblood', 80), 'halfblood');
      expect(mixBloodType('halfblood', 'pureblood', 99), 'halfblood');
    });

    test('一纯一麻瓜出身：少数会掉到麻瓜出身', () {
      expect(mixBloodType('pureblood', 'muggleborn', 0), 'halfblood');
      expect(mixBloodType('muggleborn', 'pureblood', 79), 'halfblood');
      expect(mixBloodType('pureblood', 'muggleborn', 80), 'muggleborn');
      expect(mixBloodType('muggleborn', 'pureblood', 99), 'muggleborn');
    });

    test('双混血：多数仍是混血，少数降一代、极少数隔代返祖', () {
      expect(mixBloodType('halfblood', 'halfblood', 0), 'halfblood');
      expect(mixBloodType('halfblood', 'halfblood', 69), 'halfblood');
      expect(mixBloodType('halfblood', 'halfblood', 70), 'muggleborn');
      expect(mixBloodType('halfblood', 'halfblood', 89), 'muggleborn');
      // 祖上某个纯血的祖先隔代冒出来——马尔福家最怕也最想要的那件事
      expect(mixBloodType('halfblood', 'halfblood', 90), 'pureblood');
    });

    test('一混一麻瓜出身', () {
      expect(mixBloodType('halfblood', 'muggleborn', 0), 'halfblood');
      expect(mixBloodType('muggleborn', 'halfblood', 74), 'halfblood');
      expect(mixBloodType('halfblood', 'muggleborn', 75), 'muggleborn');
    });

    test('双麻瓜出身：绝大多数仍是麻瓜出身', () {
      expect(mixBloodType('muggleborn', 'muggleborn', 0), 'muggleborn');
      expect(mixBloodType('muggleborn', 'muggleborn', 91), 'muggleborn');
      expect(mixBloodType('muggleborn', 'muggleborn', 92), 'halfblood');
    });

    test('只要父母有一方是麻瓜出身，就绝不可能生出纯血', () {
      // 回归：kBloodTypes 是按"血统高低"排的（纯血在前），
      // 曾被拿去当 rank 下标用，于是纯血 + 麻瓜出身的父母
      // 有 20% 概率跑出一个纯血孩子——正好反了。
      for (final other in kBloodTypes) {
        for (var roll = 0; roll < 100; roll++) {
          expect(mixBloodType('muggleborn', other, roll), isNot('pureblood'),
              reason: 'muggleborn + $other @ $roll 生出了纯血');
          expect(mixBloodType(other, 'muggleborn', roll), isNot('pureblood'),
              reason: '$other + muggleborn @ $roll 生出了纯血');
        }
      }
    });

    test('双麻瓜出身也有一丝可能出混血，但绝不可能凭空出纯血', () {
      // 这条是整个血统系统的底线：纯血是要靠血脉攒出来的，
      // 两个麻瓜出身的父母不可能直接生出一个纯血——那会毁掉血统的意义
      for (var roll = 0; roll < 100; roll++) {
        expect(mixBloodType('muggleborn', 'muggleborn', roll),
            isNot('pureblood'),
            reason: 'roll=$roll 生出了纯血');
      }
    });

    test('任何组合的结果都是三种合法血统之一', () {
      for (final a in kBloodTypes) {
        for (final b in kBloodTypes) {
          for (final roll in const [0, 1, 49, 50, 69, 70, 84, 85, 99]) {
            expect(kBloodTypes, contains(mixBloodType(a, b, roll)),
                reason: '$a + $b @ $roll');
          }
        }
      }
    });

    test('父母顺序不影响结果（对称）', () {
      for (final a in kBloodTypes) {
        for (final b in kBloodTypes) {
          for (var roll = 0; roll < 100; roll += 7) {
            expect(mixBloodType(a, b, roll), mixBloodType(b, a, roll),
                reason: '$a/$b @ $roll 不对称');
          }
        }
      }
    });

    test('特殊血统与未知血统按混血处理，不崩也不给意外加成', () {
      expect(mixBloodType('special', 'pureblood', 0), 'halfblood');
      expect(mixBloodType('unknown_thing', 'pureblood', 0), 'halfblood');
      expect(mixBloodType('unknown_thing', 'muggleborn', 0), 'halfblood');
    });

    test('纯血家庭的优势是"大概率"，不是"必然"', () {
      // 这条钉住设计意图：纯血不是保险箱。
      // 若哪天有人把它改成 100%，整个血统系统就退化成一张静态标签。
      int pure = 0;
      for (var roll = 0; roll < 100; roll++) {
        if (mixBloodType('pureblood', 'pureblood', roll) == 'pureblood') {
          pure++;
        }
      }
      expect(pure, 85);
      expect(pure, lessThan(100));
    });
  });

  // ============================================================
  // 声望继承
  // ============================================================
  group('声望继承', () {
    test('正向声望只传四分之一，向下取整', () {
      final r = inheritedReputation(
        academic: 100,
        social: 83,
        combat: 60,
        moral: 40,
        leadership: 20,
        dark: 0,
      );
      expect(r['academic'], 25);
      expect(r['social'], 20); // 83 * 0.25 = 20.75 → 20
      expect(r['combat'], 15);
      expect(r['moral'], 10);
      expect(r['leadership'], 5);
    });

    test('恶名传两成——比好名声传得慢，但不为零', () {
      final dark = inheritedReputation(
        academic: 0,
        social: 0,
        combat: 0,
        moral: 0,
        leadership: 0,
        dark: 90,
      );
      final good = inheritedReputation(
        academic: 90,
        social: 0,
        combat: 0,
        moral: 0,
        leadership: 0,
        dark: 0,
      );
      expect(dark['dark'], 18); // 90 * 0.20
      expect(good['academic'], 22); // 90 * 0.25
      // 恶名照样跟着姓传下来——这是传承该有的分量，
      // 但传得比好名声慢一点，不至于让孩子一进校就被当成黑巫师
      expect(dark['dark'], greaterThan(0));
      expect(dark['dark'], lessThan(good['academic']!));
    });

    test('声望是负数时也照样传（恶名昭彰的家族）', () {
      final r = inheritedReputation(
        academic: -40,
        social: -20,
        combat: 0,
        moral: 0,
        leadership: 0,
        dark: 0,
      );
      expect(r['academic'], -10);
      expect(r['social'], -5);
    });

    test('六个维度一个都不少', () {
      final r = inheritedReputation(
        academic: 1,
        social: 2,
        combat: 3,
        moral: 4,
        leadership: 5,
        dark: 6,
      );
      expect(r.keys.toSet(), {
        'academic',
        'social',
        'combat',
        'moral',
        'leadership',
        'dark',
      });
    });

    test('全 0 的一代传下去还是 0——传承不是保底', () {
      final r = inheritedReputation(
        academic: 0,
        social: 0,
        combat: 0,
        moral: 0,
        leadership: 0,
        dark: 0,
      );
      expect(r.values.every((v) => v == 0), isTrue);
    });
  });

  // ============================================================
  // 人脉继承
  // ============================================================
  group('人脉继承', () {
    test('好感不够门槛的不算世交', () {
      final out = inheritedAllies({
        '甲': 49,
        '乙': 50,
        '丙': 100,
      });
      expect(out.containsKey('甲'), isFalse);
      expect(out.containsKey('乙'), isTrue);
      expect(out.containsKey('丙'), isTrue);
    });

    test('继承后按四折算并封顶，开局只能是"认识"不是"死党"', () {
      final out = inheritedAllies({
        '挚友': 100,
        '熟人': 60,
      });
      expect(out['挚友'], kAllyAffectionCap); // 100 * 0.4 = 40 → 封到 35
      expect(out['熟人'], 24);
    });

    test('封顶值低于世交门槛——继承来的人脉永远达不到能再传下去的线', () {
      // 这条是防"人脉滚雪球"：第一代传给第二代 35，
      // 第二代不够 50 的门槛就传不下去了，人脉必须在每一代重新挣过。
      expect(kAllyAffectionCap, lessThan(kAllyAffectionMin));
    });

    test('空表不炸', () {
      expect(inheritedAllies(const {}), isEmpty);
    });

    test('宿敌不会被当成世交（负好感直接被门槛挡掉）', () {
      final out = inheritedAllies({'仇人': -80, '路人': 0});
      expect(out, isEmpty);
    });
  });

  // ============================================================
  // 遗产
  // ============================================================
  group('遗产', () {
    test('按四分之一给，封顶 2000——够体面，不够躺平', () {
      expect(inheritedWealth(4000), 1000);
      expect(inheritedWealth(0), 0);
      expect(inheritedWealth(8000), 2000); // 该给 2000，正好到顶
      expect(inheritedWealth(100000), 2000); // 巨富也只给 2000
    });

    test('小额遗产不会被封顶误伤', () {
      expect(inheritedWealth(100), 25);
      expect(inheritedWealth(4), 1);
    });
  });

  // ============================================================
  // 上一代的总结
  // ============================================================
  group('上一代的总结', () {
    String plain({
      int academic = 0,
      int combat = 0,
      int moral = 0,
      int dark = 0,
      int leadership = 0,
      bool wasFaculty = false,
      int worldLinePercent = 0,
    }) =>
        summarizeParent(
          parentName: '张三',
          academic: academic,
          combat: combat,
          moral: moral,
          dark: dark,
          leadership: leadership,
          wasFaculty: wasFaculty,
          worldLinePercent: worldLinePercent,
        );

    test('平平淡淡的一生也有话说，而不是一片空白', () {
      final s = plain();
      expect(s, contains('张三'));
      expect(s, contains('平平静静'));
      expect(s, isNot(contains('当年在课堂上')));
    });

    test('学业出挑的人会被记住', () {
      expect(plain(academic: 70), contains('当年在课堂上出过风头'));
    });

    test('打过架、当过头儿的都会被写进去', () {
      final s = plain(combat: 70, leadership: 70);
      expect(s, contains('打过几场让人记住的架'));
      expect(s, contains('当过一阵子的头儿'));
    });

    test('走过弯路这件事不会被洗白，但说法是克制的', () {
      final s = plain(dark: 50);
      expect(s, contains('走过一段没人愿意细说的弯路'));
      // 用"没人愿意细说"而不是直接写"他是个黑巫师"——
      // 这句话是要当着孩子的面念出来的，得留着余地
      expect(s, isNot(contains('黑巫师')));
    });

    test('在别人躲开时站出来过的，值得单独记一笔', () {
      expect(plain(moral: 70), contains('在别人都躲开的时候站出来过'));
    });

    test('留过校的会写进总结——这是上一代唯一能留下的职位', () {
      expect(plain(wasFaculty: true), contains('后来回了霍格沃茨教书'));
    });

    test('改过世界线的，说法是"据说"——没人会当着孩子的面承认', () {
      expect(plain(worldLinePercent: 40), contains('据说还改过一些不该改的事'));
      expect(plain(worldLinePercent: 39), isNot(contains('据说')));
    });

    test('多项标签会连成一句话，且以句号收尾', () {
      final s = plain(
        academic: 80,
        combat: 75,
        moral: 90,
        leadership: 70,
        dark: 50,
        wasFaculty: true,
        worldLinePercent: 55,
      );
      expect(s, startsWith('张三 '));
      expect(s.trim(), endsWith('。'));
      // 6 个标签都在
      for (final t in const [
        '出过风头',
        '让人记住的架',
        '当过一阵子的头儿',
        '没人愿意细说',
        '站出来过',
        '回了霍格沃茨',
        '据说',
      ]) {
        expect(s, contains(t), reason: '缺了「$t」');
      }
    });

    test('这句话会跟着孩子整整七年，所以不能写成干巴巴的"父亲是名人"', () {
      final s = plain(academic: 100);
      expect(s, isNot(contains('名人')));
      expect(s.length, greaterThan(10));
    });
  });

  // ============================================================
  // 家族背景
  // ============================================================
  group('家族背景', () {
    String bg({
      List<String> rivals = const [],
      int inheritance = 500,
    }) =>
        buildFamilyBackground(
          surname: '马尔福',
          parentName: '张三',
          parentSummary: '张三 当年在课堂上出过风头。',
          rivals: rivals,
          inheritance: inheritance,
        );

    test('没有仇怨时是完整的交代，不会断在半句上', () {
      final s = bg();
      expect(s, contains('「马尔福」家的人'));
      expect(s, contains('500 加隆'));
      expect(s, contains('没留下什么仇怨'));
      expect(s.trim(), endsWith('。'));
    });

    test('有仇人时，仇人那一栏放在最后——它是整段里最该被看见的', () {
      final s = bg(rivals: ['哈利', '赫敏']);
      final iWealth = s.indexOf('加隆');
      final iRival = s.indexOf('仇人');
      expect(iRival, greaterThan(iWealth));
      expect(s, contains('哈利、赫敏'));
    });

    test('仇人多的时候只点三个名字，但要说清总数', () {
      final s = bg(rivals: ['甲', '乙', '丙', '丁', '戊']);
      expect(s, contains('甲、乙、丙'));
      expect(s, contains('等 5 人'));
      // 第四、第五个名字不该出现——一段背景里塞五个名字没人读得下去
      expect(s, isNot(contains('丁')));
    });

    test('恰好三个仇人时不会出现"等 3 人"这种废话', () {
      final s = bg(rivals: ['甲', '乙', '丙']);
      expect(s, contains('甲、乙、丙'));
      expect(s, isNot(contains('等')));
    });

    test('仇是记在姓上的——这句话必须写明白', () {
      final s = bg(rivals: ['哈利']);
      expect(s, contains('记在你这个姓上的'));
      expect(s, contains('不会因为你是孩子就算了'));
    });

    test('功劳是上一代的，不是孩子的', () {
      expect(bg(), contains('那是别人的功劳，不是你的'));
    });
  });

  // ============================================================
  // 传承清单
  // ============================================================
  group('传承清单', () {
    LegacyCarryover carry({
      List<String> rivals = const [],
      Map<String, int> allies = const {},
    }) =>
        LegacyCarryover(
          heirName: '小明',
          heirGender: '男',
          surname: '张',
          bloodType: 'halfblood',
          familyBackground: '背景',
          reputation: inheritedReputation(
            academic: 80,
            social: 80,
            combat: 80,
            moral: 80,
            leadership: 80,
            dark: 80,
          ),
          allies: allies,
          rivals: rivals,
          inheritance: 500,
          parentName: '张三',
          startYear: 2010,
          parentSummary: '张三 当年在课堂上出过风头。',
        );

    test('有没有仇人、有没有世交，是这份清单最要紧的两个开关', () {
      expect(carry().hasRivals, isFalse);
      expect(carry().hasAllies, isFalse);
      expect(carry(rivals: ['哈利']).hasRivals, isTrue);
      expect(carry(allies: {'赫敏': 30}).hasAllies, isTrue);
    });

    test('传承不是开挂：继承来的声望必须显著低于上一代', () {
      final c = carry();
      // 上一代 80，下一代只拿到 20（四分之一）
      expect(c.reputation['academic'], 20);
      expect(c.reputation.values.every((v) => v < 80), isTrue);
    });

    test('遗产在封顶之下，不会让下一代一生下来就财务自由', () {
      expect(carry().inheritance, lessThanOrEqualTo(kInheritanceCap));
    });
  });

  // ============================================================
  // 设计不变量：有些东西是刻意不传的
  // ============================================================
  group('刻意不传的东西', () {
    final src =
        File('lib/mixins/mixin_systems.dart').readAsStringSync();
    final iStart = src.indexOf('// ==================== 家族传承');
    final iEnd = src.indexOf('@override\n  String formatFaculty()');
    final block = src.substring(iStart, iEnd > iStart ? iEnd : src.length);

    test('不传学业属性——那是下一代自己要学的东西', () {
      expect(block, isNot(contains('attributes[')));
      expect(block, isNot(contains('attributeValues')));
    });

    test('不传世界线变动率——新的一代是新的人，世界从原典重新开始', () {
      // worldLinePercent 只是拿来写总结文案，不是拿来赋值的
      expect(block, isNot(contains('worldLineDeviation =')));
    });

    test('不传教职——你爸是教授不代表你也是', () {
      expect(block, isNot(contains('facultyRankId =')));
      expect(block, isNot(contains('facultyServiceYears =')));
    });
  });

  // ============================================================
  // 接线
  // ============================================================
  group('传承真的接进了游戏', () {
    test('/传承 命令已注册', () {
      final src =
          File('lib/mixins/mixin_commands.dart').readAsStringSync();
      expect(src.contains("primary: '传承'"), isTrue);
    });

    test('startLegacy 真的会开一局新的（走 initializeGame）', () {
      final src =
          File('lib/mixins/mixin_systems.dart').readAsStringSync();
      final i = src.indexOf('Future<bool> startLegacy(');
      expect(i, greaterThan(-1));
      final body = src.substring(i, i + 900);
      expect(body.contains('initializeGame('), isTrue);
      expect(body.contains('legacy: legacy'), isTrue);
    });

    test('继承来的声望与遗产在开局前就落进角色', () {
      final src = File('lib/mixins/mixin_init.dart').readAsStringSync();
      final i = src.indexOf('if (legacy != null) {');
      expect(i, greaterThan(-1));
      final body = src.substring(i, i + 500);
      expect(body.contains('rep.add(e.key, e.value)'), isTrue);
      expect(body.contains('galleons += legacy.inheritance'), isTrue);
    });

    test('世交世仇在 NPC 建好之后才落——否则名字对不上就白给', () {
      final src = File('lib/mixins/mixin_init.dart').readAsStringSync();
      final iNpc = src.indexOf('_initializeNPCsByEra();');
      final iLegacy = src.indexOf('applyLegacyRelations(legacy);');
      expect(iNpc, greaterThan(-1));
      expect(iLegacy, greaterThan(-1));
      expect(iLegacy, greaterThan(iNpc));
    });
  });
}
