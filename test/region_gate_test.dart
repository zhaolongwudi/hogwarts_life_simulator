import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/game_config_rules.dart';
import 'package:hogwarts_life_simulator/data/locations.dart';

/// 区域门禁统一判定（evaluateRegionGate）的守门测试。
///
/// 【背景·这是一个真实存在的静默缺陷的回归测试】
/// R11 把区域解锁条件数据化（`MapRegionDef.minGrade` / `weekendOnly`），
/// 但数据化只做到"展示层"：`isUnlocked` 只被 `unlockedRegionsFor` /
/// `lockedRegionsFor` 消费，而后者只喂 prompt 文案与 /地点 面板的 🔒 标记。
/// 真正决定玩家能否进入的**状态写入硬门** `blockedByGradeGate` 里，
/// 判定条件是写死的 `detected.contains('霍格莫德') && grade < 3`，于是：
///
///   1. 禁林的 `minGrade: 2` 从未在状态层拦截过——一年级玩家被 AI 写进禁林，
///      `currentLocation` 照样切换；
///   2. 霍格莫德的 `weekendOnly: true` 从未生效——周一到周五也能去；
///   3. `location_gate_test.dart` 的测试组名就叫"霍格莫德年级门"，
///      测试与实现共享同一个盲区，所以测试全绿、缺陷存活。
///
/// 本文件用 `evaluateRegionGate` 把三条都钉死，并额外断言
/// 「配置字段必须有真实消费者」这个结构性约束（见最后一个 group）。
void main() {
  // ============================================================ 禁林（年级门）
  group('禁林 minGrade:2 必须真正生效（原缺陷 1）', () {
    test('一年级进禁林 → 拦，原因是 grade', () {
      final r = evaluateRegionGate(
        detected: '禁林',
        grade: 1,
        isWeekend: false,
      );
      expect(r.isBlocked, isTrue, reason: '一年级玩家不应能进入禁林');
      expect(r.reason, RegionGateReason.grade);
      expect(r.blocked?.name, '禁林');
    });

    test('一年级（grade 为 null，视为一年级）进禁林 → 拦', () {
      final r = evaluateRegionGate(
        detected: '禁林',
        grade: null,
        isWeekend: false,
      );
      expect(r.isBlocked, isTrue);
      expect(r.reason, RegionGateReason.grade);
    });

    test('二年级进禁林 → 放行（周末与否都放行，禁林无周末限制）', () {
      for (final weekend in [true, false]) {
        final r = evaluateRegionGate(
          detected: '禁林',
          grade: 2,
          isWeekend: weekend,
        );
        expect(r.isBlocked, isFalse,
            reason: '二年级已满足 minGrade:2，周末与否不应影响（isWeekend=$weekend）');
      }
    });

    test('禁林别名/带修饰的地点点文本也能命中', () {
      for (final loc in ['禁林深处', '霍格沃茨·禁林', '禁林边缘']) {
        final r = evaluateRegionGate(
          detected: loc,
          grade: 1,
          isWeekend: false,
        );
        expect(r.isBlocked, isTrue, reason: '「$loc」应命中禁林区域定义');
      }
    });

    test('教授带队豁免：一年级 + 带队词 → 放行', () {
      final r = evaluateRegionGate(
        detected: '禁林',
        grade: 1,
        isWeekend: false,
        escortExempt: true,
      );
      expect(r.isBlocked, isFalse,
          reason: '禁林 unlockCondition 明确写了"或由教授带队"');
    });
  });

  // ============================================================ 霍格莫德（周末门）
  group('霍格莫德 weekendOnly:true 必须真正生效（原缺陷 2）', () {
    test('三年级 + 工作日 → 拦，原因是 weekend', () {
      final r = evaluateRegionGate(
        detected: '霍格莫德村',
        grade: 3,
        isWeekend: false,
      );
      expect(r.isBlocked, isTrue, reason: '霍格莫德仅周末开放，工作日不该能去');
      expect(r.reason, RegionGateReason.weekend);
    });

    test('三年级 + 周末 → 放行', () {
      final r = evaluateRegionGate(
        detected: '霍格莫德村',
        grade: 3,
        isWeekend: true,
      );
      expect(r.isBlocked, isFalse);
    });

    test('二年级 + 周末 → 拦（年级优先），原因必须是 grade 而非 weekend', () {
      final r = evaluateRegionGate(
        detected: '霍格莫德村',
        grade: 2,
        isWeekend: true,
      );
      expect(r.isBlocked, isTrue);
      expect(r.reason, RegionGateReason.grade,
          reason: '年级不满足时不应报"仅周末开放"，否则文案会误导玩家');
    });

    test('霍格莫德不享受教授带队豁免（村民通行是制度性的）', () {
      final r = evaluateRegionGate(
        detected: '霍格莫德村',
        grade: 1,
        isWeekend: false,
        escortExempt: true,
      );
      expect(r.isBlocked, isTrue,
          reason: '带队也去不了霍格莫德——它受的是年级+周末双重限制');
    });

    test('霍格莫德子地点（三把扫帚/蜂蜜公爵）能命中', () {
      for (final loc in ['霍格莫德村·三把扫帚', '蜂蜜公爵糖果店', '霍格莫德村·蜂蜜公爵']) {
        final r = evaluateRegionGate(
          detected: loc,
          grade: 1,
          isWeekend: true,
        );
        expect(r.isBlocked, isTrue, reason: '「$loc」应命中霍格莫德村区域定义');
      }
    });
  });

  // ============================================================ 无限制区域
  group('无限制区域不应被误拦', () {
    test('大礼堂 / 图书馆 / 魁地奇球场 / 对角巷 一律放行', () {
      for (final loc in [
        '霍格沃茨大礼堂',
        '霍格沃茨·图书馆',
        '魁地奇球场',
        '对角巷',
        '国王十字车站',
        '家中·卧室',
        '霍格沃茨·宿舍',
      ]) {
        final r = evaluateRegionGate(
          detected: loc,
          grade: 1,
          isWeekend: false,
        );
        expect(r.isBlocked, isFalse, reason: '「$loc」没有门禁，不该被拦');
      }
    });

    test('空字符串不崩且放行', () {
      final r = evaluateRegionGate(detected: '', grade: 1, isWeekend: false);
      expect(r.isBlocked, isFalse);
    });
  });

  // ============================================================ 兼容层
  group('blockedByGradeGate 兼容层行为', () {
    test('霍格莫德低年级仍拦（保持旧行为）', () {
      expect(blockedByGradeGate(detected: '霍格莫德村', grade: 1), isTrue);
      expect(blockedByGradeGate(detected: '霍格莫德村', grade: 2), isTrue);
    });

    test('霍格莫德三年级放行（兼容层不判周末，故工作日也放行）', () {
      expect(blockedByGradeGate(detected: '霍格莫德村', grade: 3), isFalse);
    });

    test('禁林一年级现在也会被拦（这是相对旧实现的**行为变更**，有意为之）', () {
      expect(blockedByGradeGate(detected: '禁林', grade: 1), isTrue,
          reason: '旧实现只认霍格莫德，禁林漏拦；新实现修正为按数据表判定');
      expect(blockedByGradeGate(detected: '禁林', grade: 2), isFalse);
    });

    test('无限制区域放行', () {
      expect(blockedByGradeGate(detected: '对角巷', grade: 1), isFalse);
      expect(blockedByGradeGate(detected: '霍格沃茨大礼堂', grade: 1), isFalse);
    });
  });

  // ============================================================ 结构性约束（本审查的核心发现）
  group('结构性约束：配置字段必须有真实消费者', () {
    test('mapRegions 中带限制的区域，evaluateRegionGate 必须能识别', () {
      for (final region in mapRegions) {
        if (region.minGrade == 0 && !region.weekendOnly) continue;
        final r = evaluateRegionGate(
          detected: region.name,
          grade: 1,
          isWeekend: false,
        );
        expect(r.isBlocked, isTrue,
            reason: '「${region.name}」声明了 minGrade=${region.minGrade} / '
                'weekendOnly=${region.weekendOnly}，但门禁判定认不出它——'
                '这正是"配置字段与判定函数断链"的形态');
        expect(r.blocked?.name, region.name);
      }
    });

    test('regionForLocation 对无限制区域返回 null', () {
      expect(regionForLocation('对角巷'), isNull);
      expect(regionForLocation('霍格沃茨大礼堂'), isNull);
      expect(regionForLocation(''), isNull);
    });

    test('isUnlocked 与 evaluateRegionGate 对同一输入结论一致', () {
      // 两条判定路径必须同源，否则又会出现"展示说能去、实际去不了"。
      for (final region in mapRegions) {
        for (final grade in [1, 2, 3, 4]) {
          for (final weekend in [true, false]) {
            final byData = region.isUnlocked(grade: grade, isWeekend: weekend);
            final byGate = !evaluateRegionGate(
              detected: region.name,
              grade: grade,
              isWeekend: weekend,
            ).isBlocked;
            expect(byGate, byData,
                reason: '${region.name} 在 grade=$grade weekend=$weekend 时，'
                    'isUnlocked=$byData 而 evaluateRegionGate=$byGate，两条判定不一致');
          }
        }
      }
    });
  });

  // ============================================================ 周末判定单点化
  group('isWeekendWeekday 单点定义', () {
    test('0（周日）与 6（周六）为周末', () {
      expect(isWeekendWeekday(0), isTrue);
      expect(isWeekendWeekday(6), isTrue);
    });

    test('1–5 为工作日', () {
      for (final d in [1, 2, 3, 4, 5]) {
        expect(isWeekendWeekday(d), isFalse);
      }
    });
  });
}
