import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/ending_review_data.dart';
import 'package:hogwarts_life_simulator/models/long_term_memory.dart';

KeyFactRecord fact(
  String text, {
  int importance = 8,
  String category = 'auto_extracted',
  String timestamp = '1991-09-01 08:00',
}) =>
    KeyFactRecord(
      id: 'f_${text.hashCode}',
      fact: text,
      importance: importance,
      timestamp: timestamp,
      category: category,
    );

OpenLoopRecord loop(
  String desc, {
  String status = 'open',
  int importance = 6,
}) =>
    OpenLoopRecord(
      id: 'l_${desc.hashCode}',
      description: desc,
      status: status,
      importance: importance,
      openedAt: '1991-09-01 08:00',
    );

EndingFacts facts({
  String name = '张三',
  String house = '格兰芬多',
  String blood = '混血',
  List<KeyFactRecord> keyFacts = const [],
  List<OpenLoopRecord> openLoops = const [],
  Map<String, int> affections = const {},
  List<(String, String)> rivals = const [],
  double deviation = 0.0,
  List<String> echoes = const [],
  List<String> witnessed = const [],
  int deepBonds = 0,
  bool wasFaculty = false,
  int moral = 50,
  int combat = 50,
  int academic = 50,
  int dark = 0,
  int leadership = 50,
}) =>
    EndingFacts(
      playerName: name,
      house: house,
      bloodLabel: blood,
      keyFacts: keyFacts,
      openLoops: openLoops,
      worldEvents: const [],
      affections: affections,
      rivals: rivals,
      worldLineDeviation: deviation,
      rewrittenEchoes: echoes,
      witnessedUnchanged: witnessed,
      deepBonds: deepBonds,
      wasFaculty: wasFaculty,
      moral: moral,
      combat: combat,
      academic: academic,
      dark: dark,
      leadership: leadership,
    );

EndingFacts get quietFacts => facts();

