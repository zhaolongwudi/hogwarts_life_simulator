import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/canon_events.dart';
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
}
