/// 剧情模式 × 原著旁白注入的去重测试（批次 5）。
///
/// 【防什么】同一个原著事件被讲两遍：
///   - 剧情文本讲一遍（`StoryStepDef.canonRefId` 声明的步，有情境有分支）；
///   - 沙盒的旁白系统又贴一遍 📖 块（`_injectCanonEventIntoOfflineNarrative`）。
/// 白名单规则：剧情模式下，**当前步声明讲述的节点**跳过旁白注入
/// （firedAnchorIds 照写，节点视为已消费）。
///
/// 【测试口径】直接调用 `injectCanonEventForTest()`（批次 2 留的单测入口），
/// 不跑完整回合——要验证的是注入函数自身的白名单判断，不是回合分发。
/// 时间/时代用 makeGame 的默认开局（letter = 1991-07，era = harry_same），
/// 正好命中 `canon_ps_gringotts`（1991 年 7 月，古灵阁被闯入）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllStoryBooks);

  /// 清掉 canon_ 项，让 dueCanonEvents 能重新命中（测试自备时间窗）。
  void resetCanonFired(GameProvider gp) {
    gp.worldState.firedAnchorIds.removeWhere((id) => id.startsWith('canon_'));
  }

  group('A · 白名单抑制（当前步声明讲述的节点不贴旁白块）', () {
    test('剧情模式 + 当前步 canonRefId 命中 → 不贴 📖，但 firedAnchorIds 照写', () async {
      final gp = await makeGame(offlineQuickMode: true);
      gp.enterStoryMode();

      // 把游标手动定位到"声明讲述古灵阁节点"的那一步
      // （开局时间是 7 月 31 日，正好落在 canon_ps_gringotts 的月份窗内）
      gp.storyProgress = gp.storyProgress.copyWith(
        chapterId: 'ps_ch2',
        stepId: 'ps_ch2_bank',
      );
      resetCanonFired(gp);
      expect(gp.worldState.firedAnchorIds, isNot(contains('canon_ps_gringotts')));

      gp.injectCanonEventForTest();

      // 【断言口径】不用裸的 📖——叙事的其他部件（事件锚点/氛围句）
      // 也可能带这个 emoji。注入块的可靠特征是节点标题与 directive
      // 里的关键词，它们不会出现在开局首屏文本里。
      expect(
        gp.currentNarrative.contains('古灵阁被闯入'),
        isFalse,
        reason: '节点已由剧情步声明讲述，旁白块的标题不应出现',
      );
      expect(
        gp.currentNarrative.contains('预言家日报'),
        isFalse,
        reason: '旁白块的 directive 不应出现',
      );
      expect(
        gp.worldState.firedAnchorIds,
        contains('canon_ps_gringotts'),
        reason: '跳过注入不等于没消费——节点必须标记为已触发，'
            '防止别的路径再讲一遍',
      );
    });
  });

  group('B · 白名单不误伤（没声明讲述的节点照常注入）', () {
    test('剧情模式 + 当前步无 canonRefId → 旁白块正常出现', () async {
      final gp = await makeGame(offlineQuickMode: true);
      gp.enterStoryMode();
      // 开局游标 = ps_ch1_letter（无 canonRefId）——收信不在原著节点表里
      expect(gp.storyProgress.stepId, 'ps_ch1_letter');
      resetCanonFired(gp);

      gp.injectCanonEventForTest();

      expect(
        gp.currentNarrative.contains('古灵阁被闯入'),
        isTrue,
        reason: '当前步没声明讲述任何节点，旁白系统应照常注入这条节点',
      );
    });
  });

  group('C · 沙盒模式回归（白名单不得影响既有注入）', () {
    test('非剧情模式 → 旁白注入与从前一致', () async {
      final gp = await makeGame(offlineQuickMode: true);
      // 不进剧情模式——storyProgress 保持 inactive
      expect(gp.storyProgress.active, isFalse);
      resetCanonFired(gp);

      gp.injectCanonEventForTest();

      expect(
        gp.currentNarrative.contains('古灵阁被闯入'),
        isTrue,
        reason: '沙盒模式的原著旁白注入不能被剧情白名单误伤',
      );
      expect(
        gp.worldState.firedAnchorIds.any((id) => id.startsWith('canon_')),
        isTrue,
      );
    });
  });
}
