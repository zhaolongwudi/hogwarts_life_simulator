import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/scar_data.dart';

void main() {
  // ============================================================
  // 认不认得出重伤
  // ============================================================
  group('哪些伤会留下疤', () {
    test('骨折会留疤', () {
      expect(scarFromNarrative('你的手臂发出一声脆响，骨头断了'),
          isNotNull);
    });

    test('深度切割会留疤', () {
      expect(
        scarFromNarrative('那道咒语在他腿上留下一道深可见骨的口子'),
        isNotNull,
      );
    });

    test('烧伤会留疤', () {
      expect(scarFromNarrative('龙的火焰扫过，他的肩膀瞬间烧焦'), isNotNull);
    });

    test('诅咒留下的伤害会留疤', () {
      expect(scarFromNarrative('那个诅咒在你的胸口留下了无法愈合的伤'), isNotNull);
    });

    test('失去某个部位会留疤', () {
      expect(scarFromNarrative('他的一只眼睛瞎了'), isNotNull);
    });

    test('擦伤不留疤——它会好', () {
      expect(scarFromNarrative('你的手臂擦破了一点皮'), isNull);
    });

    test('瘀青不留疤', () {
      expect(scarFromNarrative('膝盖上青了一块'), isNull);
    });

    test('只是一阵疼，什么都不留', () {
      expect(scarFromNarrative('你的手腕一阵疼，过了一会儿好了'), isNull);
    });

    test('空文本不炸', () {
      expect(scarFromNarrative(''), isNull);
    });
  });

  // ============================================================
  // 认不认得出部位
  // ============================================================
  group('认得出伤在哪', () {
    test('手臂', () {
      expect(scarFromNarrative('你的手臂骨折了')!.site, ScarSite.wandArm);
    });

    test('腿', () {
      expect(scarFromNarrative('他的腿骨断裂了')!.site, ScarSite.leg);
    });

    test('额头', () {
      expect(scarFromNarrative('额头被击中，当场昏迷')!.site, ScarSite.head);
    });

    test('胸口', () {
      expect(scarFromNarrative('诅咒贯穿了他的胸口')!.site, ScarSite.chest);
    });

    test('后背', () {
      expect(scarFromNarrative('背上留下了一道深可见骨的伤')!.site, ScarSite.back);
    });

    test('脸颊', () {
      expect(scarFromNarrative('脸颊被划开，永久留下了一道疤')!.site, ScarSite.face);
    });

    test('脸和头是两种疤，脸排在前头', () {
      // "脸颊"里含"脸"，"额头"里含"头"。若顺序错了，
      // 脸颊的疤会被记成头上的伤——那是两种完全不同的后果。
      expect(scarFromNarrative('脸颊骨折了')!.site, ScarSite.face);
      expect(scarFromNarrative('后脑骨折了')!.site, ScarSite.head);
    });

    test('伤得够重但说不出部位，就不记——不该凭空猜一个', () {
      expect(scarFromNarrative('他受了无法愈合的重伤'), isNull);
    });

    test('知道部位但伤得不够重，同样不记', () {
      expect(scarFromNarrative('你的手臂有点疼'), isNull);
    });
  });

  // ============================================================
  // 轻伤
  // ============================================================
  group('会好的那些伤', () {
    test('擦伤、瘀青、扭伤都算轻伤', () {
      for (final s in const [
        '手臂擦伤',
        '腿上青了一块',
        '脚踝扭伤了',
        '流了点血',
        '有点酸痛',
      ]) {
        expect(isMinorInjury(s), isTrue, reason: '$s 该算轻伤');
      }
    });

    test('重伤不算轻伤', () {
      expect(isMinorInjury('骨头断了'), isFalse);
    });

    test('空文本不算', () {
      expect(isMinorInjury(''), isFalse);
    });
  });

  // ============================================================
  // 后遗症
  // ============================================================
  group('后遗症', () {
    test('每个部位都配了影响，没有空壳', () {
      for (final d in kScarDefs) {
        expect(d.penalties, isNotEmpty, reason: '${d.label} 没有后遗症');
        expect(d.aftermath, isNotEmpty, reason: '${d.label} 没有描述');
      }
    });

    test('每个部位的影响都不只是罚——总有一条是正的', () {
      // 只给惩罚的话，疤就是个 debuff 图标。
      // 有了这一正一负，它才像是发生在这具身体上的一件事。
      for (final d in kScarDefs) {
        expect(d.penalties.values.any((v) => v > 0), isTrue,
            reason: '${d.label} 全是负面，没有正面的那一半');
        expect(d.penalties.values.any((v) => v < 0), isTrue,
            reason: '${d.label} 全是正面，那不叫伤');
      }
    });

    test('影响的都是真实存在的属性', () {
      const known = {
        'social', 'emotional_stability', 'spell_understanding',
        'magic_control', 'caution', 'flying', 'reaction_time',
        'memory', 'theory', 'intuition', 'courage', 'willpower',
      };
      for (final d in kScarDefs) {
        for (final k in d.penalties.keys) {
          expect(known, contains(k), reason: '${d.label} 用了不存在的属性 $k');
        }
      }
    });

    test('同一属性取最重的那条，不累加', () {
      // 同一块地方再伤一次，不该比第一次更糟
      final p = scarPenaltiesOf([
        const Scar(site: ScarSite.head, since: 'x'),
        const Scar(site: ScarSite.head, since: 'y'),
      ]);
      expect(p['memory'], -3);
    });

    test('没有疤就没有影响', () {
      expect(scarPenaltiesOf(const []), isEmpty);
      expect(scarPenaltyTotal(const []), 0);
    });

    test('六处全中也不会废掉——总惩罚真的被压到封顶之内', () {
      final total = scarPenaltyTotal(
        ScarSite.values.map((s) => Scar(site: s, since: 'x')),
      );
      // 不封顶的话受够几处伤就废了——那不是"有重量"，是劝退。
      // 注意这里测的是压缩**之后**的值：封顶要是只写在注释里，
      // 这条断言就会失败（六处全中原始是 22）。
      expect(total, lessThanOrEqualTo(kScarPenaltyCap));
    });

    test('封顶是针对惩罚总量，正面的那一半不算进去', () {
      // 腿上的疤：飞行-3、反应-2、谨慎+2 → 惩罚总量 5
      expect(scarPenaltyTotal([const Scar(site: ScarSite.leg, since: 'x')]), 5);
    });

    test('正常的几次受伤一分不少，只有浑身是伤才打折', () {
      // 三处疤 15 点，正好还在封顶之内——正常游戏很难超过这个数
      final three = scarPenaltyTotal([
        const Scar(site: ScarSite.wandArm, since: 'x'),
        const Scar(site: ScarSite.leg, since: 'x'),
        const Scar(site: ScarSite.head, since: 'x'),
      ]);
      expect(three, 15);
      // 且数值没有被改动过
      expect(
        scarPenaltiesOf([
          const Scar(site: ScarSite.wandArm, since: 'x'),
          const Scar(site: ScarSite.leg, since: 'x'),
          const Scar(site: ScarSite.head, since: 'x'),
        ]),
        {
          'spell_understanding': -3,
          'magic_control': -2,
          'caution': 2,
          'flying': -3,
          'reaction_time': -2,
          'memory': -3,
          'theory': -2,
          'intuition': 2,
        },
      );
      // 单条疤的数值也没被改过
      expect(
        scarPenaltiesOf([const Scar(site: ScarSite.wandArm, since: 'x')])
          ..removeWhere((k, v) => v > 0),
        {'spell_understanding': -3, 'magic_control': -2},
      );
    });

    test('压缩只压负的那一半，正面的原样保留', () {
      // 正面的那些是伤带来的东西，不是惩罚，不该跟着打折
      final raw = scarPenaltiesOf(
        ScarSite.values.map((s) => Scar(site: s, since: 'x')),
        cap: 9999,
      );
      final all = scarPenaltiesOf(
        ScarSite.values.map((s) => Scar(site: s, since: 'x')),
      );
      for (final e in raw.entries) {
        if (e.value > 0) {
          expect(all[e.key], e.value,
              reason: '${e.key} 的正面影响被一起压掉了');
        }
      }
      // 确实有正面的东西在里面，不然这条测试形同虚设
      expect(raw.values.any((v) => v > 0), isTrue);
    });

    test('不管受几处伤，总惩罚都在封顶之内', () {
      final sites = <ScarSite>[];
      for (final s in ScarSite.values) {
        sites.add(s);
        expect(
          scarPenaltyTotal(sites.map((x) => Scar(site: x, since: ''))),
          lessThanOrEqualTo(kScarPenaltyCap),
          reason: '受 ${sites.length} 处伤时超了封顶',
        );
      }
    });

    test('同一个属性正负并存时，各自取最重的一条再相加', () {
      // 胸口让人畏缩（-2），脸上留疤反而让人沉得住气（+2）——
      // 这两条会互相抵消，而不是看谁先被遍历到。
      final chestOnly = scarPenaltiesOf([
        const Scar(site: ScarSite.chest, since: 'x'),
      ]);
      final both = scarPenaltiesOf([
        const Scar(site: ScarSite.chest, since: 'x'),
        const Scar(site: ScarSite.face, since: 'x'),
      ]);
      expect(chestOnly['emotional_stability'], -2);
      expect(both['emotional_stability'], 0);

      // 反过来遍历，结果必须一样——否则同一副身体换个顺序就换一套数值
      final reversed = scarPenaltiesOf([
        const Scar(site: ScarSite.face, since: 'x'),
        const Scar(site: ScarSite.chest, since: 'x'),
      ]);
      expect(reversed['emotional_stability'], 0);
    });
  });

  // ============================================================
  // 存盘
  // ============================================================
  group('存盘', () {
    test('存的是部位，不是数值——调平衡不用迁移存档', () {
      final json = const Scar(site: ScarSite.leg, since: '1993-04-02').toJson();
      expect(json['site'], 'leg');
      expect(json.containsKey('penalties'), isFalse);
      expect(json.containsKey('flying'), isFalse);
    });

    test('往返不丢', () {
      final s = const Scar(site: ScarSite.chest, since: '1995-06-30 23:10');
      final back = Scar.fromJson(s.toJson());
      expect(back!.site, s.site);
      expect(back.since, s.since);
    });

    test('认不出的部位返回 null，不会把整条存档搞崩', () {
      expect(Scar.fromJson({'site': '不存在的部位'}), isNull);
      expect(Scar.fromJson({}), isNull);
    });

    test('六个部位的 key 两两不同', () {
      final keys = kScarDefs.map((d) => d.key).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('key 能反查回定义，没有拼错的死引用', () {
      for (final d in kScarDefs) {
        expect(scarDefByKey(d.key)?.site, d.site, reason: '${d.key} 反查不到');
      }
    });
  });

  // ============================================================
  // 文案
  // ============================================================
  group('文案', () {
    test('prompt 段不写，AI 会把你当成一个完好的人', () {
      final block = scarPromptBlock([const Scar(site: ScarSite.leg, since: 'x')]);
      expect(block, contains('【身上的伤'));
      expect(block, contains('永远不会好'));
    });

    test('没有疤就不生成这一段，不留一段空标题', () {
      expect(scarPromptBlock(const []), isEmpty);
    });

    test('prompt 里写的是后遗症，不是数值', () {
      final block = scarPromptBlock(ScarSite.values.map((s) => Scar(site: s, since: 'x')));
      expect(block, isNot(contains('-3')));
      expect(block, isNot(contains('flying')));
    });

    test('通知用「留下了」，不用「受到了」——前者是结果，后者像战斗日志', () {
      final s = scarNoticeFor(kScarDefs.first);
      expect(s, startsWith('🩹'));
      expect(s, isNot(contains('受到')));
    });

    test('回望里那一句也读得懂', () {
      final s = scarEpilogueFor(kScarDefs.first);
      expect(s, contains('——'));
      expect(s, isNot(contains('penalty')));
    });

    test('每个部位的描述都不一样——套模板一眼就看出来', () {
      final texts = kScarDefs.map((d) => d.aftermath).toSet();
      expect(texts.length, kScarDefs.length);
    });
  });

  // ============================================================
  // 接线
  // ============================================================
  group('真的接进了游戏', () {
    final playerSrc = File('lib/models/player.dart').readAsStringSync();
    final responseSrc =
        File('lib/mixins/mixin_response.dart').readAsStringSync();
    final systemsSrc = File('lib/mixins/mixin_systems.dart').readAsStringSync();
    final narrativeSrc =
        File('lib/mixins/mixin_narrative.dart').readAsStringSync();

    test('Player 上有 scars 字段，而且会存盘', () {
      expect(playerSrc, contains('final List<Scar> scars;'));
      expect(playerSrc, contains("'scars': scars.map"));
    });

    test('老存档没有 scars 字段也能读进来', () {
      final i = playerSrc.indexOf("scars: (json['scars']");
      expect(i, greaterThan(-1));
      // 用了 ?? const [] 兜底，且认不出的部位会被 whereType 过滤掉
      expect(playerSrc.substring(i, i + 260), contains('?? const []'));
      expect(playerSrc.substring(i, i + 260), contains('whereType<Scar>'));
    });

    test('落疤挂在每回合的叙事副作用里——不是只在开局跑一次', () {
      final i = responseSrc.indexOf('void applyNarrativeSideEffects(');
      expect(i, greaterThan(-1));
      final body = responseSrc.substring(i, i + 800);
      expect(body, contains('tryScarFromNarrative'));
    });

    test('同一个部位不会重复落疤——它已经在那儿了', () {
      final i = responseSrc.indexOf('void tryScarFromNarrative(');
      expect(i, greaterThan(-1));
      final body = responseSrc.substring(i, i + 1200);
      expect(body, contains('p.scars.any((s) => s.site == def.site)) return;'));
    });

    test('落疤时记了长期记忆、弹了通知', () {
      final i = responseSrc.indexOf('void tryScarFromNarrative(');
      final body = responseSrc.substring(i, i + 1400);
      expect(body, contains('addKeyFact'), reason: '没有写长期记忆');
      expect(body, contains('notifications.add'), reason: '没有弹通知');
    });

    test('疤会进 prompt——不写的话 AI 会让你健步如飞', () {
      expect(narrativeSrc, contains('scarPromptBlock'));
      final i = narrativeSrc.indexOf('scarPromptBlock');
      final before = narrativeSrc.substring(i - 400, i);
      expect(before, contains('parts.add'));
    });

    test('读属性走 effectiveAttr，疤才不会在计算里消失', () {
      final i = systemsSrc.indexOf('int effectiveAttr(String key)');
      expect(i, greaterThan(-1));
      final body = systemsSrc.substring(i, i + 900);
      expect(body, contains('scarPenaltiesOf'), reason: '没有叠加上疤痕修正');
      expect(body, contains('clamp(0, 100)'), reason: '修正后没有夹回区间');
    });

    test('判定的那一处不再直接读 attributes', () {
      // _attr 曾经是 (player?.attributes[key]) ?? 50，
      // 那样身上有疤也当一个完好的人算
      final playSrc = File('lib/mixins/mixin_play.dart').readAsStringSync();
      expect(playSrc, contains('int _attr(String key) => effectiveAttr(key);'));
    });

    test('/伤痕 命令已注册——疤只在落下的瞬间弹过通知，得有地方回头看', () {
      final cmdSrc = File('lib/mixins/mixin_commands.dart').readAsStringSync();
      expect(cmdSrc, contains("primary: '伤痕'"));
      expect(cmdSrc, contains('formatScars()'));
    });

    test('轻伤会好，重伤不会——这是两套不同的东西', () {
      final i = systemsSrc.indexOf('轻伤会好');
      expect(i, greaterThan(-1));
      final body = systemsSrc.substring(i, i + 600);
      expect(body, contains('injuries.clear()'));
      // 清的是 injuries，不是 scars
      expect(body, isNot(contains('scars.clear')));
    });
  });
}
