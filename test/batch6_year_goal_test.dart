/// Batch 6 · Issue #8：selectYearGoal 加权随机 + 排除近期已用 + 关联主线。
///
/// 覆盖：
///  - 数据完整性：yearGoalPool 每个目标都有 careerAffinity 且权重 > 0；
///  - 主线牵引：给定主线目标时，亲和度高的目标被抽中的概率显著高于无亲和度目标；
///  - 排除近期：recentGoalIds 中的 id 不会被抽中；
///  - 兜底：recentGoalIds 覆盖全池时回退到全池（不抛异常）；
///  - 可复现：同一 seed 结果一致；
///  - Player 存档：recentYearGoalIds 字段往返一致 + 旧档缺省回退空列表。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/goal_data.dart';
import 'package:hogwarts_life_simulator/models/player.dart';

void main() {
  group('yearGoalPool 数据完整性', () {
    test('每个学年目标都有非空 careerAffinity', () {
      for (final g in yearGoalPool) {
        expect(g.careerAffinity, isNotEmpty,
            reason: '${g.id} 缺少 careerAffinity');
      }
    });

    test('careerAffinity 权重全部为正数', () {
      for (final g in yearGoalPool) {
        for (final entry in g.careerAffinity.entries) {
          expect(entry.value, greaterThan(0),
              reason: '${g.id} -> ${entry.key} 权重非正');
        }
      }
    });

    test('careerAffinity 的 key 都是 lifeGoalCatalog 里存在的 id', () {
      final validIds = lifeGoalCatalog.map((g) => g.id).toSet();
      for (final g in yearGoalPool) {
        for (final key in g.careerAffinity.keys) {
          expect(validIds.contains(key), isTrue,
              reason: '${g.id} 引用了不存在的 LifeGoal.id: $key');
        }
      }
    });
  });

  group('selectYearGoal 主线牵引', () {
    test('主线=傲罗时，带 auror 亲和度的目标被抽中概率显著更高', () {
      // 用 200 个不同 seed 抽样，统计带 auror 亲和度的目标占比
      final aurorAffinityIds = yearGoalPool
          .where((g) => g.careerAffinity.containsKey('auror'))
          .map((g) => g.id)
          .toSet();
      expect(aurorAffinityIds, isNotEmpty);

      var hits = 0;
      const trials = 200;
      for (int i = 0; i < trials; i++) {
        final sub = selectYearGoal(1, seed: i, currentGoalName: '成为傲罗');
        if (aurorAffinityIds.contains(sub.id)) hits++;
      }
      // 无主线时均匀分布下 auror 亲和目标占比 = 4/6 ≈ 0.667
      // 加权后应显著高于此（auror 权重 1.3~1.5，其他 1.0）
      // 期望值约 (1.5+1.3+1.5+1.5)/(1.5+1.3+1.0+1.5+1.5+1.3) ≈ 0.71
      // 用宽松阈值 0.68 避免 flaky
      expect(hits / trials, greaterThan(0.68),
          reason: '主线=傲罗时亲和目标占比应显著高于均匀分布');
    });

    test('主线=魁地奇时，yr_house_cup 被抽中概率显著高于均匀分布', () {
      var hits = 0;
      const trials = 200;
      for (int i = 0; i < trials; i++) {
        final sub = selectYearGoal(1, seed: i, currentGoalName: '成为魁地奇职业球员');
        if (sub.id == 'yr_house_cup') hits++;
      }
      // 均匀分布下 yr_house_cup 占比 = 1/6 ≈ 0.167
      // 加权后 (1.5)/(1.0+1.0+1.5+1.0+1.0+1.0) ≈ 0.214
      expect(hits / trials, greaterThan(0.18),
          reason: '主线=魁地奇时 yr_house_cup 占比应高于均匀分布');
    });

    test('无主线时结果近似均匀分布', () {
      // 无主线时所有权重都是 1.0，等价于均匀随机
      final counts = <String, int>{};
      const trials = 600;
      for (int i = 0; i < trials; i++) {
        final sub = selectYearGoal(1, seed: i);
        counts[sub.id] = (counts[sub.id] ?? 0) + 1;
      }
      // 每个目标占比应在 1/6 ± 15% 内
      for (final g in yearGoalPool) {
        final ratio = (counts[g.id] ?? 0) / trials;
        expect(ratio, inInclusiveRange(0.08, 0.22),
            reason: '${g.id} 占比 $ratio 偏离均匀分布过大');
      }
    });
  });

  group('selectYearGoal 排除近期已用', () {
    test('recentGoalIds 中的 id 不会被抽中', () {
      const recent = ['yr_first_friend', 'yr_professor_favor'];
      for (int i = 0; i < 50; i++) {
        final sub = selectYearGoal(1, seed: i, recentGoalIds: recent);
        expect(recent.contains(sub.id), isFalse,
            reason: 'seed=$i 抽到了近期已用的 ${sub.id}');
      }
    });

    test('recentGoalIds 覆盖全池时回退到全池（不抛异常）', () {
      final allIds = yearGoalPool.map((g) => g.id).toList();
      // 不应抛异常，且返回结果在全池内
      final sub = selectYearGoal(1, seed: 42, recentGoalIds: allIds);
      expect(allIds.contains(sub.id), isTrue);
    });

    test('recentGoalIds 为空时行为与不传一致', () {
      final a = selectYearGoal(1, seed: 7);
      final b = selectYearGoal(1, seed: 7, recentGoalIds: const []);
      expect(a.id, b.id);
    });
  });

  group('selectYearGoal 可复现性', () {
    test('同一 seed 结果一致', () {
      final a = selectYearGoal(2, seed: 123, currentGoalName: '成为傲罗');
      final b = selectYearGoal(2, seed: 123, currentGoalName: '成为傲罗');
      expect(a.id, b.id);
    });

    test('不同 seed 通常给出不同结果', () {
      final ids = <String>{};
      for (int i = 0; i < 20; i++) {
        ids.add(selectYearGoal(1, seed: i).id);
      }
      // 20 次抽样至少应出现 3 种不同目标
      expect(ids.length, greaterThanOrEqualTo(3));
    });
  });

  group('Player.recentYearGoalIds 存档', () {
    test('toJson/fromJson 往返一致', () {
      final p = Player(
        name: '测试',
        birthYear: '1990',
        bloodType: 'pureblood',
        birthLocation: '伦敦',
        recentYearGoalIds: ['yr_first_friend', 'yr_house_cup'],
      );
      final json = p.toJson();
      expect(json['recent_year_goal_ids'], ['yr_first_friend', 'yr_house_cup']);

      final p2 = Player.fromJson(json);
      expect(p2.recentYearGoalIds, ['yr_first_friend', 'yr_house_cup']);
    });

    test('旧档缺省回退到空列表', () {
      final p = Player(
        name: '测试',
        birthYear: '1990',
        bloodType: 'pureblood',
        birthLocation: '伦敦',
      );
      final json = p.toJson();
      json.remove('recent_year_goal_ids'); // 模拟旧档
      final p2 = Player.fromJson(json);
      expect(p2.recentYearGoalIds, isEmpty);
    });
  });
}
