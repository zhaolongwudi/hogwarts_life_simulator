/// v5 批次38 年度节庆测试（P9 万圣节/圣诞/元旦/情人节/春季寻宝/学年舞会）。
///
/// 覆盖五件事：
///  - 数据完整性：id 唯一、日期合法、每节 ≥2 种庆祝方式、`$` 占位符可替换无残留；
///  - 日期匹配：festivalForDate 按 month*100+day 命中，非法日期返回 null；
///  - 每学年去重：同一天只庆祝一次，跨学年（改 academicYear）可再次庆祝；
///  - 奖励结算：庆祝必有正向收获（声望必涨）、状态记档、非节日日期返回空串；
///  - 离线回合接入：把世界时间拨到万圣节跑一回合，叙事里出现节庆、存档去重生效；
///  - 存档序列化：festivalCelebratedAt 读写往返一致；
///  - `/节庆` 日历：庆祝后有「已庆祝」标记、未到日期有「待庆祝」与下一个提示。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/data/festival_data.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/world_state.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameProvider> makeProvider() async => makeGame(offlineQuickMode: true);

  /// 把世界时钟拨到某天（年月日时分）。
  void setDate(GameProvider gp, int y, int m, int d) {
    final t = gp.worldState.time;
    t.year = y;
    t.month = m;
    t.day = d;
  }

  /// 声望总和（所有节庆效果至少涨一种声望，因此庆祝后必严格上升）。
  int repSum(GameProvider gp) {
    final r = gp.player!.playerReputation;
    var sum = 0;
    for (final dim in [
      'academic', 'social', 'combat', 'moral', 'leadership', 'dark',
    ]) {
      sum += r.get(dim);
    }
    return sum;
  }

  group('P9 · 数据完整性', () {
    test('id 唯一、日期合法、每节至少 2 种庆祝方式', () {
      final ids = kFestivals.map((f) => f.id).toSet();
      expect(ids.length, kFestivals.length, reason: '节日 id 必须全局唯一');
      for (final f in kFestivals) {
        expect(f.month, inInclusiveRange(1, 12));
        expect(f.day, inInclusiveRange(1, 31));
        expect(f.outcomes.length, greaterThanOrEqualTo(2),
            reason: '${f.name} 需要有至少 2 种庆祝方式');
        expect(f.intro, isNotEmpty);
        for (final o in f.outcomes) {
          expect(o.title, isNotEmpty);
          expect(o.text, isNotEmpty);
        }
        // 覆盖关键节点：万圣节与圣诞必在
        expect(festivalForDate(f.month, f.day)?.id, f.id);
      }
      expect(festivalForDate(10, 31)?.id, 'halloween');
      expect(festivalForDate(12, 24)?.id, 'christmas');
    });

    test('fillFestivalText 替换学院占位符后无美元符号残留', () {
      const house = '格兰芬多';
      for (final f in kFestivals) {
        final intro = fillFestivalText(f.intro, house: house);
        expect(intro, isNot(contains(r'$')));
        // 只有带占位符的 intro 才会被替换出学院名；没占位的原本就不含
        if (f.intro.contains(r'$house')) {
          expect(intro, contains(house));
        }
        for (final o in f.outcomes) {
          final txt = fillFestivalText(o.text, house: house);
          expect(txt, isNot(contains(r'$')));
        }
      }
    });

    test('Celebration outcome 效果字段合法', () {
      const validDims = {
        'academic', 'social', 'combat', 'moral', 'leadership', 'dark', null,
      };
      for (final f in kFestivals) {
        for (final o in f.outcomes) {
          expect(validDims, contains(o.effect.reputationDim),
              reason: '${o.title} 的声望维度非法：${o.effect.reputationDim}');
        }
      }
    });
  });

  group('P9 · 日期匹配与去重', () {
    test('非节日日期返回 null，节日日期命中', () {
      expect(festivalForDate(7, 31), isNull);
      expect(festivalForDate(2, 14)?.id, 'valentine');
      expect(festivalForDate(4, 6)?.id, 'spring_hunt');
      expect(festivalForDate(1, 1)?.id, 'newyear');
      expect(festivalForDate(6, 15)?.id, 'year_end_gala');
    });

    test('同一天只庆祝一次；跨学年可再次庆祝', () async {
      final gp = await makeProvider();
      final ay = gp.worldState.academicYear;
      setDate(gp, 1991, 10, 31);
      final first = gp.celebrateFestival(seed: 1);
      expect(first, isNotEmpty);
      expect(first, contains('万圣节之夜'));
      expect(gp.worldState.festivalCelebratedAt['halloween'], ay);
      // 同日再庆祝 → 已去重，返回空
      expect(gp.celebrateFestival(seed: 1), isEmpty);
      // 跨学年（下一学年）同一节日可再庆祝
      final nextYear = '${int.parse(ay.split('-')[0]) + 1}-${int.parse(ay.split('-')[1]) + 1}';
      gp.worldState.academicYear = nextYear;
      expect(gp.celebrateFestival(seed: 2), isNotEmpty);
      expect(gp.worldState.festivalCelebratedAt['halloween'], nextYear);
    });

    test('非节日日期庆祝返回空串', () async {
      final gp = await makeProvider();
      setDate(gp, 1991, 7, 31);
      expect(gp.celebrateFestival(seed: 0), isEmpty);
    });
  });

  group('P9 · 奖励结算', () {
    test('情人节庆祝必然有正向回报（声望严格上升）', () async {
      final gp = await makeProvider();
      setDate(gp, 1991, 2, 14);
      final before = repSum(gp);
      final block = gp.celebrateFestival(seed: 7);
      final after = repSum(gp);
      expect(block, isNotEmpty);
      expect(block, contains('情人节黄油啤酒'));
      expect(after, greaterThan(before),
          reason: '每种庆祝方式都至少带来正向声望，总声望应严格上升');
      expect(gp.worldState.festivalCelebratedAt['valentine'],
          gp.worldState.academicYear);
    });

    test('多次用不同 seed 可能得到不同庆祝方式（多样性）', () async {
      final gp = await makeProvider();
      setDate(gp, 1991, 10, 31);
      final titles = <String>{};
      for (var s = 0; s < 20; s++) {
        gp.worldState.festivalCelebratedAt.clear();
        final block = gp.celebrateFestival(seed: s);
        // 抽取「你选择了」那行里的方式名
        final m = RegExp(r'你选择了】(.*)\n').firstMatch(block);
        if (m != null) titles.add(m.group(1)!);
      }
      expect(titles.length, greaterThan(1),
          reason: '20 次采样应出现不止一种庆祝方式，叙事才有变化');
    });
  });

  group('P9 · 离线回合接入', () {
    test('把时间拨到万圣节跑一回合，叙事出现节庆且去重', () async {
      final gp = await makeProvider();
      setDate(gp, 1991, 10, 31);
      gp.worldState.academicYear = '1991-1992'; // 与 1991 年日期对应的学年
      await gp.processChoice(
        gp.choices.isNotEmpty
            ? gp.choices.first
            : const GameChoice(text: '四处看看', action: '四处看看'),
      );
      expect(gp.currentNarrative, contains('万圣节之夜'),
          reason: '离线回合应将节庆文块写进正文');
      expect(gp.worldState.festivalCelebratedAt['halloween'], '1991-1992');

      // 再跑一回合，同日已庆祝，不再重复触发
      await gp.processChoice(const GameChoice(text: '继续逛逛', action: '继续逛逛'));
      final already = '———————🕯️ 10月31日 · 万圣节之夜 🕯️———————';
      final count = _countOf(gp.currentNarrative, already);
      expect(count, 0,
          reason: '同一学年的万圣节不应在下一回合再次出现在叙事里');
    });
  });

  group('P9 · 存档序列化', () {
    test('festivalCelebratedAt 读写往返一致', () {
      final ws = WorldState(
        festivalCelebratedAt: const {'halloween': '1991-1992', 'christmas': '1991-1992'},
      );
      final restored = WorldState.fromJson(ws.toJson());
      expect(restored.festivalCelebratedAt, {
        'halloween': '1991-1992',
        'christmas': '1991-1992',
      });
    });

    test('旧存档无该字段时默认为空', () {
      final restored = WorldState.fromJson(const {});
      expect(restored.festivalCelebratedAt, isEmpty);
    });
  });

  group('P9 · /节庆 日历', () {
    test('庆祝后有「已庆祝」标记、未来节日有「待庆祝」与提示', () async {
      final gp = await makeProvider();
      setDate(gp, 1991, 10, 31);
      gp.celebrateFestival(seed: 0);
      final cal = gp.formatFestivalCalendar();
      expect(cal, contains('万圣节之夜'));
      expect(cal, contains('已庆祝'));
      expect(cal, contains('待庆祝'));
      expect(cal, contains('下一个节日'));
      expect(cal, contains('本学年已庆祝 1/${kFestivals.length}'));
    });

    test('无任何庆祝时显示 0 个已庆祝', () async {
      final gp = await makeProvider();
      final cal = gp.formatFestivalCalendar();
      expect(cal, contains('本学年已庆祝 0/${kFestivals.length}'));
    });
  });
}

/// 统计 [needle] 在 [haystack] 中出现的次数（避免换行/拼接误差的稳妥计数）。
int _countOf(String haystack, String needle) {
  var n = 0;
  var i = 0;
  while (true) {
    final idx = haystack.indexOf(needle, i);
    if (idx < 0) break;
    n++;
    i = idx + needle.length;
  }
  return n;
}