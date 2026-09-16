/// 第九次审查（游戏性审查）行为测试
///
/// 三条纪律（沿用第八轮）：
///  1. 注入参数与生产同侧（compressAffectionDelta 就是生产函数本身，不测复制品）；
///  2. 断言守性质而非定义式（分段映射只锁"层次存在、上限存在"，不锁每个中间值）；
///  3. 不锁死轮询/排序实现细节。
///
/// 覆盖本轮四项修复：
///  P0-1 好感压缩分段映射（数值钝化）
///  P0-2 好感维系衰减（集邮式社交）
///  P0-3 节拍器概率化（见 director_beat_test.dart，已同步改写）
///  P1   记忆关键词补漏 + 特质豁免条款
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/balance_constants.dart';
import 'package:hogwarts_life_simulator/models/long_term_memory.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';
import 'package:hogwarts_life_simulator/data/world_rules.dart';

void main() {
  // ------------------------------------------------------------ P0-1 分段压缩
  group('P0-1 好感压缩改分段映射', () {
    test('日常互动（≤5）原样保留，不被放大也不被缩小', () {
      for (var d = -5; d <= 5; d++) {
        expect(Balance.compressAffectionDelta(d), d);
      }
    });

    test('大事件与日常好意在落地值上拉开层次（修数值钝化）', () {
      // 旧公式下这两个都压成 +5——「救命之恩」和「顺手帮忙」无法区分
      final small = Balance.compressAffectionDelta(8);
      final big = Balance.compressAffectionDelta(20);
      expect(big - small, greaterThanOrEqualTo(2),
          reason: '救命(20) 与 帮忙(8) 的落地差距至少 2 点');
    });

    test('上限仍在：任何输入都不超过 ±10', () {
      for (final raw in [6, 11, 15, 20, 21, 30, 50, 100]) {
        expect(Balance.compressAffectionDelta(raw).abs(), lessThanOrEqualTo(10));
        expect(Balance.compressAffectionDelta(-raw), greaterThanOrEqualTo(-10));
      }
    });

    test('符号对称且单调不降：伤害与恩情同档同幅', () {
      for (var d = 1; d <= 40; d++) {
        expect(Balance.compressAffectionDelta(-d),
            -Balance.compressAffectionDelta(d));
        expect(Balance.compressAffectionDelta(d),
            greaterThanOrEqualTo(Balance.compressAffectionDelta(d - 1)));
      }
    });

    test('解析器真的换了新映射，旧的一刀切公式已移除', () {
      final src =
          File('lib/mixins/mixin_response_affection.dart').readAsStringSync();
      expect(src.contains('Balance.compressAffectionDelta'), isTrue);
      expect(src.contains('(delta * 0.5)'), isFalse, reason: '旧压缩公式应已删除');
      expect(src.contains('(delta * 0.7)'), isFalse, reason: '旧压缩公式应已删除');
    });

    test('结仇语义不变：rawDelta 仍走 severity 通道', () {
      final src =
          File('lib/mixins/mixin_response_affection.dart').readAsStringSync();
      expect(src.contains('final rawDelta = delta;'), isTrue);
      expect(src.contains('severity: rawDelta'), isTrue);
    });
  });

  // ------------------------------------------------------------ P0-2 维系衰减
  group('P0-2 好感维系衰减', () {
    test('NPC 的最后互动日字段可以存取往返（老存档兼容）', () {
      final npc = NPC(id: 't1', name: '测试')..lastAffectionTouchDay = 1234;
      final restored = NPC.fromJson(npc.toJson());
      expect(restored.lastAffectionTouchDay, 1234);

      // 老存档没有这个键：-1（豁免衰减），不能读成 0（=1991-01-01，等于催衰）
      final legacy = NPC.fromJson({'id': 't2', 'name': '老存档'});
      expect(legacy.lastAffectionTouchDay, -1);
    });

    test('衰减常量的性质：宽限期、速率、地板互相自洽', () {
      expect(Balance.affectionDriftIdleDays, greaterThanOrEqualTo(28),
          reason: '宽限期至少一个月，否则正常游戏节奏也会误伤');
      expect(Balance.affectionDriftPerWeekMin, greaterThanOrEqualTo(1));
      expect(
          Balance.affectionDriftPerWeekMax,
          greaterThanOrEqualTo(
              Balance.affectionDriftPerWeekMin));
      // 地板不能高于信任锁：否则衰减会把人推出"信任"段再弹回来，反复横跳
      expect(Balance.affectionDriftFloor,
          lessThan(Balance.trustLockThreshold));
      // 地板不能低于"好感"段下沿：衰减不该把人淡回陌生
      expect(Balance.affectionDriftFloor, greaterThanOrEqualTo(10));
    });

    test('衰减挂在周结算上，且快进时按跨过的周数结算', () {
      final src = File('lib/mixins/mixin_systems.dart').readAsStringSync();
      expect(src.contains('_applyAffectionDrift('), isTrue);
      expect(src.contains('weeksCrossed'), isTrue);
    });

    test('豁免清单齐全：信任锁、恋人、未登场、逝者、老存档', () {
      final src = File('lib/mixins/mixin_systems.dart').readAsStringSync();
      expect(src.contains("npc.hasLock('信任锁')"), isTrue);
      expect(src.contains('loveState.partnerId'), isTrue);
      expect(src.contains('!npc.isAlive || !npc.introduced'), isTrue);
      expect(src.contains('npc.lastAffectionTouchDay < 0'), isTrue);
    });

    test('互动落地时才刷新保鲜计时（被周上限挡掉的 +0 不算互动）', () {
      final src =
          File('lib/providers/game_provider.dart').readAsStringSync();
      expect(src.contains('npc.lastAffectionTouchDay = currentDay'), isTrue);
      // 必须判断 actualChange 而非 change：顶着上限硬刷不能保鲜
      expect(src.contains('if (actualChange != 0)'), isTrue);
    });

    test('世界规则 Prompt 已同步维系规则（AI 不会写出与机制矛盾的叙事）', () {
      expect(kWorldRulesFused.contains('不互动会自然转淡'), isTrue);
      expect(kWorldRulesFusedCompact.contains('不互动关系会自然转淡'), isTrue);
    });
  });

  // ------------------------------------------------------------ P1 记忆关键词
  group('P1 重要性打分补委婉表达', () {
    test('死亡的委婉说法不再漏判为日常流水', () {
      for (final fact in [
        '她在禁林的战斗里牺牲了',
        '他这一去就没能回来',
        '老校长在睡梦中离世',
        '他因病逝世于圣芒戈',
        '从此长眠于霍格莫德的山坡',
      ]) {
        expect(importanceForFact(fact), kPersistentFactImportance,
            reason: '「$fact」应是永不遗忘层');
      }
    });

    test('歧义词不被误收：日常离开不算死亡', () {
      // 这是不收"走了/离开"的原因：太容易被日常语境误触发
      expect(importanceForFact('他走出了教室'), lessThan(kPersistentFactImportance));
    });

    test('失踪/绑架/失忆/绝交属于不可逆剧变', () {
      for (final fact in ['他在假期失踪了', '她被黑巫师绑架', '他失忆了，再也认不出任何人', '他们彻底绝交了']) {
        expect(importanceForFact(fact), kPersistentFactImportance);
      }
    });

    test('日常流水仍是 5 分默认值', () {
      expect(importanceForFact('今天魔药课拿了优秀'), 5);
    });
  });

  // ------------------------------------------------------------ P1 特质豁免
  group('P1 传说特质与防崩坏规则对齐', () {
    test('完整版规则带豁免条款：既定事实 + 必须呈现代价', () {
      expect(kWorldRulesFused.contains('玩家开局特质'), isTrue);
      expect(kWorldRulesFused.contains('不得否定其存在'), isTrue);
      expect(kWorldRulesFused.contains('代价'), isTrue);
    });

    test('精简版规则同样带豁免（默认切换后不漏）', () {
      expect(kWorldRulesFusedCompact.contains('开局特质是既定事实'), isTrue);
    });

    test('防崩坏规则本体仍在（豁免不是放开）', () {
      expect(kWorldRulesFused.contains('禁止：开局自动稀有血统+能力'), isTrue);
    });
  });
}
