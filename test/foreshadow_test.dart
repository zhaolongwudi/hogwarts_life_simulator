import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/foreshadow_data.dart';
import 'package:hogwarts_life_simulator/models/long_term_memory.dart';

OpenLoopRecord loop(
  String desc, {
  String id = 'l',
  String status = 'open',
  int importance = 6,
  int openedTurn = 0,
  String? type,
}) =>
    OpenLoopRecord(
      id: id,
      description: desc,
      status: status,
      importance: importance,
      openedAt: '1991-09-01 08:00',
      loopType: type,
      openedTurn: openedTurn,
    );

void main() {
  // ============================================================
  // 二字组
  // ============================================================
  group('二字组切分', () {
    test('标点与空白不算进去——否则两条不相干的文本会因为都用了逗号而"变熟"', () {
      expect(bigramsOf('斯内普，答应保密。'), bigramsOf('斯内普答应保密'));
    });

    test('数字也被剥掉', () {
      expect(bigramsOf('欠了3加隆'), bigramsOf('欠了加隆'));
    });

    test('单字退化为整串，不至于永远匹配不上', () {
      expect(bigramsOf('信'), {'信'});
    });

    test('空串不出错', () {
      expect(bigramsOf(''), isEmpty);
      expect(bigramsOf('，。！'), isEmpty);
    });
  });

  // ============================================================
  // 相似度
  // ============================================================
  group('相似度', () {
    test('一模一样是 1.0', () {
      expect(loopMatchScore('斯内普答应给主角保密身份', '斯内普答应给主角保密身份'), 1.0);
    });

    test('毫不相干是 0', () {
      expect(loopMatchScore('斯内普答应保密', '魁地奇决赛在雨天进行'), 0.0);
    });

    test('空串不参与比较', () {
      expect(loopMatchScore('', '随便什么'), 0.0);
      expect(loopMatchScore('随便什么', ''), 0.0);
    });

    test('比例会被短文本刷高——所以判定不能只看比例', () {
      // 这两件事只是撞了个人名，比例却高达 0.75。
      // 这正是 isSameLoop 还要再卡一道"至少 4 个共同二字组"的原因。
      expect(loopMatchScore('斯内普的信', '斯内普的坩埚'), greaterThan(0.5));
      expect(isSameLoop('斯内普的信', '斯内普的坩埚'), isFalse);
    });
  });

  // ============================================================
  // 是不是同一件事
  // ============================================================
  group('是不是同一件事', () {
    test('措辞换了但说的是一件事——认得出来', () {
      expect(
        isSameLoop(
          '斯内普答应给主角保密身份',
          '斯内普最终还是替主角保守了那个秘密',
        ),
        isTrue,
      );
    });

    test('补上了细节的同一件事也认得出来', () {
      expect(
        isSameLoop(
          '主角欠邓布利多一次夜探',
          '主角终于陪邓布利多夜探了禁忌森林',
        ),
        isTrue,
      );
    });

    test('原样复述直接判中，不用算相似度', () {
      expect(
        isSameLoop(
          '斯内普答应给主角保密身份',
          '这一晚，斯内普答应给主角保密身份，然后转身走了',
        ),
        isTrue,
      );
    });

    test('两个字的短词不会被当成包含关系', () {
      // 「钥匙」出现在两边，但那不算一件事说完了
      expect(isSameLoop('钥匙', '那把钥匙最终打开了尖叫棚屋的门'), isFalse);
    });

    test('只撞了人名的两件事不认', () {
      expect(isSameLoop('斯内普答应保密', '斯内普在魔药课上扣了分'), isFalse);
    });

    test('措辞差太远的会漏掉——这是刻意的取舍', () {
      // 「小天狼星留了一把钥匙」和「那把钥匙打开了尖叫棚屋的门」
      // 明明是一件事，但共同二字组只有 2 个，过不了门槛。
      //
      // 这条断言钉住的是**设计取向**：宁可漏关，不可错关。
      // 错关会让玩家眼看着一件还没办的事被系统宣布了结，
      // 那比"系统没发现我已经办完了"糟糕得多。
      expect(
        isSameLoop('小天狼星留了一把钥匙', '那把钥匙打开了尖叫棚屋的门'),
        isFalse,
      );
    });

    test('对称：A 比 B 和 B 比 A 结果一致', () {
      for (final pair in const [
        ('斯内普答应给主角保密身份', '斯内普最终替主角保守了秘密'),
        ('主角欠邓布利多一次夜探', '主角陪邓布利多夜探了禁忌森林'),
        ('斯内普答应保密', '魁地奇决赛在雨天进行'),
      ]) {
        expect(isSameLoop(pair.$1, pair.$2), isSameLoop(pair.$2, pair.$1),
            reason: '${pair.$1} / ${pair.$2} 不对称');
      }
    });

    test('自己跟自己比当然是同一件事', () {
      expect(isSameLoop('斯内普答应给主角保密身份', '斯内普答应给主角保密身份'), isTrue);
    });
  });

  // ============================================================
  // 挑出该关掉的那条
  // ============================================================
  group('挑出该关掉的那条', () {
    test('从一堆伏笔里准确挑中对应的那条', () {
      final m = pickLoopToClose(
        '斯内普最终还是替主角保守了那个秘密',
        [
          loop('主角欠邓布利多一次夜探', id: 'a'),
          loop('斯内普答应给主角保密身份', id: 'b'),
          loop('小天狼星留了一把钥匙', id: 'c'),
        ],
        currentTurn: 30,
      );
      expect(m, isNotNull);
      expect(m!.loop.id, 'b');
    });

    test('分数最高者优先，不会因为排在前头就先被挑走', () {
      final m = pickLoopToClose(
        '主角陪邓布利多夜探了禁忌森林，终于还清了那次的人情',
        [
          loop('主角欠邓布利多一次夜探', id: '欠债'),
          loop('邓布利多提到过禁忌森林里有些东西不能碰', id: '提醒'),
        ],
        currentTurn: 30,
      );
      expect(m!.loop.id, '欠债');
    });

    test('一条都对不上就返回 null——调用方应当安静地什么都不做', () {
      final m = pickLoopToClose(
        '今天的魔药课平安无事',
        [loop('斯内普答应给主角保密身份')],
        currentTurn: 30,
      );
      expect(m, isNull);
    });

    test('已经关掉的不会被再关一次', () {
      final m = pickLoopToClose(
        '斯内普最终还是替主角保守了那个秘密',
        [loop('斯内普答应给主角保密身份', status: 'done')],
        currentTurn: 30,
      );
      expect(m, isNull);
    });

    test('放下的（dropped）同样不会被捡回来', () {
      final m = pickLoopToClose(
        '斯内普最终还是替主角保守了那个秘密',
        [loop('斯内普答应给主角保密身份', status: 'dropped')],
        currentTurn: 30,
      );
      expect(m, isNull);
    });

    test('刚开不到 2 回合的不算了结——那多半只是 AI 换了个说法重写了一遍', () {
      final m = pickLoopToClose(
        '斯内普最终还是替主角保守了那个秘密',
        [loop('斯内普答应给主角保密身份', openedTurn: 29)],
        currentTurn: 30,
      );
      expect(m, isNull);
    });

    test('开满 2 回合就认了', () {
      final m = pickLoopToClose(
        '斯内普最终还是替主角保守了那个秘密',
        [loop('斯内普答应给主角保密身份', openedTurn: 28)],
        currentTurn: 30,
      );
      expect(m, isNotNull);
    });

    test('了结文本是一堆标点时不炸', () {
      expect(pickLoopToClose('。；，', [loop('随便什么')], currentTurn: 9), isNull);
    });

    test('候选为空返回 null', () {
      expect(pickLoopToClose('斯内普保守了秘密', const [], currentTurn: 9), isNull);
    });
  });

  // ============================================================
  // 回报
  // ============================================================
  group('回报', () {
    test('承诺说到做到，主要记在道德与社交上', () {
      final r = rewardForLoop('promise');
      expect(r.reputation['moral'], greaterThan(0));
      expect(r.reputation['social'], greaterThan(0));
    });

    test('还清债务，债主会替你说话——社交分最高', () {
      final r = rewardForLoop('debt');
      expect(r.reputation['social'], greaterThanOrEqualTo(2));
      expect(r.npcAffection, greaterThan(0));
    });

    test('委托不给回报：它有自己的一套加隆/学院分/声望，不能重复发', () {
      final r = rewardForLoop('quest');
      expect(r.reputation, isEmpty);
      expect(r.npcAffection, 0);
    });

    test('六种类型都有定义，不会掉进"未知类型"的兜底', () {
      for (final t in const [
        'promise',
        'debt',
        'quest',
        'appointment',
        'question',
        'grudge',
      ]) {
        expect(kLoopRewards.containsKey(t), isTrue, reason: '缺 $t');
      }
    });

    test('未知类型按泛化的"有始有终"处理，不会给空', () {
      final r = rewardForLoop('不存在的类型');
      expect(r.reputation, isNotEmpty);
    });

    test('回报压得很低——这是回响，不是奖励', () {
      // 伏笔了结是 AI 自己写出来的，一局里可能有几十次。
      // 给多了七年下来声望就通货膨胀了。
      for (final r in kLoopRewards.values) {
        for (final v in r.reputation.values) {
          expect(v, lessThanOrEqualTo(2), reason: '单项回报不该超过 2');
        }
        expect(r.npcAffection, lessThanOrEqualTo(3));
      }
    });
  });

  // ============================================================
  // 文案
  // ============================================================
  group('文案', () {
    test('六种类型都有人话说法', () {
      for (final t in kLoopRewards.keys) {
        expect(loopTypeLabel(t), isNot(t), reason: '$t 没配中文说法');
      }
    });

    test('未知类型不会把内部键名漏给玩家', () {
      expect(loopTypeLabel('promise_x'), isNot(contains('promise')));
      expect(loopTypeLabel(null), isNotEmpty);
    });

    test('记忆用"终于"，通知带"悬了多少回合"', () {
      final fact = loopClosedFact('斯内普答应给主角保密身份', 'promise');
      expect(fact, contains('了结'));

      final notice = loopClosedNotice('斯内普答应给主角保密身份', 'promise', 42);
      expect(notice, contains('悬了 42 回合'));
    });

    test('只有把等待说出来，等待才有意义', () {
      // 悬了 40 回合才了结的，和下一回合就了结的，不是同一件事
      expect(loopClosedNotice('某件小事', 'promise', 1),
          isNot(loopClosedNotice('某件小事', 'promise', 40)));
    });

    test('没记下回合数时不硬凑', () {
      expect(loopClosedNotice('某件小事', 'promise', 0), isNot(contains('悬了')));
    });

    test('过长的描述会被截断，不会撑爆通知栏', () {
      final long = '这是一件非常非常重要的事' * 10;
      // 一条通知横跨两三行就没人在看了，70 字是能一口气读完的上限
      expect(loopClosedNotice(long, 'promise', 5).length, lessThan(70));
      // 长期记忆那条会一直挂着，更要短——它要跟几十条事实挤在一起
      expect(loopClosedFact(long, 'promise').length, lessThan(80));
    });

    test('文案里不出现内部术语', () {
      for (final t in kLoopRewards.keys) {
        final s = loopClosedNotice('某件事', t, 5) + loopClosedFact('某件事', t);
        for (final banned in const [
          'foreshadow',
          'promise',
          'quest',
          'OpenLoop',
          'loop',
          'null',
        ]) {
          expect(s, isNot(contains(banned)), reason: '$t 的文案里出现了 $banned');
        }
      }
    });
  });

  // ============================================================
  // 该放下的伏笔
  // ============================================================
  group('该放下的伏笔', () {
    test('悬了 90 回合又没什么分量的，该放下了', () {
      final drops = staleLoopsToDrop(
        [loop('一件早被忘掉的小事', openedTurn: 1, importance: 5)],
        100,
      );
      expect(drops.length, 1);
    });

    test('重要的伏笔悬再久也不丢——那可能是玩家真正在等的东西', () {
      final drops = staleLoopsToDrop(
        [loop('一个重大秘密', openedTurn: 1, importance: 9)],
        500,
      );
      expect(drops, isEmpty);
    });

    test('还没到 90 回合的不动', () {
      final drops = staleLoopsToDrop(
        [loop('一件小事', openedTurn: 50, importance: 5)],
        100,
      );
      expect(drops, isEmpty);
    });

    test('已经关掉的、放下的都不再处理', () {
      final drops = staleLoopsToDrop(
        [
          loop('A', openedTurn: 1, status: 'done'),
          loop('B', openedTurn: 1, status: 'dropped'),
        ],
        500,
      );
      expect(drops, isEmpty);
    });

    test('旧存档的 openedTurn 是 0——按"刚开"放过，不能一上手就全丢掉', () {
      final drops = staleLoopsToDrop(
        [loop('老存档里的伏笔', openedTurn: 0, importance: 5)],
        100,
      );
      expect(drops, isEmpty);
    });

    test('AI 提取的伏笔默认是 importance 6，正好在会被放下的线上', () {
      // 这条钉住的是：AI 提取的伏笔**会**被放下。
      // 否则 openLoops 只增不减，100 条堆满之后按插入顺序挤掉最早的，
      // 「别忘了这些重要伏笔」那条提醒就会一直念着早就没了的事。
      expect(kLoopDropMaxImportance, greaterThanOrEqualTo(6));
      final drops = staleLoopsToDrop(
        [loop('AI 提取的伏笔', openedTurn: 1, importance: 6)],
        200,
      );
      expect(drops.length, 1);
    });
  });

  // ============================================================
  // 接线
  // ============================================================
  group('真的接进了摘要流程', () {
    final prompts =
        File('lib/prompts/summary_prompts.dart').readAsStringSync();
    final narrative =
        File('lib/mixins/mixin_narrative.dart').readAsStringSync();

    test('摘要 prompt 让 AI 输出【了结】块', () {
      expect(prompts, contains('【了结】'));
    });

    test('prompt 要求照抄伏笔原话——改写了就认不出来是哪件事', () {
      final i = prompts.indexOf('【了结】');
      expect(i, greaterThan(-1));
      final body = prompts.substring(i);
      expect(body, contains('照抄'));
      expect(body, contains('不要改写'));
    });

    test('prompt 明确说了没有就不要写——否则 AI 会为了凑格式写个"无"', () {
      final i = prompts.indexOf('【了结】');
      final body = prompts.substring(i);
      expect(body, contains('本段没有东西了结就整行不写'));
    });

    test('解析里真的会读【了结】块', () {
      expect(narrative, contains("_extractBlock(rawSummary, '了结')"));
    });

    test('清洗时会把【了结】块剥掉，不让它混进 T4 摘要', () {
      expect(narrative, contains(r'【了结】[\s\S]*?(?=【|$)'));
    });

    test('关掉伏笔时写了长期记忆、弹了通知、也给了回报', () {
      final i = narrative.indexOf('void _closeLoopIfMatched(');
      expect(i, greaterThan(-1));
      final body = narrative.substring(i, i + 2000);
      expect(body, contains("status: 'done'"), reason: '没有把伏笔置为 done');
      expect(body, contains('addKeyFact'), reason: '没有写长期记忆');
      expect(body, contains('notifications.add'), reason: '没有弹通知');
      expect(body, contains('rewardForLoop'), reason: '没有给回报');
    });

    test('匹配不上时安静地什么都不做，不弹任何东西', () {
      final i = narrative.indexOf('void _closeLoopIfMatched(');
      final body = narrative.substring(i, i + 2000);
      // 「匹配不上就 return」必须排在弹通知之前，否则就是先报喜再判断
      final iReturn = body.indexOf('if (match == null) return;');
      final iNotice = body.indexOf('notifications.add');
      expect(iNotice, greaterThan(-1));
      expect(iReturn, greaterThan(-1));
      expect(iReturn, lessThan(iNotice));
    });

    test('好感走统一入口，没有绕过 updateNpcAffection', () {
      final i = narrative.indexOf('void _closeLoopIfMatched(');
      final body = narrative.substring(i, i + 2000);
      expect(body, contains('updateNpcAffection('));
      expect(body, isNot(contains('npc.affection +=')));
    });

    test('【了结】不会跟已有的块名撞车', () {
      // 【关系】【伏笔】【核心事实】【世界事件】——加了【了结】之后
      // 任何一个都不是另一个的子串，否则 _extractBlock 会取错块
      for (final b in const ['关系', '伏笔', '了结', '核心事实', '世界事件']) {
        for (final other in const ['关系', '伏笔', '了结', '核心事实', '世界事件']) {
          if (b == other) continue;
          expect(other.contains(b), isFalse, reason: '$b 与 $other 撞名');
        }
      }
    });
  });
}
