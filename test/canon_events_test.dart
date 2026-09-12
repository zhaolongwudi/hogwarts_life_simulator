import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/canon_events.dart';

/// 原著剧情节点库的守门测试。
///
/// 三组不变量：
///   A. 时间线与结构完整性 —— 七部小说都有节点，字段合法；
///   B. 过滤语义 —— 时代/年级/月份/一次性触发都正确；
///   C. **平行世界约束**（本文件最重要的部分）—— 玩家是原创角色，
///      directive 不得把玩家写成哈利。这条一旦破防，会连带触发
///     mixin_narrative_continuity 里的 R3c 家庭设定杂交等一串校验。
void main() {
  // ================================================================ A
  group('时间线与结构完整性', () {
    test('七部小说都有节点覆盖', () {
      final books = canonEvents.map((e) => e.bookRef).toSet();
      for (final b in [
        '魔法石',
        '密室',
        '阿兹卡班的囚徒',
        '火焰杯',
        '凤凰社',
        '混血王子',
        '死亡圣器',
      ]) {
        expect(books, contains(b), reason: '《$b》至少需要一个剧情节点');
      }
    });

    test('时间线覆盖 1991-1998（玩家在校的七个学年）', () {
      final (minY, maxY) = canonYearRange;
      expect(minY, 1991);
      expect(maxY, 1998);
    });

    test('每个学年的 9 月都有节点（开学季是叙事锚点）', () {
      for (var y = 1991; y <= 1997; y++) {
        final sep = canonEvents.where((e) => e.year == y && e.month == 9);
        expect(sep, isNotEmpty, reason: '$y 年 9 月应有剧情节点');
      }
    });

    test('结构约束：id 唯一、月份合法、文本非空、eras 非空', () {
      final ids = <String>{};
      for (final e in canonEvents) {
        expect(ids.add(e.id), isTrue, reason: 'id 重复：${e.id}');
        expect(e.id, startsWith('canon_'), reason: '未加 canon_ 前缀：${e.id}');
        expect(e.month, inInclusiveRange(1, 12), reason: '${e.id} 月份非法');
        expect(e.year, inInclusiveRange(1991, 1998), reason: '${e.id} 年份越界');
        expect(e.title.trim(), isNotEmpty, reason: '${e.id} 标题为空');
        expect(e.directive.trim(), isNotEmpty, reason: '${e.id} directive 为空');
        expect(e.eras, isNotEmpty, reason: '${e.id} 未声明适用时代');
        expect(e.bookRef.trim(), isNotEmpty, reason: '${e.id} 缺出处标注');
        if (e.grade != null) {
          expect(e.grade, inInclusiveRange(1, 7), reason: '${e.id} 年级越界');
        }
      }
    });

    test('节点数量下限（防误删整段）', () {
      expect(canonEventCount, greaterThanOrEqualTo(25));
    });

    test('isCanonEventId 能区分原著节点与普通锚点', () {
      expect(isCanonEventId('canon_cos_chamber_open'), isTrue);
      expect(isCanonEventId('g1_sep_arrival'), isFalse);
      expect(isCanonEventId(''), isFalse);
    });
  });

  // ================================================================ B
  group('过滤语义', () {
    test('子世代返回原著节点', () {
      final due = dueCanonEvents(
        year: 1992,
        month: 9,
        grade: 2,
        era: 'harry_same',
        firedIds: const {},
      );
      expect(due, isNotEmpty);
      expect(due.first.id, 'canon_cos_chamber_open');
    });

    test('非子世代一律不返回（1892 少年邓布利多 / 1971 亲世代）', () {
      for (final era in ['dumbledore', 'marauders', 'first_war', 'post_war']) {
        // 用同样的年份+月份，只有时代不同
        final due = dueCanonEvents(
          year: 1992,
          month: 9,
          grade: 2,
          era: era,
          firedIds: const {},
        );
        expect(due, isEmpty, reason: '$era 时代不该套用子世代原著事件');
      }
    });

    test('eraHasCanonTimeline 只对子世代为真', () {
      expect(eraHasCanonTimeline('harry_same'), isTrue);
      expect(eraHasCanonTimeline('dumbledore'), isFalse);
      expect(eraHasCanonTimeline('marauders'), isFalse);
      expect(eraHasCanonTimeline('first_war'), isFalse);
      expect(eraHasCanonTimeline('post_war'), isFalse);
      expect(eraHasCanonTimeline(''), isFalse);
    });

    test('月份不匹配不返回', () {
      final due = dueCanonEvents(
        year: 1992,
        month: 7, // 7 月是暑假，该年没有 7 月节点
        grade: 2,
        era: 'harry_same',
        firedIds: const {},
      );
      expect(due, isEmpty);
    });

    test('年级门槛生效：巨怪事件只给一年级', () {
      final g1 = dueCanonEvents(
        year: 1991,
        month: 10,
        grade: 1,
        era: 'harry_same',
        firedIds: const {},
      );
      expect(g1.map((e) => e.id), contains('canon_ps_troll'));

      final g5 = dueCanonEvents(
        year: 1991,
        month: 10,
        grade: 5,
        era: 'harry_same',
        firedIds: const {},
      );
      expect(g5.map((e) => e.id), isNot(contains('canon_ps_troll')),
          reason: '巨怪闯入学是 1991 年一年级的事，五年级玩家不该再收到');
    });

    test('一次性触发：已 fired 的节点不再返回（整个存档只响一次）', () {
      final id = 'canon_cos_chamber_open';
      expect(
        dueCanonEvents(
          year: 1992,
          month: 9,
          grade: 2,
          era: 'harry_same',
          firedIds: const {},
        ).map((e) => e.id),
        contains(id),
      );
      expect(
        dueCanonEvents(
          year: 1992,
          month: 9,
          grade: 2,
          era: 'harry_same',
          firedIds: <String>{id},
        ),
        isEmpty,
      );
    });

    test('limit 节流：默认每回合最多返回 1 条', () {
      // 找一个同月有多条候选的月份来验证节流确实起作用
      final due = dueCanonEvents(
        year: 1991,
        month: 12,
        grade: 1,
        era: 'harry_same',
        firedIds: const {},
        limit: 1,
      );
      expect(due.length, lessThanOrEqualTo(1));
    });

    test('firedIds 接受 List（与 WorldState.firedAnchorIds 同类型）', () {
      // WorldState.firedAnchorIds 是 List<String>，不是 Set
      final due = dueCanonEvents(
        year: 1992,
        month: 9,
        grade: 2,
        era: 'harry_same',
        firedIds: <String>['canon_cos_chamber_open'],
      );
      expect(due, isEmpty);
    });
  });

  // ================================================================ C
  //
  // 平行世界约束：玩家是原创角色，不是哈利。
  // 这些措辞一旦出现，玩家会被叙事 AI 当成哈利本人，进而触发
  // R3c_family_not_dursley 等一串校验，且与「原创主角」设定自相矛盾。
  group('平行世界约束：directive 不得把玩家写成哈利', () {
    /// 把玩家当哈利 / 当原著主角的措辞。
    ///
    /// 注意这里是**针对玩家主语**的检查：单纯提到「哈利」这个 NPC
    /// （如"有传闻说哈利·波特也在场"）是允许的——平行世界里哈利确实同校。
    /// 所以禁用的是「你 + 哈利专属物/身份」的组合，以及第二人称直接扮演句。
    const forbidden = <String>[
      '你是哈利',
      '你，哈利',
      '你的伤疤',
      '你额上的闪电',
      '闪电形伤疤',
      '你举起了魔杖对着蛇怪',
      '你杀死了蛇怪',
      '你作为救世主',
      '救世主的你',
      '你的父母被伏地魔',
      '你住在女贞路4号',
      '你的姨妈是佩妮',
      '你拿到了分院帽的',
    ];

    test('没有任何节点的 directive 使用"玩家即哈利"的措辞', () {
      for (final e in canonEvents) {
        for (final bad in forbidden) {
          expect(
            e.directive.contains(bad),
            isFalse,
            reason: '「${e.id}」的 directive 出现禁忌措辞「$bad」——'
                '玩家是原创角色，原著事件必须写成"发生在周围"',
          );
        }
      }
    });

    test('事件应使用旁观/传闻视角（至少含一个旁观信号词）', () {
      const observerSignals = [
        '传闻',
        '听说',
        '报道',
        '议论',
        '消息',
        '宣布',
        '流传',
        '注意到',
        '外面',
        '学校',
        '学生',
        '你听见',
        '你可以',
        '有人',
        '通知',
        '公告',
      ];
      for (final e in canonEvents) {
        final ok = observerSignals.any(e.directive.contains);
        expect(ok, isTrue,
            reason: '「${e.id}」directive 缺少旁观视角信号词，'
                '容易让叙事 AI 写成玩家亲自主导原著事件');
      }
    });

    test('标题不包含第二人称（标题会进通知栏，不该是玩家动作）', () {
      for (final e in canonEvents) {
        expect(e.title.contains('你'), isFalse,
            reason: '「${e.id}」标题含第二人称：${e.title}');
      }
    });
  });
}
