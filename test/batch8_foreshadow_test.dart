/// Batch 8 · Issue #15：foreshadow 实体一致性放行通道。
///
/// 纯 bigram 重合度匹配有两类盲区：
///   1. **漏关**——措辞差异大的同一件事（"小天狼星·布莱克把旧书托付给主角"
///       → "主角把旧书还给了小天狼星·布莱克"），bigram 覆盖不足被误杀；
///   2. **误关的孪生问题**——实体名不一致时比例被稀释。
///
/// 本批在 isSameLoop 加一条**实体 token 双命中放行通道**：两段文本同时命中
/// ≥ 2 个实体（NPC 全名/别名 + 物品名）即放行，与 bigram 分数解耦。
/// 双命中门槛保证只撞一个人名不会放行（"西弗勒斯·斯内普的信" vs
/// "西弗勒斯·斯内普的坩埚"）。
///
/// 覆盖：
///  - sharedEntityTokens 基础行为（命中/未命中/黑名单）；
///  - isSameLoop 实体双命中放行（用 minShared: 99 关掉 bigram 通道，专测实体）；
///  - isSameLoop 单实体命中不放行（避免误关）；
///  - minEntityShared 门槛可调（收紧）；
///  - 默认参数下既有回归不受影响（bigram 通道照常工作）。
library;
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
  // sharedEntityTokens
  // ============================================================
  group('sharedEntityTokens', () {
    test('同一文本命中同一实体（全名/别名字串匹配）', () {
      expect(
        sharedEntityTokens('西弗勒斯·斯内普答应了保密',
            '西弗勒斯·斯内普保守了秘密'),
        contains('西弗勒斯·斯内普'),
      );
    });
    test('无交集返回空', () {
      expect(sharedEntityTokens('魁地奇决赛', '魔药课考试'), isEmpty);
    });
    test('物品名也算实体', () {
      expect(
        sharedEntityTokens('小天狼星·布莱克把旧书留给主角',
            '主角带着那本旧书去了禁林'),
        contains('旧书'),
      );
    });
    test('通用称谓不在实体集里（不会误放行）', () {
      expect(sharedEntityTokens('教授来了', '教授走了'), isEmpty);
    });
  });

  // ============================================================
  // isSameLoop 实体放行通道（minShared: 99 强制 bigram 通道关闭，
  // 从而单独验证实体通道）
  // ============================================================
  group('isSameLoop 实体放行通道', () {
    test('实体双命中放行：NPC+物品同时对上', () {
      expect(
        isSameLoop(
          '小天狼星·布莱克把旧书托付给主角保管',
          '主角把旧书还给了小天狼星·布莱克，了却一桩心事',
          minShared: 99,
        ),
        isTrue,
      );
    });
    test('实体双命中放行：两个 NPC 同时对上', () {
      expect(
        isSameLoop(
          '阿不思·邓布利多和米勒娃·麦格商量了一件事',
          '米勒娃·麦格拜访了阿不思·邓布利多',
          minShared: 99,
        ),
        isTrue,
      );
    });
    test('单实体命中不放行（避免把两件事误关成一件）', () {
      expect(
        isSameLoop(
          '西弗勒斯·斯内普去了魔药教室',
          '西弗勒斯·斯内普给格兰芬多扣了分',
          minShared: 99,
        ),
        isFalse,
      );
    });
    test('minEntityShared 可调高（收紧放行门槛）', () {
      expect(
        isSameLoop(
          '小天狼星·布莱克把旧书托付给主角保管',
          '主角把旧书还给了小天狼星·布莱克，了却一桩心事',
          minShared: 99,
          minEntityShared: 3,
        ),
        isFalse,
      );
    });
  });

  // ============================================================
  // 默认参数回归：bigram 通道照常工作，实体通道不误伤
  // ============================================================
  group('默认参数回归', () {
    test('原有 bigram 高分场景仍为 true', () {
      expect(
        isSameLoop('斯内普答应给主角保密身份', '斯内普答应给主角保密身份'),
        isTrue,
      );
    });
    test('措辞差太远的仍为 false（原有设计取向：宁可漏关）', () {
      // 只共享「小天狼星」相关字但 b 里没有完整实体名，bigram 也不够
      expect(
        isSameLoop('小天狼星·布莱克留了一把钥匙给主角',
            '那把钥匙打开了尖叫棚屋的门'),
        isFalse,
      );
    });
  });

  // ============================================================
  // pickLoopToClose 行为
  // ============================================================
  group('pickLoopToClose', () {
    test('实体双命中能匹配伏笔', () {
      final m = pickLoopToClose(
        '主角把旧书还给了小天狼星·布莱克，了却一桩心事',
        [loop('小天狼星·布莱克把旧书托付给主角保管', openedTurn: 5)],
        currentTurn: 9,
      );
      expect(m, isNotNull);
      expect(m!.loop.description, '小天狼星·布莱克把旧书托付给主角保管');
    });
    test('单实体命中 + bigram 不够时返回 null', () {
      final m = pickLoopToClose(
        '那把钥匙打开了尖叫棚屋的门',
        [loop('小天狼星·布莱克留了一把钥匙给主角', openedTurn: 5)],
        currentTurn: 9,
      );
      expect(m, isNull);
    });
    test('已了结（status != open）的伏笔不被重复关闭', () {
      final m = pickLoopToClose(
        '主角把旧书还给了小天狼星·布莱克，了却一桩心事',
        [loop('小天狼星·布莱克把旧书托付给主角保管',
            openedTurn: 5, status: 'done')],
        currentTurn: 9,
      );
      expect(m, isNull);
    });
  });
}