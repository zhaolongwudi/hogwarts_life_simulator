import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/faculty_data.dart';
import 'package:hogwarts_life_simulator/data/course_data.dart';
import 'package:hogwarts_life_simulator/models/player.dart';

void main() {
  /// 一套「够格」的标准输入
  Map<String, int> goodAttrs({int potions = 80}) => {
        'potions': potions,
        'transfiguration': 60,
        'spell_understanding': 60,
        'dda': 55,
        'herbology': 55,
        'theory': 50,
        'memory': 50,
        'flying': 50,
        'logic': 50,
        'intuition': 50,
        'observation': 50,
        'creativity': 50,
      };

  const goodTeachers = {'米勒娃·麦格': 60, '西弗勒斯·斯内普': 50};

  FacultyEligibility eval({
    int academic = 70,
    int moral = 60,
    int dark = 10,
    Map<String, int>? attributes,
    Map<String, int>? teachers,
  }) =>
      evaluateFacultyEligibility(
        academic: academic,
        moral: moral,
        dark: dark,
        attributes: attributes ?? goodAttrs(),
        teacherAffections: teachers ?? goodTeachers,
      );

  // ==================== 科目 ====================
  group('任教科目', () {
    test('教席科目全部来自课程表，没有自造的课', () {
      final courseNames =
          allCourses().map((c) => c.name.replaceAll(RegExp(r'（[^）]*）'), '').trim()).toSet();
      for (final s in subjectsByAttribute().values) {
        expect(courseNames, contains(s),
            reason: '教席「$s」在课程表里不存在——学校不会开这门课');
      }
    });

    test('科目名不带年级后缀', () {
      for (final s in subjectsByAttribute().values) {
        expect(s, isNot(contains('（')), reason: '「$s」还挂着年级后缀');
      }
    });

    test('挑的是最强的那门', () {
      final best = bestSubjectOf({'potions': 90, 'transfiguration': 60});
      expect(best.subject, '魔药学');
      expect(best.score, 90);
    });

    test('平手时有确定结果，不随机', () {
      final a = bestSubjectOf({'potions': 70, 'transfiguration': 70});
      final b = bestSubjectOf({'potions': 70, 'transfiguration': 70});
      expect(a.subject, b.subject);
    });

    test('属性表为空时有兜底，不返回空学科', () {
      final best = bestSubjectOf(const {});
      expect(best.subject, isNotEmpty);
      expect(best.score, 50, reason: '没数据时按默认值 50 算');
    });

    test('通用素质不能当主科', () {
      // 情绪稳定、意志这些没有对应教席，再高也不可能成为主科
      final best = bestSubjectOf({
        'emotional_stability': 99,
        'willpower': 99,
        'courage': 99,
        'potions': 30,
      });
      expect(subjectsByAttribute().keys, contains(best.key),
          reason: '挑中的「${best.subject}」不是课程表里的学科');
      expect(const ['emotional_stability', 'willpower', 'courage', 'social'],
          isNot(contains(best.key)),
          reason: '通用素质被当成了主科');
    });
  });

  // ==================== 资格门槛 ====================
  group('留校资格', () {
    test('标准优等生够格', () {
      final e = eval();
      expect(e.eligible, isTrue);
      expect(e.startingRank, FacultyRank.assistant);
      expect(e.subject, '魔药学');
      expect(e.allies, contains('米勒娃·麦格'));
    });

    test('走后门：学术够硬且有一位教授真看重你，起步就是讲师', () {
      // 光是够格只能从助教熬起（下一条钉住）；要有教授力挺才跳级
      final e = eval(academic: 80, teachers: {
        '米勒娃·麦格': 70,
        '西弗勒斯·斯内普': 46,
      });
      expect(e.eligible, isTrue);
      expect(e.startingRank, FacultyRank.lecturer);
    });

    test('只是够格的话，还是得从助教做起', () {
      final e = eval(academic: 80, teachers: {
        '米勒娃·麦格': 60,
        '西弗勒斯·斯内普': 50,
      });
      expect(e.eligible, isTrue);
      expect(e.startingRank, FacultyRank.assistant);
    });

    test('学术声望不够就没邀请', () {
      final e = eval(academic: 54);
      expect(e.eligible, isFalse);
      expect(e.startingRank, FacultyRank.none);
      expect(e.academicGap, 1, reason: '要能告诉玩家具体差多少');
    });

    test('没有拿得出手的一门课就没邀请', () {
      final e = eval(attributes: goodAttrs(potions: 67));
      expect(e.eligible, isFalse);
      expect(e.subjectGap, greaterThan(0));
    });

    test('声名狼藉的人不会被留校', () {
      expect(eval(moral: 30).eligible, isFalse);
      expect(eval(dark: 50).eligible, isFalse);
    });

    test('没有教授愿意推荐就没邀请', () {
      final e = eval(teachers: {'米勒娃·麦格': 50});
      expect(e.eligible, isFalse);
      expect(e.alliesGap, 1);
    });

    test('关系不好的教授不算推荐人', () {
      final e = eval(teachers: {
        '米勒娃·麦格': 50,
        '西弗勒斯·斯内普': 20, // 低于门槛
        '菲利乌斯·弗立维': 44, // 差 1 点
      });
      expect(e.allies.length, 1);
      expect(e.eligible, isFalse);
    });

    test('达标时各项 gap 归零', () {
      final e = eval();
      expect(e.academicGap, 0);
      expect(e.subjectGap, 0);
      expect(e.moralGap, 0);
      expect(e.alliesGap, 0);
    });

    test('checks 逐条可读，能当"差在哪"的说明书', () {
      final e = eval(academic: 10);
      expect(e.checks, isNotEmpty);
      for (final (label, _) in e.checks) {
        expect(label, contains('当前'));
      }
      // 只有学术那一条该亮红，其余都达标
      expect(e.checks[0].$2, isFalse);
      expect(e.checks.skip(1).every((c) => c.$2), isTrue);
    });

    test('门槛不是白送：默认新人拿不到邀请', () {
      // 开局玩家：属性全 50、声望全 0、没跟教授说过话
      final e = evaluateFacultyEligibility(
        academic: 0,
        moral: 0,
        dark: 0,
        attributes: const {},
        teacherAffections: const {},
      );
      expect(e.eligible, isFalse);
    });
  });

  // ==================== 晋升 ====================
  group('晋升', () {
    test('年限和声望都够才升', () {
      final next = promotionFor(
        current: FacultyRank.assistant,
        serviceYears: 2,
        academic: 60,
        leadership: 0,
      );
      expect(next, isNotNull);
      expect(next!.rank, FacultyRank.lecturer);
    });

    test('年限不够不升', () {
      expect(
          promotionFor(
            current: FacultyRank.assistant,
            serviceYears: 1,
            academic: 90,
            leadership: 90,
          ),
          isNull);
    });

    test('声望不够不升', () {
      expect(
          promotionFor(
            current: FacultyRank.assistant,
            serviceYears: 10,
            academic: 59,
            leadership: 90,
          ),
          isNull);
    });

    test('院长还要看领导声望', () {
      expect(
          promotionFor(
            current: FacultyRank.professor,
            serviceYears: 8,
            academic: 90,
            leadership: 64, // 差 1
          ),
          isNull);
      expect(
          promotionFor(
            current: FacultyRank.professor,
            serviceYears: 8,
            academic: 90,
            leadership: 65,
          ),
          isNotNull);
    });

    test('已是院长就没有更高的了', () {
      expect(
          promotionFor(
            current: FacultyRank.headOfHouse,
            serviceYears: 30,
            academic: 100,
            leadership: 100,
          ),
          isNull);
    });

    test('未任教时不谈晋升', () {
      expect(
          promotionFor(
            current: FacultyRank.none,
            serviceYears: 99,
            academic: 100,
            leadership: 100,
          ),
          isNull);
    });

    test('每一档的年限与声望都逐级抬高', () {
      for (var i = 1; i < kFacultyRanks.length; i++) {
        expect(kFacultyRanks[i].minServiceYears,
            greaterThan(kFacultyRanks[i - 1].minServiceYears),
            reason: '${kFacultyRanks[i].title} 的年限没比上一级高');
        expect(kFacultyRanks[i].minAcademic,
            greaterThan(kFacultyRanks[i - 1].minAcademic),
            reason: '${kFacultyRanks[i].title} 的学术门槛没比上一级高');
        expect(kFacultyRanks[i].annualPay,
            greaterThan(kFacultyRanks[i - 1].annualPay));
      }
    });

    test('晋升提示说得清差在哪', () {
      final hint = promotionHintFor(
        current: FacultyRank.assistant,
        serviceYears: 0,
        academic: 30,
        leadership: 0,
      );
      expect(hint, contains('任教年限'));
      expect(hint, contains('学术声望'));
    });

    test('条件都满足时提示可以升了', () {
      expect(
          promotionHintFor(
            current: FacultyRank.assistant,
            serviceYears: 5,
            academic: 90,
            leadership: 90,
          ),
          contains('全部条件'));
    });
  });

  // ==================== 指令解析 ====================
  group('教职指令', () {
    test('接受的各种说法都认', () {
      for (final s in const ['/教职 接受', '/教职 答应', '/教职 留下', '  /教职 接受  ']) {
        expect(parseFacultyCommand(s), isTrue, reason: '$s 没被认成接受');
      }
    });

    test('婉拒的各种说法都认', () {
      for (final s in const ['/教职 婉拒', '/教职 拒绝', '/教职 离校']) {
        expect(parseFacultyCommand(s), isFalse, reason: '$s 没被认成婉拒');
      }
    });

    test('不带参数或别的指令不误伤', () {
      expect(parseFacultyCommand('/教职'), isNull);
      expect(parseFacultyCommand('/教职 查看'), isNull);
      expect(parseFacultyCommand('/状态'), isNull);
      expect(parseFacultyCommand('我要留下来教书'), isNull);
    });

    test('行动文案是具体动作，能交给 AI 续写', () {
      expect(facultyActionLineFor(true, '魔药学'), contains('留下来'));
      expect(facultyActionLineFor(true, '魔药学'), contains('魔药学'));
      expect(facultyActionLineFor(false, '魔药学'), contains('离开'));
      for (final s in [
        facultyActionLineFor(true, '魔药学'),
        facultyActionLineFor(false, '魔药学')
      ]) {
        expect(s, isNot(contains('/')), reason: '行动文案里混进了指令符号');
        expect(s.length, greaterThan(8));
      }
    });
  });

  // ==================== 文案 ====================
  group('邀请文案', () {
    test('够格时的邀请说清了科目、职称、年薪、推荐人', () {
      final e = eval();
      final line = facultyOfferLineFor(
        e: e, headmasterName: '阿不思·邓布利多', playerName: '测试者');
      expect(line, contains('阿不思·邓布利多'));
      expect(line, contains('魔药学'));
      expect(line, contains('助教'));
      expect(line, contains('400'));
      expect(line, contains('米勒娃·麦格'));
    });

    test('认不出校长时退回「校方」，不指名道姓', () {
      // 1892 年邓布利多自己还是新生，2020 年他已逝世——
      // 这两种情况下都不能让一个不存在的人来发邀请。
      final line = facultyOfferLineFor(
          e: eval(), headmasterName: null, playerName: '测试者');
      expect(line, contains('校方'));
      expect(line, isNot(contains('邓布利多')));
    });

    test('推荐人超过两位时 condensed 显示', () {
      final e = eval(teachers: {
        '米勒娃·麦格': 60,
        '西弗勒斯·斯内普': 55,
        '菲利乌斯·弗立维': 52,
      });
      final line = facultyOfferLineFor(
          e: e, headmasterName: '校方', playerName: '测试者');
      expect(line, contains('3 位教授'));
    });

    test('婉拒文案承认这是不可逆的', () {
      expect(kFacultyDeclineLine, isNotEmpty);
    });
  });

  // ==================== 存档 ====================
  group('存档', () {
    test('教职字段有 JSON 往返', () {
      final p = Player(
        name: '测试',
        birthYear: '1980',
        bloodType: 'halfblood',
        birthLocation: '伦敦',
        facultyRankId: 'lecturer',
        facultySubject: '魔药学',
        facultyServiceYears: 3,
        facultyOfferDeclined: false,
      );
      final json = p.toJson();
      expect(json['faculty_rank_id'], 'lecturer');
      expect(json['faculty_subject'], '魔药学');
      expect(json['faculty_service_years'], 3);
      expect(json['faculty_offer_declined'], false);

      final back = Player.fromJson(json);
      expect(back.facultyRankId, 'lecturer');
      expect(back.facultySubject, '魔药学');
      expect(back.facultyServiceYears, 3);
      expect(back.facultyOfferDeclined, false);
    });

    test('老存档没有这几个字段时读默认值，不炸', () {
      final p = Player(
          name: '测试',
          birthYear: '1980',
          bloodType: 'halfblood',
          birthLocation: '伦敦');
      final old = Map<String, dynamic>.from(p.toJson())
        ..remove('faculty_rank_id')
        ..remove('faculty_subject')
        ..remove('faculty_service_years')
        ..remove('faculty_offer_declined');
      final back = Player.fromJson(old);
      expect(back.facultyRankId, isNull);
      expect(back.facultySubject, isNull);
      expect(back.facultyServiceYears, 0);
      expect(back.facultyOfferDeclined, false);
    });

    test('rankId 查得到对应的档', () {
      for (final r in kFacultyRanks) {
        expect(rankDefById(r.id)?.rank, r.rank);
      }
      expect(rankDefById('garbage'), isNull);
      expect(rankDefFor(FacultyRank.assistant).title, '助教');
    });
  });
}
