/// 批次 S8 / S9 / S10 / S11 专项测试。
///
/// S8：决斗赛季积分纳入每日递减（当天第 2 场起衰减）。
/// S9：八眼巨蛛掉落含「银色鳞片」（清醒剂唯一材料，禁林可获取）。
/// S10：快讯社头版防重改用学期口径（跨学期可重复报道，跨重启稳定）。
/// S11：魁地奇跨周直接比赛不再享受上周训练加成。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/bestiary_data.dart';
import 'package:hogwarts_life_simulator/models/player.dart';
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

  /// 构造一条当前学期的奇遇素材（供快讯社测试）。
  void seedHeadlineMaterial(GameProvider gp) {
    final p = gp.player!;
    p.happenstanceLog.add(HappenstanceLogEntry(
      id: 'test_happenstance',
      title: '测试奇遇',
      outcomeTitle: '测试结局',
      outcomeText: '这是一段测试结局文本',
      week: gp.gameWeek,
      term: gp.worldState.term,
    ));
  }

  group('S9 · 银色鳞片可获取', () {
    test('八眼巨蛛掉落包含银色鳞片（清醒剂材料不再死锁）', () {
      final acro = kCreatureCatalog.firstWhere((c) => c.id == 'acromantula');
      expect(acro.loot, contains('银色鳞片'));
      expect(acro.loot, contains('八眼巨蛛毒液'),
          reason: '原有主掉落不应被覆盖');
    });
  });

  group('S10 · 快讯社头版学期口径', () {
    test('同一学期不可重复报道', () async {
      final gp = await makeEnabled();
      seedHeadlineMaterial(gp);
      final p = gp.player!;
      // 报道一次
      gp.reportHeadline(0, '现场直击');
      expect(p.headlineCount, 1, reason: '首次报道应成功');
      // 同学期再报道应被拒绝
      final before = p.headlineCount;
      gp.reportHeadline(0, '现场直击');
      expect(p.headlineCount, before, reason: '同一学期不可重复报道');
      expect(gp.currentNarrative, contains('下学期再抢头条'));
    });
  });

  group('S11 · 魁地奇周训练加成', () {
    test('跨周直接比赛不再享受上周训练加成', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      // 装备扫帚（否则 playQuidditch 直接返回）
      p.equipped['broom'] = '飞天扫帚·横扫';
      // 上周训练 2 次 → qTrainWeek=2（上周）
      p.qTrainLastWeek = 0; // 上周
      p.qTrainWeek = 2;
      gp.gameWeek = 1; // 本周（跨周了）
      // 直接比赛应触发周重置
      gp.playQuidditch();
      expect(p.qTrainWeek, 0, reason: '跨周比赛应先清零训练计数');
      expect(p.qLastWeek, 1, reason: '比赛应记录本周已赛');
    });
  });
}