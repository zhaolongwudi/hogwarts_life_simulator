/// 原著节点悬念的**开→关生命周期**运行时测试。
///
/// 【为什么需要这一层】`canon_offline_integration_test.dart` 已经覆盖了
/// 「节点沉淀物进长期记忆」的数据层校验与"至少有一条世界大事落库"，但
/// **悬念这条线只测到数据层**：
///   - 静态断言「开过的都能对上关节点」（`opened.difference(closed)` 为空）；
///   - 静态断言「关的节点都能对上开过的」（无悬空引用）。
///
/// 两条断言都是**表内的**——它们能证明 `canon_events.dart` 自己自洽，
/// 却证明不了 `_sinkCanonNodeToMemory` 的悬念分支在真实游玩里被走到过。
/// 悬念分支和世界大事分支在同一个函数里，但走的是两条独立的 `if`：
/// 世界大事有运行时测试（`fresh` 断言）兜着，悬念没有。
///
/// 【这道缝隙是怎么被发现的】第九次审查时统计 `canonEvents` 的接线密度，
/// 发现 4 条悬念（`loop_ps_vault` / `loop_ps_mirror` / `loop_cos_diary` /
/// `loop_gof_mark`）开了从未被关过——它们会一直挂在 T1「未完结事项」里，
/// 直到 `staleLoopsToDrop` 按超期静默丢弃：玩家看到一条永远没有下文的
/// 伏笔，而 AI 把它当成仍在推进的线索继续加码。
///
/// 修完之后必须补上运行时验证，否则同样的漏关还会再犯一次。
///
/// 【测什么】
///   1. 单条悬念的开→关：构造一个"先开、再关"的两节点序，断言 status 与
///      `closedAt` 都落到位、`openedAt` 不被覆盖；
///   2. 多值 `closeLoops`：一条节点同时收束多条线索（学年末一次回答好几个
///      问题），这是本次从单值改成列表后的核心新语义；
///   3. 幂等：同一节点重入两次，`closedAt` 不该被刷新成第二次的时间；
///   4. 关一条从来没开过的悬念：静默跳过，不崩。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/canon_events.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/long_term_memory.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

