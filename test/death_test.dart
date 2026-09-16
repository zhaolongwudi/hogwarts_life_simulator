import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/death_data.dart';
import 'package:hogwarts_life_simulator/models/long_term_memory.dart';

const names = ['哈利', '赫敏', '德拉科·马尔福', '德拉科', '斯内普'];

void main() {
  // ============================================================
  // 认不认得出谁死了
  // ============================================================
  group('认得出谁死了', () {
    test('直白的死亡', () {
      expect(deathInNarrative('哈利死了。', names), '哈利');
    });

    test('主语离谓语很远也认得出来', () {
      // 中文里主语常常离得远，窗口太小会认不出是谁
      expect(
        deathInNarrative(
            '倒在血泊里的那个总是第一个冲上来的人，哈利，'
            '这一次再也没有醒来。',
            names),
        '哈利',
      );
    });

    test('遇难、牺牲、被杀都算', () {
      for (final s in const [
        '赫敏在爆炸中遇难了',
        '赫敏为了掩护别人牺牲了自己',
        '赫敏被杀了',
        '赫敏停止了呼吸',
      ]) {
        expect(deathInNarrative(s, names)?.contains('赫敏'), isTrue,
            reason: '$s 没认出来');
      }
    });

    test('一具尸体也会指向那个人', () {
      expect(deathInNarrative('他们在走廊尽头找到了斯内普的尸体', names), '斯内普');
    });

    test('名字取最长的那个——「德拉科·马尔福」不该被记成「德拉科」', () {
      expect(deathInNarrative('德拉科·马尔福死了', names), '德拉科·马尔福');
    });
  });

  // ============================================================
  // 不该记的那些
  // ============================================================
  group('这些不是死', () {
    test('差点死的没死', () {
      for (final s in const [
        '哈利差点死了',
        '哈利险些没命',
        '我以为哈利要死了',
        '哈利几乎倒在走廊上，死了一般',
      ]) {
        expect(deathInNarrative(s, names), isNull, reason: '$s 被误判成死亡');
      }
    });

    test('救回来了的没死', () {
      for (final s in const [
        '幸好哈利被救了回来',
        '哈利捡回一条命',
        '医生把哈利救了回来',
      ]) {
        expect(deathInNarrative(s, names), isNull, reason: '$s 被误判成死亡');
      }
    });

    test('「死」字出现在别的地方，跟死无关', () {
      for (final s in const [
        '教室里死一般的寂静',
        '哈利讲了个笑话，赫敏笑死了',
        '哈利累死了',
        '他在研究死亡圣器',
        '摄魂怪的吻',
      ]) {
        expect(deathInNarrative(s, names), isNull, reason: '$s 被误判成死亡');
      }
    });

    test('埋在长句里也不该漏', () {
      // 反向验证：上面那些排除词不能把真死的一起排除掉
      expect(
        deathInNarrative('哈利倒在台阶上，血流了一地，然后死了。', names),
        '哈利',
      );
    });

    test('说不出是谁就不记——「有人死了」不该随机指一个人', () {
      expect(deathInNarrative('远处传来一声惨叫，有人死了。', names), isNull);
    });

    test('不在名单里的人不记', () {
      expect(deathInNarrative('伏地魔死了', names), isNull);
    });

    test('空文本不炸', () {
      expect(deathInNarrative('', names), isNull);
      expect(deathInNarrative('哈利死了', const []), isNull);
    });
  });

  // ============================================================
  // 死因
  // ============================================================
  group('死因', () {
    test('认得出常见的死因', () {
      expect(deathCauseIn('他在决斗中被击中，死了'), '决斗');
      expect(deathCauseIn('中毒之后没能救回来'), '中毒');
      expect(deathCauseIn('从扫帚上坠落'), '坠落');
    });

    test('认不出就返回 null，不硬编一个', () {
      expect(deathCauseIn('他就那么没了。'), isNull);
    });
  });

  // ============================================================
  // 连锁反应
  // ============================================================
  group('活着的人', () {
    test('至交会跟你更近——共同失去一个人会把人拉近', () {
      final r = rippleFor(85);
      expect(r.affectionDelta, greaterThan(0));
      expect(r.note, contains('至交'));
    });

    test('朋友、熟人各有一档，越亲近反应越大', () {
      final close = rippleFor(75).affectionDelta;
      final friend = rippleFor(55).affectionDelta;
      final acquaintance = rippleFor(35).affectionDelta;
      expect(close, greaterThan(friend));
      expect(friend, greaterThan(acquaintance));
    });

    test('泛泛之交不会被无端波及', () {
      expect(rippleFor(10).affectionDelta, 0);
      // 但也不至于变成负面——那是惩罚，不是悲伤
      expect(rippleFor(-50).affectionDelta, 0);
    });

    test('任何好感值都能得到一档，不会掉出表外', () {
      for (final a in const [-100, -30, 0, 30, 49, 50, 69, 70, 100]) {
        expect(rippleFor(a).note, isNotEmpty, reason: '好感 $a 没有对应的反应');
      }
    });

    test('四档的门槛是递减的，取第一条命中才有意义', () {
      for (var i = 0; i < kDeathRipples.length - 1; i++) {
        expect(kDeathRipples[i].minAffection,
            greaterThan(kDeathRipples[i + 1].minAffection));
      }
    });
  });

  // ============================================================
  // 没做完的事
  // ============================================================
  group('没做完的事', () {
    OpenLoopRecord loop(String desc, Set<String> npcIds, {String status = 'open'}) =>
        OpenLoopRecord(
          id: 'l_${desc.hashCode}',
          description: desc,
          status: status,
          importance: 7,
          openedAt: '1995-03-01 09:00',
          npcIds: npcIds,
        );

    test('他参与的、还没了结的事会被挑出来', () {
      final broken = loopsBrokenByDeath(
        [
          loop('答应陪哈利去霍格莫德', {'harry'}),
          loop('答应陪赫敏去图书馆', {'hermione'}),
        ],
        'harry',
      );
      expect(broken.length, 1);
      expect(broken.first.description, contains('哈利'));
    });

    test('已经了结的、放下的都不算——那些已经结束了', () {
      final broken = loopsBrokenByDeath(
        [
          loop('办完的事', {'harry'}, status: 'done'),
          loop('放弃的事', {'harry'}, status: 'dropped'),
        ],
        'harry',
      );
      expect(broken, isEmpty);
    });

    test('没牵扯到他的事不受影响', () {
      expect(loopsBrokenByDeath([loop('别人的事', {'other'})], 'harry'), isEmpty);
    });
  });

  // ============================================================
  // 文案
  // ============================================================
  group('文案', () {
    test('记忆用第三人称纯陈述，七年之后读起来还是同一件事', () {
      expect(deathFactFor('哈利', null), '哈利 死了。');
      expect(deathFactFor('哈利', '决斗'), contains('决斗'));
    });

    test('通知带着死因，认不出就不硬凑', () {
      expect(deathNoticeFor('哈利', null), '💀 哈利 死了。');
      expect(deathNoticeFor('哈利', '中毒'), contains('中毒'));
    });

    test('没做完的事那句用的是「再也没机会」，不是「放弃了」', () {
      final s = brokenPromiseFactFor('陪他去霍格莫德');
      expect(s, contains('永远做不到'));
      expect(s, isNot(contains('放弃')));
    });

    test('宿敌的账，人死了也就了了', () {
      final s = rivalEndedFactFor('马尔福');
      expect(s, contains('没了'));
      // 这句话要带着一点空——恨了七年的人没了，那七年没有地方放
      expect(s, contains('没有地方放'));
    });

    test('文案里不出现内部字段名', () {
      final all = [
        deathFactFor('哈利', '决斗'),
        deathNoticeFor('哈利', '决斗'),
        brokenPromiseFactFor('某件事'),
        rivalEndedFactFor('马尔福'),
      ].join();
      for (final banned in const [
        'npcIds',
        'status',
        'null',
        'openLoops',
        'ripple',
      ]) {
        expect(all, isNot(contains(banned)), reason: '漏出了 $banned');
      }
    });
  });

  // ============================================================
  // 接线
  // ============================================================
  group('真的接进了游戏', () {
    final src = File('lib/mixins/mixin_response.dart').readAsStringSync();

    test('死亡检测挂在每回合的叙事副作用里', () {
      final i = src.indexOf('void applyNarrativeSideEffects(');
      expect(i, greaterThan(-1));
      expect(src.substring(i, i + 900), contains('tryDeathFromNarrative'));
    });

    test('NPC 模型能记下死因和时间', () {
      final npc = File('lib/models/npc.dart').readAsStringSync();
      expect(npc, contains('deathCause'));
      expect(npc, contains("'death_cause'"));
    });
  });
}
