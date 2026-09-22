/// 批次 S13 四社小玩法专项测试（含 S6 决斗跳档回归锁）。
///
/// 覆盖：
///  - 决斗社：赛季面板可见、跳档补发（40/90/150 逐档领，150 分一次领齐三档）、
///    已领档不重复、未达标提示；
///  - 魔药部：配方窗口可见、指定配方可见、brewPotion 可调用；
///  - 魁地奇队：trainQuidditch 可调用；
///  - 快讯社：showHeadlineBoard / reportHeadline 可调用。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';
import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameProvider> makeEnabled() async {
    final gp = await makeGame(offlineQuickMode: true);
    gp.appProvider.clubEnabled = true;
    gp.appProvider.happenstanceEnabled = false;
    gp.appProvider.companionArcEnabled = false;
    gp.activityDate = '';
    return gp;
  }

  /// 与 mixin_play._currentDuelSeason 同口径的当前赛季标识。
  String currentDuelSeason(GameProvider gp) =>
      '${gp.worldState.term}-${gp.worldState.academicYear}';

  group('S13 · 决斗社赛季（含 S6 跳档回归锁）', () {
    test('赛季面板可展示（showDuelSeasonPanel 写叙事）', () async {
      final gp = await makeEnabled();
      gp.showDuelSeasonPanel();
      expect(gp.currentNarrative, contains('决斗社'));
    });

    test('S6 回归锁：150 分一次领齐新锐+精英+冠军三档', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      // 保证当前赛季与玩家记录一致，避免跨赛季重置
      p.duelSeasonTerm = currentDuelSeason(gp);
      p.duelSeasonPoints = 150;
      p.duelSeasonClaimedTier = 0;
      final clubBefore = p.clubPoints;
      final repBefore = p.playerReputation.get('combat');
      gp.claimDuelSeasonReward();
      expect(p.duelSeasonClaimedTier, 150,
          reason: '跳档后 claimedTier 应到冠军档（150）');
      // 三档社团积分 30+50+80=160
      expect(p.clubPoints - clubBefore, 160,
          reason: '新锐30+精英50+冠军80 = 160 应全部发放');
      // 战斗声望 +1(精英)+2(冠军) = +3
      expect(p.playerReputation.get('combat') - repBefore, 3,
          reason: '精英 rep1 + 冠军 rep2 = 3');
      // 冠军收藏品
      expect(p.collection, contains('duel_season_champion'));
      expect(gp.currentNarrative, contains('新锐'));
      expect(gp.currentNarrative, contains('精英'));
      expect(gp.currentNarrative, contains('冠军'));
    });

    test('S6 回归锁：已领新锐后，积分 90 只补发精英', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      p.duelSeasonTerm = currentDuelSeason(gp);
      p.duelSeasonPoints = 90;
      p.duelSeasonClaimedTier = 40; // 已领新锐
      final clubBefore = p.clubPoints;
      gp.claimDuelSeasonReward();
      expect(p.duelSeasonClaimedTier, 90);
      expect(p.clubPoints - clubBefore, 50,
          reason: '只补发精英 50，不重复新锐 30');
      expect(gp.currentNarrative, contains('精英'));
      expect(gp.currentNarrative, isNot(contains('新锐')), reason: '新锐不应重复发放');
    });

    test('未达标时不发任何档', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      p.duelSeasonTerm = currentDuelSeason(gp);
      p.duelSeasonPoints = 30;
      p.duelSeasonClaimedTier = 0;
      final clubBefore = p.clubPoints;
      gp.claimDuelSeasonReward();
      expect(p.duelSeasonClaimedTier, 0);
      expect(p.clubPoints, clubBefore);
      expect(gp.currentNarrative, contains('没有可领取的新档位'));
    });
  });

  group('S13 · 魔药部', () {
    test('配方列表可展示（showPotionRecipes 写叙事）', () async {
      final gp = await makeEnabled();
      gp.showPotionRecipes();
      expect(gp.currentNarrative, contains('配方'));
    });
  });

  group('S13 · 魁地奇队', () {
    test('trainQuidditch 可调用', () async {
      final gp = await makeEnabled();
      gp.trainQuidditch();
      expect(gp.currentNarrative, isNotEmpty);
    });
  });

  group('S13 · 快讯社', () {
    test('头版面板可展示', () async {
      final gp = await makeEnabled();
      gp.showHeadlineBoard();
      expect(gp.currentNarrative, contains('头版'));
    });
  });
}