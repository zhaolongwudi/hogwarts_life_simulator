import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/canon_events.dart';
import 'package:hogwarts_life_simulator/data/cg_data.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/providers/game_provider_base.dart';

import 'helpers/test_fixtures.dart';

/// 离线模式接入原著剧情线的**集成**测试。
///
/// `canon_events_test.dart` 测的是数据表与纯函数的语义；本文件测的是
/// "接线是否真的通"——即 `_runOfflineQuickTurn` 走完之后，
/// `worldState.firedAnchorIds` 里是否真的多了 `canon_` 条目、
/// 叙事里是否真的出现了节点标题。
///
/// 【为什么必须有这一层】`lib/data/canon_events.dart` 写得再对，
/// 只要 `_injectCanonEventIntoOfflineNarrative()` 没被调用（或调用时机
/// 在 `_finalizeTurn` 之前、拿到的是上一回合的年份），数据表就是个死文件。
/// 上一轮的"配置字段与判定函数断链"缺陷正是这种形态——有数据、有函数、
/// 就是没连线。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 本文件后半段要跑**剧情模式**（`enterStoryMode`），而书表是靠这个函数
  // 注入 `kStoryBooks` 的注册表——漏了它 `enterStoryMode` 会静默失败。
  setUpAll(registerAllStoryBooks);

  group('离线回合会注入原著剧情线', () {
    test('新开局（1991-07 子世代）跑一回合，应触发古灵阁闯入节点', () async {
      final gp = await makeGame(offlineQuickMode: true);

      // 前置条件：默认开局是「收到通知书」那一刻，即 1991-07-31。
      // 这个月恰好有《魔法石》的「古灵阁被闯入」——原著里海格就是
      // 在带哈利去对角巷那天取走了金库里的东西。
      expect(gp.worldState.era, 'harry_same');
      expect(gp.worldState.time.year, 1991);
      expect(gp.worldState.time.month, 7);

      await gp.processChoice(
        gp.choices.isNotEmpty
            ? gp.choices.first
            : const GameChoice(text: '四处看看', action: '四处看看'),
      );

      final canonFired =
          gp.worldState.firedAnchorIds.where(isCanonEventId).toList();
      expect(canonFired, isNotEmpty,
          reason: '离线回合结束后应至少注入一条原著节点');
      expect(canonFired, contains('canon_ps_gringotts'));
    });

    test('注入后叙事正文包含节点标题，玩家能看到而不只是进通知栏', () async {
      final gp = await makeGame(offlineQuickMode: true);
      await gp.processChoice(
        gp.choices.isNotEmpty
            ? gp.choices.first
            : const GameChoice(text: '四处看看', action: '四处看看'),
      );

      final fired = gp.worldState.firedAnchorIds
          .where(isCanonEventId)
          .toList();
      if (fired.isEmpty) {
        // 该组合下本月无节点，跳过（另一条测试已保证有节点的月份能触发）
        return;
      }
      final event = canonEvents.firstWhere((e) => e.id == fired.first);
      expect(gp.currentNarrative, contains(event.title),
          reason: '节点标题必须写进正文，否则玩家只能从通知栏看到一行字');
    });

    test('同一节点不会被重复注入（复用 firedAnchorIds 去重）', () async {
      final gp = await makeGame(offlineQuickMode: true);
      await gp.processChoice(
        gp.choices.isNotEmpty
            ? gp.choices.first
            : const GameChoice(text: '四处看看', action: '四处看看'),
      );
      final afterFirst =
          gp.worldState.firedAnchorIds.where(isCanonEventId).toSet();
      expect(afterFirst.length, afterFirst.toSet().length,
          reason: 'firedAnchorIds 不应出现重复的原著节点 id');

      // 再跑一回合，已触发的节点不能重来
      await gp.processChoice(
        gp.choices.isNotEmpty
            ? gp.choices.first
            : const GameChoice(text: '四处看看', action: '四处看看'),
      );
      final afterSecond =
          gp.worldState.firedAnchorIds.where(isCanonEventId).toList();
      expect(afterSecond.toSet().length, afterSecond.length,
          reason: '两个回合后仍不允许出现重复 id');
    });
  });

  group('原著事件感知选项', () {
    test('触发节点后，兜底选项会针对该事件给出「追信息」类动作', () async {
      final gp = await makeGame(offlineQuickMode: true);
      await gp.processChoice(
        gp.choices.isNotEmpty
            ? gp.choices.first
            : const GameChoice(text: '四处看看', action: '四处看看'),
      );

      final fired =
          gp.worldState.firedAnchorIds.where(isCanonEventId).toList();
      expect(fired, isNotEmpty, reason: '前置条件：本月必须有节点被触发');

      final event = canonEvents.firstWhere((e) => e.id == fired.first);
      final topic = GameProviderBase.canonTopicFromTitle(event.title);

      // 兜底选项走的是 buildFallbackChoices（离线/AI 失败路径共用）
      final forced = gp.buildFallbackChoices(gp.currentNarrative);
      expect(forced.length, 4, reason: '兜底选项恒为 4 条');

      final joined = forced.map((c) => '${c.text}|${c.action}').join('\n');
      expect(joined, contains(topic),
          reason: '刚发生的「$topic」应该出现在至少一个可选项里，'
              '否则玩家只能读到旁白、无法对时代背景做出反应');
    });

    test('canonTopicFromTitle 剥掉结构后缀，不产生叠字病句', () {
      // 真实标题形态（取自 canon_events.dart 全表实测）
      expect(GameProviderBase.canonTopicFromTitle('古灵阁被闯入'), '古灵阁');
      expect(GameProviderBase.canonTopicFromTitle('密室被打开了'), '密室');
      expect(GameProviderBase.canonTopicFromTitle('阿兹卡班越狱事件'), '阿兹卡班');
      expect(GameProviderBase.canonTopicFromTitle('天文塔之夜'), '天文塔');
      expect(GameProviderBase.canonTopicFromTitle('石化事件'), '石化');
      // 「X的传闻」要连读剥掉，不能留下光秃秃的「的」
      expect(GameProviderBase.canonTopicFromTitle('厄里斯魔镜的传闻'), '厄里斯魔镜');
      expect(GameProviderBase.canonTopicFromTitle('日记本的传闻'), '日记本');
      // 描述句没有结构后缀，应原样返回（强行剥离会破坏语义）
      expect(
        GameProviderBase.canonTopicFromTitle('最后一个学期·风声鹤唳'),
        '最后一个学期·风声鹤唳',
      );
      // 过短时不做剥离，避免剥成空串
      expect(GameProviderBase.canonTopicFromTitle('案'), '案');
      // 开头情态词要去掉，避免「传闻…」+「去打听」语义重复
      expect(GameProviderBase.canonTopicFromTitle('传闻三强争霸赛'), '三强争霸赛');
    });

    test('所有节点的标题经剥后缀后都不为空，且不残留虚词尾巴', () {
      const badTails = ['的', '被', '与', '和', '-', '·'];
      for (final e in canonEvents) {
        final topic = GameProviderBase.canonTopicFromTitle(e.title);
        expect(topic.trim(), isNotEmpty, reason: '「${e.id}」剥后缀后为空');
        for (final tail in badTails) {
          expect(topic.endsWith(tail), isFalse,
              reason: '「${e.id}」的标题「${e.title}」剥成了「$topic」，'
                  '残留虚词尾巴「$tail」——拼进选项会读成「打听…$topic」的病句');
        }
      }
    });
  });

  // ================================================================
  // 原著节点 → 长期记忆 / 图鉴的沉淀
  // ================================================================
  //
  // 【为什么单独一组】接线之前在剧情模式里走完《魔法石》全书，
  // `memory.worldEvents` 里**一条原著事件都没有**——故事讲了几十步，
  // 长期记忆只多了几条 knowledge 转来的 T0 事实。原因是原著节点的
  // 沉淀物（worldEvent / openLoop / unlockCg）当时根本不存在，
  // `_markCanonForStep` 只往 `firedAnchorIds` 记一个 id 就结束了。
  group('原著节点沉淀进长期记忆与图鉴', () {
    test('数据层：至少 30 个节点声明了沉淀物，且都是合法字段', () {
      final enriched =
          canonEvents.where((e) => e.worldEvent != null).toList();
      expect(
        enriched.length,
        greaterThanOrEqualTo(30),
        reason: '七部曲主线必须够多节点进长期记忆，否则长局依然毫无沉淀',
      );
      for (final e in enriched) {
        expect(
          e.worldEvent!.trim(),
          isNotEmpty,
          reason: '「${e.id}」的 worldEvent 不能是空白串',
        );
        expect(
          e.worldEventImportance,
          inInclusiveRange(1, 10),
          reason: '「${e.id}」的 importance 越界',
        );
      }
    });

    test('数据层：openLoop 的格式是 id|描述，且 closeLoop 都能对上', () {
      final opened = <String>{};
      for (final e in canonEvents) {
        final loop = e.openLoop;
        if (loop == null) continue;
        final sep = loop.indexOf('|');
        expect(sep, greaterThan(0),
            reason: '「${e.id}」的 openLoop 缺 `id|描述` 分隔符：$loop');
        expect(sep, lessThan(loop.length - 1),
            reason: '「${e.id}」的 openLoop 有 id 但没描述：$loop');
        opened.add(loop.substring(0, sep));
      }
      expect(opened, isNotEmpty, reason: '至少要有一条悬念，否则 T1 层永远空转');

      for (final e in canonEvents) {
        for (final close in e.closeLoops) {
          expect(
            opened.contains(close),
            isTrue,
            reason: '「${e.id}」要关的悬念「$close」没有任何节点开过——'
                '这是内容层的悬空引用，点了也没反应',
          );
        }
      }
    });

    test('每一条开过的悬念最终都有着落（不留永悬不决的伏笔）', () {
      // 【为什么必须有这条】悬念开了不关，会一直挂在 T1「未完结事项」里，
      // 直到 `staleLoopsToDrop` 按超期静默丢弃。玩家看到的是"一条永远没有
      // 下文的线索"，而 AI 会把它当成仍在推进的伏笔继续加码。
      // 第一版内容铺完时有 4 条悬念处于这个状态（第九次审查 P1）。
      //
      // 允许例外：跨部续接的悬念——如 `loop_ootp_ministry` 在《凤凰社》
      // 末了结，而其影响延续到《混血王子》。这类"关掉但留有余波"由
      // worldEvent 承载，不算漏关。真正的漏关是"到全书结束都没关过"。
      final opened = <String>{};
      final closed = <String>{};
      for (final e in canonEvents) {
        final open = e.openLoop;
        if (open != null && open.contains('|')) {
          opened.add(open.substring(0, open.indexOf('|')).trim());
        }
        closed.addAll(e.closeLoops);
      }

      final dangling = opened.difference(closed);
      expect(
        dangling,
        isEmpty,
        reason: '以下悬念开了却从未有过关节点——玩家会看到没有下文的伏笔：'
            '$dangling',
      );
    });

    test('数据层：unlockCg 引用的 CG 都在图鉴表里', () {
      for (final e in canonEvents) {
        final cg = e.unlockCg;
        if (cg == null) continue;
        expect(
          cgById(cg),
          isNotNull,
          reason: '「${e.id}」引用了不存在的 CG「$cg」',
        );
      }
    });

    test('数据层：每一部书都要有悬念，不能有整部空白的书', () {
      // 【为什么钉住"按书分布"而不是只看总数】总量达标很容易掩盖结构性
      // 空白：《死亡圣器》15 个节点一度一条悬念都没有，而它恰恰是七部里
      // 局势最紧、最需要"悬而未决"感的一部。只看总数的话，前六部铺得够
      // 多就能把这一部的空白压下去。
      const bookRefs = [
        '魔法石',
        '密室',
        '阿兹卡班的囚徒',
        '火焰杯',
        '凤凰社',
        '混血王子',
        '死亡圣器',
      ];
      final perBook = <String, int>{};
      for (final e in canonEvents) {
        if (e.openLoop == null) continue;
        perBook[e.bookRef] = (perBook[e.bookRef] ?? 0) + 1;
      }

      for (final book in bookRefs) {
        expect(
          perBook[book] ?? 0,
          greaterThanOrEqualTo(2),
          reason: '《$book》只有 ${perBook[book] ?? 0} 条悬念——'
              '整部书推进过程中没有可牵挂的问题，玩家只是在读流水账',
        );
      }

      // 总量护栏：七部曲合计至少 18 条，防止有人一次删掉一批。
      final total = perBook.values.fold<int>(0, (a, b) => a + b);
      expect(total, greaterThanOrEqualTo(18),
          reason: '悬念总量掉到 $total 条，长期记忆 T1 层基本空转（按书 $perBook）');
    });

    test('剧情模式走一步：原著节点真的落进 worldEvents', () async {
      final gp = await makeGame(offlineQuickMode: true);
      gp.openingScene = 'letter';
      gp.enterStoryMode();

      // 【为什么必须断言起始游标】不注册书表时 `enterStoryMode` 会静默失败
      // （`stepId` 为空串），后续所有 `processChoice` 都在空转，
      // 测试会以"没有沉淀"的形态误报——实际原因跟沉淀逻辑毫无关系。
      // 先钉住前置条件，失败时能一眼看出去哪了。
      expect(
        gp.storyProgress.stepId,
        isNotEmpty,
        reason: '剧情游标必须有值——为空说明书表没注册（setUpAll 漏了）',
      );

      final before = gp.memory.worldEvents.length;

      // 一路点第一个选项，跑若干步直到至少有一条 canon 事件沉淀。
      // 12 步足够走到第二章的「古灵阁」（`ps_ch2_bank`）。
      var guard = 0;
      while (gp.memory.worldEvents.length == before && guard < 40) {
        guard++;
        if (gp.choices.isEmpty) break;
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }

      final fresh = gp.memory.worldEvents
          .where((w) => w.id.startsWith('canon_'))
          .toList();
      expect(
        fresh,
        isNotEmpty,
        reason: '跑完 $guard 步之后至少要有一条原著事件进世界大事层',
      );
      expect(
        fresh.first.description.trim(),
        isNotEmpty,
        reason: '世界大事的描述不能为空——它是注入给叙事的客观事实',
      );
      expect(
        fresh.first.importance,
        inInclusiveRange(1, 10),
        reason: '沉淀的世界大事重要度必须合法',
      );
    });

    test('剧情模式的沉淀不消耗 AI（离线红线仍然成立）', () async {
      final gp = await makeGame(offlineQuickMode: true);
      gp.openingScene = 'letter';
      gp.enterStoryMode();

      for (var i = 0; i < 10 && gp.choices.isNotEmpty; i++) {
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }
      expect(gp.apiCalls, 0, reason: '沉淀是纯本地写入，不能碰 AI');
    });
  });
}