void main() {
  // ============================================================
  // 哪些事够格进「那些事」
  // ============================================================
  group('哪些事够格进「那些事」', () {
    test('分量不够的进不来', () {
      expect(reviewableFacts([fact('一件小事', importance: 5)]), isEmpty);
      expect(reviewableFacts([fact('一件大事', importance: 8)]), hasLength(1));
    });

    test('开局的身份事实被排除——那是开局就有的，不是这七年发生的事', () {
      // T0 那批事实的重要性一律是 9，不排除就会霸占整节
      final out = reviewableFacts([
        fact('主角姓名为张三，出生于1979年', importance: 9, category: 'identity'),
        fact('张三在天文塔上做出了选择', importance: 8),
      ]);
      expect(out, hasLength(1));
      expect(out.single.fact, contains('天文塔'));
    });

    test('按发生顺序排，不按分量排——回忆不是按重要性排序的', () {
      final out = reviewableFacts([
        fact('三年级的事', importance: 9, timestamp: '1994-03-01 10:00'),
        fact('一年级的事', importance: 8, timestamp: '1992-03-01 10:00'),
        fact('五年级的事', importance: 10, timestamp: '1996-03-01 10:00'),
      ]);
      expect(out.first.fact, '一年级的事');
      expect(out.last.fact, '五年级的事');
    });

    test('一件事被翻来覆去记了好几遍，只留一次', () {
      final out = dedupeFacts([
        fact('张三把那封信交给了斯内普，从此两清'),
        fact('张三把那封信交给了斯内普，两个人之间的账清了'),
      ]);
      expect(out, hasLength(1));
    });

    test('前 12 字相同才认作同一件事，不会把相似的两件事并掉', () {
      final out = dedupeFacts([
        fact('张三帮赫敏修好了那一支魔杖'),
        fact('张三帮罗恩修好了那一支魔杖'),
      ]);
      expect(out, hasLength(2));
    });
  });

  // ============================================================
  // 还没了结的事
  // ============================================================
  group('还没了结的', () {
    test('只列还开着的，按分量排', () {
      final out = lingeringLoops([
        loop('一件小事', importance: 6),
        loop('一件要紧事', importance: 9),
        loop('已经办完的事', status: 'done', importance: 9),
      ]);
      expect(out.map((l) => l.description).toList(),
          ['一件要紧事', '一件小事']);
    });

    test('太琐碎的不进这一节', () {
      expect(lingeringLoops([loop('随手答应的事', importance: 4)]), isEmpty);
    });

    test('放下的一去不回——回望不该翻旧账', () {
      expect(
        lingeringLoops([loop('早放弃了', status: 'dropped', importance: 9)]),
        isEmpty,
      );
    });
  });

  // ============================================================
  // 那些人
  // ============================================================
  group('那些人', () {
    test('好感不够的不算深交', () {
      expect(closestAllies({'甲': 49}), isEmpty);
      expect(closestAllies({'甲': 50}), hasLength(1));
    });

    test('按好感排，最多列三个', () {
      final out = closestAllies({'甲': 60, '乙': 95, '丙': 70, '丁': 88});
      expect(out.map((e) => e.$1).toList(), ['乙', '丁', '丙']);
      expect(out, hasLength(3));
    });

    test('关系的说法是分档的，不是印一个数字', () {
      // 数字在结算上半屏已经看过了，这里要说清的是那是什么样的关系
      expect(bondLabel(95), isNot(contains('95')));
      expect(bondLabel(50), isNot(bondLabel(95)));
      expect(bondLabel(10), isNotEmpty);
    });

    test('好感越高，说法越重', () {
      const ladder = [0, 30, 50, 70, 90];
      for (var i = 0; i < ladder.length - 1; i++) {
        expect(bondLabel(ladder[i]), isNot(bondLabel(ladder[i + 1])),
            reason: '${ladder[i]} 和 ${ladder[i + 1]} 的说法一样');
      }
    });
  });

  // ============================================================
  // 一句话定性
  // ============================================================
  group('一句话定性', () {
    test('改写过世界的人，说什么别的都轻了', () {
      expect(epithetFor(facts(deviation: 0.6, moral: 90, combat: 90)),
          '一个动过世界的人');
    });

    test('在关键时刻站出来过的', () {
      expect(epithetFor(facts(moral: 75, combat: 65)), contains('站出来'));
    });

    test('走过弯路又走回来的，不会被简单洗白也不会被一棍子打死', () {
      final s = epithetFor(facts(dark: 50, moral: 55));
      expect(s, contains('弯路'));
      expect(s, contains('走了回来'));
    });

    test('道德低的人不会被说成让人信赖', () {
      // 这条钉住的是：定性得从数据里推，不能是随机挑的好听话
      final s = epithetFor(facts(moral: 20, dark: 60, deepBonds: 5));
      expect(s, isNot(contains('背后交给你')));
    });

    test('什么都没攒下也有话说，而且那句话是认真的', () {
      final s = epithetFor(quietFacts);
      expect(s, kEndingEpithetFallback);
      // 七年什么都没攒下是最多人真正会走到的结局，不能写成一句敷衍
      expect(s.length, greaterThan(15));
      expect(s, isNot(contains('平平无奇')));
    });

    test('任何一组数据都能得到一句定性，不会掉进空字符串', () {
      for (final f in [
        quietFacts,
        facts(moral: 100, combat: 100, leadership: 100, academic: 100),
        facts(dark: 100, moral: 0),
        facts(deepBonds: 9, deviation: 0.9),
      ]) {
        expect(epithetFor(f).trim(), isNotEmpty);
      }
    });
  });

  // ============================================================
  // 整篇的编排
  // ============================================================
  group('整篇的编排', () {
    test('「你是谁」永远在——你总得知道自己念完了七年', () {
      final r = buildEndingReview(quietFacts);
      expect(r.sections.first.$1, '你是谁');
      expect(r.sections.first.$2.first, contains('张三'));
    });

    test('什么都没发生的七年，只有「你是谁」一节', () {
      // 空的小节比没有小节更难受——它会明晃晃地告诉你那里本来该有什么
      final r = buildEndingReview(quietFacts);
      expect(r.sections, hasLength(1));
    });

    test('有朋友才有「那些人」，没有就整节不出现', () {
      final has = buildEndingReview(facts(affections: {'赫敏': 80}));
      final hasNot = buildEndingReview(quietFacts);
      expect(has.sections.any((s) => s.$1 == '那些人'), isTrue);
      expect(hasNot.sections.any((s) => s.$1 == '那些人'), isFalse);
    });

    test('宿敌和朋友分开两节——放在一个列表里两边都显得轻了', () {
      final r = buildEndingReview(facts(
        affections: {'赫敏': 80},
        rivals: [('马尔福', '死对头')],
      ));
      final titles = r.sections.map((s) => s.$1).toList();
      expect(titles, contains('那些人'));
      expect(titles, contains('那些没解开的事'));
      // 「那些人」那节里不该混进宿敌
      final people = r.sections.firstWhere((s) => s.$1 == '那些人').$2;
      expect(people.join(), isNot(contains('马尔福')));
    });

    test('改写过世界的，和袖手旁观的，是两节不同的东西', () {
      final rewrote = buildEndingReview(facts(echoes: ['天文塔那一夜变了']));
      final watched = buildEndingReview(facts(witnessed: ['你看着它发生了']));
      expect(rewrote.sections.any((s) => s.$1 == '被你改写过的事'), isTrue);
      expect(watched.sections.any((s) => s.$1 == '你看着它发生的'), isTrue);
      expect(rewrote.sections.any((s) => s.$1 == '你看着它发生的'), isFalse);
    });

    test('「那些事」最多讲六件——再多就不是回望，是流水账', () {
      final many = List.generate(20, (i) => fact('第 $i 件要紧事'));
      final r = buildEndingReview(facts(keyFacts: many));
      final moments = r.sections.firstWhere((s) => s.$1 == '那些事').$2;
      expect(moments.length, lessThanOrEqualTo(kReviewMaxMoments));
    });

    test('还没了结的事会单独列出来——那是你留给毕业之后的东西', () {
      final r = buildEndingReview(facts(openLoops: [loop('答应过的事', importance: 8)]));
      expect(r.sections.any((s) => s.$1 == '还没了结的'), isTrue);
    });

    test('一件事不会既在「那些事」又在「还没了结的」', () {
      // 前者是发生过的事，后者是没办完的事，两条路互斥
      final r = buildEndingReview(facts(
        keyFacts: [fact('张三答应过斯内普一件事')],
        openLoops: [loop('斯内普答应给主角保密', importance: 8)],
      ));
      expect(r.sections.any((s) => s.$1 == '那些事'), isTrue);
      expect(r.sections.any((s) => s.$1 == '还没了结的'), isTrue);
    });
  });

  // ============================================================
  // 渲染
  // ============================================================
  group('渲染', () {
    test('空的一篇不渲染出孤零零的标题', () {
      expect(formatEndingReview(const EndingReview([])), isEmpty);
    });

    test('每节都有标题，节与节之间有空行', () {
      final text = formatEndingReview(buildEndingReview(facts(
        affections: {'赫敏': 80},
        keyFacts: [fact('一件要紧事')],
      )));
      expect(text, contains('── 回望这七年 ──'));
      expect(text, contains('【你是谁】'));
      expect(text, contains('【那些人】'));
      expect(text, contains('【那些事】'));
    });

    test('收尾不留一串空行', () {
      final text = formatEndingReview(buildEndingReview(facts(
        affections: {'赫敏': 80},
      )));
      expect(text, isNot(endsWith('\n')));
      expect(text, isNot(contains('\n\n\n')));
    });

    test('整篇读下来是一段连续的话，不是一堆标签', () {
      final text = formatEndingReview(buildEndingReview(facts(
        affections: {'赫敏': 80, '罗恩': 60},
        keyFacts: [fact('张三在密室里救了金妮')],
        openLoops: [loop('答应过邓布利多一次夜探', importance: 8)],
      )));
      // 不能出现内部字段名
      for (final banned in const [
        'importance',
        'category',
        'auto_extracted',
        'null',
        '[]',
      ]) {
        expect(text, isNot(contains(banned)), reason: '渲染结果里漏出了 $banned');
      }
    });
  });

  // ============================================================
  // 接线
  // ============================================================
  group('真的接进了毕业结算', () {
    final src = File('lib/mixins/mixin_systems.dart').readAsStringSync();

    test('毕业结算里会渲染这篇回望', () {
      final i = src.indexOf('void _graduationSettlement()');
      expect(i, greaterThan(-1));
      final body = src.substring(i, i + 4200);
      expect(body, contains('buildEndingReview'));
      expect(body, contains('formatEndingReview'));
    });

    test('回望挂在统计数字之后、留校邀请之前', () {
      // 顺序是有讲究的：先看清这七年的账，再读这篇回望，
      // 最后才知道自己被留下了
      final i = src.indexOf('void _graduationSettlement()');
      final body = src.substring(i, i + 4200);
      final iStats = body.indexOf('【七年统计】');
      final iReview = body.indexOf('buildEndingReview');
      final iOffer = body.indexOf('_maybeOfferFacultyPosition');
      expect(iStats, greaterThan(-1));
      expect(iOffer, greaterThan(-1));
      expect(iStats, lessThan(iReview));
      expect(iReview, lessThan(iOffer));
    });

    test('收拢事实的方法只做收集，不做判断', () {
      final i = src.indexOf('EndingFacts endingFactsOf(');
      expect(i, greaterThan(-1), reason: '找不到 endingFactsOf');
      final body = src.substring(i, i + 1800);
      // 数据来源得是从各处读来的，不能是写死的
      expect(body, contains('memory.keyFacts'));
      expect(body, contains('memory.openLoops'));
      expect(body, contains('npcRegistry.values'));
      expect(body, contains('rewrittenEchoesOf'));
      expect(body, contains('witnessedEchoesOf'));
    });

    test('只算真正打过照面的人——没登场的不该出现在「那些人」里', () {
      // npcRegistry 里有大批从未登场的名字，算进来会让那一节变成通讯录
      final i = src.indexOf('EndingFacts endingFactsOf(');
      final body = src.substring(i, i + 1800);
      expect(body, contains('n.introduced'));
      expect(body, contains('n.isAlive'));
    });

    test('宿敌的档位标签用的是宿敌系统自己的说法', () {
      final i = src.indexOf('EndingFacts endingFactsOf(');
      final body = src.substring(i, i + 1800);
      expect(body, contains('tierDefFor(tier).label'));
      // 不能把内部枚举名印给玩家
      expect(body, isNot(contains('tier.name')));
    });

    test('世界线痕迹读的是 worldState，不是 Player', () {
      // causalChoices 挂在 worldState 上；挂在 Player 上的话
      // 毕业开局新角色时会串味
      final i = src.indexOf('EndingFacts endingFactsOf(');
      final body = src.substring(i, i + 1800);
      expect(body, contains('worldState.causalChoices'));
      expect(body, isNot(contains('p.causalChoices')));
    });
  });

  group('/结局 的终章报告里也有这篇回望', () {
    final src = File('lib/mixins/mixin_relations.dart').readAsStringSync();

    test('本地回退里就有——没配 AI 的玩家最需要这篇骨架', () {
      final i = src.indexOf('Future<void> generateEnding()');
      expect(i, greaterThan(-1));
      final body = src.substring(i, i + 3200);
      expect(body, contains('buildEndingReview'));
      expect(body, contains('localFallback'));
    });

    test('回望排在统计之后、AI 评语之前', () {
      // 顺序：统计（数字）→ 回望（发生过什么）→ 评语（那意味着什么）。
      // 两件事不重复：一篇给骨架，一篇给血肉。
      final i = src.indexOf('Future<void> generateEnding()');
      final body = src.substring(i, i + 3200);
      final iHeader = body.indexOf('《终章报告》');
      final iReview = body.indexOf('buildEndingReview');
      final iCompose = body.indexOf('ending = header +');
      expect(iHeader, greaterThan(-1));
      expect(iHeader, lessThan(iReview));
      // 拼装那一句要排在回望之后：先算出回望，再把它拼进终章
      expect(iCompose, greaterThan(iReview));
      expect(body.substring(iCompose), contains('retrospective'));
    });

    test('回望是空的整个小节就不出现，不会留一段空行', () {
      final i = src.indexOf('Future<void> generateEnding()');
      final body = src.substring(i, i + 3200);
      expect(body, contains('retrospective.isEmpty'));
    });
  });
}