/// 把一条 `OpenLoopRecord` 灌进长期记忆（模拟某个更早的节点开的悬念）。
OpenLoopRecord loopOf(
  String id, {
  String status = 'open',
  String openedAt = '1991-07-31 08:00',
  String? closedAt,
}) =>
    OpenLoopRecord(
      id: id,
      description: '测试悬念：$id',
      status: status,
      importance: 7,
      openedAt: openedAt,
      closedAt: closedAt,
      loopType: 'question',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A · 原著节点的悬念能开也能关', () {
    test('节点声明的 openLoop 落进 T1，且状态是 open', () async {
      final gp = await makeGame(offlineQuickMode: true);

      // 直接广播一条真实声明了 openLoop 的节点。
      final node = canonEvents.firstWhere((e) => e.openLoop != null);
      final expectedId = node.openLoop!.split('|').first.trim();

      gp.sinkCanonNodeToMemoryForTest(node.id);

      final rec = gp.memory.openLoops.firstWhere((r) => r.id == expectedId);
      expect(rec.status, 'open');
      expect(rec.description.trim(), isNotEmpty,
          reason: '悬念描述不能是空串，否则 AI 只看到一个光秃秃的 id');
    });

    test('节点声明的 closeLoops 把先前开的悬念标成 done 并落 closedAt',
        () async {
      final gp = await makeGame(offlineQuickMode: true);

      // 找一个"关了某条悬念"的节点，手工先把那条悬念开出来。
      final closer = canonEvents.firstWhere((e) => e.closeLoops.isNotEmpty);
      final target = closer.closeLoops.first;

      gp.memory = gp.memory.addOrUpdateOpenLoop(loopOf(target));
      expect(
        gp.memory.openLoops.firstWhere((r) => r.id == target).status,
        'open',
      );

      gp.sinkCanonNodeToMemoryForTest(closer.id);

      final after = gp.memory.openLoops.firstWhere((r) => r.id == target);
      expect(after.status, 'done',
          reason: '「${closer.id}」声明了 closeLoops: $target，必须真的关掉');
      expect(after.closedAt, isNotNull,
          reason: '只有状态位没有时间戳的话，AI 分不清"什么时候水落石出的"');
      expect(after.openedAt, '1991-07-31 08:00',
          reason: '关闭不该把开启时间改掉——那是两条不同的时间线');
    });
  });

  group('B · 多值 closeLoops（本次新增的列表语义）', () {
    test('一条节点能同时收束多条悬念', () async {
      final gp = await makeGame(offlineQuickMode: true);

      final multi =
          canonEvents.firstWhere((e) => e.closeLoops.length > 1);
      expect(multi.closeLoops.length, greaterThan(1),
          reason: '七部曲里必须真有节点一次收束多条——'
              '否则列表语义等于白改，下次又会有人把它改回单值');

      for (final id in multi.closeLoops) {
        gp.memory = gp.memory.addOrUpdateOpenLoop(loopOf(id));
      }

      gp.sinkCanonNodeToMemoryForTest(multi.id);

      for (final id in multi.closeLoops) {
        final rec = gp.memory.openLoops.firstWhere((r) => r.id == id);
        expect(rec.status, 'done',
            reason: '「${multi.id}」的 closeLoops 里的「$id」没被关掉——'
                '列表只处理了第一条，剩下的会永远悬着');
      }
    });

    test('《魔法石》学年末同时关掉金库与魔镜两条悬念', () async {
      final gp = await makeGame(offlineQuickMode: true);

      // 这两条分别开于 7 月的古灵阁与 12 月的魔镜，都在学年末收束。
      for (final id in ['loop_ps_vault', 'loop_ps_mirror']) {
        gp.memory = gp.memory.addOrUpdateOpenLoop(loopOf(id));
      }

      gp.sinkCanonNodeToMemoryForTest('canon_ps_year_end');

      final vault = gp.memory.openLoops.firstWhere((r) => r.id == 'loop_ps_vault');
      final mirror =
          gp.memory.openLoops.firstWhere((r) => r.id == 'loop_ps_mirror');
      expect(vault.status, 'done',
          reason: '「713 号金库里是什么」的答案就是活板门之下的东西');
      expect(mirror.status, 'done',
          reason: '「那面镜子照见的是什么」同样在学年末由邓布利多解答');
    });
  });

  group('C · 幂等与容错', () {
    test('同一节点重入两次，closedAt 不被刷新', () async {
      final gp = await makeGame(offlineQuickMode: true);
      final closer = canonEvents.firstWhere((e) => e.closeLoops.isNotEmpty);
      final target = closer.closeLoops.first;

      gp.memory = gp.memory.addOrUpdateOpenLoop(loopOf(target));
      gp.sinkCanonNodeToMemoryForTest(closer.id);
      final first =
          gp.memory.openLoops.firstWhere((r) => r.id == target).closedAt;

      // 剧情模式可能重入同一步（读档、跳章开局）。
      gp.sinkCanonNodeToMemoryForTest(closer.id);
      final second =
          gp.memory.openLoops.firstWhere((r) => r.id == target).closedAt;

      expect(second, first,
          reason: '重入不该把关闭时间往后刷——'
              '那会让"这件事是什么时候水落石出的"随读档次数漂移');
    });

    test('关一条从来没开过的悬念：静默跳过，不崩', () async {
      final gp = await makeGame(offlineQuickMode: true);
      final closer = canonEvents.firstWhere((e) => e.closeLoops.isNotEmpty);

      expect(
        () => gp.sinkCanonNodeToMemoryForTest(closer.id),
        returnsNormally,
        reason: '悬念表为空时广播关节点不该抛异常——'
            '跳章开局会跳过开悬念的那些节点',
      );
      expect(
        gp.memory.openLoops.any((r) => closer.closeLoops.contains(r.id)),
        isFalse,
        reason: '没开过就不该凭空冒出一条 done 记录',
      );
    });

    test('广播不存在的节点 id：静默返回，不崩', () async {
      final gp = await makeGame(offlineQuickMode: true);
      expect(
        () => gp.sinkCanonNodeToMemoryForTest('canon_根本不存在的节点'),
        returnsNormally,
      );
    });
  });

  group('D · 离线红线', () {
    test('悬念沉淀全程零 AI 调用', () async {
      final gp = await makeGame(offlineQuickMode: true);
      for (final e in canonEvents.where((e) => e.openLoop != null)) {
        gp.sinkCanonNodeToMemoryForTest(e.id);
      }
      expect(gp.apiCalls, 0,
          reason: '长期记忆写入是纯本地操作，一次 AI 都不该碰');
    });
  });
}
